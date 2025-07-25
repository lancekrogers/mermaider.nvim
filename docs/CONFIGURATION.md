# Configuration Guide

This document provides detailed information about configuring Mermaider.nvim.

## Configuration Options

### Basic Setup

```lua
require("mermaider").setup({
  -- Minimal configuration - uses sensible defaults
})
```

### Complete Configuration

```lua
require("mermaider").setup({
  -- Mermaid CLI Configuration
  mermaider_cmd = 'npx -y -p @mermaid-js/mermaid-cli mmdc -i {{IN_FILE}} -o {{OUT_FILE}}.png -s 3',
  temp_dir = vim.fn.expand('$HOME/.cache/mermaider'),
  
  -- Auto-rendering Behavior
  auto_render = true,                    -- Auto render on save
  auto_render_on_open = true,            -- Auto render when opening files
  auto_preview = true,                   -- Auto show preview after render
  throttle_delay = 500,                  -- Throttle auto-render (milliseconds)
  
  -- Display Settings
  inline_render = true,                  -- true = inline, false = split window
  max_width_window_percentage = 80,      -- Max image width (% of window)
  max_height_window_percentage = 80,     -- Max image height (% of window)
  
  -- Split Window Settings (when inline_render = false)
  split_direction = "vertical",          -- "vertical" or "horizontal"
  split_width = 50,                      -- Split width percentage
  
  -- Mermaid Styling
  theme = "forest",                      -- Mermaid theme
  background_color = "#1e1e2e",          -- Background color
  mmdc_options = "",                     -- Additional CLI options
  
  -- Custom Styling Files
  css_file = nil,                        -- Path to custom CSS file
  mermaid_config_file = nil,             -- Path to mermaid config JSON file
})
```

## Configuration Details

### Mermaid CLI Configuration

#### `mermaider_cmd`
The command used to render mermaid diagrams. Placeholders are replaced at runtime:
- `{{IN_FILE}}` - Input mermaid file path
- `{{OUT_FILE}}` - Output file path (without extension)

**Default:** `'npx -y -p @mermaid-js/mermaid-cli mmdc -i {{IN_FILE}} -o {{OUT_FILE}}.png -s 3'`

**Examples:**
```lua
-- Use local mermaid-cli installation
mermaider_cmd = 'mmdc -i {{IN_FILE}} -o {{OUT_FILE}}.png -s 3'

-- Custom scale and format
mermaider_cmd = 'npx -y -p @mermaid-js/mermaid-cli mmdc -i {{IN_FILE}} -o {{OUT_FILE}}.svg -s 2'
```

#### `temp_dir`
Directory for temporary files and cache.

**Default:** `vim.fn.expand('$HOME/.cache/mermaider')`

### Auto-rendering Configuration

#### `auto_render`
Automatically render diagrams when files are saved.

**Default:** `true`

#### `auto_render_on_open`
Automatically render diagrams when files are opened.

**Default:** `true`

#### `auto_preview`
Automatically show preview after successful rendering.

**Default:** `true`

#### `throttle_delay`
Delay in milliseconds to throttle auto-rendering. Prevents excessive rendering during rapid saves.

**Default:** `500`

### Display Configuration

#### `inline_render`
Controls how diagrams are displayed:
- `true` - Display inline within the buffer
- `false` - Display in a split window

**Default:** `true`

**Trade-offs:**
- Inline: More integrated experience, but may modify buffer appearance
- Split: Guaranteed not to modify files, side-by-side editing

#### `max_width_window_percentage` / `max_height_window_percentage`
Maximum image size as a percentage of the window dimensions.

**Default:** `80` (for both)

**Range:** `1-100`

### Split Window Configuration

These options only apply when `inline_render = false`.

#### `split_direction`
Direction for the split window.

**Options:** `"vertical"` | `"horizontal"`
**Default:** `"vertical"`

#### `split_width`
Width percentage for vertical splits (or height for horizontal splits).

**Default:** `50`
**Range:** `1-99`

### Mermaid Styling

#### `theme`
Built-in mermaid theme to use.

**Options:** `"dark"` | `"light"` | `"forest"` | `"neutral"`
**Default:** `"forest"`

#### `background_color`
Background color for rendered diagrams (CSS color format).

**Default:** `"#1e1e2e"`

**Examples:**
```lua
background_color = "#ffffff"     -- White
background_color = "transparent" -- Transparent
background_color = "#1e1e2e"     -- Dark gray
```

#### `mmdc_options`
Additional command-line options passed to mermaid-cli.

**Default:** `""`

**Examples:**
```lua
mmdc_options = "--puppeteerConfigFile /path/to/config.json"
mmdc_options = "--quiet"
```

### Custom Styling Files

#### `css_file`
Path to a custom CSS file for styling diagrams.

**Default:** `nil`

**Example:**
```lua
css_file = "~/.config/nvim/mermaid-custom.css"
```

#### `mermaid_config_file`
Path to a custom mermaid configuration JSON file.

**Default:** `nil`

**Example:**
```lua
mermaid_config_file = "~/.config/nvim/mermaid-config.json"
```

## Configuration Examples

### Minimal Configuration
```lua
require("mermaider").setup()
```

### Performance Focused
```lua
require("mermaider").setup({
  auto_render = false,           -- Manual rendering only
  auto_render_on_open = false,   -- Don't auto-render on open
  throttle_delay = 1000,         -- Longer throttle delay
})
```

### Split Window Mode
```lua
require("mermaider").setup({
  inline_render = false,
  split_direction = "horizontal",
  split_width = 60,
})
```

### Custom Styling
```lua
require("mermaider").setup({
  theme = "dark",
  background_color = "#000000",
  css_file = "~/.config/nvim/mermaid.css",
  mermaid_config_file = "~/.config/nvim/mermaid.json",
})
```

### Development Setup
```lua
require("mermaider").setup({
  auto_render = true,
  auto_render_on_open = true,
  theme = "light",
  background_color = "#ffffff",
  throttle_delay = 200,          -- Faster feedback
})
```

## Environment-Specific Configuration

### LazyVim
```lua
-- lua/plugins/mermaider.lua
{
  "snrogers/mermaider.nvim",
  dependencies = { "3rd/image.nvim" },
  ft = { "mmd", "mermaid", "markdown" },
  config = function()
    require("mermaider").setup({
      theme = "forest",
      background_color = "#1e1e2e",
    })
  end,
}
```

### Traditional init.lua
```lua
-- In your init.lua
require("mermaider").setup({
  auto_render = true,
  inline_render = true,
  theme = "dark",
})
```

## Troubleshooting Configuration

### Common Issues

**Plugin not loading:**
- Ensure file types are configured: `ft = { "mmd", "mermaid", "markdown" }`
- Check for syntax errors in configuration

**Auto-render not working:**
- Verify `auto_render = true` in configuration
- Check autocmd setup with `:autocmd Mermaider`

**Images not displaying:**
- Ensure image.nvim is installed and configured
- Try split mode: `inline_render = false`

**Performance issues:**
- Increase `throttle_delay`
- Disable `auto_render_on_open`
- Clear cache: `:MermaidCacheClear`

### Validation

The plugin validates configuration options and will warn about invalid values:
- Percentages outside 1-100 range
- Invalid throttle delays
- Missing required files

### Debug Configuration

To debug configuration issues:
```lua
require("mermaider").setup({
  -- ... your config ...
  debug = true,  -- Enable debug logging
})
```

Then check `:messages` for detailed information about configuration loading and validation.