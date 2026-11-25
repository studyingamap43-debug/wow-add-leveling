-- LevelGuide Core: namespace, logging, safe-call, bit helpers, profile detection, saved-variable migration.
-- Extended for WoW: Forever 1.60.1 (Interface 16001 / Lua 5.1) while preserving LevelGuideDB compatibility.
LevelGuide = LevelGuide or {}
local GL = LevelGuide
GL.version = "1.2.9"
GL.DBVERSION = 13
GL.errors = GL.errors or {}
GL.events = GL.events or {}
GL.errPrinted = 0
BINDING_HEADER_LEVELGUIDE = "LevelGuide"
BINDING_NAME_LEVELGUIDE_TOGGLE = "Toggle LevelGuide Window"
BINDING_NAME_LEVELGUIDE_NEXT = "Next / Skip Step"
BINDING_NAME_LEVELGUIDE_PREV = "Undo Last Skip"
BINDING_NAME_LEVELGUIDE_SKIP = "Next / Skip Step (legacy name)"
BINDING_NAME_LEVELGUIDE_PIN = "Pin Active Waypoint"
BINDING_NAME_LEVELGUIDE_SPEAK = "Speak Current Step (TTS)"
BINDING_NAME_LEVELGUIDE_RESYNC = "Recalibrate Quest Log"
_G["BINDING_NAME_CLICK LevelGuideTargetButton:LeftButton"] = "Target Active Quest Mob / NPC"

local function strip(s) return tostring(s) end

function GL.Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99LevelGuide:|r " .. strip(msg))
  else
    print("[LevelGuide] " .. strip(msg))
  end
end

-- ring buffer of the last 20 events
function GL.LogEvent(name, info)
  local t = GL.events
  local ts = (GetTime and string.format("%.1f", GetTime())) or "0.0"
  table.insert(t, "[" .. ts .. "] " .. strip(name) .. (info and (" " .. strip(info)) or ""))
  while #t > 20 do table.remove(t, 1) end
end

function GL.Err(where, err)
  local t = GL.errors
  local ts = (date and date("%H:%M:%S")) or "offline"
  table.insert(t, "[" .. ts .. "] " .. strip(where) .. ": " .. strip(err))
  while #t > 50 do table.remove(t, 1) end
  if GL.errPrinted < 5 then
    GL.errPrinted = GL.errPrinted + 1
    GL.Print("|cffff4444error|r in " .. strip(where) .. ": " .. strip(err) .. "  (/guide debug)")
  end
end

function GL.Safe(where, fn, ...)
  local ok, res = pcall(fn, ...)
  if not ok then GL.Err(where, res) return nil end
  return res
end

GL.mod = math.fmod or math.mod

function GL.Try(obj, method, ...)
  if obj and type(obj[method]) == "function" then
    local ok, err = pcall(obj[method], obj, ...)
    if not ok then GL.Err("ui:" .. tostring(method), err) end
  end
end

function GL.HasBit(mask, bit)
  if type(mask) ~= "number" or type(bit) ~= "number" or bit <= 0 then return false end
  return GL.mod(math.floor(mask / bit), 2) == 1
end

GL.RACEBITS = {
  Human = 1, Orc = 2, Dwarf = 4, ["Night Elf"] = 8, NightElf = 8,
  Undead = 16, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128,
  -- WoW: Forever Skyborne (Alliance High Order / Horde Windshaper fall back to factionMask in Engine.Eligible)
  Skyborne = nil, ["High Order Skyborne"] = nil, ["Windshaper Skyborne"] = nil,
}
GL.CLASSBITS = {
  Warrior = 1, Paladin = 2, Hunter = 4, Rogue = 8, Priest = 16,
  Shaman = 32, Mage = 64, Warlock = 128, Druid = 1024,
}
GL.FACTIONMASK = { Alliance = 77, Horde = 178 }

-- Identify THIS character. Everything else keys off this, so other sides/races/classes are never loaded.
function GL.DetectProfile()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local race, raceTok, raceID
  if UnitRace then race, raceTok, raceID = UnitRace("player") end
  local class, tok
  if UnitClass then class, tok = UnitClass("player") end
  local p = { race = race or "?", raceToken = raceTok or race or "?", raceID = raceID, class = class or "?", classToken = tok or "?" }
  p.raceBit = (race and GL.RACEBITS[race]) or (raceTok and GL.RACEBITS[raceTok]) or nil
  local tokLo = string.lower(tostring(raceTok or ""))
  local raceLo = string.lower(tostring(race or ""))
  -- Token/name only. raceID>8 was an invented heuristic and can false-flag unknown IDs.
  p.isSkyborne = (string.find(tokLo, "skyborne", 1, true) ~= nil) or (string.find(raceLo, "skyborne", 1, true) ~= nil)
  if (p.isSkyborne or not p.raceBit) and not GL._unknownRaceLogged then
    GL._unknownRaceLogged = true
    GL.Print(string.format("UnitRace snapshot -> name=%q token=%q raceID=%s faction=%s skyborne=%s raceBit=%s",
      tostring(race), tostring(raceTok), tostring(raceID), tostring(faction), tostring(p.isSkyborne), tostring(p.raceBit)))
  end
  local cb
  if tok and type(tok) == "string" then
    local cap = string.upper(string.sub(tok, 1, 1)) .. string.lower(string.sub(tok, 2))
    cb = GL.CLASSBITS[cap]
  end
  if not cb and class then cb = GL.CLASSBITS[class] end
  p.classBit = cb
  if not faction or not GL.FACTIONMASK[faction] then
    if p.raceBit and GL.HasBit(77, p.raceBit) then faction = "Alliance"
    elseif p.raceBit and GL.HasBit(178, p.raceBit) then faction = "Horde"
    else faction = nil end
  end
  p.faction = faction
  p.factionMask = faction and GL.FACTIONMASK[faction] or 255
  p.key = tostring(faction) .. "/" .. tostring(p.race) .. "/" .. tostring(p.class)
  return p
end

-- Per-character saved variables, versioned with non-destructive migration (v1 -> v2).
function GL.InitDB(profile)
  if type(LevelGuideDB) ~= "table" then LevelGuideDB = {} end
  local db = LevelGuideDB
  if type(db.version) ~= "number" then db.version = 0 end
  if db.version < 1 then
    db.done = type(db.done) == "table" and db.done or {}
    db.skipped = type(db.skipped) == "table" and db.skipped or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    db.ui = type(db.ui) == "table" and db.ui or {}
    db.version = 1
  end
  if db.version < 2 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.xpRate == nil then db.settings.xpRate = 1.0 end
    if db.settings.skipEliteSolo == nil then db.settings.skipEliteSolo = false end
    if db.settings.autoPin == nil then db.settings.autoPin = true end
    if db.settings.useTomTom == nil then db.settings.useTomTom = true end
    if db.settings.cheapestRoute == nil then db.settings.cheapestRoute = true end
    if db.settings.prof1 == nil then db.settings.prof1 = "First Aid" end
    if db.settings.prof2 == nil then db.settings.prof2 = "Cooking" end
    if db.setupDone == nil then db.setupDone = false end
    db.version = 2
  end
  if db.version < 3 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.locked == nil then db.settings.locked = false end
    if db.settings.opacity == nil then db.settings.opacity = 1.0 end
    if db.settings.miniMode == nil then db.settings.miniMode = false end
    if db.settings.showMinimap == nil then db.settings.showMinimap = true end
    db.discoveries = type(db.discoveries) == "table" and db.discoveries or {}
    db.flightPaths = type(db.flightPaths) == "table" and db.flightPaths or {}
    db.version = 3
  end
  if db.version < 4 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.theme == nil then db.settings.theme = "DarkGold" end
    if db.settings.voiceEnabled == nil then db.settings.voiceEnabled = true end
    if db.settings.voiceRate == nil then db.settings.voiceRate = 0 end
    if db.settings.voiceVolume == nil then db.settings.voiceVolume = 80 end
    db.timer = type(db.timer) == "table" and db.timer or { currentLevelSec = 0, totalPlayedGuideSec = 0 }
    db.splits = type(db.splits) == "table" and db.splits or {}
    db.version = 4
  end
  if db.version < 5 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.arrowEnabled == nil then db.settings.arrowEnabled = true end
    if db.settings.arrowLocked == nil then db.settings.arrowLocked = false end
    db.version = 5
  end
  if db.version < 6 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.trailEnabled == nil then db.settings.trailEnabled = true end
    db.version = 6
  end
  if db.version < 7 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.fontSize == nil then db.settings.fontSize = 12 end
    if db.settings.clusterRoute == nil then db.settings.clusterRoute = true end
    db.stepHistory = type(db.stepHistory) == "table" and db.stepHistory or {}
    db.lastSkipped = type(db.lastSkipped) == "table" and db.lastSkipped or {}
    db.version = 7
  end
  if db.version < 8 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.arrowScale == nil then db.settings.arrowScale = 1.0 end
    db.lastGoodBackup = { version = db.version, profileKey = db.profileKey }
    db.version = 8
  end
  if db.version < 9 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.useQuestieSpawns == nil then db.settings.useQuestieSpawns = true end
    db.version = 9
  end
  if db.version < 10 then
    db.settings = type(db.settings) == "table" and db.settings or {}
    if db.settings.hcWarnings == nil then db.settings.hcWarnings = true end
    if db.settings.autoQuest == nil then db.settings.autoQuest = false end
    db.version = 10
  end
  if db.version < 11 then
    db.stepChecks = type(db.stepChecks) == "table" and db.stepChecks or {}
    db.version = 11
  end
  if db.version < 12 then
    db.skippedDungeons = type(db.skippedDungeons) == "table" and db.skippedDungeons or {}
    db.version = 12
  end
  if db.version < 13 then
    db.ignoredQuests = type(db.ignoredQuests) == "table" and db.ignoredQuests or {}
    db.version = 13
  end
  if type(db.done) ~= "table" then db.done = {} end
  if type(db.skipped) ~= "table" then db.skipped = {} end
  if type(db.ignoredQuests) ~= "table" then db.ignoredQuests = {} end
  if type(db.skippedDungeons) ~= "table" then db.skippedDungeons = {} end
  if type(db.settings) ~= "table" then db.settings = {} end
  if type(db.ui) ~= "table" then db.ui = {} end
  if db.settings.mode ~= "speed" and db.settings.mode ~= "thorough" then
    db.settings.mode = "thorough"
  end
  if db.profileKey and db.profileKey ~= profile.key then
    GL.Print("Character profile changed (" .. db.profileKey .. " -> " .. profile.key .. "): progress reset.")
    db.done = {}
    db.skipped = {}
    db.ignoredQuests = {}
    db.synced = nil
  end
  db.profileKey = profile.key
  return db
end

function GL.BuildDiagnosticString()
  local p = GL.profile or {}
  local lines = {}
  lines[#lines + 1] = "=== LevelGuide v" .. tostring(GL.version) .. " Diagnostic Report ==="
  if GL.Compat then
    lines[#lines + 1] = "Client: " .. GL.Compat.GetBuildString()
    lines[#lines + 1] = "Memory: " .. string.format("%.1f KB", GL.Compat.GetMemoryKB())
  end
  lines[#lines + 1] = string.format("Profile: %s (raceBit=%s, classBit=%s, loaded=%s)",
    tostring(p.key), tostring(p.raceBit), tostring(p.classBit), tostring(GL.loadedFaction))
  lines[#lines + 1] = string.format("Char: Lv %s | Zone: %s | Ready: %s | Dead: %s",
    tostring(UnitLevel and UnitLevel("player") or "?"),
    tostring(GL.lastCtx and GL.lastCtx.zone or "?"),
    tostring(GL.ready),
    tostring(GL.Compat and GL.Compat.IsPlayerDead() or false))
  local s = GL.step
  lines[#lines + 1] = string.format("Step: [%s] %s | Where: %s",
    tostring(s and s.kind or "NONE"), tostring(s and s.header or "-"), tostring(s and s.where or "-"))
  if GL.report then
    lines[#lines + 1] = string.format("Data: total=%d bad=%d cycles=%d dangling=%d",
      GL.report.total or 0, GL.report.bad or 0, GL.report.cycles or 0, GL.report.dangling or 0)
  end
  if GL.Integrations then
    lines[#lines + 1] = GL.Integrations.GetSummaryLine()
  end
  if GL.QuestieBridge then
    lines[#lines + 1] = GL.QuestieBridge.GetStatusString()
  end
  lines[#lines + 1] = string.format("Hardened Checks: Gossip=%s | ActionBar=%s | Skyborne=%s (rawToken=%s, raceID=%s)",
    tostring(GL.AutoQuest and GL.AutoQuest.GetGossipMode and GL.AutoQuest.GetGossipMode() or "?"),
    tostring(GL.ActionBar and GL.ActionBar.mode or "?"),
    tostring(p.isSkyborne), tostring(p.raceToken), tostring(p.raceID))
  local hasCanvas = (WorldMapFrame and type(WorldMapFrame.GetCanvas) == "function") and true or false
  local canvasValid = false
  if hasCanvas then
    local okC, cv = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
    canvasValid = okC and cv ~= nil
  end
  local viewRad = "N/A"
  if C_Minimap and C_Minimap.GetViewRadius then
    local okR, rv = pcall(C_Minimap.GetViewRadius)
    if okR and rv then viewRad = tostring(rv) end
  end
  local allyLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LevelGuide_Data_Alliance")) and true or false
  local hordeLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LevelGuide_Data_Horde")) and true or false
  lines[#lines + 1] = string.format("API Probes: GetCanvas=%s (valid=%s) | MinimapViewRadius=%s | issecretvalue=%s | issecrettable=%s",
    tostring(hasCanvas), tostring(canvasValid), tostring(viewRad), tostring(type(issecretvalue) == "function"), tostring(type(issecrettable) == "function"))
  lines[#lines + 1] = string.format("Data AddOns Loaded: Alliance=%s | Horde=%s", tostring(allyLoaded), tostring(hordeLoaded))
  local log = (GL.state and GL.state.log) or {}
  lines[#lines + 1] = "Active Quests (" .. tostring(#log) .. "):"
  for _, e in ipairs(log) do
    lines[#lines + 1] = string.format("  [%s] %s (complete=%s)", tostring(e.id or "?"), tostring(e.title), tostring(e.complete))
    for _, o in ipairs(e.objectives or {}) do
      lines[#lines + 1] = string.format("    type=%s %s/%s fin=%s | %s",
        tostring(o.objectiveType or o.objType or "?"), tostring(o.numFulfilled or "?"), tostring(o.numRequired or "?"), tostring(o.finished), tostring(o.text))
    end
  end
  lines[#lines + 1] = "--- Last 20 Events ---"
  if #GL.events == 0 then
    lines[#lines + 1] = "(none)"
  else
    for i = 1, #GL.events do lines[#lines + 1] = GL.events[i] end
  end
  lines[#lines + 1] = "--- Errors (" .. tostring(#GL.errors) .. ") ---"
  if #GL.errors == 0 then
    lines[#lines + 1] = "(none)"
  else
    for i = 1, #GL.errors do lines[#lines + 1] = GL.errors[i] end
  end
  return table.concat(lines, "\n")
end

function GL.BuildAIContextExport()
  local p = GL.profile or {}
  local ctx = GL.lastCtx or {}
  local lines = {
    "=== LevelGuide AI Context Export (Offline Snapshot) ===",
    string.format("Addon: LevelGuide v%s | Client: %s", tostring(GL.version), GL.Compat and GL.Compat.GetBuildString() or "?"),
    string.format("Character: %s | Level: %s | Zone: %s (%.1f, %.1f)",
      tostring(p.key), tostring(ctx.level or "?"), tostring(ctx.zone or "?"), tonumber(ctx.px or 0), tonumber(ctx.py or 0)),
    string.format("Mode: %s | InGroup: %s | InInstance: %s",
      tostring(GL.db and GL.db.settings.mode or "?"), tostring(ctx.inGroup), tostring(ctx.inInstance)),
    "--- Active Quest Log ---",
  }
  local log = (GL.state and GL.state.log) or {}
  if #log == 0 then
    lines[#lines + 1] = "(none)"
  else
    for _, e in ipairs(log) do
      local status = e.complete and "[READY]" or "[IN PROGRESS]"
      lines[#lines + 1] = string.format("  [%s] %s (Lv %s) %s", tostring(e.id or "?"), tostring(e.title), tostring(e.level), status)
      for _, o in ipairs(e.objectives or {}) do
        local rem = (o.numRequired and o.numRequired > 0) and string.format(" (%d/%d)", o.numFulfilled or 0, o.numRequired) or ""
        lines[#lines + 1] = "    - " .. tostring(o.text) .. rem
      end
    end
  end
  if GL.Metrics then
    local xph, ttl = GL.Metrics.GetStats()
    lines[#lines + 1] = string.format("--- Pace: %d XP/hr | Est TTL: %sm ---", xph, tostring(ttl or "?"))
  end
  return table.concat(lines, "\n")
end

function GL.RecordStepHistory(label)
  if not GL.db or not label or label == "" then return end
  GL.db.stepHistory = type(GL.db.stepHistory) == "table" and GL.db.stepHistory or {}
  local h = GL.db.stepHistory
  if h[#h] and h[#h].label == label then return end
  local ts = (date and date("%H:%M")) or "00:00"
  h[#h + 1] = { ts = ts, label = label }
  while #h > 15 do table.remove(h, 1) end
end

function GL.GetLastStepText()
  local h = GL.db and GL.db.stepHistory
  if type(h) == "table" and #h > 0 then
    local last = h[#h]
    return string.format("[%s] %s", tostring(last.ts or ""), tostring(last.label or ""))
  end
  return "—"
end

function GL.ExportStepHistory()
  local lines = { "=== LevelGuide Previous Steps (Last 15) ===" }
  local h = GL.db and GL.db.stepHistory or {}
  if #h == 0 then
    lines[#lines + 1] = "(no completed steps recorded yet)"
  else
    for i = #h, 1, -1 do
      lines[#lines + 1] = string.format("%d. [%s] %s", #h - i + 1, tostring(h[i].ts or ""), tostring(h[i].label or ""))
    end
  end
  return table.concat(lines, "\n")
end
