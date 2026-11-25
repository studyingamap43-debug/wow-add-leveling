LevelGuide v1.2.9 (review hotfixes on Gemini v1.2.6) — WoW: Forever 1.60.1.71037 (Interface: 16001)

INSTALL
  Extract all 3 folders directly into World of Warcraft/_forever_/Interface/AddOns/:
    LevelGuide                (core engine, 16001 Compat, Arrow, Theme, Timer, Voice, Integrations, UI)
    LevelGuide_Data_Alliance  (LoadOnDemand — 3,716 quests, Alliance characters only)
    LevelGuide_Data_Horde     (LoadOnDemand — 3,686 quests, Horde characters only)
  Fully restart WoW: Forever and enable all three in Character Select -> AddOns.

COMMANDS
  /guide              toggle main HUD
  /guide arrow        toggle directional quest arrow (Shift+Drag to move, /guide arrow lock|reset)
  /guide pin          set map pin + arrow + optional TomTom waypoint
  /guide speak        speak current step via native client TTS (C_VoiceChat.SpeakText)
  /guide voice        toggle TTS on/off (/guide voice cycle to change OS voice)
  /guide timer        pause/resume stopwatch (/guide timer reset)
  /guide splits       open copyable per-level split history
  /guide theme        cycle Dark-Gold / Midnight Slate / Warm Obsidian skins
  /guide mini         toggle compact 1-line HUD
  /guide lock         lock/unlock window drag & resize
  /guide stats        print session XP/hr and estimated Time-to-Level
  /guide discoveries  open copyable log of newly recorded WoW: Forever quests
  /guide export-ai    open copyable offline AI context snapshot
  /guide chain        open BtWQuests for current quest chain (if installed)
  /guide skip|unskip  skip current step quests or restore skipped quests
  /guide mode         toggle thorough / speed mode
  /guide sync         sync completed quests from server (C_QuestLog.IsQuestFlaggedCompleted)
  /guide reset        wipe this character's progress only
  /guide debug        open copyable diagnostic & error report
  /guide skipdungeon  dismiss the current level-band dungeon prompt
  /guide ignore       ignore the current step (per character)
  /guide unignore     restore one ignored id, or /guide unignore all
  /guide optimize     quest log optimizer (also /guide cleanup)
  /guide test         run in-game API + behavioral self-test

DATA PROVENANCE & LIMITATIONS
  - Base quest database (7,402 quests) generated from pfQuest (MIT, github.com/shagu/pfQuest), tagged UNVERIFIED-AUTO.
  - See LICENSE-pfQuest.txt and CHANGELOG.md included in this archive.
  - Mob/object spawn coordinates are not yet bundled in Data.lua; OBJECTIVE steps clearly note when turn-in coords are shown and pair cleanly with Questie for spawn pins.
