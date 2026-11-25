-- LevelGuide PathInfo: PathForever-style Class Quest Chains & Trainer Milestones (1-60)
-- Covers all 9 classes + WoW: Forever race/class combos (Human Hunter, Dwarf Shaman, Undead Paladin, Skyborne).

local GL = LevelGuide
local P = {}
GL.PathInfo = P

P.CHAINS = {
  WARRIOR = {
    { lv = 10, title = "Defensive Stance & Taunt", note = "Class trainer in starter hub (Goldshire / Razor Hill / Kharanos / Dolanaar / Brill)." },
    { lv = 20, title = "Class Armor Chain (Brutal / Fire Hardened)", note = "Starts at major city Warrior trainer; optional if dungeon/BoE geared." },
    { lv = 30, title = "Berserker Stance + Whirlwind Weapon", note = "HUGE power spike! Whirlwind Axe carries Warriors from Lv 30 to mid-40s (buy Troll Charms on AH if funded)." },
    { lv = 50, title = "Sunken Temple Warrior Quest", note = "Diamond Flask trinket — BiS burst/sustain item even at Lv 60." },
  },
  PALADIN = {
    { lv = 12, title = "Redemption (Resurrection)", note = "Tome of Divinity (Alliance) or Forever Undead Paladin Deathknell -> Bandarion Keep chain." },
    { lv = 20, title = "Verigan's Fist (2H Mace)", note = "Massive 2H upgrade spanning SFK/BFD/Deadmines/Loch Modan." },
    { lv = 40, title = "Summon Warhorse (Free 60% Mount)", note = "Train directly at Paladin trainer at Lv 40." },
    { lv = 60, title = "Charger Epic Mount Quest", note = "Multi-dungeon chain (Dire Maul / Scholomance)." },
  },
  HUNTER = {
    { lv = 10, title = "Tame Beast (Pet Quest)", note = "Mandatory! Unlocks pet taming + Feed/Revive Pet (Human Hunter: check Goldshire; Skyborne: Zephras Isle)." },
    { lv = 50, title = "Sunken Temple Hunter Quest", note = "Devilsaur Eye / Huntkeeper's Mark." },
    { lv = 60, title = "Rhok'delar (Ancient Petrified Leaf)", note = "Molten Core drop + solo demon kiting chain." },
  },
  ROGUE = {
    { lv = 16, title = "Lockpicking Practice", note = "Picklock footlockers (Redridge / Barrens) to level skill early." },
    { lv = 20, title = "Poisons Quest (Klaven's Tower / Shattered Salute)", note = "Unlocks Instant/Deadly/Crippling Poisons — big DPS boost." },
    { lv = 50, title = "Sunken Temple Rogue Quest", note = "Whisperwalk Boots / Ebon Mask." },
  },
  PRIEST = {
    { lv = 10, title = "Racial Priest Spell Quest", note = "Unlocks racial Priest spell (verify Forever Gnome Priest trainer lead)." },
    { lv = 50, title = "Sunken Temple Priest Quest", note = "Blessed Prayer Beads / Woestave." },
  },
  SHAMAN = {
    { lv = 4,  title = "Call of Earth (Earth Totem)", note = "Starter hub Shaman trainer (Dwarf Shaman: follow Forever Dun Morogh chain)." },
    { lv = 10, title = "Call of Fire (Fire Totem)", note = "Unlocks Searing Totem — big leveling DPS jump." },
    { lv = 20, title = "Call of Water (Water Totem)", note = "Long travel chain; unlocks Healing Stream / Mana Spring." },
    { lv = 30, title = "Call of Air (Air Totem)", note = "Fast turn-in; unlocks Windfury / Grace of Air." },
  },
  MAGE = {
    { lv = 15, title = "Class Wand / Arcane Chain", note = "Check capital Mage Quarter trainer." },
    { lv = 20, title = "Forever Comprehension / Battle Mage Research", note = "Check Stormwind (Garion Wendell) or Undercity (Owen Thadd) in Forever." },
    { lv = 30, title = "Tabetha's Task (Dustwallow Marsh)", note = "Strong caster off-hand/wand reward." },
  },
  WARLOCK = {
    { lv = 10, title = "Summon Voidwalker", note = "Core solo tanking pet (verify Troll Warlock starter lead in Forever)." },
    { lv = 20, title = "Summon Succubus", note = "Strong DPS/CC pet chain." },
    { lv = 30, title = "Summon Felhunter + Robe of the Void/Shadoweave", note = "Utility pet + Menethil/Ratchet chain." },
    { lv = 40, title = "Summon Felsteed (Free 60% Mount)", note = "Train at Warlock trainer at Lv 40." },
  },
  DRUID = {
    { lv = 10, title = "Bear Form Quest (Moonglade)", note = "Unlocks Teleport: Moonglade + Bear Form." },
    { lv = 16, title = "Aquatic Form Quest", note = "Optional water-breathing form." },
    { lv = 20, title = "Cat Form (Forever Moonglade / Skyborne Spirit)", note = "Core leveling speed form." },
  },
}

function P.ExportClassGuide(classTok, level)
  classTok = classTok or "WARRIOR"
  level = tonumber(level) or 1
  local list = P.CHAINS[classTok] or {}
  local lines = {
    "=== LevelGuide Class Chains & Milestones (" .. classTok .. ", Lv " .. level .. ") ===",
    "Tip: Visit your class trainer every even level (2, 4, 6, 8...) for new spell ranks.",
  }
  if GL.Integrations and GL.Integrations.detected and GL.Integrations.detected.PathForever then
    lines[#lines + 1] = "PathForever detected: use PathForever's Dungeon Journal/Trainer window alongside LevelGuide."
  end
  for _, item in ipairs(list) do
    local tag = (level >= item.lv) and "[AVAILABLE NOW]" or ("[Lv " .. item.lv .. "]")
    lines[#lines + 1] = string.format("%s %s — %s", tag, item.title, item.note)
  end
  return table.concat(lines, "\n")
end

P.CLASS_REMINDERS = {
  WARRIOR = "Warrior Tip: Keep weapon skill trained, stock First Aid bandages, and check stance/class quests at Lv 10 & 30.",
  PALADIN = "Paladin Tip: Refresh Seals/Auras, keep weapon & shield updated, and check Lv 12 Redemption / Lv 20 Verigan's Fist / Lv 40 Mount.",
  HUNTER  = "Hunter Tip: Stock ammo & pet food before leaving town; do Lv 10 Tame Beast immediately and keep pet skills trained.",
  ROGUE   = "Rogue Tip: Keep main-hand weapon upgraded, practice Lockpicking at Lv 16+, and stock Poisons at Lv 20+.",
  PRIEST  = "Priest Tip: Equip a Wand ASAP to save mana; check racial Priest quest at Lv 10.",
  SHAMAN  = "Shaman Tip: Complete Earth (Lv 4), Fire (Lv 10), Water (Lv 20), and Air (Lv 30) totem quests.",
  MAGE    = "Mage Tip: Conjure fresh food/water, stock teleport reagents, and check Forever Lv 20 Comprehension research.",
  WARLOCK = "Warlock Tip: Keep Soul Shards stocked and complete Voidwalker (Lv 10), Succubus (Lv 20), Felhunter (Lv 30), and Felsteed (Lv 40).",
  DRUID   = "Druid Tip: Complete Bear Form (Lv 10), Aquatic Form (Lv 16), and Cat Form (Lv 20) quests.",
}

P.CLASS_TO_BIT = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16,
  SHAMAN = 32, MAGE = 64, WARLOCK = 128, DRUID = 1024,
}

function P.GetClassStepsForEngine(classBit, level, db)
  if type(classBit) ~= "number" or type(level) ~= "number" then return nil end
  for classTok, bit in pairs(P.CLASS_TO_BIT) do
    if GL.HasBit and GL.HasBit(classBit, bit) then
      local list = P.CHAINS[classTok] or {}
      for _, item in ipairs(list) do
        if level >= item.lv and level <= item.lv + 3 then
          local stepId = "CLASS:" .. classTok .. ":" .. tostring(item.lv)
          local isDone = db and db.done and db.done[stepId]
          local isSkipped = db and db.skipped and db.skipped[stepId]
          local isIgnored = db and db.ignoredQuests and db.ignoredQuests[stepId]
          if not isDone and not isSkipped and not isIgnored then
            return {
              id = stepId,
              classTok = classTok,
              classBit = bit,
              lv = item.lv,
              title = item.title,
              note = item.note,
              reminder = P.CLASS_REMINDERS[classTok] or "",
              unverified = true,
            }
          end
        end
      end
      break
    end
  end
  return nil
end

function P.GetActiveClassAdvisory(classTok, level)
  if not classTok then return nil end
  local list = P.CHAINS[classTok] or {}
  for _, item in ipairs(list) do
    if level and level >= item.lv and level <= item.lv + 2 then
      return string.format("[%s Lv %d] %s — %s [UNVERIFIED]", classTok, item.lv, item.title, item.note)
    end
  end
  return nil
end
