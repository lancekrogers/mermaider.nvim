-- lua/mermaider/markdown.lua
-- Markdown integration for rendering mermaid blocks

local M = {}
local api = vim.api
local utils = require("mermaider.utils")

-- Pattern to match mermaid code blocks
local MERMAID_BLOCK_PATTERN = "^```mermaid%s*$"
local CODE_BLOCK_END_PATTERN = "^```%s*$"

-- Extract all mermaid blocks from buffer
-- @param bufnr number: buffer number
-- @return table: array of mermaid blocks with metadata
function M.extract_mermaid_blocks(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks = {}
  local in_block = false
  local current_block = {}
  local start_line = 0
  
  for i, line in ipairs(lines) do
    if not in_block and line:match(MERMAID_BLOCK_PATTERN) then
      -- Start of mermaid block
      in_block = true
      start_line = i
      current_block = {}
    elseif in_block and line:match(CODE_BLOCK_END_PATTERN) then
      -- End of code block
      in_block = false
      if #current_block > 0 then
        table.insert(blocks, {
          content = current_block,
          start_line = start_line,
          end_line = i,
          -- Line numbers are 1-based for display
          start_line_1based = start_line,
          end_line_1based = i,
        })
      end
    elseif in_block then
      -- Content inside mermaid block
      table.insert(current_block, line)
    end
  end
  
  -- Handle unclosed block
  if in_block and #current_block > 0 then
    utils.log_warn("Unclosed mermaid block starting at line " .. start_line)
  end
  
  return blocks
end

-- Find mermaid block at cursor position
-- @param bufnr number: buffer number
-- @param cursor_pos table: cursor position {row, col} (optional)
-- @return table|nil: mermaid block at cursor or nil
function M.get_block_at_cursor(bufnr, cursor_pos)
  bufnr = bufnr or api.nvim_get_current_buf()
  cursor_pos = cursor_pos or api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]
  
  local blocks = M.extract_mermaid_blocks(bufnr)
  
  for _, block in ipairs(blocks) do
    if cursor_line >= block.start_line_1based and cursor_line <= block.end_line_1based then
      return block
    end
  end
  
  return nil
end

-- Check if buffer contains mermaid blocks
-- @param bufnr number: buffer number
-- @return boolean: true if buffer has mermaid blocks
function M.has_mermaid_blocks(bufnr)
  local blocks = M.extract_mermaid_blocks(bufnr)
  return #blocks > 0
end

-- Get unique identifier for a mermaid block
-- @param bufnr number: buffer number
-- @param block table: mermaid block
-- @return string: unique identifier
function M.get_block_id(bufnr, block)
  local buf_name = api.nvim_buf_get_name(bufnr)
  -- Use buffer name and line number for unique ID
  return string.format("%s:%d-%d", buf_name, block.start_line, block.end_line)
end

-- Create a temporary buffer with mermaid content
-- @param content table: array of content lines
-- @param source_info string: information about source (for naming)
-- @return number: buffer number of temporary buffer
function M.create_temp_mermaid_buffer(content, source_info)
  local temp_bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, content)
  
  -- Set buffer name to help with caching
  local buf_name = string.format("mermaid://%s", source_info or "markdown-block")
  pcall(api.nvim_buf_set_name, temp_bufnr, buf_name)
  
  -- Set filetype for syntax highlighting
  api.nvim_buf_set_option(temp_bufnr, "filetype", "mermaid")
  api.nvim_buf_set_option(temp_bufnr, "buftype", "nofile")
  
  return temp_bufnr
end

-- Render all mermaid blocks in a markdown buffer
-- @param bufnr number: buffer number
-- @param config table: plugin configuration
-- @param render_fn function: render function to use
-- @return table: array of render results
function M.render_all_blocks(bufnr, config, render_fn)
  local blocks = M.extract_mermaid_blocks(bufnr)
  local results = {}
  
  if #blocks == 0 then
    utils.log_info("No mermaid blocks found in buffer")
    return results
  end
  
  utils.log_info(string.format("Found %d mermaid blocks to render", #blocks))
  
  for i, block in ipairs(blocks) do
    local block_id = M.get_block_id(bufnr, block)
    local temp_bufnr = M.create_temp_mermaid_buffer(block.content, block_id)
    
    -- Store original buffer and block info for callback
    local render_complete = false
    local render_result = nil
    
    render_fn(config, temp_bufnr, function(success, result)
      -- Use vim.schedule to ensure we're not in a fast event context
      vim.schedule(function()
        render_complete = true
        render_result = {
          success = success,
          result = result,
          block = block,
          block_id = block_id,
          temp_bufnr = temp_bufnr,
        }
      end)
    end)
    
    -- Wait for render to complete (with timeout)
    vim.wait(5000, function() return render_complete end, 100)
    
    if render_result then
      table.insert(results, render_result)
    else
      utils.log_error("Timeout rendering block " .. i)
    end
    
    -- Clean up temp buffer
    if api.nvim_buf_is_valid(temp_bufnr) then
      vim.schedule(function()
        if api.nvim_buf_is_valid(temp_bufnr) then
          api.nvim_buf_delete(temp_bufnr, { force = true })
        end
      end)
    end
  end
  
  return results
end

-- Get extmark namespace for markdown rendering
local md_namespace = api.nvim_create_namespace("mermaider_markdown")

-- Store rendered image info for markdown buffers
-- Format: { [bufnr] = { [block_id] = { extmark_id, image_path } } }
local markdown_renders = {}

-- Add rendered image below mermaid block
-- @param bufnr number: buffer number
-- @param block table: mermaid block info
-- @param image_path string: path to rendered image
function M.add_inline_image(bufnr, block, image_path)
  -- Store render info
  if not markdown_renders[bufnr] then
    markdown_renders[bufnr] = {}
  end
  
  local block_id = M.get_block_id(bufnr, block)
  
  -- Remove old extmark if exists
  if markdown_renders[bufnr][block_id] then
    local old_id = markdown_renders[bufnr][block_id].extmark_id
    pcall(api.nvim_buf_del_extmark, bufnr, md_namespace, old_id)
  end
  
  -- Add extmark after the closing ```
  local extmark_id = api.nvim_buf_set_extmark(bufnr, md_namespace, block.end_line - 1, 0, {
    virt_lines = {{ { "", "MermaidRendered" } }},
    virt_lines_above = false,
  })
  
  markdown_renders[bufnr][block_id] = {
    extmark_id = extmark_id,
    image_path = image_path,
    block = block,
  }
  
  -- Now render the actual image using image.nvim integration
  local image_integration = require("mermaider.image_integration")
  local current_win = api.nvim_get_current_win()
  
  -- Calculate position (after the code block)
  local render_options = {
    window = current_win,
    buffer = bufnr,
    x = 0,
    y = block.end_line, -- After the closing ```
    max_width = 100,    -- Will be calculated based on window
    max_height = 50,
    inline = true,
    with_virtual_padding = true,
  }
  
  -- Let image_integration calculate proper dimensions
  local config = require("mermaider").config
  local win_width = api.nvim_win_get_width(current_win)
  local win_height = api.nvim_win_get_height(current_win)
  render_options.max_width = math.floor(win_width * (config.max_width_window_percentage / 100))
  render_options.max_height = math.floor(win_height * (config.max_height_window_percentage / 100))
  
  image_integration.render_image(image_path, render_options)
end

-- Clear all rendered images in markdown buffer
-- @param bufnr number: buffer number
function M.clear_markdown_renders(bufnr)
  if not markdown_renders[bufnr] then
    return
  end
  
  -- Clear all extmarks
  api.nvim_buf_clear_namespace(bufnr, md_namespace, 0, -1)
  
  -- Clear from image.nvim
  local image_integration = require("mermaider.image_integration")
  image_integration.clear_image(bufnr, api.nvim_get_current_win())
  
  markdown_renders[bufnr] = nil
end

-- Setup autocmds for markdown cleanup
function M.setup_autocmds()
  local augroup = api.nvim_create_augroup("MermaiderMarkdown", { clear = true })
  
  -- Clean up when buffer is deleted
  api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(ev)
      M.clear_markdown_renders(ev.buf)
    end,
  })
  
  -- Clean up when leaving buffer
  api.nvim_create_autocmd("BufLeave", {
    group = augroup,
    callback = function(ev)
      -- Only clear if it's a markdown file
      local ft = api.nvim_buf_get_option(ev.buf, "filetype")
      if ft == "markdown" then
        M.clear_markdown_renders(ev.buf)
      end
    end,
  })
end

return M