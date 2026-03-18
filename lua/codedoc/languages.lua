local M = {}

-- Extension to language mapping
local ext_map = {
  md = "markdown", mdx = "markdown",
  py = "python",
  js = "javascript", ts = "typescript",
  jsx = "javascriptreact", tsx = "typescriptreact",
  java = "java",
  cpp = "cpp", cc = "cpp", cxx = "cpp", hpp = "cpp", hxx = "cpp",
  c = "c", h = "c",
  cu = "cuda", cuh = "cuda",
  cs = "csharp",
  rs = "rust",
  go = "go",
  swift = "swift",
  kt = "kotlin", kts = "kotlin",
  dart = "dart",
  php = "php",
  scala = "scala", sbt = "scala",
  sql = "sql",
}

-- Languages using /* */ block comments
M.c_style = {
  c = true, cpp = true, cuda = true, csharp = true, java = true,
  javascript = true, typescript = true, javascriptreact = true, typescriptreact = true,
  go = true, rust = true, php = true, swift = true, kotlin = true,
  scala = true, dart = true, ["objective-c"] = true, sql = true,
}

-- All supported languages
M.supported = vim.tbl_extend("force", { python = true, markdown = true }, M.c_style)

-- Language to highlight.js name
M.hljs_name = {
  javascriptreact = "javascript",
  typescriptreact = "typescript",
  cuda = "c",
  csharp = "csharp",
  ["objective-c"] = "objectivec",
}

--- Detect language from file path
---@param path string
---@return string
function M.detect(path)
  local ext = path:match("%.([^%.]+)$")
  if ext then ext = ext:lower() end
  return ext_map[ext or ""] or "plaintext"
end

--- Get highlight.js language name
---@param lang string
---@return string
function M.to_hljs(lang)
  return M.hljs_name[lang] or lang
end

return M
