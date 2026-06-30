return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#080810",
        dark_bg    = "#06060c",
        darker_bg  = "#040408",
        lighter_bg = "#212128",

        fg         = "#F4F1C4",
        dark_fg    = "#b7b593",
        light_fg   = "#f6f3cd",
        bright_fg  = "#f7f5d3",
        muted      = "#5f5f66",

        red        = "#c6826e",
        yellow     = "#ffdc97",
        orange     = "#cf9584",
        green      = "#f4b474",
        cyan       = "#ffcf64",
        blue       = "#b26677",
        purple     = "#ee8c8a",
        brown      = "#7c594f",

        bright_red    = "#e79279",
        bright_yellow = "#ffd57d",
        bright_green  = "#ffc66f",
        bright_cyan   = "#ffe356",
        bright_blue   = "#d2748a",
        bright_purple = "#ff9897",

        accent               = "#b26677",
        cursor               = "#F4F1C4",
        foreground           = "#F4F1C4",
        background           = "#080810",
        selection             = "#212128",
        selection_foreground = "#F4F1C4",
        selection_background = "#212128",
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
