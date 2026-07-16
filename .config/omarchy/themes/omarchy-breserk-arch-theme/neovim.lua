return {
  {
    "bjarneo/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = {
      colors = {
        bg         = "#141520",
        dark_bg    = "#0f1018",
        darker_bg  = "#0a0b10",
        lighter_bg = "#2c2c36",

        fg         = "#c9cbe8",
        dark_fg    = "#9798ae",
        light_fg   = "#d1d3eb",
        bright_fg  = "#d7d8ee",
        muted      = "#626369",

        red        = "#a5a6d0",
        yellow     = "#c0c4ec",
        orange     = "#b3b3d7",
        green      = "#b7bae1",
        cyan       = "#babde5",
        blue       = "#a7aad5",
        purple     = "#b0afda",
        brown      = "#6b6b81",

        bright_red    = "#c8c7fc",
        bright_yellow = "#caccff",
        bright_green  = "#c1c2ff",
        bright_cyan   = "#c4c5ff",
        bright_blue   = "#c7c9ff",
        bright_purple = "#cdcaff",

        accent               = "#a7aad5",
        cursor               = "#c9cbe8",
        foreground           = "#c9cbe8",
        background           = "#141520",
        selection             = "#2c2c36",
        selection_foreground = "#c9cbe8",
        selection_background = "#2c2c36",
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
