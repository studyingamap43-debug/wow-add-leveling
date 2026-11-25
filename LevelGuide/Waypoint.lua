-- LevelGuide Waypoint: maps pfQuest zone names to WoW: Forever 16001 UiMapIDs,
-- sets native C_Map + C_SuperTrack map pins, optional TomTom bridge, or text coord fallback.

local GL = LevelGuide
local W = {}
GL.Waypoint = W

local lastTomTomUid = nil

-- Standard Classic/Forever UiMapIDs (source: Wowpedia UiMapID)
W.ZONE_TO_UIMAP = {
  ["Durotar"] = 1411,
  ["Mulgore"] = 1412,
  ["The Barrens"] = 1413,
  ["Alterac Mountains"] = 1416,
  ["Arathi Highlands"] = 1417,
  ["Badlands"] = 1418,
  ["Blasted Lands"] = 1419,
  ["Tirisfal Glades"] = 1420,
  ["Silverpine Forest"] = 1421,
  ["Western Plaguelands"] = 1422,
  ["Eastern Plaguelands"] = 1423,
  ["Hillsbrad Foothills"] = 1424,
  ["The Hinterlands"] = 1425,
  ["Dun Morogh"] = 1426,
  ["Searing Gorge"] = 1427,
  ["Burning Steppes"] = 1428,
  ["Elwynn Forest"] = 1429,
  ["Deadwind Pass"] = 1430,
  ["Duskwood"] = 1431,
  ["Darkshire"] = 1431,
  ["Loch Modan"] = 1432,
  ["Redridge Mountains"] = 1433,
  ["Stranglethorn Vale"] = 1434,
  ["Swamp of Sorrows"] = 1435,
  ["Westfall"] = 1436,
  ["Wetlands"] = 1437,
  ["Teldrassil"] = 1438,
  ["Darkshore"] = 1439,
  ["Ashenvale"] = 1440,
  ["Thousand Needles"] = 1441,
  ["Stonetalon Mountains"] = 1442,
  ["Desolace"] = 1443,
  ["Feralas"] = 1444,
  ["Dustwallow Marsh"] = 1445,
  ["Tanaris"] = 1446,
  ["Azshara"] = 1447,
  ["Felwood"] = 1448,
  ["Un'Goro Crater"] = 1449,
  ["Moonglade"] = 1450,
  ["Silithus"] = 1451,
  ["Winterspring"] = 1452,
  ["Stormwind City"] = 1453,
  ["Orgrimmar"] = 1454,
  ["Ironforge"] = 1455,
  ["Thunder Bluff"] = 1456,
  ["Darnassus"] = 1457,
  ["Undercity"] = 1458,
  ["Alterac Valley"] = 1459,
  -- New WoW: Forever zones (UiMapIDs confirmed on forever.azerpug.com, azerdex.com, and moredots.io)
  ["Riverglades"] = 2548,
  ["Mount Hyjal"] = 2482,
  Hyjal = 2482,
  ["Shen'dralas"] = 2652,
  ["Zephras Isle"] = 2521,
}

-- If the static table misses a name, use the player's current map when the names match.
function W.ResolveMapId(zoneName)
  if not zoneName or zoneName == "" then return nil end
  local id = W.ZONE_TO_UIMAP[zoneName]
  if id then return id end
  if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
    local okM, mapId = pcall(C_Map.GetBestMapForUnit, "player")
    if okM and mapId then
      local okI, info = pcall(C_Map.GetMapInfo, mapId)
      if okI and type(info) == "table" and type(info.name) == "string"
         and string.lower(info.name) == string.lower(zoneName) then
        return mapId
      end
    end
  end
  return nil
end

function W.Clear()
  if lastTomTomUid and TomTom and TomTom.RemoveWaypoint then
    pcall(TomTom.RemoveWaypoint, TomTom, lastTomTomUid)
    lastTomTomUid = nil
  end
  if GL.Arrow and GL.Arrow.Clear then GL.Arrow.Clear() end
  if GL.MinimapTrail and GL.MinimapTrail.Clear then GL.MinimapTrail.Clear() end
  if GL.WorldMapOverlay and GL.WorldMapOverlay.SetTarget then GL.WorldMapOverlay.SetTarget(nil) end
  if C_Map and C_Map.ClearUserWaypoint then
    pcall(C_Map.ClearUserWaypoint)
  end
end

-- target = { npcName, pfZoneId, x_0_100, y_0_100 }
function W.SetForTarget(target, zoneName, title, explicitMapId)
  if not target or not target[3] or not target[4] then
    return false, "No coordinates available for this step."
  end
  local mapId = (type(explicitMapId) == "number" and explicitMapId > 0 and explicitMapId)
    or (zoneName and (W.ResolveMapId and W.ResolveMapId(zoneName) or W.ZONE_TO_UIMAP[zoneName]) or nil)
  local label = (title or "LevelGuide") .. " - " .. tostring(target[1] or "")
  local loc = GL.Location and GL.Location.FromZonePct(zoneName, target[3], target[4], "LevelGuide", "npc", "unverified", mapId, label) or nil
  if not loc then return false, "Invalid coordinates rejected by Location validator." end
  GL.activeLocation = loc
  local x, y = loc.xPercent, loc.yPercent
  mapId = loc.uiMapID
  if GL.Arrow and GL.Arrow.SetTarget then
    GL.Arrow.SetTarget(mapId, zoneName, x, y, title, target[1])
  end
  if GL.MinimapTrail and GL.MinimapTrail.SetTarget then
    GL.MinimapTrail.SetTarget(mapId, zoneName, x, y)
  end
  if GL.WorldMapOverlay and GL.WorldMapOverlay.SetTarget then
    local kind = (GL.step and GL.step.kind) or "OBJECTIVE"
    GL.WorldMapOverlay.SetTarget(mapId, zoneName, x, y, kind, label)
  end
  local useTomTom = GL.db and GL.db.settings and GL.db.settings.useTomTom

  -- 1. Optional TomTom integration (no conflict if TomTom is absent)
  if useTomTom and mapId and TomTom and TomTom.AddWaypoint then
    if lastTomTomUid and TomTom.RemoveWaypoint then
      pcall(TomTom.RemoveWaypoint, TomTom, lastTomTomUid)
    end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapId, x / 100, y / 100, {
      title = label,
      persistent = false,
      minimap = true,
      world = true,
    })
    if ok and uid then
      lastTomTomUid = uid
      if TomTom.SetCrazyArrow then pcall(TomTom.SetCrazyArrow, TomTom, uid, 12, label) end
      return true, string.format("TomTom: %s (%.1f, %.1f)", tostring(zoneName), x, y)
    end
  end

  -- 2. Native WoW: Forever 16001 C_Map + C_SuperTrack pin
  if mapId and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local okPt, pt = pcall(UiMapPoint.CreateFromCoordinates, mapId, x / 100, y / 100)
    if okPt and pt then
      local okSet = pcall(C_Map.SetUserWaypoint, pt)
      if okSet then
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
          pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        return true, string.format("Map Pin: %s (%.1f, %.1f)", tostring(zoneName), x, y)
      end
    end
  end

  -- 3. Text coordinate fallback
  return false, string.format("Coords: %s (%.1f, %.1f)", tostring(zoneName or "?"), x, y)
end

function W.SetCustomWay(x, y, label)
  local mapId, zoneName
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zoneName = GL.Compat.ReadPosition()
  end
  if not mapId then
    GL.Print("Cannot set custom waypoint: current map unknown.")
    return
  end
  local title = (label and label ~= "") and label or string.format("Waypoint (%.1f, %.1f)", x, y)
  if GL.Arrow and GL.Arrow.SetTarget then GL.Arrow.SetTarget(mapId, zoneName, x, y, "WAYPOINT", title) end
  if GL.MinimapTrail and GL.MinimapTrail.SetTarget then GL.MinimapTrail.SetTarget(mapId, zoneName, x, y) end
  if GL.db and GL.db.settings.useTomTom and TomTom and TomTom.AddWaypoint then
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapId, x / 100, y / 100, { title = title, persistent = false })
    if ok and uid then lastTomTomUid = uid end
  end
  GL.Print(string.format("Custom Waypoint: %s in %s (%.1f, %.1f)", title, tostring(zoneName or "?"), x, y))
end
