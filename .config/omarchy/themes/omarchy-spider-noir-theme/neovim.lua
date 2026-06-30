return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#090909",
        dark_bg    = "#070707",
        darker_bg  = "#050505",
        lighter_bg = "#222222",

        fg         = "#d7d7d7",
        dark_fg    = "#a1a1a1",
        light_fg   = "#dddddd",
        bright_fg  = "#e1e1e1",
        muted      = "#62605a",

        red        = "#969696",
        yellow     = "#f2f2f2",
        orange     = "#a6a6a6",
        green      = "#c3c3c3",
        cyan       = "#dadada",
        blue       = "#808080",
        purple     = "#acacac",
        brown      = "#646464",

        bright_red    = "#a8a8a8",
        bright_yellow = "#f5f5f5",
        bright_green  = "#d6d6d6",
        bright_cyan   = "#eeeeee",
        bright_blue   = "#929292",
        bright_purple = "#bfbfbf",

        accent               = "#808080",
        cursor               = "#d7d7d7",
        foreground           = "#d7d7d7",
        background           = "#090909",
        selection             = "#222222",
        selection_foreground = "#d7d7d7",
        selection_background = "#222222",
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "aether",
    },
  },
}
