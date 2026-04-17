# AGENTS.md - Coding Guidelines for Agentic Developers

This project is a Playdate game written in Lua. Use these guidelines when working on the codebase.

## Build & Run Commands

### Building the Game
```bash
run.bat                    # Build and run the game in the Playdate simulator
run.bat --debug            # Build with DEBUG_MODE enabled for debug output
```

**Requirements:** PLAYDATE_SDK_PATH environment variable must be set to your Playdate SDK installation.

### Running a Built Game
```bash
run2.bat <game.pdx>        # Run a built .pdx file in the simulator
run2.bat mouse.pdx         # Example: runs build\mouse.pdx
```

### Build Artifacts
- Game is compiled to: `build/Azhari.pdx`
- Source files are copied to: `build/tmp_source/` during build
- Debug flags written to: `build/tmp_source/core/build_flags.lua`

**No automated tests or linters.** All validation is manual code review.

## Code Style Guidelines

### Imports
- Place all imports at the top of the file, before any code
- Use `import "path/to/module"` syntax (Playdate-specific)
- Organize imports in logical groups (CoreLibs, then core modules, then systems)
- Example from main.lua:
  ```lua
  import "CoreLibs/graphics"
  import "core/build_flags"
  import "core/game"
  ```

### Formatting & Indentation
- Use **tabs for indentation** (not spaces)
- Each indentation level = 1 tab
- Opening braces on same line: `function foo()\n\t...\nend`
- No trailing whitespace

### Naming Conventions
- **Classes/Modules:** PascalCase (e.g., `Game`, `InputHandler`, `UIStateManager`)
- **Functions:** camelCase (e.g., `updateCrankFloorSelection()`, `getSelectedCharacter()`)
- **Local variables:** snake_case (e.g., `current_floor`, `max_width`)
- **Constants/Data tables:** ALL_CAPS or PascalCase (e.g., `Characters`, `Items`, `FloorHints`)
- **Private functions:** prefix with underscore (e.g., `_internalHelper()`)

### Types & Data Structures
- Use local variable declarations: `local pd = playdate`
- Explicit table creation for class instances: `local self = setmetatable({}, ClassName)`
- Store metadata in `__index`: `ClassName.__index = ClassName`
- Always return `self` from constructor functions
- Use descriptive field names in state objects

### Class Pattern
All major classes follow this pattern (see game.lua, input_handler.lua):
```lua
ClassName = {}
ClassName.__index = ClassName

function ClassName.new(...)
  local self = setmetatable({}, ClassName)
  -- Initialization
  return self
end

function ClassName:methodName()
  -- Methods use : notation for self parameter
end
```

### Comments & Documentation
- Section headers: `-- === SECTION NAME ===` (centered with ===)
- Subsection headers: `-- === SUBSECTION ===`
- Comment complex logic blocks, not obvious code
- Document function parameters if non-obvious
- Example: `-- Limited set of 5 starting items (excluding collectible-only items)`

### Error Handling
- Use defensive nil checks before accessing table fields
- Check table contents before iteration: `if itemIds and #itemIds > 0 then ... end`
- Validate input parameters early: `if not character or not character.stats then return nil end`
- Return nil or false on invalid state rather than raising errors
- Use `if item then` pattern to safely check if table entry exists

### Utility Functions
- Place utility functions in dedicated utility files (e.g., `game_utilities.lua`)
- Group related utilities together with section comments
- Use helper functions for common operations:
  - `clamp(value, min, max)` - constrain values to range
  - `containsValue(list, target)` - check table membership
  - `wrapText(text, maxWidth)` - text wrapping with width limit
  - `cloneList(values)` - safe table copying

### Function Organization
- Group related functions with section headers
- Order within sections: initialization → getters → setters → logic → utilities
- Keep functions focused and under 50 lines when possible
- Use early returns to reduce nesting

### Lua-Specific Patterns
- Use `#table` for table length (array indexing starts at 1)
- Use `ipairs()` for arrays, `pairs()` for sparse/key tables
- Prefer table concatenation: `table.concat(names, ", ")`
- Use string methods: `text:gmatch()`, `text:sub()`
- Store reference: `local gfx = playdate.graphics` for frequently used APIs

## Project Structure

- `source/main.lua` - Entry point, initializes game loop
- `source/core/` - Core game logic (game.lua, managers, utilities)
- `source/systems/` - Game systems (crank, floor generation, challenges)
- `source/assets/` - Image loading and asset management
- `source/image/` - Image rendering
- `source/sound/` - Audio handling
- `docs/` - Architecture diagrams and documentation

## Key Modules to Know

- **Game** - Main game state and update loop
- **InputHandler** - Button/crank input processing by screen
- **UIStateManager** - UI state tracking (menus, selections)
- **UIRenderer** - All rendering logic
- **InventoryManager** - Player inventory management
- **CutsceneManager** - Cutscene playback
- **FloorGenerator** - Procedural floor generation
