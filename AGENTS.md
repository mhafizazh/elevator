# AGENTS.md

## Project: Azhari (Playdate Game)

Lua-based game for Playdate handheld console. Build requires Playdate SDK installed locally.

## Prerequisites

- **PLAYDATE_SDK_PATH** environment variable must be set to the Playdate SDK root directory
- Windows only (batch scripts assume Windows)
- No external package manager; all Lua code is source-checked in

## Build & Run

- **`run.bat`** — builds and runs the game in the Playdate Simulator
  - Creates `/build/Azhari.pdx` (compiled game)
  - Requires `PLAYDATE_SDK_PATH/bin/pdc.exe` and `PlaydateSimulator.exe` to exist
  - Optional `--debug` flag: sets `DEBUG_MODE = true` in `core/build_flags.lua`
  - Copies `source/` → `build/tmp_source/`, regenerates `build_flags.lua`, compiles, runs

- **`run2.bat <game.pdx>`** — runs an already-built .pdx file in the Simulator
  - Searches `build/` and recursively if only filename given

## Source Structure

### Core Game
- **`source/main.lua`** — Playdate entry point; instantiates `Game` and calls `game:update()` + `game:draw()` each frame
- **`source/core/game.lua`** — Refactored orchestrator (~250 lines); delegates to managers and renderers

### Modular Components
- **`source/core/ui_state_manager.lua`** — All UI state (screen state, selection indices, tutorials, summary text)
- **`source/core/inventory_manager.lua`** — All item/inventory state (owned items, equipment, loot, collectibles)
- **`source/core/cutscene_manager.lua`** — Animation and cutscene state (timers, lines, debug output)
- **`source/core/ui_renderer.lua`** — All rendering logic (~580 lines); routes to screen-specific renderers
- **`source/core/input_handler.lua`** — All input handling (~310 lines); routes to screen-specific handlers
- **`source/core/game_utilities.lua`** — Shared utilities (text, lists, dialogue system, UI helpers)

### Data & Systems
- **`source/core/build_flags.lua`** — Generated at build time; contains `DEBUG_MODE` flag
- **`source/core/data/`** — Immutable data: `characters.lua`, `items.lua`
- **`source/systems/`** — Game systems (floor generation, combat, survival, item effects, crank controls)
- **`source/assets/`** — Images and sound references

## Architecture

The game follows a **modular, manager-based architecture**:

- **UIStateManager**: Centralizes all UI state (screen transitions, selection indices, tutorial flags)
- **InventoryManager**: Manages all item state (owned inventory, equipment, loot selection, collectibles)
- **CutsceneManager**: Handles animation timers and cutscene content
- **UIRenderer**: Routes screen rendering to specialized render methods based on `screenState`
- **InputHandler**: Routes button/crank input to specialized handlers based on `screenState`
- **GameUtilities**: Pure utility functions for common operations (text wrapping, list operations, dialogue)
- **Game class**: Simplified orchestrator that delegates to managers and renders

This architecture provides:
- **Separation of concerns**: State, rendering, and input are decoupled
- **Testability**: Each manager can be tested independently
- **Maintainability**: Changes to one system don't cascade to others
- **Extensibility**: New screens/items/mechanics can be added without modifying core game logic

## Key Quirks

- **Temporary build directory**: `run.bat` creates `build/tmp_source/` and deletes it before each build
- **Debug flag injection**: `run.bat` always regenerates `source/core/build_flags.lua` on build; do not edit it manually
- **No tests**: No CI, no test suite, no linting or type-checking
- **Playdate SDK paths**: Scripts fail silently if SDK paths don't exist; verify SDK installation before debugging "not found" errors
- **Multiple .pdx builds in build/**: Directory contains `Azhari.pdx`, `Barber/`, `Kurtin/`, `Rho/` — only `Azhari.pdx` is the main game
- **Manager initialization**: All managers must be created in `Game.new()` and stored as instance variables for access from other managers
- **Screen state routing**: All rendering and input is routed through `screenState` string; adding new screens requires updates to UIRenderer and InputHandler dispatchers

## Development

- Edit Lua in `source/` only
- To rebuild and test: run `run.bat` (or `run.bat --debug` for debug mode)
- Simulator runs immediately after successful build
- No hot reload; full rebuild required for changes
