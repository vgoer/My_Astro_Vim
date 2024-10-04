-- WARNING:https://github.com/AstroNvim/AstroNvim/issues/2593
---@type LazySpec
return {
  { "NvChad/nvim-colorizer.lua", enabled = false },
  {
    "brenoprata10/nvim-highlight-colors",
    event = "User AstroFile",
    cmd = "HighlightColors",
    dependencies = {
      {
        "AstroNvim/astrocore",
        opts = function(_, opts)
          local maps = opts.mappings
          maps.n["<Leader>uz"] = { function() vim.cmd.HighlightColors "Toggle" end, desc = "Toggle color highlight" }
        end,
      },
    },
    opts = {
      enabled_named_colors = false,
      render = "virtual",
      virtual_symbol_position = "inline",
      enable_tailwind = true,
    },
  },
}
