local parser = require("codedoc.parser")
local html = require("codedoc.html")
local languages = require("codedoc.languages")

local M = {}

--- Export current buffer as Markdown
---@param path? string output path (prompts if nil)
function M.markdown(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local lang = languages.detect(file_path)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")

  local segments = parser.build_segments(text, lang)
  local parts = {}
  for _, seg in ipairs(segments) do
    if seg.type == "doc" then
      parts[#parts + 1] = seg.content
    else
      parts[#parts + 1] = "```" .. lang .. "\n" .. seg.content .. "\n```"
    end
  end
  local content = table.concat(parts, "\n\n")

  if not path then
    local default = file_path:gsub("%.[^%.]+$", "") .. ".md"
    vim.ui.input({ prompt = "Export Markdown to: ", default = default }, function(input)
      if input and input ~= "" then
        M._write_file(input, content)
      end
    end)
  else
    M._write_file(path, content)
  end
end

--- Export current buffer as HTML
---@param path? string output path (prompts if nil)
function M.html(path)
  local bufnr = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local lang = languages.detect(file_path)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local text = table.concat(lines, "\n")
  local fname = vim.fn.fnamemodify(file_path, ":t")

  local segments = parser.build_segments(text, lang)
  local content = html.render(segments, lang, { title = fname })

  if not path then
    local default = file_path:gsub("%.[^%.]+$", "") .. ".html"
    vim.ui.input({ prompt = "Export HTML to: ", default = default }, function(input)
      if input and input ~= "" then
        M._write_file(input, content)
      end
    end)
  else
    M._write_file(path, content)
  end
end

---@param path string
---@param content string
function M._write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then
    vim.notify("codedoc: failed to write " .. path .. ": " .. (err or ""), vim.log.levels.ERROR)
    return
  end
  f:write(content)
  f:close()
  vim.notify("codedoc: exported to " .. path, vim.log.levels.INFO)
end

return M
