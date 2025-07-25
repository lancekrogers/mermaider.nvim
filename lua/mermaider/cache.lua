-- lua/mermaider/cache.lua
-- Content-based caching system for Mermaider

local M = {}
local fn = vim.fn
local utils = require("mermaider.utils")

-- Cache index structure: { [content_hash] = { path = "...", timestamp = ..., file_path = "..." } }
local cache_index = {}
local cache_index_loaded = false

-- Path to the cache index file
local function get_cache_index_path(config)
  return config.temp_dir .. "/cache_index.json"
end

-- Generate content hash for caching
-- @param content string|table: content to hash (string or lines table)
-- @return string: SHA256 hash of the content
function M.get_content_hash(content)
  local content_str
  if type(content) == "table" then
    content_str = table.concat(content, "\n")
  else
    content_str = content
  end
  return fn.sha256(content_str)
end

-- Load cache index from disk
-- @param config table: plugin configuration
local function load_cache_index(config)
  if cache_index_loaded then
    return
  end
  
  local index_path = get_cache_index_path(config)
  if fn.filereadable(index_path) == 1 then
    local ok, data = pcall(function()
      local content = fn.readfile(index_path)
      return vim.json.decode(table.concat(content, "\n"))
    end)
    
    if ok and type(data) == "table" then
      cache_index = data
    else
      utils.log_debug("Failed to parse cache index, starting fresh")
      cache_index = {}
    end
  end
  
  cache_index_loaded = true
end

-- Save cache index to disk
-- @param config table: plugin configuration
local function save_cache_index(config)
  local index_path = get_cache_index_path(config)
  local ok, json = pcall(vim.json.encode, cache_index)
  
  if ok then
    fn.mkdir(fn.fnamemodify(index_path, ":h"), "p")
    local file = io.open(index_path, "w")
    if file then
      file:write(json)
      file:close()
    else
      utils.log_error("Failed to write cache index")
    end
  else
    utils.log_error("Failed to encode cache index")
  end
end

-- Check if cached render exists and is valid
-- @param content_hash string: hash of the content
-- @param config table: plugin configuration
-- @return string|nil: path to cached file if exists and valid, nil otherwise
function M.check_cache(content_hash, config)
  load_cache_index(config)
  
  local entry = cache_index[content_hash]
  if entry and entry.path then
    -- Check if the cached file still exists
    if fn.filereadable(entry.path) == 1 then
      utils.log_debug("Cache hit for content hash: " .. content_hash:sub(1, 8) .. "...")
      return entry.path
    else
      -- Clean up stale cache entry
      utils.log_debug("Cache entry found but file missing, removing from index")
      cache_index[content_hash] = nil
      save_cache_index(config)
    end
  end
  
  utils.log_debug("Cache miss for content hash: " .. content_hash:sub(1, 8) .. "...")
  return nil
end

-- Update cache with new render
-- @param content_hash string: hash of the content
-- @param file_path string: path to the rendered file
-- @param source_path string: path to the source file
-- @param config table: plugin configuration
function M.update_cache(content_hash, file_path, source_path, config)
  load_cache_index(config)
  
  cache_index[content_hash] = {
    path = file_path,
    source_path = source_path,
    timestamp = os.time(),
    nvim_version = tostring(vim.version()),
  }
  
  save_cache_index(config)
  utils.log_debug("Updated cache for content hash: " .. content_hash:sub(1, 8) .. "...")
end

-- Clean old cache entries
-- @param config table: plugin configuration
-- @param max_age_days number: maximum age in days (default: 7)
function M.clean_old_entries(config, max_age_days)
  max_age_days = max_age_days or 7
  load_cache_index(config)
  
  local current_time = os.time()
  local max_age_seconds = max_age_days * 24 * 60 * 60
  local removed_count = 0
  
  for hash, entry in pairs(cache_index) do
    if entry.timestamp then
      local age = current_time - entry.timestamp
      if age > max_age_seconds then
        -- Remove the file if it exists
        if entry.path and fn.filereadable(entry.path) == 1 then
          os.remove(entry.path)
        end
        cache_index[hash] = nil
        removed_count = removed_count + 1
      end
    end
  end
  
  if removed_count > 0 then
    save_cache_index(config)
    utils.log_info(string.format("Cleaned %d old cache entries", removed_count))
  end
end

-- Get cache statistics
-- @param config table: plugin configuration
-- @return table: cache statistics
function M.get_stats(config)
  load_cache_index(config)
  
  local stats = {
    total_entries = 0,
    valid_entries = 0,
    total_size = 0,
    oldest_entry = nil,
    newest_entry = nil,
  }
  
  for _, entry in pairs(cache_index) do
    stats.total_entries = stats.total_entries + 1
    
    if entry.path and fn.filereadable(entry.path) == 1 then
      stats.valid_entries = stats.valid_entries + 1
      local size = fn.getfsize(entry.path)
      if size > 0 then
        stats.total_size = stats.total_size + size
      end
    end
    
    if entry.timestamp then
      if not stats.oldest_entry or entry.timestamp < stats.oldest_entry then
        stats.oldest_entry = entry.timestamp
      end
      if not stats.newest_entry or entry.timestamp > stats.newest_entry then
        stats.newest_entry = entry.timestamp
      end
    end
  end
  
  return stats
end

-- Clear all cache
-- @param config table: plugin configuration
function M.clear_all(config)
  load_cache_index(config)
  
  -- Remove all cached files
  for _, entry in pairs(cache_index) do
    if entry.path and fn.filereadable(entry.path) == 1 then
      os.remove(entry.path)
    end
  end
  
  -- Clear index
  cache_index = {}
  save_cache_index(config)
  
  utils.log_info("Cache cleared")
end

return M