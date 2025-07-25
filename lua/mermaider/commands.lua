-- lua/mermaider/commands.lua
-- Command building and execution functions for Mermaider

local M = {}
local uv = vim.uv or vim.loop
local utils = require("mermaider.utils")

-- Build a mermaid render command with given options
-- @param config table: plugin configuration
-- @param output_file string: base path for output (extension will be added)
-- @return string: the complete command
function M.build_render_command(config, output_file)
  local cmd = config.mermaider_cmd:gsub("{{OUT_FILE}}", output_file)

  local options = {}
  if config.theme and config.theme ~= "" then
    table.insert(options, "--theme " .. config.theme)
  end
  if config.background_color and config.background_color ~= "" then
    table.insert(options, "--backgroundColor " .. config.background_color)
  end
  if config.mmdc_options and config.mmdc_options ~= "" then
    table.insert(options, config.mmdc_options)
  end
  if #options > 0 then
    cmd = cmd .. " " .. table.concat(options, " ")
  end

  return cmd
end

-- Execute a command asynchronously with proper output handling
-- @param cmd string: command to execute
-- @param stdin_content string: content to pipe to stdin
-- @param on_success function: callback for successful execution
-- @param on_error function: callback for failed execution
-- @return handle: the process handle
function M.execute_async(cmd, stdin_content, on_success, on_error)
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local output = ""
  local error_output = ""

  local handle
  handle = uv.spawn("sh", {
    args = { "-c", cmd },
    stdio = { stdin, stdout, stderr }
  }, function(code)
    -- Only close handles if they are not already closed
    if stdout:is_closing() == false then stdout:close() end
    if stderr:is_closing() == false then stderr:close() end
    if stdin:is_closing() == false then stdin:close() end
    if handle:is_closing() == false then handle:close() end

    if code == 0 then
      if on_success then
        on_success(output)
      end
    else
      if on_error then
        on_error(error_output, cmd)
      end
    end
  end)

  if not handle then
    utils.safe_notify("Failed to spawn process for command: " .. cmd, vim.log.levels.ERROR)
    if stdin then stdin:close() end
    if stdout then stdout:close() end
    if stderr then stderr:close() end
    return nil
  end

  if stdin_content then
    stdin:write(stdin_content, function(err)
      if err then
        error_output = error_output .. "Stdin write error: " .. tostring(err)
      end
      if stdin:is_closing() == false then stdin:close() end
    end)
  else
    if stdin:is_closing() == false then stdin:close() end
  end

  stdout:read_start(function(err, data)
    if err then
      error_output = error_output .. "Stdout error: " .. tostring(err)
      return
    end
    if data then
      output = output .. data
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      error_output = error_output .. "Stderr error: " .. tostring(err)
      return
    end
    if data then
      error_output = error_output .. data
    end
  end)

  return handle
end

-- Parse mermaid CLI error output to provide helpful messages
-- @param stderr string: error output from mermaid CLI
-- @return string: parsed error message
function M.parse_mermaid_error(stderr)
  if not stderr or stderr == "" then
    return "Unknown render error"
  end
  
  -- Common mermaid error patterns
  local patterns = {
    -- Syntax errors
    ["Parse error on line (%d+)"] = "Syntax error at line %s",
    ["Lexical error on line (%d+)"] = "Invalid token at line %s",
    ["Syntax error in graph"] = "Invalid diagram syntax - check your diagram structure",
    
    -- Diagram type errors
    ["No diagram type detected"] = "Invalid diagram: must start with a valid type (graph, sequenceDiagram, etc.)",
    ["Unknown diagram type"] = "Unknown diagram type - check supported types in Mermaid documentation",
    
    -- Common mistakes
    ["Duplicate id"] = "Duplicate node ID found - each node must have a unique identifier",
    ["expected%s*'%%'"] = "Missing %% delimiter - some diagram types require %%%% markers",
    
    -- General errors
    ["Error: (.+)"] = "%s",
    ["error: (.+)"] = "%s",
  }
  
  -- Check each pattern
  for pattern, message in pairs(patterns) do
    local captures = { stderr:match(pattern) }
    if #captures > 0 then
      return string.format(message, unpack(captures))
    end
  end
  
  -- Check for common issues
  if stderr:match("ENOENT") then
    return "Mermaid CLI not found - ensure @mermaid-js/mermaid-cli is installed"
  elseif stderr:match("npm") or stderr:match("npx") then
    return "NPM/NPX error - check your Node.js installation"
  elseif stderr:match("puppeteer") then
    return "Puppeteer error - mermaid-cli requires Chrome/Chromium for rendering"
  end
  
  -- Return cleaned stderr if no pattern matches
  -- Remove excessive whitespace and newlines
  local cleaned = stderr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  
  -- Truncate very long errors
  if #cleaned > 200 then
    cleaned = cleaned:sub(1, 197) .. "..."
  end
  
  return cleaned
end

return M
