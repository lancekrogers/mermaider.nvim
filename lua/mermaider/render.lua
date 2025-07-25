-- lua/mermaider/render.lua
-- Rendering logic for Mermaider

local M = {}
local uv = vim.uv or vim.loop
local api = vim.api
local files = require("mermaider.files")
local commands = require("mermaider.commands")
local status = require("mermaider.status")
local utils = require("mermaider.utils")
local cache = require("mermaider.cache")

-- Table to keep track of active render jobs
local active_jobs = {}

-- Render the buffer content as a Mermaid diagram
-- @param config table: plugin configuration
-- @param bufnr number: buffer id
-- @param callback function: callback with (success, result) parameters
function M.render_buffer(config, bufnr, callback)
  if not api.nvim_buf_is_valid(bufnr) then
    utils.safe_notify("Invalid buffer: " .. bufnr, vim.log.levels.ERROR)
    return
  end

  -- Get buffer content for caching
  local buffer_lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content_hash = cache.get_content_hash(buffer_lines)
  
  -- Get source path before async operation
  local source_path = api.nvim_buf_get_name(bufnr)
  
  -- Check cache first
  local cached_path = cache.check_cache(content_hash, config)
  if cached_path then
    -- Use cached render
    status.set_status(bufnr, status.STATUS.SUCCESS)
    utils.log_info("Using cached render: " .. cached_path)
    utils.log_debug("Calling callback with cached path for buffer " .. bufnr)
    
    -- Schedule callback to ensure consistent behavior with async renders
    vim.schedule(function()
      if callback then 
        callback(true, cached_path) 
      else
        utils.log_debug("No callback provided for cached render")
      end
    end)
    return
  end

  -- Set status to rendering
  status.set_status(bufnr, status.STATUS.RENDERING)

  -- Get temporary file paths
  local temp_path = files.get_temp_file_path(config, bufnr)
  local input_file = temp_path .. ".mmd"
  local output_file = temp_path

  -- Write buffer content to temp file
  local write_ok, write_err = files.write_buffer_to_temp_file(bufnr, input_file)
  if not write_ok then
    status.set_status(bufnr, status.STATUS.ERROR, "Failed to write temp file")
    utils.safe_notify("Failed to write temp file: " .. tostring(write_err), vim.log.levels.ERROR)
    if callback then callback(false, write_err) end
    return
  end

  -- Build the render command
  local cmd = commands.build_render_command(config, output_file)
  cmd = cmd:gsub("{{IN_FILE}}", input_file)
  
  utils.log_debug("Rendering buffer " .. bufnr .. " to " .. output_file .. ".png")
  utils.log_debug("Input file: " .. input_file)

  -- Execute the render command
  local on_success = function()
    -- Schedule to avoid fast event context
    vim.schedule(function()
      if files.file_exists(output_file .. ".png") then
        status.set_status(bufnr, status.STATUS.SUCCESS)
        utils.log_info("Rendered diagram to " .. output_file .. ".png")
        
        -- Update cache with the new render (source_path captured before async)
        cache.update_cache(content_hash, output_file .. ".png", source_path, config)
        
        if callback then callback(true, output_file .. ".png") end
      else
        status.set_status(bufnr, status.STATUS.ERROR, "Output file not generated")
        utils.safe_notify("Output file not generated after rendering", vim.log.levels.ERROR)
        if callback then callback(false, "Output file not generated") end
      end
    end)
  end

  local on_error = function(error_output, cmd_used)
    -- Schedule to avoid fast event context
    vim.schedule(function()
      status.set_status(bufnr, status.STATUS.ERROR, "Render failed")
      local parsed_error = commands.parse_mermaid_error(error_output)
      utils.safe_notify("Render failed: " .. parsed_error, vim.log.levels.ERROR)
      utils.log_debug("Full error output: " .. error_output)
      utils.log_debug("Command used: " .. (cmd_used or "unknown"))
      if callback then callback(false, parsed_error) end
    end)
  end

  -- Store the job handle
  local job = commands.execute_async(cmd, nil, on_success, on_error)
  if job then
    active_jobs[bufnr] = job
    utils.log_debug("Started render job for buffer " .. bufnr)
  else
    utils.log_error("Failed to start render job for buffer " .. bufnr)
  end
end

-- Cancel a specific render job
-- @param bufnr number: buffer id
function M.cancel_render(bufnr)
  local job = active_jobs[bufnr]
  if job and not job:is_closing() then
    job:close()
    active_jobs[bufnr] = nil
    status.set_status(bufnr, status.STATUS.IDLE)
    utils.log_info("Render cancelled for buffer " .. bufnr)
  end
end

-- Cancel all active render jobs
function M.cancel_all_jobs()
  for bufnr, job in pairs(active_jobs) do
    if job and not job:is_closing() then
      job:close()
      utils.log_info("Render job cancelled for buffer " .. bufnr)
    end
  end
  active_jobs = {}
end

return M
