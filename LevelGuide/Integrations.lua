-- LevelGuide Integrations: safe, optional, read-only bridges to the user's installed addon stack.
-- Supported: TomTom, Questie, Syndicator/Baganator, Auctionator, BtWQuests, What's Training?,
-- Leatrix Maps / OpenMap (non-intrusive), Dialogue UI (rapid turn-in safe), Guidelime/PathForever conflict guard.

local GL = LevelGuide
local I = {}
GL.Integrations = I

I.detected = {}

local function isLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local ok, res = pcall(C_AddOns.IsAddOnLoaded, name)
    if ok then return res and true or false end
  end
  return false
end

function I.Scan()
  local d = {
    TomTom = (TomTom ~= nil) or isLoaded("TomTom"),
    Questie = (QuestieLoader ~= nil) or (Questie ~= nil) or isLoaded("Questie"),
    Syndicator = (Syndicator ~= nil) or isLoaded("Syndicator"),
    Baganator = (Baganator ~= nil) or isLoaded("Baganator"),
    Auctionator = (Auctionator ~= nil) or isLoaded("Auctionator"),
    BtWQuests = (BtWQuests ~= nil) or isLoaded("BtWQuests"),
    DialogueUI = (DialogueUI ~= nil) or isLoaded("DialogueUI"),
    WhatsTraining = isLoaded("WhatsTraining") or isLoaded("WhatsTraining_Forever"),
    LeatrixMaps = isLoaded("Leatrix_Maps"),
    OpenMap = isLoaded("OpenMap"),
    EllesmereUI = isLoaded("EllesmereUI"),
    Guidelime = isLoaded("Guidelime"),
    PathForever = isLoaded("PathForever"),
    BindOnForever = isLoaded("BindOnForeverGuide") or isLoaded("Bind on Forever Guide"),
    NovaInstanceTracker = isLoaded("NovaInstanceTracker"),
    RareScanner = (RareScanner ~= nil) or isLoaded("RareScanner"),
  }
  I.detected = d
  return d
end

-- Check if another guide addon might also control TomTom's arrow
function I.HasCompetingGuide()
  local d = I.detected
  local list = {}
  if d.Guidelime then list[#list + 1] = "Guidelime" end
  if d.PathForever then list[#list + 1] = "PathForever" end
  if d.BindOnForever then list[#list + 1] = "Bind on Forever Guide" end
  return #list > 0, list
end

-- Syndicator / Baganator: total count across ALL characters/banks if available, else current char bags+bank
function I.GetItemCounts(itemId)
  local charCount = (GL.Compat and GL.Compat.GetItemCount(itemId, true)) or 0
  local warbandOrAltCount = nil
  if Syndicator and Syndicator.API and Syndicator.API.GetInventoryInfoByItemID then
    local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, itemId)
    if ok and type(info) == "table" and type(info.characters) == "table" then
      local total = 0
      for _, c in pairs(info.characters) do
        total = total + (c.bags or 0) + (c.bank or 0) + (c.mail or 0)
      end
      warbandOrAltCount = total
    end
  end
  return charCount, warbandOrAltCount
end

-- Auctionator v1 API: get cached AH unit price in copper (read-only, never triggers scans)
function I.GetAuctionPriceCopper(itemId)
  if not itemId or not Auctionator or not Auctionator.API or not Auctionator.API.v1 then
    return nil
  end
  local fn = Auctionator.API.v1.GetAuctionPriceByItemID
  if type(fn) ~= "function" then return nil end
  local ok, price = pcall(fn, "LevelGuide", itemId)
  if ok and type(price) == "number" and price > 0 then
    return price
  end
  return nil
end

function I.FormatCopper(copper)
  if not copper or copper <= 0 then return nil end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  if g > 0 then return string.format("%dg %ds", g, s)
  elseif s > 0 then return string.format("%ds %dc", s, c)
  else return string.format("%dc", c) end
end

-- Questie bridge: look up Forever-exclusive or missing quest title/level from QuestieDB if loaded
function I.GetQuestieQuestName(questId)
  if not questId or not QuestieLoader or not QuestieLoader.ImportModule then return nil end
  local okMod, qdb = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
  if okMod and qdb and qdb.QueryQuestSingle then
    local okQ, name = pcall(qdb.QueryQuestSingle, questId, "name")
    if okQ and type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

-- BtWQuests bridge: open quest chain viewer for a questID (out of combat only)
function I.OpenBtWQuests(questId)
  if GL.Compat and GL.Compat.InCombat() then
    GL.Print("Cannot open BtWQuests during combat.")
    return false
  end
  if not BtWQuestsFrame or not BtWQuestsDatabase then
    GL.Print("BtWQuests is not loaded.")
    return false
  end
  local ok = pcall(function()
    if questId and BtWQuestsDatabase.GetQuestItem then
      local item = BtWQuestsDatabase:GetQuestItem(questId)
      if item and BtWQuestsFrame.SelectFromLink then
        BtWQuestsFrame:Show()
        return
      end
    end
    BtWQuestsFrame:Show()
  end)
  return ok
end

function I.GetSummaryLine()
  local d = I.detected
  local active = {}
  local order = {
    "TomTom", "Questie", "Syndicator", "Baganator", "Auctionator",
    "BtWQuests", "DialogueUI", "WhatsTraining", "LeatrixMaps",
    "OpenMap", "EllesmereUI", "NovaInstanceTracker", "RareScanner", "PathForever",
  }
  for _, k in ipairs(order) do
    if d[k] then active[#active + 1] = k end
  end
  local comp, compList = I.HasCompetingGuide()
  local msg = "Bridges: " .. (#active > 0 and table.concat(active, ", ") or "none")
  if comp then
    msg = msg .. "\n|cffffaa00Overlap:|r " .. table.concat(compList, ", ") .. " (turn off Auto-Pin in one to avoid TomTom arrow fights)"
  end
  return msg
end

-- QuestieDB live objective spawn bridge: when Questie is installed, look up real mob/object
-- spawn coordinates for an active OBJECTIVE quest so Arrow + MinimapTrail point to the mobs!
function I.GetQuestieObjectiveTarget(questId, curMapId)
  if not questId or not QuestieLoader or not QuestieLoader.ImportModule then return nil end
  local okM, qdb = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
  if not okM or not qdb or not qdb.GetQuest then return nil end
  local okQ, q = pcall(qdb.GetQuest, questId)
  if not okQ or type(q) ~= "table" or type(q.Objectives) ~= "table" then return nil end

  local fallbackName, fallbackZ, fallbackX, fallbackY = nil, nil, nil, nil
  for _, obj in pairs(q.Objectives) do
    if type(obj) == "table" and not obj.Completed and type(obj.spawnList) == "table" then
      for _, sp in pairs(obj.spawnList) do
        if type(sp) == "table" and type(sp.Spawns) == "table" then
          for zoneId, coordsList in pairs(sp.Spawns) do
            if type(coordsList) == "table" and type(coordsList[1]) == "table" then
              local cx, cy = coordsList[1][1], coordsList[1][2]
              if type(cx) == "number" and type(cy) == "number" and cx >= 0 and cx <= 100 and cy >= 0 and cy <= 100 then
                if curMapId and zoneId == curMapId then return sp.Name or "Objective Target", zoneId, cx, cy end
                if not fallbackX then fallbackName, fallbackZ, fallbackX, fallbackY = sp.Name or "Objective Target", zoneId, cx, cy end
              end
            end
          end
        end
      end
    end
  end
  if fallbackX then return fallbackName, fallbackZ, fallbackX, fallbackY end
  return nil
end
