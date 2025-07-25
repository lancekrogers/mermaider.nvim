# Changelog

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