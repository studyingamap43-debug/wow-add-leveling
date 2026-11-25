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

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
  "QUEST_REMOVED", "QUEST_COMPLETE", "TAXIMAP_OPENED", "GROUP_ROSTER_UPDATE",
  "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
  "PLAYER_XP_UPDATE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ALIVE",
  "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "UPDATE_INVENTORY_DURABILITY",
  "VIGNETTE_MINIMAP_UPDATED", "UPDATE_MOUSEOVER_UNIT", "UNIT_SPELLCAST_SUCCEEDED",
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
  if GL.Reminders then
    local rem = GL.Reminders.BuildAdvisories(step, ctx)
    for _, line in ipairs(rem) do table.insert(step.advisories, line) end
  end
  if GL.Integrations and GL.Integrations.detected.WhatsTraining and ctx.levelUp and GL.mod(level, 2) == 0 then
    table.insert(step.advisories, "Tip: Check your Spellbook -> What's Training? tab for new spells.")
  end

  GL.step = step
  GL.lastCtx = ctx
  local stepKey = tostring(step.kind) .. ":" .. tostring(step.ids and step.ids[1] or step.header)
  if GL.Timer then GL.Timer.OnStepChanged(stepKey) end
  if GL.Voice and GL.ready then GL.Voice.AnnounceStep(step, false) end

  -- Questie spawn bridge: if on an OBJECTIVE step and Questie is loaded, aim Arrow/Trail at real mob spawns!
  if step.kind == "OBJECTIVE" and step.ids and step.ids[1] and GL.Integrations and GL.Integrations.GetQuestieObjectiveTarget then
    local pMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil
    local spName, _, sx, sy = GL.Integrations.GetQuestieObjectiveTarget(step.ids[1], pMap)
    if spName and sx and sy then
      step.target = { spName, step.target and step.target[2] or 0, sx, sy }
      step.targetZone = zone or step.targetZone
      step.targetIsTurnIn = false
      step.where = string.format("Questie Spawn: %s (%.1f, %.1f) in %s", spName, sx, sy, tostring(step.targetZone or "?"))
    end
  end

  -- Auto-pin only outdoors and when WorldMapFrame is not actively being browsed
  local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
  if not inInst and not mapOpen and GL.db and GL.db.settings.autoPin and step.target and GL.Waypoint then
    local pinKey = tostring(step.target[1]) .. ":" .. tostring(step.target[2]) .. ":" .. tostring(step.target[3])
    if pinKey ~= GL.lastPinnedKey then
      GL.lastPinnedKey = pinKey
      GL.Waypoint.SetForTarget(step.target, step.targetZone, step.header)
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
    local qid = (type(a1) == "number" and a1 > 0) and a1 or (type(a2) == "number" and a2 > 0 and a2 or nil)
    if qid and GL.Discoveries then GL.Safe("DiscoverAccept", GL.Discoveries.RecordQuest, qid, "ACCEPT") end
    GL.Safe("ScanLog", GL.ScanLog)
    GL.dirty = true
  elseif event == "QUEST_TURNED_IN" then
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
  elseif event == "QUEST_COMPLETE" then
    if GL.Rewards then
      local advice = GL.Safe("Rewards", GL.Rewards.EvaluateChoices)
      if advice then GL.Print(advice) GL.dirty = true end
    end
  elseif event == "TAXIMAP_OPENED" then
    if GL.Travel then GL.Safe("ScanFP", GL.Travel.ScanFlightPaths) end
  elseif event == "VIGNETTE_MINIMAP_UPDATED" and GL.RareAlert then
    GL.Safe("RareVignette", GL.RareAlert.OnVignette, a1)
  elseif event == "UPDATE_MOUSEOVER_UNIT" and GL.RareAlert then
    GL.Safe("RareMouseover", GL.RareAlert.OnMouseoverUnit)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" and a1 == "player" and GL.GatherNodes then
    local sid = (type(a3) == "number" and a3) or (type(a2) == "number" and a2) or nil
    if sid == 2366 then
      GL.Safe("RecHerb", GL.GatherNodes.RecordCurrentNode, "HERB", "Herb")
    elseif sid == 2575 then
      GL.Safe("RecMine", GL.GatherNodes.RecordCurrentNode, "MINE", "Mining Vein")
    elseif sid and C_Spell and C_Spell.GetSpellName then
      local spellName = C_Spell.GetSpellName(sid)
      if spellName then
        local lo = string.lower(tostring(spellName))
        if string.find(lo, "herb") then GL.Safe("RecHerb", GL.GatherNodes.RecordCurrentNode, "HERB", "Herb")
        elseif string.find(lo, "mining") then GL.Safe("RecMine", GL.GatherNodes.RecordCurrentNode, "MINE", "Mining Vein") end
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
GL.timerAccum = 0
      GL.dirty = true
    end
    if GL.dirty and GL.accum >= 0.5 then
      GL.accum = 0
      GL.Safe("Refresh", GL.Refresh)
    end
  end)
end

-- ---------- commands ----------
function GL.CmdSkip()
  if not GL.state or not GL.step or not GL.step.ids then GL.Print("Nothing to skip.") return end
  GL.db.lastSkipped = {}
  for _, id in ipairs(GL.step.ids) do
    for _, sid in ipairs(GL.Engine.Siblings(GL.state, id)) do
      GL.db.skipped[sid] = true
      GL.db.lastSkipped[#GL.db.lastSkipped + 1] = sid
    end
  end
  GL.RecordStepHistory("[SKIPPED] " .. tostring(GL.step.header or "Step"))
  GL.Print("Skipped " .. #GL.step.ids .. " quest(s). /guide unskip to restore.")
  GL.Refresh()
end

function GL.CmdChain()
  local qid = (GL.step and GL.step.ids and GL.step.ids[1]) or nil
  if GL.Integrations then GL.Integrations.OpenBtWQuests(qid) end
end

function GL.CmdPin()
  if not GL.step or not GL.step.target then GL.Print("No waypoint target for current step.") return end
  local _, msg = GL.Waypoint.SetForTarget(GL.step.target, GL.step.targetZone, GL.step.header)
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
  GL.db.done = {} GL.db.skipped = {} GL.db.synced = nil
  if GL.state then GL.state.prev = nil end
  GL.Print("Progress reset for this character.")
  if GL.state then GL.Refresh() end
end

function GL.CmdScan()
  if not GL.state then GL.Print("LevelGuide data not loaded yet.") return end
  GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.ScanLog()
  local level = UnitLevel and UnitLevel("player") or 1
  local _, zone, px, py = GL.Compat.ReadPosition()
  local ctx = { level = level, zone = zone, px = px, py = py }
  local best = GL.Engine.ScanNearestArea(GL.state, GL.db, ctx)
  if not best then
    GL.Print("Scan: No available quests found in your level window (check Dungeons / Grinding tab).")
    return
  end
  if GL.Waypoint and GL.Waypoint.SetForTarget then
    GL.Waypoint.SetForTarget(best.n, best.zone, "Nearest Area: " .. best.n[1])
  end
  local distStr = best.sameZone and string.format("~%.0f map units away", best.distUnits or 0) or ("travel to " .. tostring(best.zone))
  GL.Print(string.format("|cff55ff55Scan locked:|r %s in %s (%.1f, %.1f) — %s, %d quest(s) ready!",
    tostring(best.n[1]), tostring(best.zone), best.n[3], best.n[4], distStr, #best.ids))
  GL.Refresh()
end

function GL.CmdRecalibrate()
  if not GL.state then
    GL.inited = false
    GL.Init()
    return
  end
  GL.state.prev = nil
  GL.lastPinnedKey = nil
  local synced = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.ScanLog()
  GL.Refresh()
  if GL.step and GL.step.target and GL.Waypoint then
    GL.Waypoint.SetForTarget(GL.step.target, GL.step.targetZone, GL.step.header)
  end
  GL.Print(string.format("Recalibrated quest log: +%d server-completed, %d active in log -> [%s] %s",
    synced, GL.lastLogCount or 0, tostring(GL.step and GL.step.kind or "NONE"), tostring(GL.step and GL.step.header or "-")))
end

function GL.CmdSync()
  if not GL.state then return end
  local c = GL.Engine.SyncFromServer(GL.state, GL.db, GL.Compat.IsQuestCompleted)
  GL.Print("Synced " .. c .. " completed quest(s) from server (no level-based guessing).")
  GL.Refresh()
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
  chk("LevelGuideDB v8 initialized", type(GL.db) == "table" and GL.db.version == 8)
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
    elseif cmd == "way" then GL.CmdWay(rest)
    elseif cmd == "map" then GL.CmdMap()
    elseif cmd == "gather" then GL.CmdGather(rest)
    elseif cmd == "font" then GL.CmdFont(rest)
    elseif cmd == "cluster" then GL.CmdCluster()
    elseif cmd == "prev" or cmd == "history" then GL.CmdHistory()
    elseif cmd == "undo" then GL.CmdUndo()
    elseif cmd == "export-ai" or cmd == "ai" then GL.CmdExportAI()
    elseif cmd == "pin" then GL.CmdPin()
    elseif cmd == "chain" then GL.CmdChain()
    elseif cmd == "skip" then GL.CmdSkip()
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
    else GL.Print("/guide [arrow|speak|voice|timer|splits|theme|mini|lock|stats|pin|chain|discoveries|skip|unskip|mode|sync|reset|debug|test]") end
  end)
end
