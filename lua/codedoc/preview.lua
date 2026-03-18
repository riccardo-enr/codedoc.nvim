local parser = require("codedoc.parser")
local html_mod = require("codedoc.html")
local languages = require("codedoc.languages")

local M = {}

---@class PreviewState
---@field server uv_tcp_t?
---@field port number?
---@field hash string
---@field augroup number?
---@field bufnr number?

---@type PreviewState
local state = {
  server = nil,
  port = nil,
  hash = "",
  augroup = nil,
  bufnr = nil,
}

--- Simple hash for change detection
---@param s string
---@return string
local function quick_hash(s)
  -- Use length + first/last bytes + checksum of sampled chars
  local len = #s
  if len == 0 then return "0" end
  local h = len
  local step = math.max(1, math.floor(len / 200))
  for i = 1, len, step do
    h = (h * 31 + s:byte(i)) % 2147483647
  end
  return tostring(h)
end

--- Get the current buffer content as rendered HTML
---@return string html
---@return string hash
local function build_html()
  local bufnr = state.bufnr or vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local lang = languages.detect(file_path)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  local fname = vim.fn.fnamemodify(file_path, ":t")

  local segments = parser.build_segments(text, lang)
  local hash = quick_hash(text)

  local port = state.port or 9876
  local rendered = html_mod.render_live(segments, lang, {
    title = fname,
    poll_url = ("http://localhost:%d/hash"):format(port),
  })
  return rendered, hash
end

--- HTTP response helper
---@param client uv_tcp_t
---@param status string
---@param content_type string
---@param body string
local function http_respond(client, status, content_type, body)
  local resp = table.concat({
    "HTTP/1.1 " .. status,
    "Content-Type: " .. content_type,
    "Content-Length: " .. #body,
    "Access-Control-Allow-Origin: *",
    "Connection: close",
    "",
    body,
  }, "\r\n")
  client:write(resp, function()
    if not client:is_closing() then client:close() end
  end)
end

--- Start the HTTP preview server
---@param port? number
local function start_server(port)
  port = port or 9876

  local uv = vim.uv or vim.loop
  local server = uv.new_tcp()
  assert(server, "codedoc: failed to create TCP handle")

  local ok, bind_err = pcall(function() server:bind("127.0.0.1", port) end)
  if not ok then
    -- Try a random port
    port = port + math.random(1, 100)
    server:bind("127.0.0.1", port)
  end

  server:listen(128, function(err)
    if err then return end
    local client = uv.new_tcp()
    server:accept(client)

    local buf = ""
    client:read_start(function(read_err, data)
      if read_err or not data then
        if not client:is_closing() then client:close() end
        return
      end
      buf = buf .. data
      -- Wait for full headers
      if not buf:find("\r\n\r\n") then return end
      client:read_stop()

      local path = buf:match("^%w+ ([^ ]+)")
      if path == "/hash" then
        vim.schedule(function()
          local _, hash = build_html()
          state.hash = hash
          http_respond(client, "200 OK", "text/plain", hash)
        end)
      elseif path == "/" then
        vim.schedule(function()
          local rendered, hash = build_html()
          state.hash = hash
          http_respond(client, "200 OK", "text/html; charset=utf-8", rendered)
        end)
      else
        http_respond(client, "404 Not Found", "text/plain", "not found")
      end
    end)
  end)

  state.server = server
  state.port = port
  return port
end

--- Open the preview in a browser
function M.open()
  if state.server then
    vim.notify("codedoc: preview already running on port " .. state.port, vim.log.levels.WARN)
    return
  end

  state.bufnr = vim.api.nvim_get_current_buf()
  local port = start_server(require("codedoc").config.port)

  -- Set up autocmd to update hash on buffer changes
  state.augroup = vim.api.nvim_create_augroup("codedoc_preview", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
    group = state.augroup,
    buffer = state.bufnr,
    callback = function()
      -- Hash is recomputed on next /hash request, nothing to do here
    end,
  })

  local url = ("http://localhost:%d"):format(port)
  vim.notify("codedoc: preview at " .. url)

  -- Open browser
  local open_cmd
  if vim.fn.has("mac") == 1 then
    open_cmd = { "open", url }
  elseif vim.fn.has("wsl") == 1 then
    open_cmd = { "wslview", url }
  else
    open_cmd = { "xdg-open", url }
  end
  vim.fn.jobstart(open_cmd, { detach = true })
end

--- Stop the preview server
function M.close()
  if state.server then
    if not state.server:is_closing() then
      state.server:close()
    end
    state.server = nil
    state.port = nil
    vim.notify("codedoc: preview stopped", vim.log.levels.INFO)
  end
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
    state.augroup = nil
  end
  state.bufnr = nil
  state.hash = ""
end

--- Toggle preview on/off
function M.toggle()
  if state.server then
    M.close()
  else
    M.open()
  end
end

--- Check if preview is running
---@return boolean
function M.is_running()
  return state.server ~= nil
end

return M
