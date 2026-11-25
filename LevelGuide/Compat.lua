-- LevelGuide Compat: guarded WoW: Forever 1.60.1 (Interface 16001) API wrappers.
-- Replaces removed 1.12 globals (LoadAddOn, GetPlayerMapPosition, SetMapToCurrentZone,
-- GetNumQuestLogEntries, gcinfo, SetMinResize) with modern C_* namespaces.

local GL = LevelGuide
local C = {}
GL.Compat = C

function C.GetBuildString()
  if GetBuildInfo then
    local v, b, d, t = GetBuildInfo()
    return string.format("%s.%s (TOC %s, %s)", tostring(v), tostring(b), tostring(t), tostring(d))
  end
  return "Offline/Mock"
end

function C.InCombat()
  if InCombatLockdown then
    return InCombatLockdown() and true or false
  end
  return false
end

function C.IsPlayerDead()
  if UnitIsDeadOrGhost then
    return UnitIsDeadOrGhost("player") and true or false
  end
  return false
end

function C.LoadAddOn(name)
  if C_AddOns and C_AddOns.LoadAddOn then
    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, name)
    if ok then return loaded, reason end
    return false, loaded
  end
  return false, "C_AddOns.LoadAddOn unavailable"
end

function C.IsQuestCompleted(questId)
  if not questId then return false end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questId)
    if ok then return done and true or false end
  end
  return false
end

function C.IsQuestReadyForTurnIn(questId)
  if not questId then return false end
  if C_QuestLog and C_QuestLog.ReadyForTurnIn then
    local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questId)
    if ok and ready then return true end
  end
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questId)
    if ok and type(objs) == "table" and #objs > 0 then
      for i = 1, #objs do
        if not objs[i].finished then return false end
      end
      return true
    end
  end
  return false
end

function C.GetQuestObjectives(questId)
  local out = {}
  if not questId or not C_QuestLog or not C_QuestLog.GetQuestObjectives then return out end
  local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questId)
  objs = ok and C.SafeTable(objs) or nil
  if objs then
    for i = 1, #objs do
      local o = C.SafeTable(objs[i])
      local txt = o and C.SafeValue(o.text) or nil
      if o and type(txt) == "string" then
        out[#out + 1] = {
          text = txt,
          finished = (C.SafeValue(o.finished) == true),
          numFulfilled = C.SafeNumber(o.numFulfilled, nil),
          numRequired = C.SafeNumber(o.numRequired, nil),
          objType = C.SafeValue(o.type),
          objectiveType = C.SafeValue(o.objectiveType) or C.SafeValue(o.type),
        }
      end
    end
  end
  return out
end

-- Returns (list, numQuests, maxQuests, hasCollapsed)
function C.ReadQuestLog()
  local list, collapsed = {}, false
  local maxQ = (C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or 20
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local okN, numEntries, numQuests = pcall(C_QuestLog.GetNumQuestLogEntries)
    if okN and numEntries then
      for i = 1, numEntries do
        local okI, info = pcall(C_QuestLog.GetInfo, i)
        if okI and info and info.title then
          if info.isHeader then
            if info.isCollapsed then collapsed = true end
          elseif not info.isHidden then
            local qid = info.questID
            local complete = C.IsQuestReadyForTurnIn(qid)
            local objs = C.GetQuestObjectives(qid)
            list[#list + 1] = {
              questID = qid,
              title = info.title,
              level = info.level or info.difficultyLevel or 0,
              complete = complete,
              failed = false,
              objectives = objs,
            }
          end
        end
      end
      return list, (numQuests or #list), maxQ, collapsed
    end
  end
  return list, 0, maxQ, collapsed
end

-- Returns (mapId, zoneName, px_0_100, py_0_100)
function C.ReadPosition()
  if not C_Map or not C_Map.GetBestMapForUnit then
    return nil, GetRealZoneText and GetRealZoneText() or nil, nil, nil
  end
  local okM, mapId = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or not mapId then
    return nil, GetRealZoneText and GetRealZoneText() or nil, nil, nil
  end
  local zoneName = GetRealZoneText and GetRealZoneText() or nil
  if (not zoneName or zoneName == "") and C_Map.GetMapInfo then
    local okInfo, info = pcall(C_Map.GetMapInfo, mapId)
    if okInfo and info and info.name then zoneName = info.name end
  end
  local px, py = nil, nil
  if C_Map.GetPlayerMapPosition then
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, mapId, "player")
    if okP and pos and pos.GetXY then
      local x, y = pos:GetXY()
      if x and y and (x ~= 0 or y ~= 0) then
        px, py = x * 100, y * 100
      end
    end
  end
  return mapId, zoneName, px, py
end

-- Project player coordinates directly into a specific UiMapID (fixes sub-map / cave / micro-map drift)
function C.ReadPositionOnMap(targetMapId)
  if type(targetMapId) ~= "number" or not C_Map or not C_Map.GetPlayerMapPosition then
    return nil, nil
  end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, targetMapId, "player")
  if okP and pos and pos.GetXY then
    local okXY, x, y = pcall(pos.GetXY, pos)
    if okXY then
      x = C.SafeNumber(x, nil)
      y = C.SafeNumber(y, nil)
      if x and y and (x ~= 0 or y ~= 0) and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return x * 100, y * 100
      end
    end
  end
  return nil, nil
end

-- Counts item across bags + bank (for profession mat tracker)
function C.GetItemCount(itemId, includeBank)
  if not itemId then return 0 end
  if C_Item and C_Item.GetItemCount then
    local ok, cnt = pcall(C_Item.GetItemCount, itemId, includeBank and true or false)
    if ok and cnt then return cnt end
  end
  return 0
end

function C.GetMemoryKB()
  if C_AddOns and C_AddOns.UpdateAddOnMemoryUsage and C_AddOns.GetAddOnMemoryUsage then
    local okU = pcall(C_AddOns.UpdateAddOnMemoryUsage)
    if okU then
      local okM, kb = pcall(C_AddOns.GetAddOnMemoryUsage, "LevelGuide")
      if okM and kb then return kb end
    end
  end
  if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
    local ok = pcall(UpdateAddOnMemoryUsage)
    if ok then
      local okM, kb = pcall(GetAddOnMemoryUsage, "LevelGuide")
      if okM and kb then return kb end
    end
  end
  if collectgarbage then
    local okC, kb = pcall(collectgarbage, "count")
    if okC and kb then return kb end
  end
  return 0
end

function C.IsSecret(val)
  if type(issecretvalue) ~= "function" then return false end
  local ok, sec = pcall(issecretvalue, val)
  return ok and sec == true
end

function C.SafeValue(val)
  if C.IsSecret(val) then return nil end
  return val
end

function C.IsSecretTable(val)
  if C.IsSecret(val) then return true end
  if type(val) ~= "table" then return false end
  if type(issecrettable) ~= "function" then return false end
  local ok, sec = pcall(issecrettable, val)
  return (not ok) or sec == true
end

function C.SafeTable(val)
  if C.IsSecretTable(val) or type(val) ~= "table" then return nil end
  return val
end

function C.SafeNumber(val, default)
  val = C.SafeValue(val)
  if type(val) ~= "number" then return default end
  if val ~= val or val == math.huge or val == -math.huge then return default end
  return val
end

function C.PlayerSpeed()
  if type(GetUnitSpeed) ~= "function" then return nil end
  local ok, cur, run, flight, swim = pcall(GetUnitSpeed, "player")
  if not ok then return nil end
  return C.SafeNumber(cur, nil), C.SafeNumber(run, nil), C.SafeNumber(flight, nil), C.SafeNumber(swim, nil)
end

function C.PlayerFacing()
  if type(GetPlayerFacing) ~= "function" then return nil end
  local ok, raw = pcall(GetPlayerFacing)
  if not ok then return nil end
  return C.SafeNumber(raw, nil)
end

function C.UnitGUID(unit)
  if type(UnitGUID) ~= "function" then return nil end
  local ok, raw = pcall(UnitGUID, unit)
  if not ok then return nil end
  local g = C.SafeValue(raw)
  return (type(g) == "string") and g or nil
end

function C.GetCVar(name)
  if C_CVar and C_CVar.GetCVar then
    local ok, v = pcall(C_CVar.GetCVar, name)
    if ok then return v end
  end
  if GetCVar then
    local ok, v = pcall(GetCVar, name)
    if ok then return v end
  end
  return nil
end
