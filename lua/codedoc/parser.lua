local languages = require("codedoc.languages")

local M = {}

---@class Segment
---@field type "doc"|"code"
---@field content string
---@field start_line number 0-indexed

--- Count newlines before position
---@param src string
---@param pos number 1-indexed byte position
---@return number
local function line_at(src, pos)
  local count = 0
  for i = 1, pos - 1 do
    if src:sub(i, i) == "\n" then count = count + 1 end
  end
  return count
end

--- Merge adjacent same-type segments
---@param raw Segment[]
---@return Segment[]
local function merge_segments(raw)
  local result = {}
  for _, seg in ipairs(raw) do
    local content = vim.trim(seg.content)
    if content ~= "" then
      local last = result[#result]
      if last and last.type == seg.type then
        last.content = last.content .. "\n\n" .. content
      else
        result[#result + 1] = { type = seg.type, content = content, start_line = seg.start_line }
      end
    end
  end
  return result
end

--- Parse Python docstrings (""" """ and ''' ''')
---@param src string
---@return Segment[]
local function parse_python(src)
  local raw = {}
  local i = 1
  local n = #src
  local code_start = 1

  local function is_doc_context(pos)
    local j = pos - 1
    while j >= 1 and src:sub(j, j) ~= "\n" do
      local ch = src:sub(j, j)
      if ch ~= " " and ch ~= "\t" then return false end
      j = j - 1
    end
    return true
  end

  local function flush_code(end_pos)
    local chunk = vim.trim(src:sub(code_start, end_pos - 1))
    if chunk ~= "" then
      raw[#raw + 1] = { type = "code", content = chunk, start_line = line_at(src, code_start) }
    end
  end

  while i <= n do
    local ch = src:sub(i, i)

    -- Skip single-line strings
    if (ch == '"' or ch == "'") and src:sub(i, i + 2) ~= '"""' and src:sub(i, i + 2) ~= "'''" then
      i = i + 1
      while i <= n and src:sub(i, i) ~= ch and src:sub(i, i) ~= "\n" do
        if src:sub(i, i) == "\\" then i = i + 1 end
        i = i + 1
      end
      i = i + 1
      goto continue
    end

    -- Triple-quote
    local q3 = src:sub(i, i + 2)
    if q3 == '"""' or q3 == "'''" then
      local is_doc = is_doc_context(i)
      if is_doc then
        flush_code(i)
        local doc_start_line = line_at(src, i)
        i = i + 3
        local close_idx = src:find(q3, i, true)
        local inner
        if close_idx then
          inner = vim.trim(src:sub(i, close_idx - 1))
          i = close_idx + 3
        else
          inner = vim.trim(src:sub(i))
          i = n + 1
        end
        if inner ~= "" then
          raw[#raw + 1] = { type = "doc", content = inner, start_line = doc_start_line }
        end
        code_start = i
      else
        -- String value, skip
        i = i + 3
        local close_idx = src:find(q3, i, true)
        i = close_idx and (close_idx + 3) or (n + 1)
      end
      goto continue
    end

    -- Single-line comment
    if ch == "#" then
      while i <= n and src:sub(i, i) ~= "\n" do i = i + 1 end
      goto continue
    end

    i = i + 1
    ::continue::
  end

  flush_code(n + 1)
  return merge_segments(raw)
end

--- Strip JSDoc-style leading asterisks
---@param text string
---@return string
local function strip_jsdoc_stars(text)
  local lines = vim.split(text, "\n")
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("^%s*%*%s?", "")
  end
  return vim.trim(table.concat(lines, "\n"))
end

--- Parse C-style block comments (/* */ and /** */)
---@param src string
---@return Segment[]
local function parse_c_style(src)
  local raw = {}
  local cursor = 1

  for match_start, match_text in src:gmatch("()(/[*].-[*]/)") do
    ---@cast match_start integer
    if match_start > cursor then
      local chunk = vim.trim(src:sub(cursor, match_start - 1))
      if chunk ~= "" then
        raw[#raw + 1] = { type = "code", content = chunk, start_line = line_at(src, cursor) }
      end
    end
    -- Strip comment delimiters and leading stars
    local inner = match_text:gsub("^/%*+", ""):gsub("%*+/$", "")
    inner = strip_jsdoc_stars(inner)
    if inner ~= "" then
      raw[#raw + 1] = { type = "doc", content = inner, start_line = line_at(src, match_start) }
    end
    cursor = match_start + #match_text
  end

  local tail = vim.trim(src:sub(cursor))
  if tail ~= "" then
    raw[#raw + 1] = { type = "code", content = tail, start_line = line_at(src, cursor) }
  end

  return merge_segments(raw)
end

--- Build segments from file text and language
---@param file_text string
---@param language string
---@return Segment[]
function M.build_segments(file_text, language)
  if language == "markdown" then
    return { { type = "doc", content = file_text, start_line = 0 } }
  end
  if language == "python" then
    return parse_python(file_text)
  end
  if languages.c_style[language] then
    return parse_c_style(file_text)
  end
  return {}
end

return M
