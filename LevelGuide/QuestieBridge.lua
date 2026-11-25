-- LevelGuide QuestieBridge v1.1.1: Multi-source live nearby monster/objective spawn resolver.
-- Checks in order:
--   1. QuestieMap live drawn objective pins (QuestieMap.questIdFrames[questId]) — closest to player!
--   2. QuestiePlayer.currentQuestlog[questId].Objectives spawnList (via ZoneDB AreaID -> UiMapID)
--   3. QuestieDB.QueryQuestSingle / QueryNPCSingle / QueryObjectSingle / QueryItemSingle
--   4. Blizzard native C_QuestLog.GetNextWaypointForMap / GetNextWaypoint (Forever 16001)
-- Always picks the CLOSEST spawn point to (px, py) and returns canonical LevelGuide.Location.

local GL = LevelGuide
local QB = {}
GL.QuestieBridge = QB

QB.cache = {}
local CACHE_TTL = 1.5 -- short TTL so arrow dynamically switches to next nearby spawn as you move

local function safeZoneName(uiMapId)
  if not uiMapId or not C_Map or type(C_Map.GetMapInfo) ~= "function" then return "?" end
  local ok, info = pcall(C_Map.GetMapInfo, uiMapId)
  return (ok and type(info) == "table" and info.name) or "?"
end

local function importMod(name)
  if not QuestieLoader or type(QuestieLoader.ImportModule) ~= "function" then return nil end
  local ok, mod = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
  return (ok and type(mod) == "table") and mod or nil
end

function QB.HasQuestieModules()
  return (importMod("QuestieDB") ~= nil) or (importMod("QuestieMap") ~= nil)
end

function QB.IsQuestieAddonLoaded()
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, res = pcall(C_AddOns.IsAddOnLoaded, "Questie")
    if ok and res then return true end
  end
  return false
end

function QB.IsLoadedOnForever()
  return QB.IsQuestieAddonLoaded() and QB.HasQuestieModules()
end

function QB.IsAvailable()
  -- Use live modules whenever they exist, even if the addon folder is not named "Questie".
  return QB.HasQuestieModules()
end

function QB.AreaToUiMapID(areaId)
  if type(areaId) ~= "number" or areaId <= 0 then return nil end
  local zdb = importMod("ZoneDB")
  if zdb and type(zdb.GetUiMapIdByAreaId) == "function" then
    local ok, uiMapId = pcall(zdb.GetUiMapIdByAreaId, zdb, areaId)
    if ok and type(uiMapId) == "number" and uiMapId > 0 then
      return uiMapId
    end
  end
  return nil
end

local function pickClosestSpawn(spawnsByArea, playerUiMapId, px, py)
  if type(spawnsByArea) ~= "table" then return nil end
  local best, bestScore = nil, 1e12

  for areaId, coordList in pairs(spawnsByArea) do
    if type(areaId) == "number" and areaId > 0 and type(coordList) == "table" then
      local uiMapId = QB.AreaToUiMapID(areaId)
      if uiMapId then
        local sameMap = (playerUiMapId and uiMapId == playerUiMapId)
        for i = 1, #coordList do
          local pt = coordList[i]
          if type(pt) == "table" then
            local cx = GL.Compat and GL.Compat.SafeNumber(pt[1], nil)
            local cy = GL.Compat and GL.Compat.SafeNumber(pt[2], nil)
            if cx and cy and cx >= 0 and cx <= 100 and cy >= 0 and cy <= 100 then
              local d = (sameMap and px and py) and math.sqrt((cx - px) ^ 2 + (cy - py) ^ 2) or 50
              -- Slightly avoid pinning a spot < 0.8 units directly under player's feet if another spawn exists nearby
              local score = (sameMap and 0 or 10000) + ((d < 0.8) and (d + 4) or d)
              if score < bestScore then
                bestScore = score
                best = { areaId = areaId, uiMapId = uiMapId, x = cx, y = cy, sameMap = sameMap }
              end
            end
          end
        end
      end
    end
  end
  return best
end

-- Source 1: Read Questie's live drawn objective map pins (works even for Forever-custom quests!)
local function findFromQuestieMapPins(questId, playerUiMapId, px, py)
  local qMap = importMod("QuestieMap")
  if not qMap or type(qMap.questIdFrames) ~= "table" then return nil end
  local frames = qMap.questIdFrames[questId]
  if type(frames) ~= "table" then return nil end

  local best, bestScore = nil, 1e12
  for _, frameName in pairs(frames) do
    local icon = (type(frameName) == "string" and _G[frameName]) or (type(frameName) == "table" and frameName) or nil
    if type(icon) == "table" and type(icon.data) == "table" then
      local d = icon.data
      -- Only objective pins (skip available/complete turn-in pins)
      local itype = d.Type
      if itype ~= "available" and itype ~= "complete" then
        local ix = GL.Compat and GL.Compat.SafeNumber(icon.x, nil)
        local iy = GL.Compat and GL.Compat.SafeNumber(icon.y, nil)
        if ix and iy and ix > 0 and ix <= 1 and iy > 0 and iy <= 1 then
          ix, iy = ix * 100, iy * 100
        end
        local uiMapId = icon.AreaID and QB.AreaToUiMapID(icon.AreaID) or nil
        if ix and iy and ix >= 0 and ix <= 100 and iy >= 0 and iy <= 100 and uiMapId then
          local sameMap = (playerUiMapId and uiMapId == playerUiMapId)
          local distU = (sameMap and px and py) and math.sqrt((ix - px) ^ 2 + (iy - py) ^ 2) or 50
          local score = (sameMap and 0 or 10000) + ((distU < 0.8) and (distU + 4) or distU)
          if score < bestScore then
            bestScore = score
            local lbl = (d.Name and tostring(d.Name)) or (d.ObjectiveData and d.ObjectiveData.Name and tostring(d.ObjectiveData.Name)) or "Quest Mob/Area"
            best = { uiMapId = uiMapId, x = ix, y = iy, label = lbl }
          end
        end
      end
    end
  end

  if best then
    return GL.Location and GL.Location.FromZonePct(safeZoneName(best.uiMapId), best.x, best.y, "QuestieMap", "creature", "questie", best.uiMapId, best.label)
  end
  return nil
end

-- Source 4: Blizzard native Forever 16001 C_QuestLog.GetNextWaypointForMap / GetNextWaypoint
local function findFromBlizzardWaypoint(questId, playerUiMapId)
  if not C_QuestLog then return nil end
  local mapId, wx, wy = nil, nil, nil
  if playerUiMapId and type(C_QuestLog.GetNextWaypointForMap) == "function" then
    local ok, x, y = pcall(C_QuestLog.GetNextWaypointForMap, questId, playerUiMapId)
    if ok and x and y then mapId, wx, wy = playerUiMapId, x, y end
  end
  if not wx and type(C_QuestLog.GetNextWaypoint) == "function" then
    local ok, m, x, y = pcall(C_QuestLog.GetNextWaypoint, questId)
    if ok and m and x and y then mapId, wx, wy = m, x, y end
  end
  wx = GL.Compat and GL.Compat.SafeNumber(wx, nil)
  wy = GL.Compat and GL.Compat.SafeNumber(wy, nil)
  if mapId and wx and wy and wx >= 0 and wx <= 1 and wy >= 0 and wy <= 1 then
    return GL.Location and GL.Location.FromZonePct(safeZoneName(mapId), wx * 100, wy * 100, "BlizzardMap", "area", "verified", mapId, "Objective Area")
  end
  return nil
end

function QB.GetObjectiveLocation(questId, playerUiMapId, px, py)
  if not questId then return nil end
  if GL.db and GL.db.settings and GL.db.settings.useQuestieSpawns == false then return nil end
  if not QB.HasQuestieModules() then return findFromBlizzardWaypoint(questId, playerUiMapId) end

  local now = GetTime and GetTime() or 0
  local c = QB.cache[questId]
  local moved = (not c) or (not px) or (not c.px) or (math.abs(px - c.px) > 1.5) or (math.abs((py or 0) - (c.py or 0)) > 1.5)
  if c and not moved and (now - c.ts) < CACHE_TTL and c.mapId == playerUiMapId then
    return c.loc
  end

  local foundLoc = nil

  -- 1. Live QuestieMap pins (closest monster/object spawn drawn right now!)
  foundLoc = findFromQuestieMapPins(questId, playerUiMapId, px, py)

  -- 2. Live QuestiePlayer.currentQuestlog[questId].Objectives
  if not foundLoc then
    local qPlayer = importMod("QuestiePlayer")
    local liveQ = qPlayer and type(qPlayer.currentQuestlog) == "table" and qPlayer.currentQuestlog[questId] or nil
    if type(liveQ) == "table" and type(liveQ.Objectives) == "table" then
      for _, obj in pairs(liveQ.Objectives) do
        if type(obj) == "table" and not obj.Completed and type(obj.spawnList) == "table" then
          for _, sp in pairs(obj.spawnList) do
            if type(sp) == "table" and type(sp.Spawns) == "table" then
              local hit = pickClosestSpawn(sp.Spawns, playerUiMapId, px, py)
              if hit then
                local locType = (obj.Type == "item") and "item_drop_candidate" or (obj.Type or "creature")
                local lbl = tostring(sp.Name or "Objective") .. ((obj.Type == "item") and " (Drop Candidate)" or "")
                foundLoc = GL.Location and GL.Location.FromZonePct(safeZoneName(hit.uiMapId), hit.x, hit.y, "QuestieDB", locType, "questie", hit.uiMapId, lbl)
                break
              end
            end
          end
        end
        if foundLoc then break end
      end
    end
  end

  -- 3. Static QuestieDB.QueryQuestSingle(questId, "objectives") -> NPC / Object / Item drops
  if not foundLoc then
    local qdb = importMod("QuestieDB")
    if qdb and type(qdb.QueryQuestSingle) == "function" then
      local okO, objs = pcall(qdb.QueryQuestSingle, questId, "objectives")
      if okO and type(objs) == "table" then
        local function tryEntityList(list, queryFn, locType, suffix)
          if type(list) ~= "table" or type(queryFn) ~= "function" then return nil end
          local bestLoc, bestD = nil, 1e12
          for _, entry in ipairs(list) do
            local eid = type(entry) == "table" and entry[1] or entry
            if type(eid) == "number" then
              local okS, spawns = pcall(queryFn, eid, "spawns")
              if okS and type(spawns) == "table" then
                local hit = pickClosestSpawn(spawns, playerUiMapId, px, py)
                if hit then
                  local d = (hit.sameMap and px and py) and math.sqrt((hit.x - px) ^ 2 + (hit.y - py) ^ 2) or 1000
                  if d < bestD then
                    bestD = d
                    local okN, ename = pcall(queryFn, eid, "name")
                    local lbl = tostring((okN and ename) or ("Entity #" .. tostring(eid))) .. (suffix or "")
                    bestLoc = GL.Location and GL.Location.FromZonePct(safeZoneName(hit.uiMapId), hit.x, hit.y, "QuestieDB", locType, "questie", hit.uiMapId, lbl)
                  end
                end
              end
            end
          end
          return bestLoc
        end

        foundLoc = tryEntityList(objs[1], qdb.QueryNPCSingle, "creature", "")
          or tryEntityList(objs[2], qdb.QueryObjectSingle, "object", "")

        if not foundLoc and type(objs[3]) == "table" and type(qdb.QueryItemSingle) == "function" then
          for _, entry in ipairs(objs[3]) do
            local itemId = type(entry) == "table" and entry[1] or entry
            if type(itemId) == "number" then
              local okD, droppers = pcall(qdb.QueryItemSingle, itemId, "npcDrops")
              if okD and type(droppers) == "table" then
                foundLoc = tryEntityList(droppers, qdb.QueryNPCSingle, "item_drop_candidate", " (Drop Candidate)")
                if foundLoc then break end
              end
            end
          end
        end
      end
    end
  end

  -- 4. Blizzard native C_QuestLog.GetNextWaypoint fallback
  if not foundLoc then
    foundLoc = findFromBlizzardWaypoint(questId, playerUiMapId)
  end

  QB.cache[questId] = { ts = now, mapId = playerUiMapId, px = px, py = py, loc = foundLoc }
  return foundLoc
end

function QB.GetFinisherLocation(questId, playerUiMapId, px, py)
  local qdb = importMod("QuestieDB")
  if not qdb or type(qdb.QueryQuestSingle) ~= "function" then return nil end
  local okF, fin = pcall(qdb.QueryQuestSingle, questId, "finishedBy")
  if not okF or type(fin) ~= "table" then return nil end
  local npcs = fin[1]
  if type(npcs) == "table" and type(qdb.QueryNPCSingle) == "function" then
    for _, npcId in ipairs(npcs) do
      local okS, spawns = pcall(qdb.QueryNPCSingle, npcId, "spawns")
      if okS and type(spawns) == "table" then
        local hit = pickClosestSpawn(spawns, playerUiMapId, px, py)
        if hit then
          local okN, nname = pcall(qdb.QueryNPCSingle, npcId, "name")
          return GL.Location and GL.Location.FromZonePct(safeZoneName(hit.uiMapId), hit.x, hit.y, "QuestieDB", "turnin", "questie", hit.uiMapId, tostring((okN and nname) or "Turn-In NPC"))
        end
      end
    end
  end
  return nil
end

function QB.GetStatusString()
  local hasQDB = importMod("QuestieDB") ~= nil
  local hasQMap = importMod("QuestieMap") ~= nil
  local hasZDB = importMod("ZoneDB") ~= nil
  local hasQP  = importMod("QuestiePlayer") ~= nil
  local on = not (GL.db and GL.db.settings and GL.db.settings.useQuestieSpawns == false)
  local mode
  if QB.IsQuestieAddonLoaded() and QB.HasQuestieModules() then
    mode = "QuestieLive"
  elseif QB.HasQuestieModules() then
    mode = "QuestieModules"
  else
    mode = "BlizzardWaypointFallback"
  end
  return string.format("QuestieBridge(%s): enabled=%s | QuestieMap=%s | QuestieDB=%s | ZoneDB=%s | QuestiePlayer=%s", mode,
    tostring(on), tostring(hasQMap), tostring(hasQDB), tostring(hasZDB), tostring(hasQP))
end
