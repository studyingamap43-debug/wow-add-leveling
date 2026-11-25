-- LevelGuide Fallback: Dungeons, Grinding Spots, and ALL 12 Professions 1-300
-- with live Syndicator/Bag+Bank Mat Tracker + Auctionator Shopping List total cost.

local GL = LevelGuide
local F = {}
GL.Fallback = F

F.DUNGEONS = {
  { name = "Hall of Thanes [Forever*]", minL = 13, maxL = 18, fac = "Both", zone = "Beneath Ironforge, Dun Morogh", size = 5, notes = "New Forever dungeon; verify quests & entrance in-game." },
  { name = "Ragefire Chasm", minL = 13, maxL = 18, fac = "Horde", zone = "Orgrimmar", size = 5, notes = "Fast Horde starter XP; grab Thrall/Varimathras/Neeru quests." },
  { name = "Ruins of Lordaeron [Forever*]", minL = 15, maxL = 20, fac = "Both", zone = "Tirisfal Glades", size = 5, notes = "New Forever dungeon; verify quests & access in-game." },
  { name = "Wailing Caverns", minL = 15, maxL = 24, fac = "Both", zone = "The Barrens", size = 5, notes = "Great Horde quest hub; skip full maze if group is slow." },
  { name = "The Deadmines", minL = 17, maxL = 26, fac = "Alliance", zone = "Westfall", size = 5, notes = "Core Alliance melee upgrades (Cruel Barb / Smite's Hammer)." },
  { name = "Shadowfang Keep", minL = 20, maxL = 30, fac = "Both", zone = "Silverpine Forest", size = 5, notes = "Strong caster/melee drops (Arugal's Belt, Meteor Shard)." },
  { name = "Blackfathom Deeps", minL = 22, maxL = 32, fac = "Both", zone = "Ashenvale", size = 5, notes = "Good wand/caster upgrades; skip if travel is too far." },
  { name = "Excavation Site: Wetlands [Forever*]", minL = 24, maxL = 29, fac = "Both", zone = "Wetlands", size = 5, notes = "New Forever dungeon; great mid-20s XP." },
  { name = "The Stockade", minL = 24, maxL = 32, fac = "Alliance", zone = "Stormwind City", size = 5, notes = "Zero travel time for Alliance; 5-6 stacked quests." },
  { name = "City of Dalaran [Forever*]", minL = 28, maxL = 33, fac = "Both", zone = "Alterac Mountains", size = 5, notes = "New Forever dungeon; check Dalaran Sewer Key / attunement." },
  { name = "Gnomeregan", minL = 29, maxL = 38, fac = "Both", zone = "Dun Morogh", size = 5, notes = "Triprunner Dungarees quest reward; skip if group lacks patience." },
  { name = "Razorfen Kraul", minL = 29, maxL = 38, fac = "Both", zone = "The Barrens", size = 5, notes = "Corpsemaker 2H axe for Warriors/Paladins/Shamans." },
  { name = "Scarlet Monastery: Graveyard", minL = 30, maxL = 38, fac = "Both", zone = "Tirisfal Glades", size = 5, notes = "Fastest SM wing; good starter cleave XP." },
  { name = "Scarlet Monastery: Armory", minL = 32, maxL = 42, fac = "Both", zone = "Tirisfal Glades", size = 5, notes = "Herod's Shoulder + Ravager 2H axe for melee." },
  { name = "Scarlet Monastery: Library", minL = 33, maxL = 41, fac = "Both", zone = "Tirisfal Glades", size = 5, notes = "Hypnotic Blade + Illusionary Rod + Scarlet Key." },
  { name = "The Drowned City [Forever*]", minL = 35, maxL = 40, fac = "Both", zone = "Stranglethorn Vale", size = 5, notes = "New Forever dungeon; verify faction access & quests." },
  { name = "Scarlet Monastery: Cathedral", minL = 35, maxL = 45, fac = "Both", zone = "Tirisfal Glades", size = 5, notes = "Whitemane's Chapeau + Mograine's Might." },
  { name = "Razorfen Downs", minL = 37, maxL = 46, fac = "Both", zone = "The Barrens", size = 5, notes = "Vanquisher's Sword quest reward." },
  { name = "Krol'dok Stronghold [Forever*]", minL = 40, maxL = 45, fac = "Both", zone = "Riverglades", size = 5, notes = "New Forever dungeon in Riverglades; verify access." },
  { name = "Uldaman", minL = 41, maxL = 51, fac = "Both", zone = "Badlands", size = 5, notes = "Enchanting trainer inside; Archaedas optional if under-leveled." },
  { name = "Zul'Farrak", minL = 44, maxL = 54, fac = "Both", zone = "Tanaris", size = 5, notes = "Huge XP pyramid event + Carrot on a Stick quest." },
  { name = "Maraudon", minL = 46, maxL = 55, fac = "Both", zone = "Desolace", size = 5, notes = "Thrash Blade quest reward + Blackstone Ring." },
  { name = "Alcaz Island / Prison [Forever*]", minL = 48, maxL = 53, fac = "Both", zone = "Dustwallow Marsh", size = 5, notes = "New Forever dungeon; verify quests & access." },
  { name = "Sunken Temple", minL = 50, maxL = 56, fac = "Both", zone = "Swamp of Sorrows", size = 5, notes = "Level 50 class quests; bring a map for statue order." },
  { name = "Blackrock Depths", minL = 52, maxL = 60, fac = "Both", zone = "Blackrock Mountain", size = 5, notes = "Arena/Angerforge/Emperor runs; Onyxia/MC attunements." },
  { name = "Blackmaw Hold [Forever*]", minL = 55, maxL = 60, fac = "Both", zone = "Azshara", size = 5, notes = "New Forever endgame dungeon; verify attunement/quests." },
  { name = "Blackrock Spire (LBRS/UBRS)", minL = 55, maxL = 60, fac = "Both", zone = "Blackrock Mountain", size = 5, notes = "Pre-raid BiS + Seal of Ascension / Onyxia chain." },
  { name = "Dire Maul (East/West/North)", minL = 55, maxL = 60, fac = "Both", zone = "Feralas", size = 5, notes = "Tribute buffs, class books, pre-raid BiS." },
  { name = "Scholomance", minL = 58, maxL = 60, fac = "Both", zone = "Western Plaguelands", size = 5, notes = "Skeleton Key required; pre-raid BiS & Tier 0." },
  { name = "Stratholme (Live/Dead)", minL = 58, maxL = 60, fac = "Both", zone = "Eastern Plaguelands", size = 5, notes = "Argent Dawn rep, Tier 0, Baron mount." },
  { name = "The Shaper's Terrace [Forever*]", minL = 58, maxL = 60, fac = "Both", zone = "Un'Goro Crater", size = 5, notes = "New Forever 58-60 dungeon; endgame gear & quests." },
}

F.GRINDING = {
  { minL = 1, maxL = 10, fac = "Alliance", zone = "Elwynn Forest", spot = "Fargodeep / Northshire Kobolds & Wolves", loot = "Linen Cloth, vendor meat/candles" },
  { minL = 1, maxL = 10, fac = "Horde", zone = "Durotar / Tirisfal", spot = "Razor Hill Quilboars & Scorpids", loot = "Linen Cloth, vendor tails/tusks" },
  { minL = 10, maxL = 20, fac = "Alliance", zone = "Westfall / Loch Modan", spot = "Moonbrook Defias / Troggs", loot = "Linen/Wool Cloth, green BoEs" },
  { minL = 10, maxL = 20, fac = "Horde", zone = "The Barrens", spot = "Crossroads Razormane & Savannah Beasts", loot = "Linen Cloth, Light Leather" },
  { minL = 20, maxL = 30, fac = "Both", zone = "Duskwood / Hillsbrad", spot = "Raven Hill Undead / Hillsbrad Yetis", loot = "Wool/Silk Cloth, Heavy Leather" },
  { minL = 30, maxL = 40, fac = "Both", zone = "Riverglades (33-54) / Shen'dralas (38-43) / STV", spot = "New Forever Riverglades hubs / STV Beasts", loot = "Thick Leather, Silk/Mageweave, vendor trash" },
  { minL = 40, maxL = 50, fac = "Both", zone = "Tanaris / Hinterlands / Feralas", spot = "Southsea Pirates / Feralas Yetis", loot = "Mageweave Cloth, Rugged Leather" },
  { minL = 50, maxL = 60, fac = "Both", zone = "Mount Hyjal (55-60) / WPL / Felwood / Winterspring", spot = "Mount Hyjal Forever quests / Sorrow Hill / Timbermaw", loot = "Runecloth, Lv 48+ bonus quest gold, rep" },
}

-- All 12 Classic Professions 1-300 with Classic itemIDs for live bag+bank+Syndicator+Auctionator tracking
F.PROFESSIONS = {
  ["First Aid"] = {
    { range = "1-40",    rank = "Apprentice",   recipe = "Linen Bandage",         itemId = 2589,  matName = "Linen Cloth",     need = 50 },
    { range = "40-80",   rank = "Journeyman",   recipe = "Heavy Linen Bandage",   itemId = 2589,  matName = "Linen Cloth",     need = 80 },
    { range = "80-115",  rank = "Journeyman",   recipe = "Wool Bandage",          itemId = 2592,  matName = "Wool Cloth",      need = 60 },
    { range = "115-150", rank = "Expert Book",  recipe = "Heavy Wool Bandage",    itemId = 2592,  matName = "Wool Cloth",      need = 80 },
    { range = "150-210", rank = "Expert",       recipe = "Silk / Heavy Silk",     itemId = 4306,  matName = "Silk Cloth",      need = 120 },
    { range = "210-260", rank = "Artisan Quest",recipe = "Mageweave / Heavy MW",  itemId = 4338,  matName = "Mageweave Cloth", need = 100 },
    { range = "260-300", rank = "Artisan",      recipe = "Runecloth / Heavy RC",  itemId = 14047, matName = "Runecloth",       need = 120 },
  },
  ["Cooking"] = {
    { range = "1-40",    rank = "Apprentice",   recipe = "Spice Bread (vendor!)", itemId = 2678,  matName = "Mild Spices",     need = 45, vendor = true },
    { range = "40-85",   rank = "Journeyman",   recipe = "Smoked Bear / Crab",    itemId = 3173,  matName = "Bear Meat",       need = 45 },
    { range = "85-130",  rank = "Journeyman",   recipe = "Boiled Clams / Coyote", itemId = 5503,  matName = "Clam Meat",       need = 50 },
    { range = "130-175", rank = "Expert Book",  recipe = "Curiously Tasty Omelet",itemId = 3685,  matName = "Raptor Egg",      need = 50 },
    { range = "175-225", rank = "Expert",       recipe = "Roast Raptor / Turtle", itemId = 12203, matName = "Red Wolf Meat",   need = 60 },
    { range = "225-300", rank = "Artisan Quest",recipe = "Monster Omelet / Squid",itemId = 12207, matName = "Giant Egg",       need = 80 },
  },
  ["Fishing"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Starter zones",         itemId = 6529,  matName = "Shiny Bauble",    need = 10, vendor = true },
    { range = "75-150",  rank = "Journeyman",   recipe = "Barrens / Westfall",    itemId = 6530,  matName = "Nightcrawlers",   need = 10, vendor = true },
    { range = "150-225", rank = "Expert Book",  recipe = "STV / Arathi",          itemId = 6532,  matName = "Bright Baubles",  need = 10, vendor = true },
    { range = "225-300", rank = "Artisan Quest",recipe = "Tanaris / Feralas",     itemId = 6533,  matName = "Aquadynamic",     need = 10, vendor = true },
  },
  ["Mining"] = {
    { range = "1-65",    rank = "Apprentice",   recipe = "Copper Vein (Starter)", itemId = 2770,  matName = "Copper Ore",      need = 65 },
    { range = "65-125",  rank = "Journeyman",   recipe = "Tin / Silver",          itemId = 2771,  matName = "Tin Ore",         need = 65 },
    { range = "125-175", rank = "Expert",       recipe = "Iron Deposit",          itemId = 2772,  matName = "Iron Ore",        need = 60 },
    { range = "175-245", rank = "Expert/Art.",  recipe = "Mithril Deposit",       itemId = 3858,  matName = "Mithril Ore",     need = 80 },
    { range = "245-300", rank = "Artisan",      recipe = "Thorium Vein",          itemId = 10620, matName = "Thorium Ore",     need = 80 },
  },
  ["Herbalism"] = {
    { range = "1-70",    rank = "Apprentice",   recipe = "Peacebloom / Silverleaf",itemId = 2447, matName = "Peacebloom",      need = 50 },
    { range = "70-150",  rank = "Journeyman",   recipe = "Mageroyal / Briarthorn", itemId = 2450, matName = "Briarthorn",      need = 60 },
    { range = "150-230", rank = "Expert",       recipe = "Kingsblood / Fadeleaf",  itemId = 3356, matName = "Kingsblood",      need = 60 },
    { range = "230-300", rank = "Artisan",      recipe = "Sungrass / Dreamfoil",   itemId = 8838, matName = "Sungrass",        need = 70 },
  },
  ["Skinning"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Lv 1-15 Beasts",        itemId = 2318,  matName = "Light Leather",   need = 60 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Lv 15-30 Beasts",       itemId = 2319,  matName = "Medium Leather",  need = 60 },
    { range = "150-225", rank = "Expert",       recipe = "Lv 30-45 Beasts",       itemId = 4234,  matName = "Heavy Leather",   need = 60 },
    { range = "225-300", rank = "Artisan",      recipe = "Lv 45-60 Beasts",       itemId = 8170,  matName = "Rugged Leather",  need = 60 },
  },
  ["Alchemy"] = {
    { range = "1-60",    rank = "Apprentice",   recipe = "Minor Healing Potion",  itemId = 2447,  matName = "Peacebloom",      need = 60 },
    { range = "60-140",  rank = "Journeyman",   recipe = "Lesser / Healing Pot",  itemId = 2450,  matName = "Briarthorn",      need = 60 },
    { range = "140-215", rank = "Expert",       recipe = "Greater Healing Pot",   itemId = 3357,  matName = "Liferoot",        need = 50 },
    { range = "215-300", rank = "Artisan",      recipe = "Superior / Major Pots", itemId = 8838,  matName = "Sungrass",        need = 75 },
  },
  ["Blacksmithing"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Rough Sharpening / Bracers", itemId = 2840, matName = "Copper Bar",  need = 90 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Coarse Grinding Stone (to 90!) / Bronze", itemId = 2841, matName = "Bronze Bar", need = 100 },
    { range = "150-215", rank = "Expert",       recipe = "Heavy / Iron / Steel",  itemId = 3575,  matName = "Iron Bar",        need = 120 },
    { range = "215-300", rank = "Artisan",      recipe = "Mithril / Thorium Gear",itemId = 3860,  matName = "Mithril Bar",     need = 160 },
  },
  ["Engineering"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Rough Blasting Powder", itemId = 2835,  matName = "Rough Stone",     need = 90 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Coarse / Bronze Tubes", itemId = 2836,  matName = "Coarse Stone",    need = 90 },
    { range = "150-215", rank = "Expert",       recipe = "Heavy / Iron Struts",   itemId = 2838,  matName = "Heavy Stone",     need = 90 },
    { range = "215-300", rank = "Artisan",      recipe = "Solid / Dense Powder",  itemId = 7912,  matName = "Solid Stone",     need = 120 },
  },
  ["Enchanting"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Minor Health / Bracer", itemId = 10940, matName = "Strange Dust",    need = 100 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Lesser Stamina/Spirit", itemId = 11083, matName = "Soul Dust",       need = 90 },
    { range = "150-225", rank = "Expert",       recipe = "Vision Dust Enchants",  itemId = 11137, matName = "Vision Dust",     need = 100 },
    { range = "225-300", rank = "Artisan",      recipe = "Dream / Illusion Dust", itemId = 11176, matName = "Dream Dust",      need = 120 },
  },
  ["Leatherworking"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Light Armor Kit",       itemId = 2318,  matName = "Light Leather",   need = 100 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Medium Armor / Boots",  itemId = 2319,  matName = "Medium Leather",  need = 110 },
    { range = "150-225", rank = "Expert",       recipe = "Heavy / Thick Kits",    itemId = 4234,  matName = "Heavy Leather",   need = 120 },
    { range = "225-300", rank = "Artisan",      recipe = "Nightscape / Rugged",   itemId = 8170,  matName = "Rugged Leather",  need = 140 },
  },
  ["Tailoring"] = {
    { range = "1-75",    rank = "Apprentice",   recipe = "Bolt of Linen Cloth",   itemId = 2589,  matName = "Linen Cloth",     need = 160 },
    { range = "75-150",  rank = "Journeyman",   recipe = "Bolt of Woolen Cloth",  itemId = 2592,  matName = "Wool Cloth",      need = 160 },
    { range = "150-225", rank = "Expert",       recipe = "Bolt of Silk / Hood",   itemId = 4306,  matName = "Silk Cloth",      need = 220 },
    { range = "225-300", rank = "Artisan",      recipe = "Mageweave / Runecloth", itemId = 14047, matName = "Runecloth",       need = 240 },
  },
}

F.PROF_ORDER = {
  "First Aid", "Cooking", "Fishing", "Mining", "Herbalism", "Skinning",
  "Alchemy", "Blacksmithing", "Engineering", "Enchanting", "Leatherworking", "Tailoring",
}

function F.GetDungeonLines(level, faction)
  local lines = { "|cff88ccffForever Note:|r Max 5 dungeon resets/hr (Nov 20 hotfix); * = new Forever dungeon." }
  if IsInInstance then
    local ok, inInst, instType = pcall(IsInInstance)
    if ok and inInst and instType == "party" then
      lines[#lines + 1] = "|cff55ff55Currently inside a 5-man dungeon!|r Outdoor quest auto-resync is paused."
    end
  end
  local matched = 0
  for _, d in ipairs(F.DUNGEONS) do
    if (d.fac == "Both" or d.fac == faction) and level >= d.minL - 3 and level <= d.maxL + 4 then
      matched = matched + 1
      lines[#lines + 1] = string.format("|cffffd100%s|r (Lv %d-%d, %d-man) — %s\n  %s",
        d.name, d.minL, d.maxL, d.size, d.zone, d.notes)
    end
  end
  if matched == 0 then
    lines[#lines + 1] = "No dungeons in immediate range for Lv " .. tostring(level) .. " (first opens around Lv 13-17)."
  end
  return lines
end

function F.GetGrindingLines(level, faction)
  local lines = {}
  for _, g in ipairs(F.GRINDING) do
    if (g.fac == "Both" or g.fac == faction) and level >= g.minL - 2 and level <= g.maxL + 2 then
      lines[#lines + 1] = string.format("|cff55ff55%s|r (Lv %d-%d): %s\n  Loot: %s",
        g.zone, g.minL, g.maxL, g.spot, g.loot)
    end
  end
  if #lines == 0 then
    lines[1] = "No grinding spots matched Lv " .. tostring(level) .. "."
  end
  return lines
end

function F.GetProfessionLines(profName)
  local list = F.PROFESSIONS[profName]
  if not list then return { "Select a profession." } end
  local rows = {
    "|cffffd100" .. profName .. " (1-300 Skill-Band Estimates)|r",
    "|cffaaaaaaNote: Rough primary-mat estimates only (not a full multi-reagent recipe BOM).|r",
  }
  for _, row in ipairs(list) do
    local have, allChars = 0, nil
    if GL.Integrations then
      have, allChars = GL.Integrations.GetItemCounts(row.itemId)
    elseif GL.Compat then
      have = GL.Compat.GetItemCount(row.itemId, true)
    end
    local col = (have >= row.need) and "|cff55ff55" or "|cffffaa00"
    local vTag = row.vendor and " [Vendor]" or ""
    local altStr = (allChars and allChars > have) and string.format(" (Alts: %d)", allChars) or ""
    local ahStr = ""
    if GL.Integrations and not row.vendor then
      local unitPrice = GL.Integrations.GetAuctionPriceCopper(row.itemId)
      if unitPrice and unitPrice > 0 then
        local fmt = GL.Integrations.FormatCopper(unitPrice)
        if fmt then ahStr = "  |cff88ccff(AH unit: " .. fmt .. ")|r" end
      end
    end
    rows[#rows + 1] = string.format("[%s] %s (%s)%s\n  Est. %s: %s%d / ~%d|r%s%s",
      row.range, row.recipe, row.rank, vTag, row.matName, col, have, row.need, altStr, ahStr)
  end
  return rows
end

function F.GetPromptDungeon(level, faction, skippedMap)
  level = tonumber(level) or 1
  skippedMap = skippedMap or {}
  for _, d in ipairs(F.DUNGEONS) do
    if (d.fac == "Both" or d.fac == faction) and level >= d.minL and level <= d.maxL and not skippedMap[d.name] then
      return d
    end
  end
  return nil
end
