# Changelog

## Phase 2 - Core Features

### Added
- **Markdown Integration**: Full support for rendering mermaid code blocks in markdown files
  - Auto-detect and render mermaid blocks on save/open
  - `:MermaiderRenderBlock` command to render block at cursor
  - `:MermaiderRenderAllBlocks` command to render all blocks in file
  - Inline image display below code blocks
  - Proper cleanup when leaving buffer
- **Visual Selection Rendering**: Render any selected text as a mermaid diagram
  - `:MermaiderRenderSelection` command (works in visual mode)
  - `<leader>mr` keybinding in visual mode
  - Useful for testing diagram snippets or rendering parts of larger files
- **Custom CSS Styling**: Apply custom styles to diagrams
  - `css_file` config option for custom CSS
  - `mermaid_config_file` option for mermaid configuration
  - Example files provided in `examples/` directory
  - Validation to ensure files exist before use

### Improved
- **Command Organization**: Commands now grouped by category in documentation
- **File Type Support**: Extended beyond just `.mmd` files to include markdown
- **Module Structure**: Added dedicated `markdown.lua` module for clean separation

### Technical Details
- Markdown blocks tracked by line numbers for accurate positioning
- Temporary buffers created for each mermaid block with unique naming
- Visual selection creates ephemeral buffers that auto-cleanup
- CSS and config files expanded and validated before passing to mermaid CLI

## Phase 1 - Foundation Improvements

### Fixed
- **Path Collision Issue**: Replaced weak sum-based path hashing with SHA256 to prevent file collisions between projects with same-named files
- **Missing Error Functions**: Added `log_error` and `log_warn` functions that were being called but didn't exist
- **Variable Shadowing**: Fixed `code_bufnr` parameter being overwritten in `render_inline` function

### Added
- **Content-Based Caching**: New caching system that skips re-rendering unchanged diagrams
  - Cache index stored in JSON format
  - SHA256 content hashing for reliable cache keys
  - Cache management commands: `:MermaiderCacheClear` and `:MermaiderCacheStats`
  - Automatic cleanup of stale cache entries
- **Better Error Messages**: Enhanced error parsing for mermaid CLI failures
  - Pattern matching for common syntax errors
  - Helpful suggestions for fixing issues
  - Truncation of overly long error messages
- **Configurable Throttle Delay**: New `throttle_delay` config option (default: 500ms)
  - Controls the delay for auto-render on save
  - Validated to ensure positive numeric value

### Improved
- **Performance**: Significant reduction in redundant renders through caching
- **User Experience**: Clearer error messages help users fix diagram issues quickly
- **Developer Experience**: Better code organization with dedicated cache module

### Technical Details
- Cache files use format: `filename_pathhash.png` where pathhash is first 16 chars of SHA256
- Cache index includes timestamp, source path, and Neovim version for debugging
- Error parser handles mermaid-cli, npm/npx, and puppeteer errors specifically