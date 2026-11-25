-- LevelGuide Location: single canonical location object shared by Arrow, MinimapTrail,
-- WorldMapOverlay, and Waypoint so coordinate conversions never drift.

local GL = LevelGuide
local L = {}
GL.Location = L

function L.FromZonePct(zoneName, xPct, yPct, source, locationType, confidence, uiMapID, label)
  local x = GL.Compat and GL.Compat.SafeNumber(xPct, nil) or nil
  local y = GL.Compat and GL.Compat.SafeNumber(yPct, nil) or nil
  if not x or not y or x < 0 or x > 100 or y < 0 or y > 100 then
    return nil
  end
  local mapId = uiMapID
  if not mapId and zoneName and GL.Waypoint then
    if GL.Waypoint.ResolveMapId then mapId = GL.Waypoint.ResolveMapId(zoneName)
    elseif GL.Waypoint.ZONE_TO_UIMAP then mapId = GL.Waypoint.ZONE_TO_UIMAP[zoneName] end
  end
  return {
    source = source or "LevelGuide",
    locationType = locationType or "npc",
    uiMapID = mapId,
    zoneName = zoneName or "?",
    xPercent = x,
    yPercent = y,
    zoneX = x / 100,
    zoneY = y / 100,
    confidence = confidence or "unverified",
    label = label or "",
  }
end
