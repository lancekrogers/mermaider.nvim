-- lua/mermaider/image_integration.lua
-- Image rendering with image.nvim

local M = {}
local utils = require("mermaider.utils")

M.image_objects = {} -- Buffer -> image object mapping
M.buffer_pairs = {}  -- Code buffer -> Preview buffer mapping

function M.is_available()
  local has_image_nvim, _ = pcall(require, "image")
  return has_image_nvim
end

function M.setup(config)
  if not M.is_available() then
    utils.log_error("image.nvim not available during setup")
    return false
  end
  utils.log_info("image.nvim integration enabled")
  return true
end

function M.render_image(image_path, options)
  if not M.is_available() then
    utils.log_error("image.nvim not available for rendering")
    return false
  end

  local image = require("image")
  options = options or {}

  if not vim.fn.filereadable(image_path) == 1 then
    utils.log_error("Image file not found: " .. image_path)
    return false
  end

  local display_options = {
    window               = options.window or vim.api.nvim_get_current_win(),
    buffer               = options.buffer or vim.api.nvim_get_current_buf(),
    max_width            = options.max_width,
    max_height           = options.max_height,
    x                    = options.x or 0,
    y                    = options.y or 0,
    inline               = options.inline or false,
    with_virtual_padding = options.with_virtual_padding or false,
    height               = options.max_height,
    width                = options.max_width,
  }

  local buf = display_options.buffer
  local win = display_options.window
  local img = M.image_objects[buf]

  utils.log_debug("Rendering image for buffer " .. buf .. " in window " .. win)
  utils.log_debug("Image path: " .. image_path)

  local success, err

  if img then
    -- Check if the window has changed
    if img.window and img.window ~= win then
      utils.log_debug("Window changed for buffer " .. buf .. ". Clearing old image.")
      pcall(function() img:clear() end)
      img = nil
      M.image_objects[buf] = nil
    end
  end

  if img then
    -- Update existing image
    utils.log_debug("Reusing existing image object for buffer " .. buf)
    success, err = pcall(function()
      img.path = image_path
      img:render(display_options)
    end)
  else
    -- Create new image
    utils.log_debug("Creating new image object for buffer " .. buf)
    success, err = pcall(function()
      img = image.from_file(image_path, display_options)
      if not img then
        error("Failed to create image object from file: " .. image_path)
      end
      utils.log_debug("Image object created, attempting to render")
      img:render(display_options)
      M.image_objects[buf] = img
      utils.log_debug("Image object stored for buffer " .. buf)
    end)
  end

  if not success then
    utils.log_error("Failed to render image: " .. tostring(err))
    -- Try to provide more helpful error messages
    if err and err:match("kitty") then
      utils.log_error("Kitty graphics protocol error. Ensure you're using Kitty terminal or configure image.nvim for your terminal.")
    elseif err and err:match("ueberzug") then
      utils.log_error("Ueberzugpp error. Ensure ueberzugpp is installed and configured correctly.")
    end
    return false
  end

  utils.log_info("Image rendered successfully with image.nvim")
  return true
end

function M.clear_images()
  if not M.is_available() then
    return false
  end

  local image = require("image")
  local success, err = pcall(function()
    for buf, img in pairs(M.image_objects) do
      img:clear()
    end
    M.image_objects = {}
    image.clear()
  end)

  if not success then
    utils.log_error("Failed to clear images: " .. tostring(err))
    return false
  end

  utils.log_debug("All images cleared")
  return true
end

function M.clear_image(buffer, window)
  if not M.is_available() then
    return false
  end

  local image = require("image")
  local success, err = pcall(function()
    image.clear({ buffer = buffer, window = window })
    if M.image_objects[buffer] then
      M.image_objects[buffer] = nil
    end
  end)
  if not success then
    utils.log_error("Failed to clear image: " .. tostring(err))
    return false
  end
  utils.log_debug("Image cleared for buffer " .. buffer .. " and window " .. window)
  return true
end

-- Render an image inline in the current window
-- @param code_bufnr number: buffer id of the code buffer
-- @param image_path string: path to the rendered image
-- @param config table: plugin configuration
-- @return boolean: true if successful, false otherwise
function M.render_inline(code_bufnr, image_path, config)
  if not M.is_available() then
    utils.log_error("image.nvim not available for inline rendering")
    return false
  end

  local api = vim.api
  local current_win = api.nvim_get_current_win()
  -- Use the passed code_bufnr instead of overwriting it

  -- Place image after the last line without modifying the buffer
  local line_count = api.nvim_buf_line_count(code_bufnr)
  local row = line_count  -- Place after the last line (0-based)
  local col = 0          -- Start at the beginning of the line

  -- Calculate image dimensions based on window size
  local win_width  = api.nvim_win_get_width(current_win)
  local win_height = api.nvim_win_get_height(current_win)
  local max_width  = math.floor(win_width * (config.max_width_window_percentage / 100))
  local max_height = math.floor(win_height * (config.max_height_window_percentage / 100))

  -- Set up display options
  local render_image_options = {
    window = current_win,
    buffer = code_bufnr,
    x = col,
    y = row,
    max_width  = max_width,
    max_height = max_height,
    inline = true,
    with_virtual_padding = true,  -- This should create virtual space without modifying the file
  }
  
  utils.log_debug(string.format("Inline render position: row=%d, col=%d, win=%d, buf=%d", 
    row, col, current_win, code_bufnr))
  utils.log_debug(string.format("Image dimensions: max_width=%d, max_height=%d", 
    max_width, max_height))

  -- Render the image in the code buffer
  local success = M.render_image(image_path, render_image_options)

  if success then
    utils.log_info("Mermaid diagram rendered inline with image.nvim")
  else
    utils.log_error("Failed to render inline Mermaid diagram")
  end

  return success
end

-- Toggle between code and diagram view (optional, adjust if needed)
function M.toggle_preview(bufnr)
  local api = vim.api
  local current_win = api.nvim_get_current_win()
  local img = M.image_objects[bufnr]

  if img and img.is_rendered then
    img:clear()
    utils.log_info("Diagram hidden")
    return true
  else
    local image_path = require("mermaider.files").get_temp_file_path(M.config, bufnr) .. ".png"
    if vim.fn.filereadable(image_path) == 1 then
      return M.render_inline(bufnr, image_path, M.config)
    else
      utils.log_error("No rendered diagram available to toggle")
      return false
    end
  end
end

return M
