-- LevelGuide Engine: data validation, per-character filtering, quest-log tracking, next-step selection.
-- Pure Lua (no direct WoW API calls; optional callbacks passed in) for offline testing.
local GL = LevelGuide
local E = {}
GL.Engine = E

local function isnum(v) return type(v) == "number" end

-- ---------- validation (bad entries are DROPPED, never crash) ----------
function E.Validate(data)
  local rep = { total = 0, bad = 0, issues = {}, dangling = 0, cycles = 0 }
  local function issue(msg)
    if #rep.issues < 25 then table.insert(rep.issues, msg) end
  end
  if type(data) ~= "table" or type(data.quests) ~= "table" then
    rep.fatal = "data table missing"
    return rep
  end
  data.npc = type(data.npc) == "table" and data.npc or {}
  data.obj = type(data.obj) == "table" and data.obj or {}
  data.zones = type(data.zones) == "table" and data.zones or {}
  local drop = {}
  for id, q in pairs(data.quests) do
    rep.total = rep.total + 1
    local why
    if type(q) ~= "table" then why = "not a table"
    elseif type(q.n) ~= "string" or q.n == "" then why = "no name"
    elseif not isnum(q.l) or not isnum(q.m) then why = "bad level fields"
    elseif type(q.s) ~= "table" or type(q.e) ~= "table" then why = "no giver/turn-in"
    else
      for _, g in ipairs({ q.s, q.e }) do
        local t, nid = g[1], g[2]
        if t == "U" or t == "O" then
          local tbl = (t == "U") and data.npc or data.obj
          local n = tbl[nid]
          if type(n) ~= "table" then why = "unknown npc/object " .. tostring(nid)
          elseif not isnum(n[3]) or not isnum(n[4]) or n[3] < 0 or n[3] > 100 or n[4] < 0 or n[4] > 100 then
            why = "bad coords for " .. tostring(nid)
          elseif type(n[1]) ~= "string" then why = "unnamed npc " .. tostring(nid) end
        elseif t ~= "I" then why = "bad giver type" end
      end
      if not why and q.p ~= nil and type(q.p) ~= "table" then why = "bad prereq field" end
    end
    if why then
      rep.bad = rep.bad + 1
      issue("quest " .. tostring(id) .. ": " .. why)
      table.insert(drop, id)
    end
  end
  for _, id in ipairs(drop) do data.quests[id] = nil end
  for id, q in pairs(data.quests) do
    if q.p then
      local keep = {}
      for _, pid in ipairs(q.p) do
        if pid ~= id then table.insert(keep, pid) end
        if not data.quests[pid] then rep.dangling = rep.dangling + 1 end
      end
      q.p = keep
    end
  end
  local state = {}
  local function visit(id, depth)
    if depth > 200 then return end
    if state[id] == 2 then return end
    if state[id] == 1 then
      rep.cycles = rep.cycles + 1
      local q = data.quests[id]
      if q then q.cyc = true end
      return
    end
    state[id] = 1
    local q = data.quests[id]
    if q and q.p then
      for _, pid in ipairs(q.p) do
        if data.quests[pid] then visit(pid, depth + 1) end
      end
    end
    state[id] = 2
  end
  for id, _ in pairs(data.quests) do visit(id, 0) end
  return rep
end

-- ---------- per-character filtering ----------
local function eligible(q, profile)
  if q.r then
    if profile.raceBit then
      if not GL.HasBit(q.r, profile.raceBit) then return false end
    else
      local f = profile.factionMask or 255
      local ok = false
      for _, b in ipairs({ 1, 2, 4, 8, 16, 32, 64, 128 }) do
        if GL.HasBit(q.r, b) and GL.HasBit(f, b) then ok = true end
      end
      if not ok then return false end
    end
  end
  if q.c and profile.classBit then
    if not GL.HasBit(q.c, profile.classBit) then return false end
  end
  return true
end
E.Eligible = eligible

function E.Build(data, profile)
  local st = { data = data, profile = profile, byTitle = {}, ids = {}, unlocks = {}, n = 0 }
  for id, q in pairs(data.quests) do
    if eligible(q, profile) then
      table.insert(st.ids, id)
      local l = st.byTitle[q.n]
      if not l then l = {} st.byTitle[q.n] = l end
      table.insert(l, id)
    end
  end
  table.sort(st.ids)
  for _, l in pairs(st.byTitle) do table.sort(l) end
  for _, id in ipairs(st.ids) do
    local q = data.quests[id]
    if q and q.p then
      for _, pid in ipairs(q.p) do
        st.unlocks[pid] = (st.unlocks[pid] or 0) + 1
      end
    end
  end
  st.n = #st.ids
  return st
end

local function npcOf(st, g)
  if not g then return nil end
  if g[1] == "U" then return st.data.npc[g[2]] end
  if g[1] == "O" then return st.data.obj[g[2]] end
  return nil
end

local function zoneName(st, zid)
  return st.data.zones[zid] or "?"
end
E.ZoneName = zoneName

-- ---------- quest-log tracking ----------
function E.Resolve(st, title, level)
  local l = st.byTitle[title]
  if not l then return nil end
  local exactMatches = {}
  local allValid = {}
  for _, id in ipairs(l) do
    local q = st.data.quests[id]
    if q then
      allValid[#allValid + 1] = id
      if level and q.l == level then
        exactMatches[#exactMatches + 1] = id
      end
    end
  end
  if #exactMatches == 1 then return exactMatches[1] end
  if #allValid == 1 then return allValid[1] end
  return nil -- ambiguous title/level: rely on exact questID from C_QuestLog.GetInfo
end

function E.Siblings(st, id)
  if not id then return {} end
  return { id } -- exact quest ID only: never mark same-title chain stages done/skipped together
end

-- Exact server-truth sync via C_QuestLog.IsQuestFlaggedCompleted(id)
function E.SyncFromServer(st, db, isCompletedFn)
  if type(isCompletedFn) ~= "function" then return 0 end
  local count = 0
  for _, id in ipairs(st.ids) do
    if not db.done[id] and isCompletedFn(id) then
      db.done[id] = true
      count = count + 1
    end
  end
  return count
end

-- Fallback mid-game sync if server API is unavailable
function E.Sync(st, db, level)
  local c = 0
  for _, id in ipairs(st.ids) do
    local q = st.data.quests[id]
    if q.l <= level - 6 and not db.done[id] then db.done[id] = true c = c + 1 end
  end
  db.synced = level
  return c
end

-- list = array of {questID?, title, level, complete, failed, objectives?}
function E.ApplyLog(st, db, list, abandoned, ready, isCompletedFn)
  local cur = {}
  for _, e in ipairs(list) do
    if e.questID and st.data.quests[e.questID] then
      e.id = e.questID
    else
      e.id = E.Resolve(st, e.title, e.level)
    end
    e.key = e.id and ("id:" .. tostring(e.id)) or (e.title .. "\t" .. tostring(e.level))
    cur[e.key] = e
  end
  local changed = false
  if ready and st.prev then
    local vanished = {}
    for key in pairs(st.prev) do
      if not cur[key] then table.insert(vanished, key) end
    end
    local nv = #vanished
    for _, key in ipairs(vanished) do
      local p = st.prev[key]
      if abandoned and abandoned[p.title] then
        abandoned[p.title] = nil
      elseif p.id then
        local serverDone = type(isCompletedFn) == "function" and isCompletedFn(p.id)
        if serverDone or (p.complete and nv <= 2 and type(isCompletedFn) ~= "function") then
          for _, sid in ipairs(E.Siblings(st, p.id)) do
            if not db.done[sid] then db.done[sid] = true changed = true end
          end
        end
      end
    end
  end
  st.prev = cur
  st.log = list
  return changed
end

-- ---------- availability ----------
local function prereqOk(st, db, q, level)
  if not q.p or q.cyc then return true end
  local any, n = false, 0
  for _, pid in ipairs(q.p) do
    local pq = st.data.quests[pid]
    if pq then
      n = n + 1
      if db.done[pid] then any = true end
      if pq.l <= level - 5 then any = true end
    end
  end
  if n == 0 then return true end
  return any
end

local function window(db)
  if db.settings.mode == "speed" then return 4, 1 end
  return 7, 3
end

function E.Available(st, db, level, inLog)
  local doneN, skipN, logN = 0, 0, 0
  for _ in pairs(db.done or {}) do doneN = doneN + 1 end
  for _ in pairs(db.skipped or {}) do skipN = skipN + 1 end
  for _ in pairs(inLog or {}) do logN = logN + 1 end
  local cKey = string.format("%d:%s:%d:%d:%d", level, tostring(db.settings.mode), doneN, skipN, logN)
  if st._availKey == cKey and st._availCache then return st._availCache end

  local lo, hi = window(db)
  local out = {}
  for _, id in ipairs(st.ids) do
    local q = st.data.quests[id]
    if q and not db.done[id] and not db.skipped[id] and not inLog[id]
       and q.m <= level and q.l >= level - lo and q.l <= level + hi and q.l >= 1
       and q.s[1] ~= "I" and prereqOk(st, db, q, level) then
      table.insert(out, id)
    end
  end
  st._availKey = cKey
  st._availCache = out
  return out
end

local function dist(px, py, n)
  if not px or not py then return nil end
  local dx, dy = px - n[3], py - n[4]
  return math.sqrt(dx * dx + dy * dy)
end

local function samezone(st, n, zone)
  if not zone then return false end
  return string.lower(zoneName(st, n[2])) == string.lower(zone)
end

local function lines_for(st, ids, key, logById)
  local out = {}
  for _, id in ipairs(ids) do
    local q = st.data.quests[id]
    local s = "- " .. q.n .. " (" .. q.l .. ")"
    if key == "obj" then
      local le = logById and logById[id]
      if le and le.objectives and #le.objectives > 0 then
        local parts = {}
        for _, o in ipairs(le.objectives) do
          local suffix = ""
          if not o.finished and o.numRequired and o.numRequired > 0 and o.numFulfilled ~= nil then
            suffix = string.format(" |cffaaaaaa(client: %d/%d)|r", o.numFulfilled, o.numRequired)
          end
          parts[#parts + 1] = (o.finished and "|cff55ff55[Done]|r " or "") .. o.text .. suffix
        end
        s = s .. "\n    " .. table.concat(parts, "\n    ")
      elseif q.o then
        s = s .. ": " .. q.o
      end
    end
    table.insert(out, s)
  end
  return out
end

local function compass(px, py, n)
  local dx, dy = n[3] - px, n[4] - py
  if math.abs(dx) < 1.5 and math.abs(dy) < 1.5 then return "here" end
  local v = (dy < -0.4 * math.abs(dx)) and "N" or ((dy > 0.4 * math.abs(dx)) and "S" or "")
  local h = (dx > 0.4 * math.abs(dy)) and "E" or ((dx < -0.4 * math.abs(dy)) and "W" or "")
  return v .. h
end

local function where(st, n, ctx)
  local z = zoneName(st, n[2])
  local s = n[1] .. " in " .. z .. " (" .. string.format("%.1f", n[3]) .. ", " .. string.format("%.1f", n[4]) .. ")"
  if ctx.zone and not samezone(st, n, ctx.zone) then
    s = s .. "  -- travel to " .. z .. " (you are in " .. ctx.zone .. ")"
  elseif ctx.px then
    local d = dist(ctx.px, ctx.py, n)
    s = s .. "  -- " .. compass(ctx.px, ctx.py, n) .. ", ~" .. string.format("%.0f", d) .. " away"
  end
  return s
end


-- Thorough High-XP/hr scoring helpers (keeps full Thorough quest coverage while ordering by XP/minute)
local function estQuestXP(st, q, playerLevel, xpRate)
  if not q then return 0 end
  local ql = math.max(1, q.l or 1)
  local base = (45 + ql * 5) * (1 + ql * 0.085) * (xpRate or 1.0)
  -- Quest color XP scaling: yellow/orange/green = 100%; grey scales down sharply
  local diff = (playerLevel or 1) - ql
  local grayCut = (playerLevel <= 5 and 5) or (playerLevel <= 39 and (5 + math.floor(playerLevel / 10))) or 9
  local mult = 1.0
  if diff > grayCut then
    mult = math.max(0.15, 1.0 - (diff - grayCut) * 0.20)
  elseif diff >= -2 and diff <= 2 then
    mult = 1.15 -- sweet-spot yellow quests = fastest kill speed + full XP
  elseif diff < -3 then
    mult = 0.70 -- deep orange/red = slower kill time / higher death risk
  end
  -- Chain starter bonus: quests that unlock follow-ups multiply hub XP/hr
  local chainBonus = (st.unlocks and st.unlocks[q._id or 0]) and 1.25 or 1.0
  return base * mult * chainBonus
end

local function estWalkMinutes(distUnits, playerLevel, crossZone)
  if crossZone then return 4.5 end
  local d = distUnits or 25
  local yds = d * 15 -- approx ~15 yd per map unit average
  local spd = (playerLevel and playerLevel >= 40) and 11.2 or 7.0
  return (yds / spd) / 60
end

-- ---------- next step ----------
function E.Next(st, db, ctx)
  local level = ctx.level or 1
  local inLog, logById = {}, {}
  local complete, incomplete = {}, {}
  for _, e in ipairs(st.log or {}) do
    if e.id then
      logById[e.id] = e
      for _, sid in ipairs(E.Siblings(st, e.id)) do inLog[sid] = true end
      if e.complete then table.insert(complete, e) elseif not e.failed then table.insert(incomplete, e) end
    end
  end
  local step = { kind = "NONE", header = "", lines = {}, level = level }
  local advisories = {}
  local maxQ = ctx.maxQuests or 20
  if (ctx.logCount or 0) >= maxQ then
    table.insert(advisories, "Quest log is full (" .. tostring(maxQ) .. "): finish or abandon a quest.")
  end
  if ctx.dead then
    table.insert(advisories, "You are dead — release spirit and run back to your corpse.")
  end

  -- 1) turn-ins
  if #complete > 0 then
    local groups = {}
    for _, e in ipairs(complete) do
      local q = st.data.quests[e.id]
      local n = npcOf(st, q.e)
      local k = q.e[1] .. q.e[2]
      if not groups[k] then groups[k] = { n = n, ids = {} } end
      table.insert(groups[k].ids, e.id)
    end
    local best, bk
    for k, g in pairs(groups) do
      local score = 1e9
      if g.n then
        score = samezone(st, g.n, ctx.zone) and 0 or 1000
        local d = dist(ctx.px, ctx.py, g.n)
        if d and samezone(st, g.n, ctx.zone) then score = score + d end
      end
      if not best or score < best or (score == best and k < bk) then best, bk = score, k end
    end
    local g = groups[bk]
    step.kind = "TURNIN"
    step.header = "Turn in"
    step.lines = lines_for(st, g.ids)
    if g.n then
      step.target = g.n
      step.targetZone = zoneName(st, g.n[2])
      step.where = where(st, g.n, ctx)
    end
    step.ids = g.ids
  end

  -- 2) pick-up hubs
  local avail = E.Available(st, db, level, inLog)
  local hub
  if #avail > 0 then
    local hubs = {}
    for _, id in ipairs(avail) do
      local q = st.data.quests[id]
      local n = npcOf(st, q.s)
      if n then
        local k = q.s[1] .. q.s[2]
        local h = hubs[k]
        if not h then h = { n = n, ids = {}, key = k, z = n[2], seen = {} } hubs[k] = h end
        local dk = q.n .. "\t" .. q.l
        if not h.seen[dk] then
          h.seen[dk] = true
          table.insert(h.ids, id)
        end
      end
    end
    local zcount = {}
    local curHas = false
    for _, h in pairs(hubs) do
      zcount[h.z] = (zcount[h.z] or 0) + #h.ids
      if samezone(st, h.n, ctx.zone) then curHas = true end
    end
    local bestZ
    if not curHas then
      for z, c in pairs(zcount) do
        if not bestZ or c > zcount[bestZ] or (c == zcount[bestZ] and z < bestZ) then bestZ = z end
      end
    end
    local bestScore
    for k, h in pairs(hubs) do
      local ok = curHas and samezone(st, h.n, ctx.zone) or (not curHas and h.z == bestZ)
      if ok then
        local d = dist(ctx.px, ctx.py, h.n) or 0
        local lvl = 0
        for _, id in ipairs(h.ids) do lvl = lvl + math.abs(st.data.quests[id].l - level) end
        local nearbyClusterQuests = 0
        for okk, oh in pairs(hubs) do
          if okk ~= k and oh.z == h.z then
            local hd = math.sqrt((oh.n[3] - h.n[3]) ^ 2 + (oh.n[4] - h.n[4]) ^ 2)
            if hd <= 6 then nearbyClusterQuests = nearbyClusterQuests + #oh.ids end
          end
        end
        -- Thorough High-XP/hr hub score: negate XP/minute so lower score wins
        local xpRate = (db.settings and tonumber(db.settings.xpRate)) or 1.0
        local hubXP = 0
        for _, id in ipairs(h.ids) do
          local q = st.data.quests[id]
          if q then q._id = id hubXP = hubXP + estQuestXP(st, q, level, xpRate) end
        end
        hubXP = hubXP + (nearbyClusterQuests * (45 + level * 5) * 0.65)
        local walkMin = estWalkMinutes(d, level, not samezone(st, h.n, ctx.zone))
        local estMin = math.max(0.35, walkMin + (#h.ids * 0.25))
        local xpPerMin = hubXP / estMin
        h.xpPerHr = math.floor(xpPerMin * 60 + 0.5)
        h.score = -xpPerMin
        if not bestScore or h.score < bestScore or (h.score == bestScore and k < hub.key) then
          bestScore, hub = h.score, h
        end
      end
    end
  end

  -- 3) 200-IQ Area Quest Cluster Optimizer: finish same-hub quests before walking back to turn in!
  local deferTurnIn = false
  if step.kind == "TURNIN" and #incomplete > 0 and (ctx.logCount or 0) < maxQ then
    local clusterOn = not (db.settings and db.settings.clusterRoute == false)
    if clusterOn and step.target then
      local turnInDist = (ctx.px and samezone(st, step.target, ctx.zone)) and dist(ctx.px, ctx.py, step.target) or 999
      local turnInCrossZone = ctx.zone and not samezone(st, step.target, ctx.zone)
      -- Defer turn-in if turn-in is far (> 10 units) OR cross-zone AND we have active quests in our current zone or same hub!
      if turnInCrossZone or turnInDist > 10 then
        local localInc = 0
        for _, inc in ipairs(incomplete) do
          local iq = st.data.quests[inc.id]
          local itn = iq and npcOf(st, iq.e)
          local isn = iq and npcOf(st, iq.s)
          local inCurZone = (itn and samezone(st, itn, ctx.zone)) or (isn and samezone(st, isn, ctx.zone))
          local sameHub = (itn and itn[2] == step.target[2] and math.sqrt((itn[3] - step.target[3]) ^ 2 + (itn[4] - step.target[4]) ^ 2) <= 18)
          if inCurZone or sameHub then localInc = localInc + 1 end
        end
        if localInc > 0 then
          local sameHubInc = localInc
          deferTurnIn = true
          step.deferredTurnInCount = #complete
          step.deferredTurnInNpc = step.target[1]
          table.insert(advisories, string.format(
            "Cluster Route: Finish %d active quest(s) in this area first, then batch turn-in (%d ready) at %s — saves walking!",
            sameHubInc, #complete, tostring(step.target[1])
          ))
          step.kind = "NONE" -- fall through to OBJECTIVE / nearby PICKUP
          step.target = nil
          step.where = nil
        end
      end
    end
  end

  if step.kind == "TURNIN" then
    if #step.ids > 1 then
      step.header = string.format("Batch Turn-In (%d quests!)", #step.ids)
    end
    if #incomplete > 0 then
      local qn = st.data.quests[incomplete[1].id]
      step.nextPreview = "Objective: " .. (qn and qn.n or "active quest")
    elseif hub then
      step.nextPreview = "Pick up at " .. hub.n[1] .. " (" .. zoneName(st, hub.n[2]) .. ")"
    end
  elseif #incomplete > 0 then
    local near = false
    if hub and (ctx.logCount or 0) < maxQ and ctx.px and samezone(st, hub.n, ctx.zone) and dist(ctx.px, ctx.py, hub.n) <= 10 then
      near = true
    end
    if near then
      step.kind = "PICKUP"
      local qn = st.data.quests[incomplete[1].id]
      step.nextPreview = "Complete: " .. (qn and qn.n or "active quest")
    else
      step.kind = "OBJECTIVE"
      step.header = "Complete objectives"
      local ids = {}
      for _, e in ipairs(incomplete) do table.insert(ids, e.id) end
      local xpRate = (db.settings and tonumber(db.settings.xpRate)) or 1.0
      local function objScore(qid)
        local q = st.data.quests[qid]
        if not q then return 1e9 end
        q._id = qid
        local n = npcOf(st, q.e) or npcOf(st, q.s)
        local crossZ = not (n and samezone(st, n, ctx.zone))
        local d = (n and ctx.px and not crossZ) and (dist(ctx.px, ctx.py, n) or 25) or 25
        local rem = 5
        local le = logById[qid]
        if le and le.objectives and #le.objectives > 0 then
          rem = 0
          for _, o in ipairs(le.objectives) do
            if not o.finished then rem = rem + math.max(1, (o.numRequired or 1) - (o.numFulfilled or 0)) end
          end
        end
        local xpVal = estQuestXP(st, q, level, xpRate)
        local walkMin = estWalkMinutes(d, level, crossZ)
        local workMin = math.max(0.4, math.min(25, rem) * 0.35)
        local xpPerMin = xpVal / (walkMin + workMin)
        -- Return negative XP/min (with strong same-zone bonus) so highest local XP/hr sorts #1!
        return (crossZ and 10000 or 0) - xpPerMin
      end
      table.sort(ids, function(a, b)
        local sa, sb = objScore(a), objScore(b)
        if sa ~= sb then return sa < sb end
        return a < b
      end)
      step.lines = lines_for(st, ids, "obj", logById)
      step.ids = ids
      local q1 = st.data.quests[ids[1]]
      local tn = npcOf(st, q1.e)
      if tn then
        step.target = tn
        step.targetZone = zoneName(st, tn[2])
        step.where = "Turn-in after objectives: " .. where(st, tn, ctx) .. " (mob spawns: see Questie/map)"
        step.targetIsTurnIn = true
        step.nextPreview = "Turn in to " .. tn[1] .. " (" .. step.targetZone .. ")"
      end
    end
  elseif hub and (ctx.logCount or 0) < maxQ then
    step.kind = "PICKUP"
  end

  if step.kind == "PICKUP" then
    table.sort(hub.ids)
    step.header = "Pick up"
    step.lines = lines_for(st, hub.ids)
    step.target = hub.n
    step.targetZone = zoneName(st, hub.n[2])
    step.where = where(st, hub.n, ctx)
    step.ids = hub.ids
    if not step.nextPreview and #hub.ids > 0 then
      local q1 = st.data.quests[hub.ids[1]]
      step.nextPreview = "Do objectives for " .. (q1 and q1.n or "new quests")
    end
  elseif step.kind == "NONE" then
    step.header = "No quests in level " .. level .. " window"
    step.lines = {
      "Nothing left in your current level window.",
      "Check the Dungeons or Grinding tab, or try /guide mode thorough or /guide unskip.",
    }
  end

  -- Milestone & level-up reminders
  if ctx.levelUp then
    if GL.mod(level, 2) == 0 then table.insert(advisories, "Level " .. level .. ": visit your class trainer for new spells.") end
    if level == 10 then table.insert(advisories, "Level 10 breakpoint: talents unlocked + class quest (Warrior Stance / Hunter Pet / Warlock Voidwalker).") end
    if level == 20 then table.insert(advisories, "Level 20 breakpoint: check class quest & weapon masters.") end
    if level == 30 then table.insert(advisories, "Level 30 breakpoint: class quest chain (e.g., Whirlwind Weapon / mounts).") end
    if level == 40 then table.insert(advisories, "Level 40 breakpoint: Riding Skill (60% mount) & class mount quests.") end
    if level == 48 then table.insert(advisories, "Level 48+ (Forever): most quests Lv 48+ now award bonus gold — complete them while leveling!") end
    if level == 50 then table.insert(advisories, "Level 50 breakpoint: Sunken Temple class quest available.") end
    if level == 60 then table.insert(advisories, "Level 60 reached! Check attunements & endgame dungeons.") end
  end
  step.advisories = advisories
  step.hubSummary = string.format("Ready: %d  |  Active: %d  |  Available nearby: %d", #complete, #incomplete, #avail)

  -- Action-by-action step-by-step walkthrough ("Walk here -> Talk to NPC -> Kill/Collect -> Turn in")
  local wt = {}
  local function dirText(n)
    if not n then return "the target area" end
    local z = zoneName(st, n[2])
    local coords = string.format("(%.1f, %.1f) in %s", n[3], n[4], z)
    if ctx.zone and not samezone(st, n, ctx.zone) then
      return "Travel to " .. z .. " " .. coords
    elseif ctx.px then
      local c = compass(ctx.px, ctx.py, n)
      local d = dist(ctx.px, ctx.py, n)
      if c == "here" then return "You are right next to " .. n[1] .. " " .. coords end
      return string.format("Walk %s (~%.0f map units) to %s %s", c, d, n[1], coords)
    end
    return "Go to " .. n[1] .. " " .. coords
  end

  if step.kind == "PICKUP" and step.target then
    wt[#wt + 1] = "1. " .. dirText(step.target) .. " (follow arrow & minimap dots)."
    local qNames = {}
    for _, id in ipairs(step.ids or {}) do
      local q = st.data.quests[id]
      if q then qNames[#qNames + 1] = q.n end
    end
    wt[#wt + 1] = "2. Talk to |cfff0c252" .. tostring(step.target[1]) .. "|r and ACCEPT: " .. table.concat(qNames, ", ") .. "."
    if step.nextPreview then
      wt[#wt + 1] = "3. Next: " .. tostring(step.nextPreview) .. "."
    end
  elseif step.kind == "OBJECTIVE" then
    local idx = 1
    for _, id in ipairs(step.ids or {}) do
      local q = st.data.quests[id]
      local le = logById[id]
      if q then
        if le and le.objectives and #le.objectives > 0 then
          for _, o in ipairs(le.objectives) do
            if not o.finished then
              local verb = (o.objType == "monster") and "Kill: " or ((o.objType == "item") and "Kill/Loot: " or "Complete: ")
              local rem = (o.numRequired and o.numRequired > 0 and o.numFulfilled ~= nil)
                and string.format(" (client: %d/%d)", o.numFulfilled, o.numRequired) or ""
              wt[#wt + 1] = string.format("%d. %s%s%s [%s]", idx, verb, tostring(o.text), rem, q.n)
              idx = idx + 1
            end
          end
        else
          wt[#wt + 1] = string.format("%d. Complete objectives for %s%s", idx, q.n, q.o and (": " .. q.o) or "")
          idx = idx + 1
        end
      end
    end
    if step.target then
      wt[#wt + 1] = string.format("%d. When done, return to |cff55ff55%s|r at (%.1f, %.1f) in %s.",
        idx, tostring(step.target[1]), step.target[3], step.target[4], zoneName(st, step.target[2]))
    end
  elseif step.kind == "TURNIN" and step.target then
    wt[#wt + 1] = "1. " .. dirText(step.target) .. " (follow arrow & minimap dots)."
    local qNames = {}
    for _, id in ipairs(step.ids or {}) do
      local q = st.data.quests[id]
      if q then qNames[#qNames + 1] = q.n end
    end
    wt[#wt + 1] = "2. Talk to |cff55ff55" .. tostring(step.target[1]) .. "|r and TURN IN: " .. table.concat(qNames, ", ") .. "."
    wt[#wt + 1] = "3. Grab any follow-up quests, sell grey junk, and check nearby trainer."
  end
  step.walkthrough = wt
  return step
end

function E.Progress(level, xp, xpmax)
  local f = 0
  if xpmax and xpmax > 0 and xp then f = xp / xpmax end
  local p = ((level or 1) - 1 + f) / 59
  if p < 0 then p = 0 elseif p > 1 then p = 1 end
  return p
end

-- Scan for the nearest high-XP/hr quest hub / leveling area from player's current position
function E.ScanNearestArea(st, db, ctx)
  local level = ctx.level or 1
  local inLog = {}
  for _, e in ipairs(st.log or {}) do
    if e.id then inLog[e.id] = true end
  end
  local avail = E.Available(st, db, level, inLog)
  if #avail == 0 then return nil end

  local hubs = {}
  for _, id in ipairs(avail) do
    local q = st.data.quests[id]
    local n = q and npcOf(st, q.s)
    if n then
      local k = q.s[1] .. q.s[2]
      local h = hubs[k]
      if not h then h = { n = n, ids = {}, z = n[2], zone = zoneName(st, n[2]) } hubs[k] = h end
      h.ids[#h.ids + 1] = id
    end
  end

  local best, bestScore = nil, 1e9
  local xpRate = (db.settings and tonumber(db.settings.xpRate)) or 1.0
  for _, h in pairs(hubs) do
    local sameZ = samezone(st, h.n, ctx.zone)
    local d = (ctx.px and sameZ) and (dist(ctx.px, ctx.py, h.n) or 50) or 100
    local hubXP = 0
    for _, id in ipairs(h.ids) do
      local q = st.data.quests[id]
      if q then q._id = id hubXP = hubXP + estQuestXP(st, q, level, xpRate) end
    end
    -- Strong nearest-area bias in current zone, else highest-density leveling zone for your level
    local score = sameZ and ((d * 2.5) - math.min(20, #h.ids * 3) - (hubXP / 500)) or (5000 - (#h.ids * 25) - (hubXP / 200))
    if score < bestScore then
      bestScore = score
      best = h
      best.distUnits = d
      best.sameZone = sameZ
    end
  end
  return best
end
