-- LevelGuide Discoveries: records WoW: Forever-exclusive quests (not in pfQuest 1.12 DB)
-- automatically as you accept/turn them in, storing verified IDs, zone, and coords in LevelGuideDB.

local GL = LevelGuide
local D = {}
GL.Discoveries = D

function D.RecordQuest(questId, eventTag)
  if not questId or not GL.db then return end
  if GL.data and GL.data.quests and GL.data.quests[questId] then return end -- already in pfQuest DB
  GL.db.discoveries = type(GL.db.discoveries) == "table" and GL.db.discoveries or {}

  local title = nil
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questId)
    if ok and t and t ~= "" then title = t end
  end
  if not title and GL.Integrations then
    title = GL.Integrations.GetQuestieQuestName(questId)
  end

  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zone, px, py = GL.Compat.ReadPosition()
  end
  local existing = GL.db.discoveries[questId] or {}
  existing.id = questId
  existing.title = title or existing.title or ("Quest #" .. tostring(questId))
  existing.level = (UnitLevel and UnitLevel("player")) or existing.level or 1
  existing.zone = zone or existing.zone or "?"
  existing.mapId = mapId or existing.mapId
  if eventTag == "ACCEPT" and px and py then
    existing.sx, existing.sy = math.floor(px * 10 + 0.5) / 10, math.floor(py * 10 + 0.5) / 10
  elseif eventTag == "TURNIN" and px and py then
    existing.ex, existing.ey = math.floor(px * 10 + 0.5) / 10, math.floor(py * 10 + 0.5) / 10
  end
  GL.db.discoveries[questId] = existing
  GL.LogEvent("DISCOVERY", tostring(questId) .. " " .. tostring(existing.title))
end

function D.Count()
  if not GL.db or type(GL.db.discoveries) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(GL.db.discoveries) do n = n + 1 end
  return n
end

function D.ExportString()
  local lines = { "=== LevelGuide Discovered WoW: Forever Quests ===" }
  if not GL.db or type(GL.db.discoveries) ~= "table" then
    lines[#lines + 1] = "(none yet — accept or turn in Forever-exclusive quests to record them)"
    return table.concat(lines, "\n")
  end
  local ids = {}
  for id in pairs(GL.db.discoveries) do ids[#ids + 1] = id end
  table.sort(ids)
  if #ids == 0 then
    lines[#lines + 1] = "(none yet)"
  else
    for _, id in ipairs(ids) do
      local q = GL.db.discoveries[id]
      lines[#lines + 1] = string.format("[%d] %s (Lv %s, %s, map=%s, start=%s,%s, end=%s,%s)",
        id, tostring(q.title), tostring(q.level), tostring(q.zone), tostring(q.mapId or "?"),
        tostring(q.sx or "?"), tostring(q.sy or "?"), tostring(q.ex or "?"), tostring(q.ey or "?"))
    end
  end
  return table.concat(lines, "\n")
end
