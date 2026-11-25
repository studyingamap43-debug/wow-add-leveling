## v1.2.9 (Coordinate Accuracy Fixes & Fixed Local-Cluster Step-by-Step Routing)
- Preserved every v1.2.1–v1.2.8 fix (bidirectional server sync, missed-step scan, previous-step back stack, real visual checkboxes, Ignore & Continue, Skip-a-Chain warning, Quest Log Optimizer, `[CLASS]` steps, `Bindings.xml`, and pfQuest MIT credit).
- **Sub-Map / Cave Coordinate Projection (`Compat.lua`, `Arrow.lua`, `MinimapTrail.lua`):** Added `Compat.ReadPositionOnMap(targetMapId)` (`C_Map.GetPlayerMapPosition(targetMapId, "player")`). Fixed `Arrow` and `MinimapTrail` mixing sub-map/cave coordinates with parent-zone coordinates whenever `zoneName == pZone` — they now project into `tgt.mapId`'s exact space first and refuse to subtract mismatched `uiMapID`s.
- **QuestieBridge & Waypoint Coordinate Fixes (`QuestieBridge.lua`, `Waypoint.lua`, `Main.lua`):** Removed the cross-zone `or playerUiMapId` fallback in `findFromQuestieMapPins` (which could stamp unmapped cross-zone pins onto your current map), normalized `0..1` Questie pin coords to `0..100` if returned, preserved `loc.uiMapID` through `step.targetMapId` into `Waypoint.SetForTarget`, and added `["Alterac Valley"] = 1459` to `ZONE_TO_UIMAP`.
- **Fixed Step-by-Step Local-Cluster Routing (`Engine.lua`):** Replaced XP/min cross-map jumping with deterministic local-cluster-first ordering (`LOCAL_RADIUS = 18` for nearby turn-ins/pickups, distance-first local objectives with `st._lockedObjId` anti-flip-flop lock) so the guide finishes quest clusters near you before sending you across the map.

## v1.2.8 (Bidirectional Server Sync & Missed-Step Scan Re-Anchor)
- Preserved every v1.2.1–v1.2.7 fix (including all v1.2.7 review fixes: `[CLASS]` priority guard, `HasBit(classBit, bit)`, chain warning skip/ignore filter, Classic 40–59 grey formula, missing-from-data off-route detection, binding names, and pfQuest MIT credit).
- **Bidirectional Server Sync (`Engine.lua`, `Main.lua`):** `Engine.SyncFromServer` now both marks server-completed quests done AND reopens any quest falsely marked `db.done` when `C_QuestLog.IsQuestFlaggedCompleted(id)` returns false, so `/lg sync`, `/lg resync` (`Sync` button), and `/lg scan` always snap back to missed or uncompleted steps even when the quest is not in your quest log.
- **Missed-Step Scan & Waypoint Lock Fix (`Engine.lua`, `Main.lua`):** Fixed `CmdScan` calling `GL.Refresh()` after `Waypoint.SetForTarget` (which overwrote the Scan pin). `Engine.ScanNearestArea` now prioritizes missed chain starters and lower-level unaccepted pickups in your current zone (falling back to temporarily skipped quests if none remain while respecting `ignoredQuests`), and `CmdScan` surfaces the missed hub directly on the HUD and pins it without clobbering.
- **Go Back to Previous Step (`Main.lua`, `UI.lua`):** Added a 15-step session stack (`GL.stepStack`) and `GL.CmdBack()` wired to the Guide frame's `Prev` button and `/lg back` (with `/lg prev` alias; `/lg history` kept for the text log; `Bindings.xml` untouched). Stepping back holds the previous step and its waypoint until you click `Skip`, `Sync`, `Scan`, or accept/turn in a quest; falls back to `CmdUndo()` if the stack is empty.
- **Real Visual Checkboxes (`UI.lua`):** Replaced ASCII `[ ]` / `[x]` text prefixes on the 6 Guide walkthrough rows with actual 14×14 bordered checkbox frames and WoW's `UI-CheckBox-Check` checkmark texture, preserving the v1.2.3 oldest-first `stepChecks` prune.

## v1.2.7 (Review hotfixes on top of Gemini v1.2.6)
- Kept every v1.2.1–1.2.5 fix; Gemini v1.2.6 did not revert them (SKIP alias, PREV = "Undo Last Skip", plain ActionBar `TargetUnit`/`UseItemByName`, no `raceID > 8`, QuestieBridge `BlizzardWaypointFallback`, `Metrics.Init` SafeNumber, ignored/skipped sanitizers, oldest-first stepChecks prune).
- Class `[CLASS]` steps no longer replace an active turn-in, in-log objective, or same-zone pickup (`Engine.lua`).
- `PathInfo.GetClassStepsForEngine` now calls `GL.HasBit(classBit, bit)` in the documented argument order.
- Skip-a-chain warning no longer counts follow-ups that are already skipped or ignored.
- Quest Log Optimizer uses the standard Classic grey-level formula (the 1.2.6 flat cut of 9 was wrong in the 40–59 band) and lists log quests missing from guide data as off-route. Still no invented XP numbers.
- Bumped version to 1.2.7. Data.lua unchanged. No live `/lg debug` unknowns were locked in (none were pasted).

## v1.2.6 (Ignore & Continue, Skip-a-Chain Warning, Quest Log Optimizer & Real Class Route Steps)
- Preserved every v1.2.1–v1.2.5 fix (including `LEVELGUIDE_SKIP` alias, `LEVELGUIDE_PREV` = "Undo Last Skip", plain ActionBar out-of-combat `TargetUnit`/`UseItemByName`, no `raceID > 8` Skyborne heuristic, QuestieBridge `BlizzardWaypointFallback`, oldest-first `stepChecks` prune, `select(2, GetActiveTitle(i))`, and pfQuest MIT attribution).
- **Ignore & Continue (`Core.lua`, `Engine.lua`, `UI.lua`, `Main.lua`):** Added per-character `LevelGuideDB.ignoredQuests` (schema v13), an `Ignore` button on the Guide frame, and `/lg unignore <id>` / `/lg unignore all`.
- **Skip-a-Chain Warning (`Engine.lua`, `Main.lua`):** Built `st.children` from pfQuest `q.p` prereq links and added `Engine.CountBlockedFollowUps` (cycle-safe BFS) to warn how many downstream follow-up quests are blocked before skipping or ignoring (no invented XP numbers).
- **Quest Log Optimizer (`Engine.lua`, `Main.lua`):** Added `Engine.OptimizeQuestLog` using `C_QuestLog`-derived log data only; warns automatically when within 3 slots of the quest log cap and prints grey quests, completed turn-ins, and off-zone/off-route quests via `/lg optimize` (or `/lg cleanup`).
- **Real Class Route Steps (`PathInfo.lua`, `Engine.lua`, `UI.lua`):** Wired `PathInfo.CLASS_REMINDERS` and `PathInfo.CHAINS` into `Engine` via `GL.CLASSBITS` (`PathInfo.GetClassStepsForEngine`) so class quests (pet, totems, Cat Form at 20, etc.) surface as `[CLASS]` route steps filtered by player class and marked `UNVERIFIED`.
- Live `/lg debug` lock-down (Step 1) intentionally held open — no unverified live values hard-coded.

## v1.2.5 (Review hotfixes on top of Gemini v1.2.4)
- Kept every v1.2.1–1.2.3 fix; Gemini v1.2.4 did not revert them.
- Restored `LEVELGUIDE_SKIP` as a legacy alias of `LEVELGUIDE_NEXT` so existing Skip keybinds keep working (`Bindings.xml`, `Core.lua`). `LEVELGUIDE_PREV` is honestly labeled "Undo Last Skip" (it calls `CmdUndo`, not a true previous-step cursor).
- Plain ActionBar fallback now tries `TargetUnit` / `UseItemByName` out of combat instead of only printing a chat hint (`ActionBar.lua`).
- Skyborne flag uses race name/token only; dropped the invented `raceID > 8` heuristic. Unknown races (no `raceBit`) still one-time chat-log raw `UnitRace` name/token/raceID/faction (`Core.lua`).
- `QuestieBridge` uses live Questie modules whenever they import, even if `C_AddOns.IsAddOnLoaded("Questie")` is false. Status string no longer claims a pfQuest spawn fallback; the no-module path is `BlizzardWaypointFallback`.
- `InitDB` always sanitizes `skippedDungeons`; `Metrics.Init` uses `SafeNumber` so a secret first XP read cannot poison the session tracker.
- Bumped version to 1.2.5. Data.lua unchanged (still UNVERIFIED-AUTO, no invented quest IDs / XP / dungeon totals).

## v1.2.4 (Hardened Unknowns, Class/Dungeon Prompts, UX Collapse & Keybinds)
- **Real Bug Fixes:** Fixed `BINDING_NAME_CLICK LevelGuideTargetButton:LeftButton` display global (`Core.lua:16`), nil/zero guard on `Minimap:GetCenter()` / `GetEffectiveScale()` during minimap drag (`UI.lua:58-61`), idle `OnUpdate` early-return in `MinimapTrail.lua:34`, and 3rd return `raceID` capture from `UnitRace("player")` (`Core.lua:83`).
- **Hardened In-Game Unknowns:** Dual `C_GossipInfo` (questID + index fallback) & legacy gossip fallback in `AutoQuest.lua` (preserving `select(2, GetActiveTitle(i))`); `ActionBar.lua` degrades cleanly to plain clickable buttons if secure template or click CVar fails; Skyborne detection logs raw `UnitRace` name/token/raceID/faction once to chat; `QuestieBridge.lua` detects live Forever Questie load and silently falls back to pfQuest; `/lg debug` prints all hardened checks in one report.
- **Class, Dungeon & Pace Enhancements:** Added all-9-class active milestone reminders (`PathInfo.lua`), level-band dungeon prompts with `/lg skipdungeon` (`Fallback.lua`, `LevelGuideDB` v12), secret-safe real-XP pace tracker (`Metrics.lua`), and `UNVERIFIED` status hover tooltips on step checkboxes (`UI.lua`).
- **UX & Keybinds:** Collapse button (`[-]`/`[+]`), `LEVELGUIDE_NEXT` and `LEVELGUIDE_PREV` keybinds in `Bindings.xml`, and preserved v1.2.3 oldest-first `stepChecks` pruning.

## v1.2.3 (Review hotfixes on top of Gemini v1.2.2)
- Kept every v1.2.1 fix; Gemini v1.2.2 did not revert them.
- `UI.lua` stepChecks prune now drops the oldest stamped keys (max 50, trim to 40) instead of deleting arbitrary `pairs()` order, which could wipe recent checkbox state.
- `AutoQuest.lua` QUEST_GREETING uses `select(2, GetActiveTitle(i))` so Lua 5.1 does not write a global `_`.

## v1.2.2 (Merged Grok v1.2.1 Lua 5.1 / Luacheck Fixes + Memory & Location Polish)
- Preserved all 13 verified fixes from Grok's v1.2.1 review (Skyborne `raceBit` faction-wide guard, `Integrations.lua` `fallbackX` scope fix, `Main.lua` `timerAccum` & Find Herbs/Minerals `2383`/`2580` filter, `ActionBar.lua` combat-create & click CVar & bag 0-5 scan, `AutoQuest.lua` DialogueUI yield & `GOSSIP_SHOW`/`QUEST_GREETING`, Forever `UiMapID`s 2548/2482/2652/2521 + `ResolveMapId`, `C_AddOns` memory probe, `Safety.lua` nil guard, `LICENSE-pfQuest.txt` copyright line, Horde Riverglades boat, honest `PaceGuide.lua` ranges).
- Added bounded `LevelGuideDB.stepChecks` pruning (max 50 keys) in `UI.lua`.
- Wired `Waypoint.ResolveMapId` into canonical `Location.lua` so all 4 new Forever zones resolve across Arrow, MinimapTrail, and WorldMapOverlay.
- Removed unused `deferTurnIn` local in `Engine.lua`.

## v1.2.1 (Review hotfixes on top of Gemini v1.2.0)
- Fixed Skyborne/unknown-race quest eligibility (no longer offers other races' exclusive quests).
- Fixed Questie spawn fallback locals that never returned, and removed stray `fallbackX` returns in unrelated Integrations functions.
- Removed accidental `GL.timerAccum = 0` in the position-refresh OnUpdate block.
- AutoQuest now handles GOSSIP_SHOW / QUEST_GREETING and yields when DialogueUI is loaded.
- Secure ActionBar buttons are not created in combat; clicks follow ActionButtonUseKeyDown; macro names are sanitized; bags 0-5.
- Added verified Forever UiMapIDs (Riverglades 2548, Mount Hyjal 2482, Shen'dralas 2652, Zephras Isle 2521) plus current-map name fallback.
- Safety nil-guard, C_AddOns memory API, pfQuest copyright line, Horde Riverglades boat text, PaceGuide honesty tags.

## v1.2.0 (15 Audit Hotfixes + Interactive Step Checkboxes + Complete Forever 1-60 Optimal Pace Guide)
- **15 Code Audit Hotfixes:** Guarded `BackdropTemplateMixin` in `ActionBar.lua`, removed `q._id` table mutation in `Engine.lua`, wrapped all `C_Map.GetMapInfo`, `C_Spell.GetSpellName`, `GetBindLocation`, `GetMoney`, and `WorldMapFrame:GetMapID` calls in `pcall`.
- **Interactive Step Checkboxes (`UI.lua`):** Up to 6 clickable `[ ] / [x]` step-by-step checkboxes right inside the Guide card (persisted per character in `LevelGuideDB.stepChecks`, schema v11).
- **Complete WoW: Forever 1.60.1 Optimal 1-60 Pace Guide (`PaceGuide.lua`, header `Pace` button, `/guide pace`):** Researched quest-led + 1-run-per-dungeon route across all 6 brackets (1–60), Camp Tent / Crafted XP Food / Lv 25 Legacy `Well Rested` tips, Stormwind↔Auberdine & Tanaris↔Riverglades boats (`Travel.lua`), Dalaran attunements, Hall of Thanes Alliance-only note, Drowned City (~48k XP), Krol'dok Stronghold (~61.5k/37k XP), and Lv 48+ gold quests.

## v1.1.1 (Dynamic Nearby Monster & Objective Spawn Arrow Tracking)
- Upgraded `QuestieBridge.lua` to resolve the **closest live monster/object spawn point** from 4 layered sources: (1) `QuestieMap.questIdFrames` live drawn objective pins, (2) `QuestiePlayer.currentQuestlog` objectives, (3) `QuestieDB` NPC/Object/Item drop spawns via `ZoneDB:GetUiMapIdByAreaId`, and (4) Blizzard native `C_QuestLog.GetNextWaypointForMap`.
- Arrow + Minimap Dot Trail + World Map Overlay now dynamically retarget to the next nearest mob spawn cluster as you move.

## v1.1.0 (Bind on Forever-Inspired Secure Targeting, Quest Item Use, Hardcore Safety & Auto-Quest)
- **1-Click Secure Quest Mob/NPC Targeting (`ActionBar.lua`):** Zero-taint `SecureActionButtonTemplate` button docked below the HUD that targets your active quest mob (from QuestieDB or live quest log) or quest giver/turn-in NPC—clickable even in combat, updates safely on `PLAYER_REGEN_ENABLED`, and bindable in WoW Keybindings.
- **1-Click Secure Quest Item Button (`ActionBar.lua`):** Automatically detects usable quest items in your bags (`C_Container.GetContainerItemQuestInfo` + `C_Item.GetItemSpell`) and surfaces a 1-click secure use button.
- **Hardcore / Dangerous-Pull Warnings (`Safety.lua`, `/guide hc`):** Flags +3 level orange/red quests, caves/mines/indoors, and solo named/high-density pulls before you engage.
- **Safe Optional Auto-Accept & Auto-Turn-In (`AutoQuest.lua`, `/guide auto`):** Shift-bypassable auto-accept/turn-in that never auto-picks multi-choice rewards (preserves `Rewards.lua`).
- **Quest Log Cleanup & Step Feedback (`Main.lua`):** Added `/guide cleanup` (lists incomplete grey quests) and `/guide feedback <note>` (copyable step report).

## v1.0.3 (First-Class Questie & QuestieDB Integration)
- Added dedicated **`QuestieBridge.lua`** (`## OptionalDeps: Questie, QuestieDB`).
- Uses `ZoneDB:GetUiMapIdByAreaId` to cleanly convert Questie AreaIDs to Blizzard `UiMapID`s, resolves live unfinished creature/object/item-drop-candidate spawns from `QuestiePlayer` and `QuestieDB`, and picks the **closest spawn point to your player** to drive Arrow, MinimapTrail, WorldMapOverlay, and TomTom.
- Added **`/guide questie [on|off|status]`** and QuestieBridge status in `/guide debug`.

## v1.0.2 (P0/P1 Senior Audit Hardening + Canonical Location Pipeline)
- **P0 Centralized Midnight Secret-Value & Secret-Table Guards (`Compat.lua`):** Added `IsSecret`, `IsSecretTable`, `SafeValue`, `SafeTable`, `SafeNumber` (NaN/Inf safe), `PlayerSpeed`, `PlayerFacing`, and `UnitGUID`.
- **P0 Honest Arrow & Minimap Behavior (`Arrow.lua`, `MinimapTrail.lua`):** Never displays a fake ETA when player speed is unavailable/secret; never snaps arrow or minimap rotation to 0 when facing is unavailable; prefers `C_Minimap.GetViewRadius()` when available.
- **P1 Canonical `LevelGuide.Location` (`Location.lua`):** Single validated location schema shared across `Waypoint`, `Arrow`, `MinimapTrail`, and `WorldMapOverlay`.
- **P1 WorldMap & OpenMap Safety (`WorldMapOverlay.lua`):** Uses `C_Map.OpenWorldMap` / `OpenWorldMap` and hides Blizzard-canvas overlay cleanly when **OpenMap** is active.
- **P1 Objective-Type Labels & 11-Point Live Debug Probes (`Engine.lua`, `Core.lua`):** Clearly distinguishes `[Mob]`, `[Item]`, `[Obj]`, `[Event]`, `[Rep]`, `[Spell]` objectives and outputs full client API probes (`GetCanvas`, `GetViewRadius`, `issecretvalue`/`issecrettable`, LoD faction states, active quest objectives) in `/guide debug`.
- **P2 Timer SV Throttle & Strict Lua 5.1 Linter (`Timer.lua`, `Tools/verify_all.py`):** Throttled timer DB writes to every 10s and added Lua 5.2+/5.3+ syntax bans (`table.unpack`, `goto`, `//`).

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
