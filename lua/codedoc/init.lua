local M = {}

---@class CodedocConfig
---@field port number HTTP server port for live preview
---@field theme "dark"|"light" Default theme
M.config = {
  port = 9876,
  theme = "dark",
}

--- Setup codedoc with user config
---@param opts? CodedocConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Commands
  vim.api.nvim_create_user_command("CodedocPreview", function()
    require("codedoc.preview").open()
  end, { desc = "Open codedoc live preview in browser" })

  vim.api.nvim_create_user_command("CodedocClose", function()
    require("codedoc.preview").close()
  end, { desc = "Stop codedoc preview server" })

  vim.api.nvim_create_user_command("CodedocToggle", function()
    require("codedoc.preview").toggle()
  end, { desc = "Toggle codedoc preview" })

  vim.api.nvim_create_user_command("CodedocExportHtml", function(args)
    require("codedoc.export").html(args.args ~= "" and args.args or nil)
  end, { nargs = "?", complete = "file", desc = "Export as HTML" })

  vim.api.nvim_create_user_command("CodedocExportMarkdown", function(args)
    require("codedoc.export").markdown(args.args ~= "" and args.args or nil)
  end, { nargs = "?", complete = "file", desc = "Export as Markdown" })

  -- Clean up on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      local preview = require("codedoc.preview")
      if preview.is_running() then
        preview.close()
      end
    end,
  })
end

return M
