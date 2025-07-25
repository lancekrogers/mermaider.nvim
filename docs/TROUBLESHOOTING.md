# Troubleshooting Guide

This guide helps you diagnose and fix common issues with Mermaider.nvim.

## Quick Diagnostics

Run these commands to get basic information:

```vim
:messages                  " Recent plugin messages
:MermaidCacheStats        " Cache status
:lua =require('mermaider').config  " Current configuration
```

## Common Issues

### Images Not Displaying

#### Problem: Plugin renders but images don't show up

**Symptoms:**
- Success messages appear
- PNG files are created in `~/.cache/mermaider/`
- No images visible in terminal

**Causes & Solutions:**

1. **image.nvim not configured properly**
   ```lua
   -- Check if image.nvim is loaded
   :lua print(vim.inspect(require('image')))
   ```
   
   Solution: Ensure image.nvim is installed and configured for your terminal

2. **Unsupported terminal**
   
   Solution: Use a supported terminal (Kitty, WezTerm, etc.) or switch to split mode:
   ```lua
   require("mermaider").setup({
     inline_render = false,  -- Use split window instead
   })
   ```

3. **ImageMagick not installed**
   ```bash
   # Test ImageMagick installation
   magick --version
   ```
   
   Solution: Install ImageMagick:
   - macOS: `brew install imagemagick`
   - Ubuntu: `sudo apt-get install imagemagick`
   - Arch: `sudo pacman -S imagemagick`

### Rendering Failures

#### Problem: Diagrams fail to render

**Symptoms:**
- Error messages about rendering failure
- No PNG files created
- Red error notifications

**Debugging Steps:**

1. **Test mermaid CLI directly**
   ```bash
   npx -y -p @mermaid-js/mermaid-cli mmdc --help
   ```
   
   If this fails, install Node.js and npm.

2. **Test with a simple diagram**
   Create `test.mmd`:
   ```mermaid
   graph TD
       A --> B
   ```
   
   Test CLI:
   ```bash
   npx -y -p @mermaid-js/mermaid-cli mmdc -i test.mmd -o test.png
   ```

3. **Check diagram syntax**
   - Validate syntax at [mermaid.live](https://mermaid.live)
   - Look for common syntax errors (missing quotes, invalid node names)

#### Problem: Specific diagrams fail to render

**Common Syntax Issues:**

1. **Invalid characters in node IDs**
   ```mermaid
   graph TD
       A-B --> C  # Invalid: hyphen in node ID
       A_B --> C  # Valid: underscore is OK
   ```

2. **Missing quotes in labels**
   ```mermaid
   graph TD
       A[Hello World] --> B  # Invalid: space without quotes
       A["Hello World"] --> B  # Valid: quoted label
   ```

3. **Complex diagrams timing out**
   ```lua
   require("mermaider").setup({
     mmdc_options = "--timeout 30000",  -- 30 second timeout
   })
   ```

### Performance Issues

#### Problem: Slow rendering or frequent re-renders

**Solutions:**

1. **Increase throttle delay**
   ```lua
   require("mermaider").setup({
     throttle_delay = 1000,  -- Wait 1 second before re-rendering
   })
   ```

2. **Disable auto-render**
   ```lua
   require("mermaider").setup({
     auto_render = false,          -- Manual rendering only
     auto_render_on_open = false,  -- Don't render on file open
   })
   ```

3. **Clear cache if corrupted**
   ```vim
   :MermaidCacheClear
   ```

### File Modification Issues

#### Problem: Inline rendering modifies files

**Symptoms:**
- Buffer shows as modified after rendering
- Unwanted empty lines added to file

**Solutions:**

1. **Switch to split mode**
   ```lua
   require("mermaider").setup({
     inline_render = false,
   })
   ```

2. **Check image.nvim configuration**
   Ensure virtual padding is properly configured in image.nvim

### Configuration Issues

#### Problem: Plugin not loading

**Check file type triggers:**
```lua
-- Ensure these file types are configured
{
  "snrogers/mermaider.nvim",
  ft = { "mmd", "mermaid", "markdown" },
}
```

#### Problem: Commands not available

**Check plugin loading:**
```vim
:lua print(package.loaded['mermaider'])
```

If `nil`, the plugin isn't loaded. Check your plugin manager configuration.

### Cache Issues

#### Problem: Old diagrams showing despite changes

**Solutions:**

1. **Clear specific cache entry**
   ```vim
   :MermaidCacheClear
   ```

2. **Check cache statistics**
   ```vim
   :MermaidCacheStats
   ```

3. **Manual cache cleanup**
   ```bash
   rm -rf ~/.cache/mermaider/
   ```

### Terminal-Specific Issues

#### Kitty Terminal

**Images not showing:**
1. Ensure Kitty graphics protocol is enabled
2. Check Kitty version (0.20.0+)
3. Verify image.nvim Kitty backend configuration

#### WezTerm

**Images flickering or not displaying:**
1. Update to latest WezTerm version
2. Configure image.nvim for WezTerm backend

#### Tmux

**Images not displaying in tmux:**
- image.nvim has limited tmux support
- Consider using split mode instead of inline rendering

## Debug Mode

Enable detailed logging for troubleshooting:

```lua
require("mermaider").setup({
  debug = true,  -- Enable debug logging
})
```

Then check `:messages` for detailed information about:
- Configuration loading
- Render process steps
- Cache operations
- Error details

## Getting Help

### Information to Include

When reporting issues, include:

1. **Environment:**
   ```vim
   :version                    " Neovim version
   :lua print(jit.version)     " LuaJIT version
   ```

2. **Plugin configuration:**
   ```vim
   :lua print(vim.inspect(require('mermaider').config))
   ```

3. **Terminal information:**
   - Terminal emulator and version
   - Operating system

4. **Error reproduction:**
   - Minimal mermaid file that causes the issue
   - Exact steps to reproduce
   - Error messages from `:messages`

5. **Cache and file information:**
   ```vim
   :MermaidCacheStats
   ```
   ```bash
   ls -la ~/.cache/mermaider/
   ```

### Test Commands

Run these to provide diagnostic information:

```vim
" Basic functionality test
:MermaidRender

" Check dependencies
:lua print(vim.fn.executable('npx'))
:lua print(pcall(require, 'image'))

" Cache information
:MermaidCacheStats

" Configuration dump
:lua print(vim.inspect(require('mermaider').config))
```

## Known Limitations

1. **Terminal support:** Limited to terminals supported by image.nvim
2. **Tmux support:** image.nvim has limited tmux compatibility
3. **Large diagrams:** Very complex diagrams may cause performance issues
4. **File modification:** Inline rendering may modify buffer appearance
5. **CLI dependency:** Requires Node.js and functional internet connection for initial mermaid-cli download

## Recovery Steps

If the plugin is completely broken:

1. **Reset configuration:**
   ```lua
   require("mermaider").setup({})  -- Use all defaults
   ```

2. **Clear all caches:**
   ```bash
   rm -rf ~/.cache/mermaider/
   ```

3. **Test with minimal setup:**
   ```lua
   require("mermaider").setup({
     inline_render = false,    -- Use split mode
     auto_render = false,      -- Manual only
   })
   ```

4. **Verify dependencies:**
   ```bash
   npx -y -p @mermaid-js/mermaid-cli mmdc --help
   magick --version
   ```