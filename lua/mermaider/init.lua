-- lua/mermaider/init.lua
-- Main entry point for Mermaider plugin, now focused on image.nvim

local M = {}
local api = vim.api
local fn = vim.fn

-- Import modules
local config_module = require("mermaider.config")
local files = require("mermaider.files")
local image_integration = require("mermaider.image_integration")
local mermaid = require("mermaider.mermaid")
local render = require("mermaider.render")
local utils = require("mermaider.utils")
local markdown = require("mermaider.markdown")

M.config = {}
M.tempfiles = {}

function M.setup(opts)
  M.config = config_module.setup(opts)
  M.check_dependencies()
  image_integration.setup(M.config)

  api.nvim_create_user_command("MermaiderRender", function()
    M.render_current_buffer()
  end, { desc = "Render the current mermaid diagram" })

  api.nvim_create_user_command("MermaiderPreview", function()
    local bufnr = api.nvim_get_current_buf()
    local image_path = files.get_temp_file_path(M.config, bufnr) .. ".png"
    mermaid.preview_diagram(bufnr, image_path, M.config)
  end, { desc = "Preview the current mermaid diagram" })

  api.nvim_create_user_command("MermaiderToggle", function()
    local bufnr = api.nvim_get_current_buf()
    image_integration.toggle_preview(bufnr)
  end, { desc = "Toggle between mermaid code and preview" })

  vim.keymap.set('n', '<leader>mt', function()
    vim.cmd('MermaiderToggle')
  end, { desc = "Toggle mermaid preview", silent = true })

  -- Visual mode mapping for rendering selection
  vim.keymap.set('v', '<leader>mr', ':MermaiderRenderSelection<CR>', {
    desc = "Render selected mermaid diagram",
    silent = true
  })

  -- Cache management commands
  api.nvim_create_user_command("MermaiderCacheClear", function()
    require("mermaider.cache").clear_all(M.config)
  end, { desc = "Clear all cached renders" })

  api.nvim_create_user_command("MermaiderCacheStats", function()
    local stats = require("mermaider.cache").get_stats(M.config)
    local lines = {
      string.format("Total entries: %d", stats.total_entries),
      string.format("Valid entries: %d", stats.valid_entries),
      string.format("Total size: %.2f MB", stats.total_size / 1024 / 1024),
    }
    if stats.oldest_entry then
      lines[#lines + 1] = string.format("Oldest entry: %s", os.date("%Y-%m-%d %H:%M", stats.oldest_entry))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Mermaider Cache" })
  end, { desc = "Show cache statistics" })

  -- Markdown-specific commands
  api.nvim_create_user_command("MermaiderRenderBlock", function()
    M.render_markdown_block_at_cursor()
  end, { desc = "Render mermaid block at cursor position" })

  api.nvim_create_user_command("MermaiderRenderAllBlocks", function()
    M.render_all_markdown_blocks()
  end, { desc = "Render all mermaid blocks in markdown file" })

  -- Visual selection rendering
  api.nvim_create_user_command("MermaiderRenderSelection", function(opts)
    M.render_visual_selection(opts.line1, opts.line2)
  end, { 
    desc = "Render selected mermaid diagram",
    range = true 
  })

  M.setup_autocmds()
  
  -- Load debug module if available
  pcall(require, "mermaider.debug_image")
  
  utils.safe_notify("Mermaider plugin loaded with image.nvim", vim.log.levels.INFO)
end

function M.check_dependencies()
  if not utils.is_program_installed("npx") then
    utils.safe_notify(
      "npx command not found. Please install Node.js and npm.",
      vim.log.levels.WARN
    )
  end

  if not image_integration.is_available() then
    utils.safe_notify(
      "image.nvim not available. Please ensure it's installed and configured.",
      vim.log.levels.ERROR
    )
  end
end

function M.setup_autocmds()
  local augroup = api.nvim_create_augroup("Mermaider", { clear = true })

  if M.config.auto_render then
    api.nvim_create_autocmd({ "BufWritePost" }, {
      group = augroup,
      pattern = { "*.mmd", "*.mermaid" },
      callback = utils.throttle(function()
        M.render_current_buffer()
      end, M.config.throttle_delay),
    })
    
    -- Auto-render markdown files with mermaid blocks
    api.nvim_create_autocmd({ "BufWritePost" }, {
      group = augroup,
      pattern = { "*.md", "*.markdown" },
      callback = utils.throttle(function()
        local bufnr = api.nvim_get_current_buf()
        if markdown.has_mermaid_blocks(bufnr) then
          M.render_all_markdown_blocks()
        end
      end, M.config.throttle_delay),
    })
  end

  if M.config.auto_render_on_open then
    api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
      group = augroup,
      pattern = { "*.mmd", "*.mermaid" },
      callback = function()
        M.render_current_buffer()
      end,
    })
    
    -- Auto-render markdown files on open
    api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
      group = augroup,
      pattern = { "*.md", "*.markdown" },
      callback = function()
        local bufnr = api.nvim_get_current_buf()
        if markdown.has_mermaid_blocks(bufnr) then
          vim.defer_fn(function()
            M.render_all_markdown_blocks()
          end, 100)
        end
      end,
    })
  end

  api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      render.cancel_all_jobs()
      image_integration.clear_images()
      files.cleanup_temp_files(M.tempfiles)
    end,
  })

  api.nvim_create_autocmd("BufDelete", {
    group = augroup,
    callback = function(ev)
      render.cancel_render(ev.buf)
      image_integration.clear_image(ev.buf, vim.api.nvim_get_current_win())
      M.tempfiles[ev.buf] = nil
    end,
  })
end

function M.render_current_buffer()
  local bufnr = api.nvim_get_current_buf()

  local on_complete = function(success, result)
    if success then
      M.tempfiles[bufnr] = result  -- Store the output file path (e.g., temp_path.png)
      if M.config.auto_preview then
        mermaid.preview_diagram(bufnr, result, M.config)
      end
    end
  end

  render.render_buffer(M.config, bufnr, on_complete)
end

-- Render mermaid block at cursor position in markdown
function M.render_markdown_block_at_cursor()
  local bufnr = api.nvim_get_current_buf()
  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  
  if ft ~= "markdown" then
    utils.safe_notify("This command only works in markdown files", vim.log.levels.WARN)
    return
  end
  
  local block = markdown.get_block_at_cursor(bufnr)
  if not block then
    utils.safe_notify("No mermaid block found at cursor position", vim.log.levels.WARN)
    return
  end
  
  utils.log_info("Rendering mermaid block at lines " .. block.start_line_1based .. "-" .. block.end_line_1based)
  
  -- Create temp buffer and render
  local block_id = markdown.get_block_id(bufnr, block)
  local temp_bufnr = markdown.create_temp_mermaid_buffer(block.content, block_id)
  
  render.render_buffer(M.config, temp_bufnr, function(success, result)
    if success then
      -- Add inline image to markdown
      markdown.add_inline_image(bufnr, block, result)
      utils.log_info("Rendered mermaid block successfully")
    else
      utils.log_error("Failed to render mermaid block: " .. tostring(result))
    end
    
    -- Clean up temp buffer
    if api.nvim_buf_is_valid(temp_bufnr) then
      api.nvim_buf_delete(temp_bufnr, { force = true })
    end
  end)
end

-- Render all mermaid blocks in markdown file
function M.render_all_markdown_blocks()
  local bufnr = api.nvim_get_current_buf()
  local ft = api.nvim_buf_get_option(bufnr, "filetype")
  
  if ft ~= "markdown" then
    utils.safe_notify("This command only works in markdown files", vim.log.levels.WARN)
    return
  end
  
  -- Clear existing renders first
  markdown.clear_markdown_renders(bufnr)
  
  -- Render all blocks
  local results = markdown.render_all_blocks(bufnr, M.config, render.render_buffer)
  
  local success_count = 0
  for _, result in ipairs(results) do
    if result.success then
      success_count = success_count + 1
      markdown.add_inline_image(bufnr, result.block, result.result)
    end
  end
  
  if success_count > 0 then
    utils.log_info(string.format("Rendered %d/%d mermaid blocks", success_count, #results))
  elseif #results > 0 then
    utils.log_error("Failed to render any mermaid blocks")
  end
end

-- Render visual selection as mermaid diagram
function M.render_visual_selection(start_line, end_line)
  local bufnr = api.nvim_get_current_buf()
  
  -- Get selected lines
  local lines = api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  
  if #lines == 0 then
    utils.safe_notify("No content selected", vim.log.levels.WARN)
    return
  end
  
  utils.log_info(string.format("Rendering visual selection: lines %d-%d", start_line, end_line))
  
  -- Create temporary buffer with selection
  local source_name = api.nvim_buf_get_name(bufnr)
  local selection_id = string.format("%s:selection:%d-%d", source_name, start_line, end_line)
  local temp_bufnr = api.nvim_create_buf(false, true)
  
  api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, lines)
  api.nvim_buf_set_name(temp_bufnr, "mermaid://" .. selection_id)
  api.nvim_buf_set_option(temp_bufnr, "filetype", "mermaid")
  api.nvim_buf_set_option(temp_bufnr, "buftype", "nofile")
  
  -- Render the selection
  render.render_buffer(M.config, temp_bufnr, function(success, result)
    if success then
      -- Preview the rendered selection
      if M.config.auto_preview then
        mermaid.preview_diagram(temp_bufnr, result, M.config)
      end
      utils.log_info("Visual selection rendered successfully")
    else
      utils.log_error("Failed to render visual selection: " .. tostring(result))
    end
    
    -- Clean up temp buffer after a delay
    vim.defer_fn(function()
      if api.nvim_buf_is_valid(temp_bufnr) then
        api.nvim_buf_delete(temp_bufnr, { force = true })
      end
    end, 1000)
  end)
end

-- Setup markdown autocmds
markdown.setup_autocmds()

return M
