-- LevelGuide Main v0.4.0: WoW: Forever 1.60.1 (Interface 16001) events, lazy per-faction data loading,
-- throttled refresh loop, zero-taint quest tracking, Discoveries, Rewards, Travel, Metrics, Reminders.

local GL = LevelGuide
local frame = CreateFrame and CreateFrame("Frame", "LevelGuideEvents", UIParent) or nil
GL.frame = frame

GL.abandoned = {}
GL.ready = false
GL.dirty = false
GL.accum = 0
GL.posAccum = 0
GL.timerAccum = 0
GL.lastLevel = nil
GL.lastPinnedKey = nil
GL.stepStack = {}
GL.pinnedBackStep = nil

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
  "QUEST_REMOVED", "QUEST_COMPLETE", "TAXIMAP_OPENED", "GROUP_ROSTER_UPDATE",
  "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "PLAYER_XP_UPDATE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE",
  "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "UPDATE_INVENTORY_DURABILITY",
  "VIGNETTE_MINIMAP_UPDATED", "UPDATE_MOUSEOVER_UNIT", "UNIT_SPELLCAST_SUCCEEDED",
  "PLAYER_REGEN_ENABLED", "QUEST_DETAIL", "QUEST_PROGRESS",
  "QUEST_GREETING", "GOSSIP_SHOW",
}
if frame then
  for _, e in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, e) end
end

function GL.RegisterData(faction, tbl)
  GL.loadedFaction = faction
  GL.data = tbl
end

function GL.LoadData()
  local p = GL.profile
  if not p.faction then GL.Err("LoadData", "faction unknown") return false end
  local name = "LevelGuide_Data_" .. p.faction
  GL.data = nil
  local loaded, reason = GL.Compat.LoadAddOn(name)
  if not loaded and reason then
    GL.Err("LoadAddOn", name .. ": " .. tostring(reason))
  end
  if not GL.data then
    GL.Err("LoadData", name .. " did not load (check AddOns list & Interface 16001)")
    return false
  end
  return true
end

function GL.Init()
  if GL.inited then return end
  GL.inited = true
  GL.profile = GL.DetectProfile()
  GL.db = GL.InitDB(GL.profile)
  if GL.Metrics then GL.Metrics.Init() end
  if GL.Timer then GL.Timer.Init() end
  if GL.Arrow then GL.Safe("Arrow.Create", GL.Arrow.Create) end
  if GL.MinimapTrail then GL.Safe("Trail.Create", GL.MinimapTrail.Create) end
  if GL.WorldMapOverlay then GL.Safe("WM.Create", GL.WorldMapOverlay.Create) end
  if GL.UI and GL.UI.RegisterBlizzardSettings then GL.Safe("BlizzSettings", GL.UI.RegisterBlizzardSettings) end
  if GL.Integrations then
    GL.Integrations.Scan()
    local comp, list = GL.Integrations.HasCompetingGuide()
    if comp and GL.Integrations.detected.TomTom and GL.db.settings.autoPin then
      GL.Print("|cffffaa00Note:|r Detected " .. table.concat(list, ", ") .. " alongside TomTom. Toggle Auto-Pin OFF in Settings if arrows conflict.")
    end
  end
  GL.LogEvent("init", GL.profile.key)
  GL.Safe("UI.Create", GL.UI.Create)
  if not GL.LoadData() then
    GL.UI.Update({
      kind = "NONE",
      header = "Data not loaded",
      lines = { "Enable LevelGuide_Data_" .. tostring(GL.profile.faction) .. " in AddOns.", "Then run /guide reload" },
      level = UnitLevel and UnitLevel("player") or 1,
    }, 0, "")
    return
  end
  local rep = GL.Engine.Validate(GL.data)
  GL.report = rep
  if rep.fatal then GL.Err("Validate", rep.fatal) return end
  GL.state = GL.Engine.Build(GL.data, GL.profile)
  GL.Print("v" .. GL.version .. " " .. GL.profile.key .. ": " .. GL.state.n .. " quests for you (" .. rep.total .. " in data, " .. rep.bad .. " bad skipped).")

  local syncedServer = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  if syncedServer > 0 then
    GL.Print("Synced " .. syncedServer .. " completed quest(s) from server.")
  end
  GL.db.synced = GL.db.synced or (UnitLevel and UnitLevel("player") or 1)
  GL.lastLevel = UnitLevel and UnitLevel("player") or 1
  GL.dirty = true
  GL.readyAt = nil

  if not GL.db.setupDone and GL.UI and GL.UI.ShowWizard then
    GL.Safe("UI.ShowWizard", GL.UI.ShowWizard)
  end
end

function GL.ScanLog()
  if not GL.state then return end
  local list, numQuests, maxQuests, collapsed = GL.Compat.ReadQuestLog()
  GL.collapsed = collapsed
  GL.lastLogCount = numQuests
  GL.lastMaxQuests = maxQuests
  return GL.Engine.ApplyLog(GL.state, GL.db, list, GL.abandoned, GL.ready, GL.Compat.IsQuestCompleted)
end

function GL.Refresh()
  if not GL.state then return end
  GL.ScanLog()
  local level = UnitLevel and UnitLevel("player") or 1
  local _, zone, px, py = GL.Compat.ReadPosition()
  local inInst = false
  if IsInInstance then
    local okI, inst = pcall(IsInInstance)
    if okI then inInst = inst and true or false end
  end
  local inGroup = (IsInGroup and IsInGroup()) and true or false

  local ctx = {
    level = level,
    zone = zone,
    px = px,
    py = py,
    logCount = GL.lastLogCount or 0,
    maxQuests = GL.lastMaxQuests or 20,
    dead = GL.Compat.IsPlayerDead(),
    inInstance = inInst,
    inGroup = inGroup,
    levelUp = (GL.lastLevel and level ~= GL.lastLevel),
  }
  if ctx.levelUp then GL.lastLevel = level end
  local step = GL.Engine.Next(GL.state, GL.db, ctx)

  if GL.collapsed then
    table.insert(step.advisories, "Expand all quest-log headers so every quest is visible.")
  end
  if inInst then
    table.insert(step.advisories, "Inside instance — switch to Dungeons tab; outdoor auto-pin paused.")
  end
  if GL.Safety then
    local warns = GL.Safety.GetWarnings(step, ctx)
    for _, line in ipairs(warns) do table.insert(step.advisories, line) end
  end
  if GL.PathInfo and GL.profile and step.kind ~= "CLASS" then
    local cAdv = GL.PathInfo.GetActiveClassAdvisory(GL.profile.classToken, level)
    if cAdv then table.insert(step.advisories, cAdv) end
  end
  if GL.Engine and GL.Engine.OptimizeQuestLog then
    local opt = GL.Engine.OptimizeQuestLog(GL.state, GL.db, ctx)
    if opt and opt.nearCap then
      table.insert(step.advisories, string.format(
        "Quest Log Optimizer (%d/%d): %d grey, %d ready turn-in(s), %d off-zone/route — /lg optimize",
        opt.logCount, opt.maxQuests, #opt.grey, #opt.turnIns, #opt.offRoute
      ))
    end
  end
  if GL.Fallback and GL.profile and not inInst then
    local dg = GL.Fallback.GetPromptDungeon(level, GL.profile.faction, GL.db and GL.db.skippedDungeons)
    if dg then
      GL._promptDungeonName = dg.name
      table.insert(step.advisories, string.format("Dungeon Ready: %s (Lv %d-%d, %s) — /lg skipdungeon to dismiss [UNVERIFIED]", dg.name, dg.minL, dg.maxL, dg.zone))
    else
      GL._promptDungeonName = nil
    end
  end
  if GL.Reminders then
    local rem = GL.Reminders.BuildAdvisories(step, ctx)
    for _, line in ipairs(rem) do table.insert(step.advisories, line) end
  end
  if GL.Integrations and GL.Integrations.detected.WhatsTraining and ctx.levelUp and GL.mod(level, 2) == 0 then
    table.insert(step.advisories, "Tip: Check your Spellbook -> What's Training? tab for new spells.")
  end

  if GL.pinnedBackStep then
    step = GL.pinnedBackStep
  else
    local prevStep = GL.step
    local prevKey = prevStep and (tostring(prevStep.kind) .. ":" .. tostring(prevStep.ids and prevStep.ids[1] or prevStep.header)) or nil
    local newKey = tostring(step.kind) .. ":" .. tostring(step.ids and step.ids[1] or step.header)
    if prevStep and prevStep.kind ~= "NONE" and prevKey and prevKey ~= newKey then
      GL.stepStack = type(GL.stepStack) == "table" and GL.stepStack or {}
      GL.stepStack[#GL.stepStack + 1] = prevStep
      while #GL.stepStack > 15 do table.remove(GL.stepStack, 1) end
    end
  end
  GL.step = step
  GL.lastCtx = ctx
  local stepKey = tostring(step.kind) .. ":" .. tostring(step.ids and step.ids[1] or step.header)
  if GL.Timer then GL.Timer.OnStepChanged(stepKey) end
  if GL.Voice and GL.ready then GL.Voice.AnnounceStep(step, false) end

  -- First-class QuestieBridge: aim Arrow, MinimapTrail, WorldMapOverlay & TomTom at closest live QuestieDB spawn!
  if step.kind == "OBJECTIVE" and step.ids and step.ids[1] and GL.QuestieBridge then
    local pMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    local loc = GL.QuestieBridge.GetObjectiveLocation(step.ids[1], pMap, px, py)
    if loc and loc.xPercent and loc.yPercent then
      step.target = { loc.label or "Objective", step.target and step.target[2] or 0, loc.xPercent, loc.yPercent }
      step.targetZone = loc.zoneName or zone or step.targetZone
      step.targetMapId = loc.uiMapID
      step.targetIsTurnIn = false
      step.where = string.format("Nearest Spawn (%s): %s (%.1f, %.1f) in %s", tostring(loc.source), tostring(loc.label), loc.xPercent, loc.yPercent, tostring(step.targetZone))
    end
  end

  -- Auto-pin only outdoors and when WorldMapFrame is not actively being browsed
  local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
  if not inInst and not mapOpen and GL.db and GL.db.settings.autoPin and step.target and GL.Waypoint then
    local pinKey = string.format("%s:%s:%.1f:%.1f", tostring(step.target[1]), tostring(step.targetZone or step.target[2]), tonumber(step.target[3] or 0), tonumber(step.target[4] or 0))
    if pinKey ~= GL.lastPinnedKey then
      GL.lastPinnedKey = pinKey
      GL.Waypoint.SetForTarget(step.target, step.targetZone, step.header, step.targetMapId)
    end
  end

  local prog = GL.Engine.Progress(level, UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player"))
  local bridgeInfo = GL.Integrations and ("\n" .. GL.Integrations.GetSummaryLine()) or ""
  local fpCount = GL.Travel and GL.Travel.KnownFlightPathCount() or 0
  local discCount = GL.Discoveries and GL.Discoveries.Count() or 0
  local info = string.format(
    "Profile: %s\nData: %s only (LoD) | Quests: %d | Memory: %.1f KB\nFlight Paths: %d | Forever Discoveries: %d%s",
    GL.profile.key, tostring(GL.loadedFaction), GL.state.n, GL.Compat.GetMemoryKB(), fpCount, discCount, bridgeInfo
  )
  if GL.ActionBar then GL.Safe("ActionBar.Update", GL.ActionBar.UpdateForStep, step) end
  GL.UI.Update(step, prog, info)
  GL.dirty = false
end

function GL.OnEvent(event, a1, a2, a3)
  GL.LogEvent(event, a1)
  if event == "PLAYER_ENTERING_WORLD" then
    GL.Safe("Init", GL.Init)
    GL.ready = false
    GL.readyAt = GetTime and (GetTime() + 2) or 0
    GL.dirty = true
  elseif event == "QUEST_ACCEPTED" then
    GL.pinnedBackStep = nil
    local qid = (type(a1) == "number" and a1 > 0) and a1 or (type(a2) == "number" and a2 > 0 and a2 or nil)
    if qid and GL.Discoveries then GL.Safe("DiscoverAccept", GL.Discoveries.RecordQuest, qid, "ACCEPT") end
    GL.Safe("ScanLog", GL.ScanLog)
    GL.dirty = true
  elseif event == "QUEST_TURNED_IN" then
    GL.pinnedBackStep = nil
    if type(a1) == "number" then
      if GL.Discoveries then GL.Safe("DiscoverTurnIn", GL.Discoveries.RecordQuest, a1, "TURNIN") end
      if GL.state and GL.db then
        local q = GL.state.data.quests[a1]
        GL.RecordStepHistory("[TURN IN] " .. tostring(q and q.n or ("Quest #" .. tostring(a1))))
        for _, sid in ipairs(GL.Engine.Siblings(GL.state, a1)) do GL.db.done[sid] = true end
      end
    end
    if GL.Rewards then GL.Rewards.lastAdvice = nil end
    GL.dirty = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    if GL.ActionBar then GL.Safe("ActionBar.Apply", GL.ActionBar.ApplyPending) end
  elseif event == "QUEST_DETAIL" then
    if GL.AutoQuest then GL.Safe("AutoQuest.Detail", GL.AutoQuest.OnQuestDetail) end
  elseif event == "QUEST_PROGRESS" then
    if GL.AutoQuest then GL.Safe("AutoQuest.Progress", GL.AutoQuest.OnQuestProgress) end
  elseif event == "QUEST_GREETING" then
    if GL.AutoQuest then GL.Safe("AutoQuest.Greeting", GL.AutoQuest.OnQuestGreeting) end
  elseif event == "GOSSIP_SHOW" then
    if GL.AutoQuest then GL.Safe("AutoQuest.Gossip", GL.AutoQuest.OnGossipShow) end
  elseif event == "QUEST_COMPLETE" then
    if GL.Rewards then
      local advice = GL.Safe("Rewards", GL.Rewards.EvaluateChoices)
      if advice then GL.Print(advice) GL.dirty = true end
    end
    if GL.AutoQuest then GL.Safe("AutoQuest.Complete", GL.AutoQuest.OnQuestComplete) end
  elseif event == "TAXIMAP_OPENED" then
    if GL.Travel then GL.Safe("ScanFP", GL.Travel.ScanFlightPaths) end
  elseif event == "VIGNETTE_MINIMAP_UPDATED" and GL.RareAlert then
    GL.Safe("RareVignette", GL.RareAlert.OnVignette, a1)
  elseif event == "UPDATE_MOUSEOVER_UNIT" and GL.RareAlert then
    GL.Safe("RareMouseover", GL.RareAlert.OnMouseoverUnit)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" and a1 == "player" and GL.GatherNodes then
    local sid = (type(a3) == "number" and a3) or (type(a2) == "number" and a2) or nil
    -- 2366/2575 are rank-1 gather spells. Skip "Find Herbs" (2383) and "Find Minerals" (2580).
    if sid ~= 2383 and sid ~= 2580 then
      if sid == 2366 then
        GL.Safe("RecHerb", GL.GatherNodes.RecordCurrentNode, "HERB", "Herb")
      elseif sid == 2575 then
        GL.Safe("RecMine", GL.GatherNodes.RecordCurrentNode, "MINE", "Mining Vein")
      elseif sid and C_Spell and C_Spell.GetSpellName then
        local okSN, spellName = pcall(C_Spell.GetSpellName, sid)
        spellName = okSN and spellName or nil
        if spellName then
          local lo = string.lower(tostring(spellName))
          if lo ~= "find herbs" and lo ~= "find minerals" then
            if string.find(lo, "herb gathering", 1, true) or lo == "herbalism" then
              GL.Safe("RecHerb", GL.GatherNodes.RecordCurrentNode, "HERB", "Herb")
            elseif string.find(lo, "mining", 1, true) and not string.find(lo, "smelt", 1, true) then
              GL.Safe("RecMine", GL.GatherNodes.RecordCurrentNode, "MINE", "Mining Vein")
            end
          end
        end
      end
    end
  elseif event == "PLAYER_LEVEL_UP" then
    if GL.Metrics then GL.Safe("Metrics", GL.Metrics.Update) end
    local newLv = (type(a1) == "number" and a1) or (UnitLevel and UnitLevel("player")) or 2
    if GL.Timer then GL.Safe("TimerSplit", GL.Timer.OnLevelUp, newLv) end
    if GL.Voice then GL.Voice.Speak("Congratulations! Level " .. tostring(newLv) .. " reached.", false) end
    GL.dirty = true
  elseif event == "PLAYER_XP_UPDATE" then
    if GL.Metrics then GL.Safe("Metrics", GL.Metrics.Update) end
    GL.dirty = true
  elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_REMOVED" then
    GL.Safe("ScanLog", GL.ScanLog)
    GL.dirty = true
  elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "GROUP_ROSTER_UPDATE" or event == "UPDATE_INVENTORY_DURABILITY" or string.find(event, "ZONE_CHANGED") then
    GL.dirty = true
  elseif event == "BAG_UPDATE_DELAYED" or event == "BANKFRAME_OPENED" then
    if GL.UI and GL.UI.tab == "Profs" then GL.UI.Update() else GL.dirty = true end
  end
end

if frame then
  frame:SetScript("OnEvent", function(_, e, a1, a2, a3) GL.OnEvent(e, a1, a2, a3) end)
  frame:SetScript("OnUpdate", function(_, elapsed)
    local el = elapsed or 0
    GL.accum = GL.accum + el
    GL.posAccum = GL.posAccum + el
    GL.timerAccum = GL.timerAccum + el
    if GL.timerAccum >= 1.0 then
      local dt = GL.timerAccum
      GL.timerAccum = 0
      if GL.Timer then GL.Timer.Tick(dt) end
      if GL.UI and GL.UI.UpdateTimerText then GL.UI.UpdateTimerText() end
    end
    if GL.readyAt and not GL.ready and GetTime and GetTime() >= GL.readyAt then
      GL.ready = true
      GL.dirty = true
    end
    local f = GL.UI and GL.UI.frame
    if f and f:IsVisible() and GL.posAccum >= 2 then
      GL.posAccum = 0
      GL.dirty = true
    end
    if GL.dirty and GL.accum >= 0.5 then
      GL.accum = 0
      GL.Safe("Refresh", GL.Refresh)
    end
  end)
end

-- ---------- commands ----------
local function warnChainBlocks(actionLabel, ids)
  if not GL.Engine or not GL.Engine.CountBlockedFollowUps then return end
  local blocked, sample = GL.Engine.CountBlockedFollowUps(GL.state, GL.db, ids)
  if blocked > 0 then
    local ex = (#sample > 0) and (" (" .. table.concat(sample, ", ") .. ((blocked > #sample) and ", ..." or "") .. ")") or ""
    GL.Print(string.format("|cffffaa00Chain Warning:|r %s blocks %d follow-up quest(s)%s.", actionLabel, blocked, ex))
  end
end

function GL.CmdSkip()
  if GL.pinnedBackStep then
    GL.pinnedBackStep = nil
    GL.Print("Returned to live guide step.")
    GL.Refresh()
    return
  end
  if not GL.state or not GL.step or not GL.step.ids then GL.Print("Nothing to skip.") return end
  warnChainBlocks("Skipping this step", GL.step.ids)
  GL.db.lastSkipped = {}
  for _, id in ipairs(GL.step.ids) do
    for _, sid in ipairs(GL.Engine.Siblings(GL.state, id)) do
      GL.db.skipped[sid] = true
      GL.db.lastSkipped[#GL.db.lastSkipped + 1] = sid
    end
  end
  GL.RecordStepHistory("[SKIPPED] " .. tostring(GL.step.header or "Step"))
  GL.Print("Skipped " .. #GL.step.ids .. " step/quest(s). /lg undo or /lg unskip to restore.")
  GL.Refresh()
end

function GL.CmdIgnore()
  GL.pinnedBackStep = nil
  if not GL.db or not GL.state or not GL.step or not GL.step.ids or #GL.step.ids == 0 then
    GL.Print("Nothing to ignore.")
    return
  end
  warnChainBlocks("Ignoring this step", GL.step.ids)
  GL.db.ignoredQuests = type(GL.db.ignoredQuests) == "table" and GL.db.ignoredQuests or {}
  local added = {}
  for _, id in ipairs(GL.step.ids) do
    GL.db.ignoredQuests[id] = true
    added[#added + 1] = tostring(id)
  end
  GL.RecordStepHistory("[IGNORED] " .. tostring(GL.step.header or "Step"))
  GL.Print("Ignored " .. table.concat(added, ", ") .. ". Use /lg unignore <id> or /lg unignore all to restore.")
  GL.Refresh()
end

function GL.CmdUnignore(arg)
  if not GL.db then return end
  GL.db.ignoredQuests = type(GL.db.ignoredQuests) == "table" and GL.db.ignoredQuests or {}
  if arg == "all" then
    GL.db.ignoredQuests = {}
    GL.Print("Cleared all ignored quests/steps for this character.")
    GL.Refresh()
    return
  end
  if not arg or arg == "" then
    local list = {}
    for k in pairs(GL.db.ignoredQuests) do list[#list + 1] = tostring(k) end
    table.sort(list)
    if #list == 0 then
      GL.Print("No ignored quests/steps. Usage: /lg unignore <id> or /lg unignore all")
    else
      GL.Print("Ignored (" .. tostring(#list) .. "): " .. table.concat(list, ", ") .. " — /lg unignore <id> or /lg unignore all")
    end
    return
  end
  local numId = tonumber(arg)
  if numId and GL.db.ignoredQuests[numId] then
    GL.db.ignoredQuests[numId] = nil
    GL.Print("Unignored quest ID " .. tostring(numId) .. ".")
    GL.Refresh()
    return
  end
  local up = string.upper(arg)
  if GL.db.ignoredQuests[arg] or GL.db.ignoredQuests[up] then
    GL.db.ignoredQuests[arg] = nil
    GL.db.ignoredQuests[up] = nil
    GL.Print("Unignored " .. tostring(arg) .. ".")
    GL.Refresh()
    return
  end
  GL.Print("ID not found in ignoredQuests: " .. tostring(arg))
end

function GL.CmdChain()
  local qid = (GL.step and GL.step.ids and GL.step.ids[1]) or nil
  if GL.Integrations then GL.Integrations.OpenBtWQuests(qid) end
end

function GL.CmdPin()
  if not GL.step or not GL.step.target then GL.Print("No waypoint target for current step.") return end
  local _, msg = GL.Waypoint.SetForTarget(GL.step.target, GL.step.targetZone, GL.step.header, GL.step.targetMapId)
  GL.Print(msg)
end

function GL.CmdMini()
  if not GL.db then return end
  GL.db.settings.miniMode = not GL.db.settings.miniMode
  GL.UI.ApplyVisualSettings()
  GL.UI.Update()
end

function GL.CmdLock()
  if not GL.db then return end
  GL.db.settings.locked = not GL.db.settings.locked
  GL.Print("Window lock: " .. (GL.db.settings.locked and "ON" or "OFF"))
  GL.UI.Update()
end

function GL.CmdStats()
  if not GL.Metrics then return end
  local xph, ttl, sessXP, mins = GL.Metrics.GetStats()
  GL.Print(string.format("Session: %d XP in %dm | Rate: %d XP/hr | Est. TTL: %s",
    sessXP, mins, xph, ttl and (tostring(ttl) .. "m") or "N/A"))
end

function GL.CmdSpeak()
  if GL.Voice and GL.step then GL.Voice.AnnounceStep(GL.step, true) end
end

function GL.CmdVoice(arg)
  if not GL.db then return end
  if arg == "cycle" then
    if GL.Voice then GL.Voice.CycleVoice() end
  elseif arg == "on" then
    GL.db.settings.voiceEnabled = true
    GL.Print("Voice TTS: ON")
  elseif arg == "off" then
    GL.db.settings.voiceEnabled = false
    GL.Print("Voice TTS: OFF")
  else
    GL.db.settings.voiceEnabled = not GL.db.settings.voiceEnabled
    GL.Print("Voice TTS: " .. (GL.db.settings.voiceEnabled and "ON" or "OFF"))
  end
  if GL.UI then GL.UI.Update() end
end

function GL.CmdTimer(arg)
  if not GL.Timer then return end
  if arg == "reset" then GL.Timer.ResetSession()
  else GL.Timer.TogglePause() end
  if GL.UI and GL.UI.UpdateTimerText then GL.UI.UpdateTimerText() end
end

function GL.CmdSplits()
  if GL.Timer and GL.UI then
    GL.UI.ShowBugReport(GL.Timer.ExportSplits(), "LevelGuide — Level Split Times (Ctrl+C)")
  end
end

function GL.CmdArrow(arg)
  if not GL.db then return end
  if arg == "on" then
    GL.db.settings.arrowEnabled = true
  elseif arg == "off" then
    GL.db.settings.arrowEnabled = false
    if GL.Arrow then GL.Arrow.Clear() end
  elseif arg == "lock" then
    GL.db.settings.arrowLocked = not GL.db.settings.arrowLocked
    if GL.Arrow then GL.Arrow.ApplyMouseLock() end
    GL.Print("Arrow click-through lock: " .. (GL.db.settings.arrowLocked and "ON" or "OFF"))
    return
  elseif arg == "reset" then
    if GL.Arrow then GL.Arrow.ResetPos() end
    GL.Print("Arrow position reset to top-center.")
    return
  elseif arg and string.find(arg, "^scale%s+") then
    local _, _, sc = string.find(arg, "^scale%s+(%d+%.?%d*)")
    if tonumber(sc) then
      GL.db.settings.arrowScale = math.max(0.6, math.min(1.6, tonumber(sc)))
      if GL.Arrow and GL.Arrow.ApplyScale then GL.Arrow.ApplyScale() end
      GL.Print("Arrow scale: " .. tostring(GL.db.settings.arrowScale))
    end
    return
  else
    GL.db.settings.arrowEnabled = not GL.db.settings.arrowEnabled
    if not GL.db.settings.arrowEnabled and GL.Arrow then GL.Arrow.Clear() end
  end
  GL.Print("Quest Arrow: " .. (GL.db.settings.arrowEnabled and "ON (Shift+Drag to move)" or "OFF"))
  if GL.db.settings.arrowEnabled then GL.CmdPin() end
  if GL.UI then GL.UI.Update() end
end

function GL.CmdTrail()
  if not GL.db then return end
  GL.db.settings.trailEnabled = not (GL.db.settings.trailEnabled ~= false)
  if not GL.db.settings.trailEnabled and GL.MinimapTrail then GL.MinimapTrail.HideAll() end
  GL.Print("Minimap Dot Trail: " .. (GL.db.settings.trailEnabled and "ON" or "OFF"))
  if GL.db.settings.trailEnabled then GL.CmdPin() end
end

function GL.CmdFont(arg)
  if not GL.db then return end
  local map = { small = 11, normal = 12, large = 14, xl = 16 }
  local sizes = { 11, 12, 14, 16 }
  local chosen = map[arg] or tonumber(arg)
  if not chosen then
    local cur = tonumber(GL.db.settings.fontSize) or 12
    chosen = sizes[1]
    for i = 1, #sizes do
      if sizes[i] == cur then chosen = sizes[(i % #sizes) + 1] break end
    end
  end
  GL.db.settings.fontSize = math.max(9, math.min(20, chosen))
  if GL.UI then GL.UI.ApplyFontSize() GL.UI.Update() end
  GL.Print("Font size: " .. tostring(GL.db.settings.fontSize) .. "pt")
end

function GL.CmdCluster()
  if not GL.db then return end
  GL.db.settings.clusterRoute = not (GL.db.settings.clusterRoute ~= false)
  GL.Print("Cluster Route (minimum walking): " .. (GL.db.settings.clusterRoute and "ON" or "OFF"))
  GL.Refresh()
end

function GL.CmdBack()
  if type(GL.stepStack) == "table" and #GL.stepStack > 0 then
    local prev = table.remove(GL.stepStack)
    GL.pinnedBackStep = prev
    GL.lastPinnedKey = nil
    GL.Print("Stepped back to: [" .. tostring(prev.kind or "?") .. "] " .. tostring(prev.header or "-") .. " (click Skip or Sync to return to live step).")
    GL.Refresh()
    return
  end
  if GL.db and type(GL.db.lastSkipped) == "table" and #GL.db.lastSkipped > 0 then
    GL.CmdUndo()
    return
  end
  GL.Print("No previous step in session history.")
end

function GL.CmdHistory()
  if GL.UI and GL.ExportStepHistory then
    GL.UI.ShowBugReport(GL.ExportStepHistory(), "LevelGuide — Previous Steps History")
  end
end

function GL.CmdUndo()
  if not GL.db or type(GL.db.lastSkipped) ~= "table" or #GL.db.lastSkipped == 0 then
    GL.Print("Nothing to undo.")
    return
  end
  for _, sid in ipairs(GL.db.lastSkipped) do GL.db.skipped[sid] = nil end
  GL.db.lastSkipped = {}
  GL.Print("Restored last skipped step.")
  GL.Refresh()
end

function GL.CmdMap()
  if GL.WorldMapOverlay then GL.WorldMapOverlay.OpenToTarget() end
end

function GL.CmdGather(arg)
  if not GL.GatherNodes then return end
  local kind = nil
  if arg == "herb" or arg == "herbs" then kind = "HERB"
  elseif arg == "mine" or arg == "mining" or arg == "ore" then kind = "MINE" end
  GL.GatherNodes.PinNearestNode(kind)
end

function GL.CmdRare()
  if GL.RareAlert then GL.RareAlert.PinLastRare() end
end

function GL.CmdClass()
  if GL.PathInfo and GL.UI then
    local cls = (GL.profile and GL.profile.classToken) or "WARRIOR"
    local lv = (UnitLevel and UnitLevel("player")) or 1
    GL.UI.ShowBugReport(GL.PathInfo.ExportClassGuide(cls, lv), "LevelGuide — Class Chains & Milestones (" .. cls .. ")")
  end
end

function GL.CmdSkipDungeon()
  if not GL.db or not GL._promptDungeonName then
    GL.Print("No active dungeon prompt to skip.")
    return
  end
  GL.db.skippedDungeons = type(GL.db.skippedDungeons) == "table" and GL.db.skippedDungeons or {}
  GL.db.skippedDungeons[GL._promptDungeonName] = true
  GL.Print("Skipped dungeon prompt: " .. tostring(GL._promptDungeonName))
  GL.Refresh()
end

function GL.CmdPace()
  if GL.PaceGuide and GL.UI then
    local lv = (UnitLevel and UnitLevel("player")) or 1
    local fac = (GL.profile and GL.profile.faction) or "Alliance"
    GL.UI.ShowBugReport(GL.PaceGuide.ExportGuide(lv, fac), "WoW: Forever 1.60.1 — Optimal 1-60 Pace Checklist")
  end
end

function GL.CmdHC(arg)
  if not GL.db then return end
  if arg == "on" then GL.db.settings.hcWarnings = true
  elseif arg == "off" then GL.db.settings.hcWarnings = false
  else GL.db.settings.hcWarnings = not (GL.db.settings.hcWarnings ~= false) end
  GL.Print("Hardcore / Danger Pull Warnings: " .. (GL.db.settings.hcWarnings and "ON" or "OFF"))
  GL.Refresh()
end

function GL.CmdAuto(arg)
  if not GL.db then return end
  if arg == "on" then GL.db.settings.autoQuest = true
  elseif arg == "off" then GL.db.settings.autoQuest = false
  else GL.db.settings.autoQuest = not GL.db.settings.autoQuest end
  GL.Print("Auto-Accept / Single-Reward Auto-Turn-In: " .. (GL.db.settings.autoQuest and "ON (hold Shift to pause)" or "OFF"))
end

function GL.CmdCleanup()
  if not GL.state or not GL.Engine or not GL.Engine.OptimizeQuestLog then return end
  GL.ScanLog()
  local lv = (UnitLevel and UnitLevel("player")) or 1
  local _, zone = GL.Compat.ReadPosition()
  local opt = GL.Engine.OptimizeQuestLog(GL.state, GL.db, {
    level = lv, zone = zone, logCount = GL.lastLogCount or 0, maxQuests = GL.lastMaxQuests or 20,
  })
  GL.Print(string.format("Quest Log Optimizer (%d/%d quests):", opt.logCount, opt.maxQuests))
  GL.Print("  Grey (" .. tostring(#opt.grey) .. "): " .. (#opt.grey > 0 and table.concat(opt.grey, ", ") or "none"))
  GL.Print("  Ready Turn-Ins (" .. tostring(#opt.turnIns) .. "): " .. (#opt.turnIns > 0 and table.concat(opt.turnIns, ", ") or "none"))
  GL.Print("  Off-Zone / Off-Route (" .. tostring(#opt.offRoute) .. "): " .. (#opt.offRoute > 0 and table.concat(opt.offRoute, ", ") or "none"))
end

function GL.CmdFeedback(note)
  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then mapId, zone, px, py = GL.Compat.ReadPosition() end
  local s = GL.step
  local report = table.concat({
    "=== LevelGuide Step Feedback ===",
    "Version: " .. tostring(GL.version) .. " | Client: " .. (GL.Compat and GL.Compat.GetBuildString() or "?"),
    "Char: " .. tostring(GL.profile and GL.profile.key or "?") .. " Lv " .. tostring(UnitLevel and UnitLevel("player") or "?"),
    string.format("Pos: %s (map=%s, %.1f, %.1f)", tostring(zone or "?"), tostring(mapId or "?"), tonumber(px or 0), tonumber(py or 0)),
    "Step: [" .. tostring(s and s.kind or "NONE") .. "] " .. tostring(s and s.header or "-") .. " | QIDs: " .. (s and s.ids and table.concat(s.ids, ",") or "none"),
    "Note: " .. ((note and note ~= "") and note or "(describe what was wrong with this step)"),
  }, "\n")
  if GL.UI and GL.UI.ShowBugReport then
    GL.UI.ShowBugReport(report, "LevelGuide — Step Feedback (Ctrl+C)")
  end
end

function GL.CmdQuestie(arg)
  if not GL.db then return end
  if arg == "on" then GL.db.settings.useQuestieSpawns = true
  elseif arg == "off" then GL.db.settings.useQuestieSpawns = false
  elseif arg == "status" then
    GL.Print(GL.QuestieBridge and GL.QuestieBridge.GetStatusString() or "QuestieBridge unavailable")
    return
  else
    GL.db.settings.useQuestieSpawns = not (GL.db.settings.useQuestieSpawns ~= false)
  end
  GL.Print("Questie live spawn bridge: " .. (GL.db.settings.useQuestieSpawns and "ON" or "OFF"))
  if GL.QuestieBridge then GL.Print(GL.QuestieBridge.GetStatusString()) end
  GL.Refresh()
end

function GL.CmdTomTom()
  if not GL.db then return end
  GL.db.settings.useTomTom = not GL.db.settings.useTomTom
  GL.Print("TomTom bridge: " .. (GL.db.settings.useTomTom and "ON" or "OFF (using LevelGuide built-in Arrow only)"))
end

function GL.CmdWay(rest)
  local _, _, xs, ys, lbl = string.find(rest or "", "^(%d+%.?%d*)%s+(%d+%.?%d*)%s*(.*)$")
  local x, y = tonumber(xs), tonumber(ys)
  if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
    GL.Print("Usage: /guide way <x> <y> [optional label]  (e.g. /guide way 48.2 42.9 Deputy Willem)")
    return
  end
  if GL.Waypoint and GL.Waypoint.SetCustomWay then
    GL.Waypoint.SetCustomWay(x, y, lbl)
  end
end

function GL.CmdTwink()
  GL.UI.Create():Show()
  GL.UI.ShowTab("Twink")
end

function GL.CmdTheme()
  if not GL.db or not GL.Theme then return end
  local ord = GL.Theme.ORDER
  local cur = GL.db.settings.theme or ord[1]
  local nxt = ord[1]
  for i = 1, #ord do
    if ord[i] == cur then nxt = ord[(i % #ord) + 1] break end
  end
  GL.db.settings.theme = nxt
  if GL.UI then GL.UI.ApplyVisualSettings() GL.UI.Update() end
  GL.Print("Theme: " .. tostring(GL.Theme.THEMES[nxt].label))
end

function GL.CmdExportAI()
  if GL.UI and GL.UI.ShowBugReport then
    GL.UI.ShowBugReport(GL.BuildAIContextExport(), "LevelGuide — AI Context Export (Ctrl+C)")
  end
end

function GL.CmdDiscoveries()
  if not GL.Discoveries then return end
  GL.UI.ShowBugReport(GL.Discoveries.ExportString(), "LevelGuide — Discovered WoW: Forever Quests (Ctrl+C)")
end

function GL.CmdMode(m)
  if not GL.db then return end
  if m ~= "speed" and m ~= "thorough" then
    m = (GL.db.settings.mode == "thorough") and "speed" or "thorough"
  end
  GL.db.settings.mode = m
  GL.Print("Mode: " .. m)
  GL.Refresh()
end

function GL.CmdReset()
  if not GL.db then return end
  GL.db.done = {} GL.db.skipped = {} GL.db.ignoredQuests = {} GL.db.synced = nil
  if GL.state then GL.state.prev = nil end
  GL.Print("Progress reset for this character.")
  if GL.state then GL.Refresh() end
end

function GL.CmdScan()
  if not GL.state then GL.Print("LevelGuide data not loaded yet.") return end
  GL.pinnedBackStep = nil
  GL.state.prev = nil
  local added, reopened = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.ScanLog()
  local level = UnitLevel and UnitLevel("player") or 1
  local _, zone, px, py = GL.Compat.ReadPosition()
  local ctx = { level = level, zone = zone, px = px, py = py }
  local best = GL.Engine.ScanNearestArea(GL.state, GL.db, ctx)
  if not best then
    GL.Refresh()
    GL.Print(string.format("Scan (+%d done, %d reopened): No unaccepted quests found in your level window (check Dungeons / Grinding tab).", added or 0, reopened or 0))
    return
  end
  if best.fromSkipped and GL.db and type(GL.db.skipped) == "table" then
    for _, id in ipairs(best.ids) do GL.db.skipped[id] = nil end
    GL.state._availKey = nil
  end
  GL.Refresh()
  -- Pin AFTER Refresh and sync lastPinnedKey so autoPin does not clobber the Scan lock.
  if GL.Waypoint and GL.Waypoint.SetForTarget then
    GL.lastPinnedKey = string.format("%s:%s:%.1f:%.1f", tostring(best.n[1]), tostring(best.zone or best.n[2]), tonumber(best.n[3] or 0), tonumber(best.n[4] or 0))
    GL.Waypoint.SetForTarget(best.n, best.zone, "Missed / Nearest Hub: " .. best.n[1])
  end
  -- If player has no active quests or wants to go back to a missed pickup, surface it on the HUD too.
  if GL.step and GL.step.kind ~= "PICKUP" and best.ids and #best.ids > 0 then
    local qNames = {}
    for _, id in ipairs(best.ids) do
      local q = GL.state.data and GL.state.data.quests and GL.state.data.quests[id]
      if q and q.n then qNames[#qNames + 1] = "- " .. q.n .. " (" .. tostring(q.l or "?") .. ")" end
    end
    local scanStep = {
      kind = "PICKUP",
      header = "Missed / Nearest Hub (" .. tostring(#best.ids) .. ")",
      lines = qNames,
      walkthrough = {
        string.format("1. Go to %s in %s (%.1f, %.1f).", tostring(best.n[1]), tostring(best.zone), tonumber(best.n[3] or 0), tonumber(best.n[4] or 0)),
        "2. Accept: " .. table.concat(qNames, ", "),
      },
      target = best.n,
      targetZone = best.zone,
      where = string.format("%s in %s (%.1f, %.1f)", tostring(best.n[1]), tostring(best.zone), tonumber(best.n[3] or 0), tonumber(best.n[4] or 0)),
      ids = best.ids,
      level = level,
      advisories = GL.step.advisories,
      hubSummary = GL.step.hubSummary,
      nextPreview = GL.step.header,
    }
    GL.step = scanStep
    if GL.ActionBar then GL.Safe("ActionBar.Update", GL.ActionBar.UpdateForStep, scanStep) end
    local prog = GL.Engine.Progress(level, UnitXP and UnitXP("player"), UnitXPMax and UnitXPMax("player"))
    if GL.UI then GL.UI.Update(scanStep, prog) end
  end
  local distStr = best.sameZone and string.format("~%.0f map units away", best.distUnits or 0) or ("travel to " .. tostring(best.zone))
  local extra = (reopened and reopened > 0) and string.format(" (%d missed reopened)", reopened) or ""
  GL.Print(string.format("|cff55ff55Scan locked:|r %s in %s (%.1f, %.1f) — %s, %d quest(s) ready%s!",
    tostring(best.n[1]), tostring(best.zone), best.n[3], best.n[4], distStr, #best.ids, extra))
end

function GL.CmdRecalibrate()
  GL.pinnedBackStep = nil
  if not GL.state then
    GL.inited = false
    GL.Init()
    return
  end
  GL.state.prev = nil
  GL.state._availKey = nil
  GL.lastPinnedKey = nil
  local added, reopened = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.ScanLog()
  GL.Refresh()
  if GL.step and GL.step.target and GL.Waypoint then
    GL.Waypoint.SetForTarget(GL.step.target, GL.step.targetZone, GL.step.header)
  end
  GL.Print(string.format("Synced to live guide position: +%d completed, %d missed reopened, %d in log -> [%s] %s",
    added or 0, reopened or 0, GL.lastLogCount or 0, tostring(GL.step and GL.step.kind or "NONE"), tostring(GL.step and GL.step.header or "-")))
end

function GL.CmdSync()
  if not GL.state then return end
  GL.pinnedBackStep = nil
  GL.state.prev = nil
  GL.state._availKey = nil
  GL.lastPinnedKey = nil
  local added, reopened = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.ScanLog()
  GL.Refresh()
  GL.Print(string.format("Synced from server: +%d completed, %d missed/uncompleted reopened (no level-based guessing).", added or 0, reopened or 0))
end

function GL.CmdDebug()
  local report = GL.BuildDiagnosticString()
  GL.Print("Opened copyable diagnostic report (/guide debug).")
  if GL.UI and GL.UI.ShowBugReport then
    GL.UI.ShowBugReport(report)
  else
    print(report)
  end
end

function GL.CmdTest()
  local ok, fail = 0, 0
  local function chk(name, cond)
    if cond then ok = ok + 1 else fail = fail + 1 GL.Print("|cffff4444[FAIL]|r " .. name) end
  end
  chk("LevelGuideDB v13 initialized", type(GL.db) == "table" and GL.db.version == 13)
  chk("Only active faction data loaded", GL.profile and GL.loadedFaction == GL.profile.faction)
  chk("Validator ran with 0 fatal", GL.report and not GL.report.fatal)
  chk("Compat C_Map available", C_Map and C_Map.GetBestMapForUnit ~= nil)
  chk("Compat C_QuestLog available", C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted ~= nil)
  chk("Compat C_AddOns available", C_AddOns and C_AddOns.LoadAddOn ~= nil)
  chk("Modules loaded (Theme/Timer/Voice/Travel/Rewards/Metrics/Reminders/Discoveries)", GL.Theme and GL.Timer and GL.Voice and GL.Travel and GL.Rewards and GL.Metrics and GL.Reminders and GL.Discoveries)
  chk("Engine.Progress bounds [0,1]", GL.Engine.Progress(1, 0, 400) == 0 and GL.Engine.Progress(60, 0, 1) == 1)
  chk("Timer.Format formats MM:SS & HH:MM:SS", GL.Timer.Format(65) == "01:05" and GL.Timer.Format(3661) == "01:01:01")
  chk("Arrow + MinimapTrail + Twink loaded", GL.Arrow and GL.MinimapTrail and GL.Twink)
  GL.Print(string.format("Self-test: %d passed, %d failed.", ok, fail))
end

SLASH_LEVELGUIDE1 = "/guide"
SLASH_LEVELGUIDE2 = "/lg"
SLASH_LEVELGUIDE3 = "/levelguide"
SlashCmdList = SlashCmdList or {}
SlashCmdList["LEVELGUIDE"] = function(msg)
  GL.Safe("slash", function()
    msg = string.lower(msg or "")
    local _, _, cmd, rest = string.find(msg, "^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd or ""
    if cmd == "" then GL.UI.Toggle()
    elseif cmd == "mini" then GL.CmdMini()
    elseif cmd == "lock" then GL.CmdLock()
    elseif cmd == "stats" then GL.CmdStats()
    elseif cmd == "discoveries" then GL.CmdDiscoveries()
    elseif cmd == "speak" then GL.CmdSpeak()
    elseif cmd == "voice" then GL.CmdVoice(rest)
    elseif cmd == "timer" then GL.CmdTimer(rest)
    elseif cmd == "splits" then GL.CmdSplits()
    elseif cmd == "theme" then GL.CmdTheme()
    elseif cmd == "arrow" then GL.CmdArrow(rest)
    elseif cmd == "trail" then GL.CmdTrail()
    elseif cmd == "twink" then GL.CmdTwink()
    elseif cmd == "rare" then GL.CmdRare()
    elseif cmd == "class" then GL.CmdClass()
    elseif cmd == "tomtom" then GL.CmdTomTom()
    elseif cmd == "questie" then GL.CmdQuestie(rest)
    elseif cmd == "hc" then GL.CmdHC(rest)
    elseif cmd == "pace" then GL.CmdPace()
    elseif cmd == "skipdungeon" then GL.CmdSkipDungeon()
    elseif cmd == "auto" then GL.CmdAuto(rest)
    elseif cmd == "cleanup" or cmd == "optimize" then GL.CmdCleanup()
    elseif cmd == "feedback" then GL.CmdFeedback(rest)
    elseif cmd == "way" then GL.CmdWay(rest)
    elseif cmd == "map" then GL.CmdMap()
    elseif cmd == "gather" then GL.CmdGather(rest)
    elseif cmd == "font" then GL.CmdFont(rest)
    elseif cmd == "cluster" then GL.CmdCluster()
    elseif cmd == "back" or cmd == "prev" then GL.CmdBack()
    elseif cmd == "history" then GL.CmdHistory()
    elseif cmd == "undo" then GL.CmdUndo()
    elseif cmd == "export-ai" or cmd == "ai" then GL.CmdExportAI()
    elseif cmd == "pin" then GL.CmdPin()
    elseif cmd == "chain" then GL.CmdChain()
    elseif cmd == "skip" then GL.CmdSkip()
    elseif cmd == "ignore" then GL.CmdIgnore()
    elseif cmd == "unignore" then GL.CmdUnignore(rest)
    elseif cmd == "unskip" then if GL.db then GL.db.skipped = {} GL.Refresh() end
    elseif cmd == "mode" then GL.CmdMode(rest)
    elseif cmd == "sync" then GL.CmdSync()
    elseif cmd == "resync" or cmd == "recalibrate" then GL.CmdRecalibrate()
    elseif cmd == "scan" then GL.CmdScan()
    elseif cmd == "reset" then GL.CmdReset()
    elseif cmd == "debug" then GL.CmdDebug()
    elseif cmd == "test" then GL.CmdTest()
    elseif cmd == "errors" then GL.UI.Create():Show() GL.UI.ShowTab("Log")
    elseif cmd == "reload" then GL.inited = false GL.state = nil GL.lastPinnedKey = nil GL.Init() GL.CmdRecalibrate()
    else GL.Print("/lg [ignore|unignore|optimize|skip|undo|unskip|skipdungeon|arrow|speak|voice|timer|splits|theme|mini|lock|stats|pin|chain|class|mode|sync|reset|debug|test]") end
  end)
end
