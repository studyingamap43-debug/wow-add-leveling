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
  if ok and type(objs) == "table" then
    for i = 1, #objs do
      local o = objs[i]
      if o and o.text then
        out[#out + 1] = {
          text = o.text,
          finished = o.finished and true or false,
          numFulfilled = tonumber(o.numFulfilled),
          numRequired = tonumber(o.numRequired),
          objType = o.type,
          objectiveType = o.objectiveType or o.type,
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
  if issecretvalue then
    local ok, sec = pcall(issecretvalue, val)
    if ok and sec then return true end
  end
  return false
end

function C.SafeNumber(val, default)
  if val == nil or C.IsSecret(val) or type(val) ~= "number" then
    return default
  end
  return val
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
