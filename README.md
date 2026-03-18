# codedoc.nvim

A Neovim plugin for literate programming — view and export source code with embedded documentation side-by-side. Inspired by the VSCode [explicode](https://marketplace.visualstudio.com/items?itemName=nicolo.explicode) extension.

## Features

- **Live preview** — HTTP server with auto-refresh in your browser
- **26+ languages** — Python docstrings, C-style block comments, Markdown
- **Export** — self-contained HTML or Markdown
- **Math** — KaTeX for LaTeX equations
- **Syntax highlighting** — highlight.js per language
- **Themes** — dark and light (GitHub-inspired)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "riccardo/codedoc.nvim",
  cmd = { "CodedocPreview", "CodedocToggle", "CodedocExportHtml", "CodedocExportMarkdown" },
  opts = {},
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "riccardo/codedoc.nvim",
  config = function()
    require("codedoc").setup()
  end,
}
```

## Configuration

All options are optional with sensible defaults:

```lua
require("codedoc").setup({
  port = 9876,    -- HTTP server port (auto-fallback if busy)
  theme = "dark", -- "dark" or "light"
})
```

## Usage

| Command | Description |
|---|---|
| `:CodedocPreview` | Open live preview in browser |
| `:CodedocClose` | Stop preview server |
| `:CodedocToggle` | Toggle preview on/off |
| `:CodedocExportHtml [path]` | Export as self-contained HTML |
| `:CodedocExportMarkdown [path]` | Export as Markdown |

### Quick start

1. Open a source file in a supported language
2. Run `:CodedocPreview` — your browser opens with a live preview
3. Edit your code and docs — the preview auto-refreshes
4. Export with `:CodedocExportHtml` or `:CodedocExportMarkdown`

### How it works

codedoc parses your source files into alternating **documentation** and **code** segments:

- **Python** — triple-quoted docstrings (`"""` / `'''`) become documentation
- **C-style languages** — block comments (`/* */`) become documentation
- **Markdown** — treated as pure documentation

These segments are rendered side-by-side with syntax highlighting, Markdown formatting, and math support.

## Supported Languages

| Category | Languages |
|---|---|
| Python | `py` |
| C-style | `js`, `ts`, `jsx`, `tsx`, `java`, `cpp`, `c`, `h`, `cu`, `cs`, `rs`, `go`, `swift`, `kt`, `dart`, `php`, `scala`, `sql` |
| Markdown | `md`, `mdx` |

## Requirements

- Neovim ≥ 0.9
- A web browser

No external Lua dependencies — uses only Neovim's built-in `vim.uv` (libuv) for the HTTP server.

## License

MIT
