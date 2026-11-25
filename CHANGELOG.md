## v1.0.1 (Thorough High-XP/hr Objective & Hub Optimizer)
- Replaced raw distance scoring with **Thorough High-XP/hr (`XP / estimated minutes`)** ranking in `Engine.lua`.
- Keeps full Thorough quest coverage (`-7/+3` window) while prioritizing **sweet-spot yellow quests**, **chain-unlocking quests (`+25%` bonus)**, **nearly-finished local objectives**, and **stacked nearby super-hubs** over grey errands or 2,000-yd cross-zone treks.
- Added 1-click **Scan** header button (`/guide scan`) that scans and pins the nearest high-XP/hr quest hub / leveling area from your live position.

## v1.0.0 (Proximity-First Local Routing + Full UI/API Polish)
- **Fixed 2,000-yard routing bug (`Engine.lua`):** Incomplete quests now sort by (1) same zone first, (2) closest distance to player, (3) fewest remaining objectives as tiebreaker; far/cross-zone turn-ins defer automatically whenever active quests remain in your current zone; pickup scoring weights distance `3.0x` with capped cluster bonus; added `Available()` memoization cache.
- **UI & Input Polish (`UI.lua`, `Arrow.lua`, `Bindings.xml`):** Added mouse-wheel scrolling, dynamic scroll height, clean non-overlapping bottom bar (`470px` min width) with **Prev** button, Blizzard **Esc -> Options -> AddOns** panel (`Settings.RegisterCanvasLayoutCategory`), `/guide arrow scale <0.6-1.6>` + theme-synced arrow pill, and `Bindings.xml` keybindings.
- **16001 Accuracy (`MinimapTrail.lua`, `Integrations.lua`, `Main.lua`):** Added indoor vs. outdoor minimap zoom radii (`IsIndoors()`), Questie same-zone spawn filtering, locale-independent Herb/Mining spell IDs (`2366`/`2575`), and pre-migration DB backup (`LevelGuideDB` v8).

## v0.9.4 (Font Sizing, Previous Steps History & 200-IQ Cluster Route Optimizer)
- Added cycleable **Font Size** (`11pt / 12pt / 14pt / 16pt`) in Settings and `/guide font [small|normal|large|xl]`.
- Added **Previous Steps History** (`Prev:` strip in Guide card + `/guide prev` / `/guide history` last-15 log + `/guide undo` to restore last skipped step).
- Added **Area Quest Cluster & Minimum-Walking Optimizer**: finishes same-hub area quests before returning for a **Batch Turn-In**, and groups pickup NPCs within 6 map units into super-hubs (`/guide cluster`).
- Fixed `UNIT_SPELLCAST_SUCCEEDED` `spellID` argument order (`a3` in WoW 12.x/16001) for live Herb/Mining node recording.

## v0.9.3 (16001/Midnight Lua Error Hardening + World Map Overlay + GatherMate2 Nodes)
- Fixed Midnight/16001 secret-value Lua error traps on `GetUnitSpeed`, `GetPlayerFacing`, `UnitGUID("mouseover")`, and `GetCVar` -> `C_CVar.GetCVar`; wrapped all `OnUpdate` ticks in `GL.Safe` and removed legacy `(s or this)` references in `UI.lua`.
- Added `WorldMapOverlay.lua`: draws active quest pin, 8 guide breadcrumb trail dots, and Herb/Mining node dots directly on the open World Map (OpenMap & Leatrix Maps compatible) + **Map** button (`/guide map`).
- Added `GatherNodes.lua`: reads verified Herb & Mining node locations from `GatherMate2HerbDB` / `GatherMate2MineDB` (if installed) + live-records harvested Forever nodes + `/guide gather [herb|mine]` to pin the nearest node.

## v0.9.2 (Questie, TomTom, RareScanner & PathForever Integration)
- Added `Integrations.GetQuestieObjectiveTarget()`: when Questie is installed, `OBJECTIVE` steps aim the Arrow, Minimap Dot Trail, and TomTom directly at live QuestieDB mob/object spawn coordinates.
- Added `RareAlert.lua`: detects nearby rare mobs & treasure vignettes (`VIGNETTE_MINIMAP_UPDATED`, `UPDATE_MOUSEOVER_UNIT`), auto-mutes duplicate chimes when RareScanner is loaded, and adds `/guide rare` to temporarily pin the rare.
- Added `PathInfo.lua`: PathForever-style class quest chains & trainer milestones for all 9 classes + Forever combos (`/guide class`), coexisting cleanly with PathForever.
- Upgraded TomTom bridge: added `TomTom:SetCrazyArrow`, `/guide tomtom` toggle, and `/guide way <x> <y> [label]` custom waypoints.

## v0.9.1 (Critical Hotfix)
- Fixed Lua multi-return collapse on `Compat.ReadPosition()` in `Arrow.lua`, `MinimapTrail.lua`, and `Discoveries.lua`.
- `Engine.Siblings()` now returns exact quest ID only; `Engine.Resolve()` returns unique matches only.
- Removed level-based quest completion guessing on login and `/guide sync`.
- Fixed `QUEST_ACCEPTED` ignoring low quest IDs (`< 100`) in `Discoveries.lua`.
- Fixed `Fallback.GetDungeonLines()` empty-state check and removed fabricated combined profession AH total.
- Retained `objectiveType` and labeled numeric counters as client-reported.
- Added static regression guards in `Tools/verify_all.py`.

# LevelGuide Changelog

## v0.8.0 (Release 1 Truthfulness & Provenance Audit)
- Retained numeric `numFulfilled`, `numRequired`, and `objType` in `Compat.GetQuestObjectives` for exact remaining kill/drop counters (`X left` / `X left, drop-based`).
- Clarified `OBJECTIVE` step labels so turn-in NPC coordinates are never presented as mob spawn clusters.
- Added combat-quiet TTS guard in `Voice.lua` so automatic TTS never speaks over combat.
- Added `/guide export-ai` offline-first AI context snapshot (read-only, zero API keys).
- Reconciled all version strings (`0.8.0`, `LevelGuideDB` v5), expanded `/guide test` behavioral checks, and bundled `CHANGELOG.md`, `LICENSE-pfQuest.txt` (MIT), and `Tools/verify_all.py`.

## v0.7.0
- Added standalone smooth directional questing arrow (`Arrow.lua`) with real yard distance (`C_Map.GetMapWorldSize`), live ETA, dynamic alignment color (emerald/gold/coral/cross-zone blue), arrival chime, click-through lock, and Shift+Drag positioning.

## v0.6.0
- Added modern Dark-Gold / Midnight Slate / Warm Obsidian HUD (`Theme.lua`), live Session & Level Split Timer (`Timer.lua`), and native `C_VoiceChat.SpeakText` TTS + VoicePack hook (`Voice.lua`).
- Merged WoW: Forever 1.60.1 content: all 31 dungeons (9 new Forever dungeons), Skyborne race support, Riverglades/Shen'dralas/Mount Hyjal zones, and Nov 2026 hotfix notes.

## v0.4.0 – v0.5.0
- Added 15 features: Live Forever Quest Discovery Recorder, Class Reward Advisor, Cross-Zone Travel Router, Flight Path Tracker, ScrollFrames, XP/hr & TTL Metrics, Bag/Durability/Hearthstone Reminders, Instance/Group Awareness, Mini-Mode, Minimap Button, and all 12 Classic Professions 1–300.

## v0.2.0 – v0.3.0
- Ported LevelGuide to WoW: Forever 1.60.1 (`Interface: 16001`) with `Compat.lua`, `Waypoint.lua`, `Fallback.lua`, and `Integrations.lua` (TomTom, Questie, Syndicator/Baganator, Auctionator, BtWQuests, Dialogue UI, Leatrix Maps, What's Training?).
