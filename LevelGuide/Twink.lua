-- LevelGuide Twink: Gold-funded Alt & Twinking Leveling Guide (1-60).
-- Class-aware enchants (zero level req!), potions/elixirs, food, BoE power spikes, bags,
-- and profession power-leveling — with live GetMoney() budget & Auctionator price checks.

local GL = LevelGuide
local TW = {}
GL.Twink = TW

local CLASS_ROLE = {
  WARRIOR = "MELEE", PALADIN = "MELEE", ROGUE = "MELEE",
  HUNTER = "RANGED",
  MAGE = "CASTER", WARLOCK = "CASTER", PRIEST = "CASTER",
  SHAMAN = "HYBRID", DRUID = "HYBRID",
}

local function formatGold(copper)
  copper = math.floor(tonumber(copper) or 0)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  return string.format("%dg %ds", g, s)
end

local function ahTag(itemId)
  if not itemId or not GL.Integrations then return "" end
  local p = GL.Integrations.GetAuctionPriceCopper(itemId)
  if p and p > 0 then
    local f = GL.Integrations.FormatCopper(p)
    if f then return " |cff88ccff(AH: " .. f .. ")|r" end
  end
  return ""
end

function TW.GetLines(level, classTok)
  level = tonumber(level) or 1
  classTok = classTok or "WARRIOR"
  local role = CLASS_ROLE[classTok] or "MELEE"
  local okM, rawM = pcall(GetMoney or function() return 0 end)
  local copper = (okM and GL.Compat and GL.Compat.SafeNumber(rawM, 0)) or 0
  local gold = math.floor(copper / 10000)

  local tier = "Budget (<10g)"
  if gold >= 100 then tier = "High-Budget Twink (100g+)"
  elseif gold >= 25 then tier = "Funded Alt (25g+)"
  elseif gold >= 10 then tier = "Starter Alt (10g+)" end

  local lines = {}
  lines[#lines + 1] = string.format("|cfff0c252Alt / Twink Guide — Lv %d %s|r  |cff55ff55Gold: %s|r (%s)",
    level, classTok, formatGold(copper), tier)

  -- 1. Zero-Level-Req Enchants (huge leveling ROI!)
  lines[#lines + 1] = "\n|cfff0c2521) Best Enchants (Work from Level 1!)|r"
  lines[#lines + 1] = "• Boots: |cff55ff55Minor Speed (+8% run speed)|r — #1 leveling enchant for EVERY class."
  lines[#lines + 1] = "• Chest: +100 Health (or +3/+4 All Stats) | Cloak: +50/+70 Armor."
  if role == "MELEE" or role == "HYBRID" then
    lines[#lines + 1] = "• Weapon: |cffffd100Fiery Weapon|r (insane 1-45 proc DPS!) or Crusader (budget: +5/+7 Weapon Dmg, Iron Counterweight +3% haste)."
    lines[#lines + 1] = "• Bracers: +5/+7/+9 Strength or Stamina | Gloves: +5/+7 Agi or +5/+7 Str."
  elseif role == "RANGED" then
    lines[#lines + 1] = "• Ranged: Deadly Scope (+7 dmg) / Sniper Scope | Melee: +15 Agility (2H) or +5/+7 Agi."
    lines[#lines + 1] = "• Bracers/Gloves: +7 Agility / +7 Stamina."
  else
    lines[#lines + 1] = "• Weapon: +30 Spell Power (or +22 Intellect) + Minor/Lesser Wizard Oil."
    lines[#lines + 1] = "• Bracers: +7 Intellect / +7 Stamina | Boots: Minor Speed."
  end

  -- 2. Potions, Elixirs & Food for current level bracket
  lines[#lines + 1] = "\n|cfff0c2522) Consumables (Pots, Elixirs & Food for Lv " .. level .. ")|r"
  lines[#lines + 1] = "• Speed & Survival: Swiftness Potion" .. ahTag(2459) .. " | Rumsey Rum Black Label (+15 Stam!)" .. ahTag(21151)
  if level < 15 then
    lines[#lines + 1] = "• Pots: Minor/Lesser Healing Potion" .. ahTag(858) .. " | Elixir of Lion's Strength" .. ahTag(2454) .. " | Weak Troll's Blood" .. ahTag(3382)
    lines[#lines + 1] = "• Food: Spiced Wolf Meat / Roasted Boar (+2 Stam/Spirit) + Rough Sharpening Stone" .. ahTag(2862)
  elseif level < 30 then
    lines[#lines + 1] = "• Pots: Healing Potion" .. ahTag(929) .. " | Strong Troll's Blood" .. ahTag(3388) .. " | Elixir of Ogre's Strength" .. ahTag(3391) .. " / Lesser Agility" .. ahTag(3390)
    lines[#lines + 1] = "• Food: Smoked Sagefish (Mana/5) / Seasoned Wolf Kabob (+6 Stam/Spirit) + Coarse/Heavy Sharpening Stone."
  elseif level < 45 then
    lines[#lines + 1] = "• Pots: Greater Healing Potion" .. ahTag(1710) .. " | Elixir of Agility" .. ahTag(8949) .. " / Arcane Elixir" .. ahTag(9155) .. " | Free Action Potion" .. ahTag(5634)
    lines[#lines + 1] = "• Food: Soothing Turtle Bisque / Heavy Crocolisk Stew (+8 Stam/Spirit) + Solid Sharpening Stone."
  else
    lines[#lines + 1] = "• Pots: Superior/Major Healing Potion" .. ahTag(13446) .. " | Elixir of Giants" .. ahTag(9206) .. " / Mongoose" .. ahTag(13452) .. " / Greater Arcane" .. ahTag(13454)
    lines[#lines + 1] = "• Food: Grilled Squid / Nightfin Soup / Smoked Desert Dumplings (+20 Str) + Dense Sharpening Stone."
  end

  -- 3. Class BoE Power Spikes & Bags
  lines[#lines + 1] = "\n|cfff0c2523) Gear Power Spikes & Bags|r"
  lines[#lines + 1] = "• Bags: Buy 4x Runecloth Bag (14-slot)" .. ahTag(14046) .. " or Traveler's Backpack (16-slot) immediately — eliminates vendor backtracking."
  if classTok == "WARRIOR" or classTok == "PALADIN" then
    lines[#lines + 1] = "• Weapons (Lv 1-20): White/Green slow 2H every 4-5 levels + Fiery Weapon (e.g. Lv 12 Heavy Copper Broadsword -> Lv 18 Cruel Barb/Smite's Hammer)."
    lines[#lines + 1] = "• Weapons (Lv 25-50): Lv 30 Whirlwind Axe (buy Troll Charms on AH!) -> Lv 37 Executioner's Cleaver / Kang -> Lv 48+ Lord Alexander's Battle Axe."
  elseif role == "CASTER" then
    lines[#lines + 1] = "• Wands: Lesser Magic Wand (Lv 5)" .. ahTag(11287) .. " -> Greater Magic Wand (Lv 13)" .. ahTag(11288) .. " — #1 caster leveling DPS spike!"
    lines[#lines + 1] = "• Gear: Stack 'of the Eagle' (Int/Stam) or '+Spell/Shadow/Frost Damage' greens every 6-8 levels."
  elseif role == "RANGED" then
    lines[#lines + 1] = "• Weapons: Upgrade Bow/Gun every 5 levels + best Scope; keep high-DPS arrows/bullets + 14-slot Quiver/Ammo Pouch."
  else
    lines[#lines + 1] = "• Gear: Upgrade slow MH weapon (Rogue/Shaman) or high-DPS Staff/Mace (Druid) every 5-6 levels + Fiery/Agility enchant."
  end

  -- 4. Gold-Funded Profession Fast-Track
  lines[#lines + 1] = "\n|cfff0c2524) Fast Profession Upgrades (With Gold)|r"
  lines[#lines + 1] = "• First Aid (1-300): Buy Linen/Wool/Silk/Mageweave/Runecloth on AH — Heavy Runecloth Bandages at Lv 35+ remove downtime."
  lines[#lines + 1] = "• Engineering (1-225): Rough/Coarse/Heavy Dynamite, Iron Grenades, and Target Dummies make soloing elites trivial."
  lines[#lines + 1] = "• Cooking (1-225): Buy vendor Spice Bread (1-40) then AH meat/eggs for cheap +Stamina/+Spirit Well Fed buffs."

  return lines
end
