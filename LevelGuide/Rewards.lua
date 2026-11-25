-- LevelGuide Rewards: zero-taint class-aware quest reward advisor on QUEST_COMPLETE.
-- Evaluates offered choices by class armor/weapon priority and vendor sell value (fallback).

local GL = LevelGuide
local R = {}
GL.Rewards = R

-- Preferred armor subclasses by class token
local PREFERRED_ARMOR = {
  WARRIOR = { Plate = 3, Mail = 2.5, Leather = 1 },
  PALADIN = { Plate = 3, Mail = 2.5, Leather = 1 },
  HUNTER  = { Mail = 3, Leather = 2.5 },
  SHAMAN  = { Mail = 3, Leather = 2.5 },
  ROGUE   = { Leather = 3 },
  DRUID   = { Leather = 3, Cloth = 1 },
  PRIEST  = { Cloth = 3 },
  MAGE    = { Cloth = 3 },
  WARLOCK = { Cloth = 3 },
}

local PREFERRED_WEAPONS = {
  WARRIOR = { ["Two-Handed Swords"] = 3, ["Two-Handed Axes"] = 3, ["Two-Handed Maces"] = 3, ["One-Handed Swords"] = 2, ["One-Handed Axes"] = 2, ["Polearms"] = 2.5 },
  PALADIN = { ["Two-Handed Maces"] = 3, ["Two-Handed Swords"] = 3, ["Two-Handed Axes"] = 2.5, ["One-Handed Maces"] = 2 },
  HUNTER  = { Bows = 3, Crossbows = 3, Guns = 3, ["Two-Handed Axes"] = 2, Polearms = 2, Staves = 1.5 },
  ROGUE   = { ["One-Handed Swords"] = 3, Daggers = 3, ["One-Handed Maces"] = 2.5 },
  PRIEST  = { Wands = 3, Staves = 2.5, ["One-Handed Maces"] = 2 },
  MAGE    = { Wands = 3, Staves = 2.5, ["One-Handed Swords"] = 2 },
  WARLOCK = { Wands = 3, Staves = 2.5, Daggers = 2 },
  SHAMAN  = { ["Two-Handed Maces"] = 2.5, ["Two-Handed Axes"] = 2.5, Staves = 2.5, ["One-Handed Maces"] = 2 },
  DRUID   = { Staves = 3, ["Two-Handed Maces"] = 2.5, Daggers = 1.5 },
}

function R.EvaluateChoices()
  if not GetNumQuestChoices or not GetQuestItemLink then return nil end
  local okN, n = pcall(GetNumQuestChoices)
  if not okN or not n or n <= 1 then return nil end

  local classTok = (GL.profile and GL.profile.classToken) or "WARRIOR"
  local armPref = PREFERRED_ARMOR[classTok] or {}
  local wepPref = PREFERRED_WEAPONS[classTok] or {}

  local bestIdx, bestScore, bestName, bestReason = nil, -1, nil, nil
  local bestVendorIdx, bestVendorPrice, bestVendorName = nil, -1, nil

  for i = 1, n do
    local okL, link = pcall(GetQuestItemLink, "choice", i)
    if okL and link and C_Item and C_Item.GetItemInfo then
      local okI, name, _, quality, ilvl, _, itemType, itemSubType, _, _, _, sellPrice = pcall(C_Item.GetItemInfo, link)
      if okI and name then
        sellPrice = sellPrice or 0
        if sellPrice > bestVendorPrice then
          bestVendorPrice = sellPrice
          bestVendorIdx = i
          bestVendorName = name
        end
        local score = (ilvl or 1) + (quality or 1) * 5
        local reason = nil
        if itemType == "Weapon" and wepPref[itemSubType] then
          score = score + wepPref[itemSubType] * 25
          reason = itemSubType .. " upgrade for " .. classTok
        elseif itemType == "Armor" and armPref[itemSubType] then
          score = score + armPref[itemSubType] * 15
          reason = itemSubType .. " armor for " .. classTok
        end
        if reason and score > bestScore then
          bestScore = score
          bestIdx = i
          bestName = name
          bestReason = reason
        end
      end
    end
  end

  if bestIdx then
    local msg = string.format("Reward Pick (#%d): |cff55ff55%s|r (%s)", bestIdx, bestName, bestReason)
    if bestVendorIdx and bestVendorIdx ~= bestIdx and bestVendorPrice > 0 and GL.Integrations then
      local vFmt = GL.Integrations.FormatCopper(bestVendorPrice)
      if vFmt then
        msg = msg .. string.format(" | Highest vendor: #%d %s (%s)", bestVendorIdx, tostring(bestVendorName), vFmt)
      end
    end
    R.lastAdvice = msg
    return msg
  elseif bestVendorIdx and bestVendorPrice > 0 then
    local vFmt = (GL.Integrations and GL.Integrations.FormatCopper(bestVendorPrice)) or (tostring(bestVendorPrice) .. "c")
    local msg = string.format("Reward Vendor Pick (#%d): |cffffd100%s|r (%s)", bestVendorIdx, tostring(bestVendorName), vFmt)
    R.lastAdvice = msg
    return msg
  end
  return nil
end
