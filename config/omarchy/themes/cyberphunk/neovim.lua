return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#15191F",
        dark_bg    = "#101317",
        darker_bg  = "#0b0d10",
        lighter_bg = "#2c3035",

        fg         = "#cdd6f4",
        dark_fg    = "#9aa1b7",
        light_fg   = "#d5dcf6",
        bright_fg  = "#dae0f7",
        muted      = "#61656B",

        red        = "#F865A5",
        yellow     = "#FFC457",
        orange     = "#f97cb3",
        green      = "#29EDBE",
        cyan       = "#2BE3FC",
        blue       = "#33AEFF",
        purple     = "#AF54FF",
        brown      = "#954a6b",

        bright_red    = "#FF598B",
        bright_yellow = "#FFB630",
        bright_green  = "#1FE0A6",
        bright_cyan   = "#2BCAFC",
        bright_blue   = "#33AEFF",
        bright_purple = "#B467F9",

        accent               = "#89b4fa",
        cursor               = "#cdd6f4",
        foreground           = "#cdd6f4",
        background           = "#15191F",
        selection             = "#2c3035",
        selection_foreground = "#cdd6f4",
        selection_background = "#2c3035",
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
