-- LevelGuide GatherNodes: reads verified Herb & Mining node locations from GatherMate2 /
-- GatherMate2_Data / GatherLite (if installed) + live-records nodes you harvest in WoW: Forever.
-- Never invents node coordinates.

local GL = LevelGuide
local G = {}
GL.GatherNodes = G

-- Decode GatherMate2 packed integer coordinate key -> (x_0_100, y_0_100)
local function decodeGM2Coord(coord)
  if type(coord) ~= "number" or coord <= 0 then return nil, nil end
  local x = math.floor(coord / 1000000) / 100
  local y = math.floor((coord % 1000000) / 100) / 100
  if x >= 0 and x <= 100 and y >= 0 and y <= 100 then
    return x, y
  end
  return nil, nil
end

-- Returns list of { kind = "HERB"|"MINE", x = 0..100, y = 0..100, name = string, source = string }
function G.GetNodesForMap(mapId, maxCount)
  if not mapId then return {} end
  maxCount = maxCount or 60
  local out = {}

  -- 1. GatherMate2 / GatherMate2_Data Herb & Mining DBs
  local function readGM2(dbTbl, kind, label)
    if type(dbTbl) ~= "table" or type(dbTbl[mapId]) ~= "table" then return end
    for coord, nodeId in pairs(dbTbl[mapId]) do
      if #out >= maxCount then return end
      local x, y = decodeGM2Coord(coord)
      if x and y then
        out[#out + 1] = { kind = kind, x = x, y = y, name = label .. " #" .. tostring(nodeId), source = "GatherMate2" }
      end
    end
  end

  if type(GatherMate2HerbDB) == "table" then
    readGM2(GatherMate2HerbDB, "HERB", "Herb")
  end
  if type(GatherMate2MineDB) == "table" then
    readGM2(GatherMate2MineDB, "MINE", "Mining Vein")
  end

  -- 2. Player's own live-recorded WoW: Forever nodes (LevelGuideDB.gatherNodes[mapId])
  local saved = GL.db and GL.db.gatherNodes and GL.db.gatherNodes[mapId]
  if type(saved) == "table" then
    for _, n in ipairs(saved) do
      if #out >= maxCount then break end
      if n.x and n.y then
        out[#out + 1] = { kind = n.kind or "HERB", x = n.x, y = n.y, name = n.name or "Node", source = "Recorded" }
      end
    end
  end

  return out
end

function G.RecordCurrentNode(kind, label)
  if not GL.db then return end
  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zone, px, py = GL.Compat.ReadPosition()
  end
  if not mapId or not px or not py then return end

  GL.db.gatherNodes = type(GL.db.gatherNodes) == "table" and GL.db.gatherNodes or {}
  GL.db.gatherNodes[mapId] = type(GL.db.gatherNodes[mapId]) == "table" and GL.db.gatherNodes[mapId] or {}
  local list = GL.db.gatherNodes[mapId]

  -- Deduplicate within 1.5 map units
  for _, n in ipairs(list) do
    if n.kind == kind and math.abs((n.x or 0) - px) < 1.5 and math.abs((n.y or 0) - py) < 1.5 then
      return
    end
  end
  list[#list + 1] = {
    kind = kind,
    name = label or kind,
    x = math.floor(px * 10 + 0.5) / 10,
    y = math.floor(py * 10 + 0.5) / 10,
    zone = zone or "?",
  }
  GL.LogEvent("GATHER_NODE", tostring(kind) .. " " .. tostring(zone))
end

function G.PinNearestNode(filterKind)
  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zone, px, py = GL.Compat.ReadPosition()
  end
  if not mapId or not px or not py then
    GL.Print("Cannot locate player on current map to find nearest node.")
    return
  end
  local nodes = G.GetNodesForMap(mapId, 200)
  local best, bestD = nil, 1e9
  for _, n in ipairs(nodes) do
    if not filterKind or n.kind == filterKind then
      local dx, dy = n.x - px, n.y - py
      local d = math.sqrt(dx * dx + dy * dy)
      if d > 0.4 and d < bestD then
        best, bestD = n, d
      end
    end
  end
  if not best then
    GL.Print("No Herb/Mining nodes found for " .. tostring(zone or "this zone") .. " (install GatherMate2_Data or harvest a node to record it).")
    return
  end
  if GL.Arrow and GL.Arrow.SetTarget then GL.Arrow.SetTarget(mapId, zone, best.x, best.y, best.kind, best.name) end
  if GL.MinimapTrail and GL.MinimapTrail.SetTarget then GL.MinimapTrail.SetTarget(mapId, zone, best.x, best.y) end
  GL.Print(string.format("Pinned nearest %s (%s): (%.1f, %.1f) in %s. Use /guide pin to return to quest.",
    best.kind, best.source, best.x, best.y, tostring(zone or "?")))
end
