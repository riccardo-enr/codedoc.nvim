local languages = require("codedoc.languages")

local M = {}

--- Escape HTML special characters
---@param s string
---@return string
local function escape(s)
  return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

--- Generate self-contained HTML page from segments
---@param segments table[]
---@param lang string
---@param opts? { theme?: "dark"|"light", title?: string }
---@return string
function M.render(segments, lang, opts)
  opts = opts or {}
  local theme = opts.theme or "dark"
  local title = opts.title or "codedoc"
  local hljs_lang = languages.to_hljs(lang)
  local is_dark = theme == "dark"

  local parts = {}
  for _, seg in ipairs(segments) do
    if seg.type == "doc" then
      parts[#parts + 1] = ('<div class="seg-doc" data-start-line="%d"><div class="markdown-body">%s</div></div>'):format(
        seg.start_line,
        escape(seg.content)
      )
    else
      parts[#parts + 1] = ('<div class="seg-code" data-start-line="%d"><pre><code class="language-%s">%s</code></pre></div>'):format(
        seg.start_line,
        hljs_lang,
        escape(seg.content)
      )
    end
  end

  local body = table.concat(parts, "\n")

  return ([[<!DOCTYPE html>
<html data-theme="]] .. theme .. [[">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>]] .. escape(title) .. [[</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/]] .. (is_dark and "github-dark" or "github") .. [[.min.css">
<style>
  :root {
    --bg: ]] .. (is_dark and "#0d1117" or "#ffffff") .. [[;
    --fg: ]] .. (is_dark and "#e6edf3" or "#1f2328") .. [[;
    --border: ]] .. (is_dark and "#30363d" or "#d0d7de") .. [[;
    --code-bg: ]] .. (is_dark and "#161b22" or "#f6f8fa") .. [[;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px 32px;
    background: var(--bg); color: var(--fg);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    font-size: 16px; line-height: 1.6;
  }
  .container { max-width: 900px; margin: 0 auto; }
  .seg-code { margin: 16px 0; }
  .seg-code pre {
    padding: 16px; border-radius: 6px;
    border: 1px solid var(--border);
    background: var(--code-bg);
    overflow-x: auto; font-size: 13.5px; line-height: 1.5;
  }
  .seg-doc { margin: 16px 0; }
  .markdown-body h1 { font-size: 2em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
  .markdown-body h2 { font-size: 1.5em; border-bottom: 1px solid var(--border); padding-bottom: .3em; }
  .markdown-body h3 { font-size: 1.25em; }
  .markdown-body code {
    padding: 0.2em 0.4em; border-radius: 3px;
    background: var(--code-bg); font-size: 85%;
  }
  .markdown-body pre code { padding: 0; background: none; font-size: inherit; }
  .markdown-body blockquote {
    margin: 0; padding: 0 1em;
    border-left: 4px solid var(--border); color: ]] .. (is_dark and "#8b949e" or "#656d76") .. [[;
  }
  .markdown-body table { border-collapse: collapse; width: 100%; margin: 16px 0; }
  .markdown-body th, .markdown-body td {
    padding: 6px 13px; border: 1px solid var(--border);
  }
  .markdown-body th { font-weight: 600; background: var(--code-bg); }
  .markdown-body img { max-width: 100%; height: auto; display: block; margin: 16px auto; }
  .markdown-body a { color: ]] .. (is_dark and "#58a6ff" or "#0969da") .. [[; }
  .markdown-body ul, .markdown-body ol { padding-left: 2em; }
  .markdown-body hr { border: none; border-top: 1px solid var(--border); margin: 24px 0; }
</style>
</head>
<body>
<div class="container" id="content">
]] .. body .. [[
</div>

<script src="https://cdn.jsdelivr.net/npm/marked@12.0.0/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/marked-gfm-heading-id@4.1.1/lib/index.umd.js"></script>
<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"></script>
<script>
(function() {
  // Parse markdown in doc segments
  document.querySelectorAll('.seg-doc .markdown-body').forEach(function(el) {
    el.innerHTML = marked.parse(el.textContent || '');
  });
  // Highlight code blocks
  document.querySelectorAll('pre code').forEach(function(el) {
    hljs.highlightElement(el);
  });
  // Render math
  renderMathInElement(document.body, {
    delimiters: [
      {left: '$$', right: '$$', display: true},
      {left: '$', right: '$', display: false},
      {left: '\\(', right: '\\)', display: false},
      {left: '\\[', right: '\\]', display: true},
    ],
    throwOnError: false,
  });
})();
</script>
</body>
</html>]])
end

--- Generate HTML with auto-refresh via polling
---@param segments table[]
---@param lang string
---@param opts? { theme?: "dark"|"light", title?: string, poll_url?: string }
---@return string
function M.render_live(segments, lang, opts)
  opts = opts or {}
  local html = M.render(segments, lang, opts)
  if not opts.poll_url then return html end

  -- Inject polling script before </body>
  local poll_script = ([[
<script>
(function() {
  var lastHash = '';
  setInterval(function() {
    fetch('%s').then(function(r) { return r.text(); }).then(function(h) {
      if (lastHash && h !== lastHash) location.reload();
      lastHash = h;
    }).catch(function(){});
  }, 500);
})();
</script>
]]):format(opts.poll_url)

  return html:gsub("</body>", poll_script .. "</body>")
end

return M
