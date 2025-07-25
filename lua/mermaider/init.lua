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
  end

  if M.config.auto_render_on_open then
    api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
      group = augroup,
      pattern = { "*.mmd", "*.mermaid" },
      callback = function()
        M.render_current_buffer()
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

return M
