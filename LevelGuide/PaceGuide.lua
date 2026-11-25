-- LevelGuide PaceGuide: Researched WoW: Forever 1.60.1 Optimal 1-60 Questing + Dungeon Pace Checklist.
-- Incorporates Forever's 1,000+ new quests, 9 new dungeons, Camp Tents, XP Food, Lv 25 Legacy Well Rested,
-- Stormwind<->Auberdine & Tanaris<->Riverglades boats, Dalaran attunements, and 1-run-per-dungeon XP meta.

local GL = LevelGuide
local PG = {}
GL.PaceGuide = PG

PG.UNIVERSAL_TIPS = {
  "• Core Rule: Quest-led pace — run each dungeon once near the top of its range with ALL its quests picked up. After the Nov 8, 2026 dungeon-kill XP hotfix, Blizzard's stated goal is dungeon XP close to (not clearly faster than) questing; short repeat farms also hit the per-dungeon hourly reset cap.",
  "• Always log out in an Inn/Capital AND use Campfires / Camp Tents in the world to stack Rested kill XP.",
  "• Eat crafted food constantly — in WoW: Forever, crafted food grants stats + a kill XP bonus!",
  "• At Level 25: spend Legacy points on 'Well Rested' to boost rested XP rate and cap.",
  "• At Level 48+: quests award bonus gold while leveling — turn in your quest log BEFORE hitting 60 (no Lv 60 XP-to-gold conversion).",
  "• Dungeon limit: max 5 resets and entries PER DUNGEON per hour (Nov 20, 2026 official hotfix; was 10).",
}

PG.BRACKETS = {
  {
    minL = 1, maxL = 12,
    title = "Levels 1-12: Starter Zone Full Clear",
    alliance = "Elwynn Forest (Human) | Dun Morogh (Dwarf/Gnome) | Teldrassil (Night Elf) | Zephras Isle (High Order Skyborne). Finish starter chains, train First Aid/Cooking, grab weapon upgrades.",
    horde = "Durotar (Orc/Troll) | Mulgore (Tauren) | Tirisfal Glades (Undead) | Zephras Isle (Windshaper Skyborne). Finish starter chains & Lv 10 class quest.",
    dungeons = "None yet — stay on dense starter quest loops.",
  },
  {
    minL = 12, maxL = 20,
    title = "Levels 12-20: Second Hub + First Single-Run Dungeons",
    alliance = "Westfall -> Loch Modan -> Darkshore (new Stormwind Harbor <-> Auberdine ship!) -> early Redridge.",
    horde = "The Barrens (Crossroads) -> Silverpine Forest -> early Stonetalon.",
    dungeons = "Alliance: Hall of Thanes (13-18, beneath Ironforge, Alliance-oriented; Horde access/quest count should be checked in-game) & Deadmines (17-26 with full Defias chain). Horde: Ragefire Chasm (13-18), Ruins of Lordaeron (15-20, Undercity courtyard), Wailing Caverns (17-24).",
  },
  {
    minL = 20, maxL = 30,
    title = "Levels 20-30: Mid-Low Hubs + Lv 25 Well Rested + Dalaran Prep",
    alliance = "Redridge Mountains -> Duskwood -> Wetlands -> Ashenvale -> Southshore (Hillsbrad).",
    horde = "Southern Barrens -> Stonetalon -> Ashenvale -> Hillsbrad (Tarren Mill) -> Thousand Needles.",
    dungeons = "Blackfathom Deeps (23-26), Stockade (25-29, Alliance fast XP), Shadowfang Keep (22-28), Excavation Site: Wetlands (27-30, new Forever dungeon). START City of Dalaran attunement BEFORE Lv 28 (Ally: An Alarming Request in Southshore; Horde: Key to the City / Prison Break-In in Tarren Mill).",
  },
  {
    minL = 30, maxL = 40,
    title = "Levels 30-40: STV, Scarlet Monastery & New Forever Dungeons",
    alliance = "Northern STV -> Arathi Highlands -> Desolace -> Alterac -> Thousand Needles -> early Riverglades (Farholde Keep, Lv 36+).",
    horde = "Thousand Needles -> Desolace -> Arathi (Hammerfall) -> STV (Grom'gol) -> early Riverglades (Rog'mar, Lv 36+).",
    dungeons = "City of Dalaran (28-33; a community guide cites ~37.6k Alliance quest XP — UNVERIFIED, confirm in-game), Gnomeregan (29-38), Razorfen Kraul (29-38), Scarlet Monastery wings (34-45), The Drowned City (35-40, STV coast; a community guide cites ~48k quest XP across 8 quests — UNVERIFIED).",
  },
  {
    minL = 40, maxL = 50,
    title = "Levels 40-50: Mount (100g), Riverglades (150+ Quests) & Tanaris",
    alliance = "Train riding (Forever includes the riding skill with the mount; gold cost: confirm in-game). Clear Riverglades (mid-30s to mid-40s, Farholde Keep) & Shen'dralas (level range UNVERIFIED, often listed 38-43) -> Tanaris (boat <-> Powderfuse Port) -> Feralas -> Hinterlands -> Searing Gorge.",
    horde = "Train riding (Forever includes the riding skill with the mount; gold cost: confirm in-game). Clear Riverglades (mid-30s to mid-40s, Rog'mar) & Shen'dralas (level range UNVERIFIED, often listed 38-43) -> Tanaris (boat <-> Powderfuse Port) -> Feralas -> Hinterlands -> Searing Gorge.",
    dungeons = "Krol'dok Stronghold (40-45, Riverglades; a community guide cites ~61.5k Alliance / ~37k Horde quest XP — UNVERIFIED, confirm in-game), Uldaman (41-51), Zul'Farrak (44-54), Maraudon (46-55), Alcaz Prison (48-53, Dustwallow).",
  },
  {
    minL = 50, maxL = 60,
    title = "Levels 50-60: High-Yield Finish + Pre-Raid Dungeons",
    alliance = "Un'Goro Crater (Marshal's Refuge — collect Power Crystals for Shaper's Terrace!) -> Felwood -> Blasted Lands -> WPL (Chillwind) -> EPL -> Winterspring -> Mount Hyjal (55-60).",
    horde = "Un'Goro Crater (Marshal's Refuge — collect Power Crystals for Shaper's Terrace!) -> Felwood -> Azshara -> WPL (Bulwark) -> EPL -> Winterspring -> Mount Hyjal (55-60).",
    dungeons = "Sunken Temple (50-55, class quests), Blackrock Depths (52-60, huge quest density — worth 2+ runs), Blackmaw Hold (55-60, Azshara), Dire Maul / BRS / Scholo / Strat / The Shaper's Terrace (58-60, Un'Goro).",
  },
}

function PG.ExportGuide(level, faction)
  level = tonumber(level) or 1
  faction = faction or "Alliance"
  local lines = {
    "=== WoW: Forever 1.60.1 — Optimal 1-60 XP, Questing & Dungeon Pace ===",
    "Character: Lv " .. tostring(level) .. " (" .. tostring(faction) .. ")",
    "",
    "--- High-XP/hr Forever Pace Rules ---",
  }
  for _, tip in ipairs(PG.UNIVERSAL_TIPS) do
    lines[#lines + 1] = tip
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "--- 1-60 Bracket Route & Single-Run Dungeon Checklist ---"
  for _, b in ipairs(PG.BRACKETS) do
    local active = (level >= b.minL and level <= b.maxL) and "  <<< YOUR CURRENT BRACKET" or ""
    lines[#lines + 1] = ""
    lines[#lines + 1] = "[" .. b.title .. "]" .. active
    lines[#lines + 1] = "  Zones (" .. faction .. "): " .. ((faction == "Horde") and b.horde or b.alliance)
    lines[#lines + 1] = "  Dungeons (1x w/ quests): " .. b.dungeons
  end
  return table.concat(lines, "\n")
end
