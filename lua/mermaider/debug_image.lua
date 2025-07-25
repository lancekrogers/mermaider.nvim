-- Debug script to test image.nvim functionality
local M = {}

function M.test_image_nvim()
  local utils = require("mermaider.utils")
  
  -- Test 1: Check if image.nvim is available
  local has_image, image = pcall(require, "image")
  if not has_image then
    utils.log_error("image.nvim is not installed or not available")
    return false
  end
  utils.log_info("✓ image.nvim is available")
  
  -- Test 2: Check backend
  local api = require("image.api")
  local backend = api.get_backend()
  if backend then
    utils.log_info("✓ image.nvim backend: " .. backend)
  else
    utils.log_error("✗ No backend configured for image.nvim")
    utils.log_error("Please ensure image.nvim is properly configured with a backend (kitty or ueberzug)")
    return false
  end
  
  -- Test 3: Try to render a test image
  local test_image_path = vim.fn.expand("~/.cache/mermaider/") .. "architecture_6878.png"
  if vim.fn.filereadable(test_image_path) == 1 then
    utils.log_info("✓ Found test image: " .. test_image_path)
    
    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()
    
    local success, err = pcall(function()
      local img = image.from_file(test_image_path, {
        buffer = bufnr,
        window = winnr,
        x = 0,
        y = 1,
        width = 50,
        height = 20,
      })
      
      if not img then
        error("Failed to create image object")
      end
      
      img:render()
      utils.log_info("✓ Successfully rendered test image")
      
      -- Clean up after 3 seconds
      vim.defer_fn(function()
        pcall(function() img:clear() end)
        utils.log_info("Test image cleared")
      end, 3000)
    end)
    
    if not success then
      utils.log_error("✗ Failed to render test image: " .. tostring(err))
      return false
    end
  else
    utils.log_warn("No test image found at: " .. test_image_path)
    utils.log_warn("Please render a mermaid diagram first to create a test image")
  end
  
  return true
end

-- Add debug command
vim.api.nvim_create_user_command("MermaiderDebugImage", function()
  M.test_image_nvim()
end, {
  desc = "Debug image.nvim integration"
})

return M