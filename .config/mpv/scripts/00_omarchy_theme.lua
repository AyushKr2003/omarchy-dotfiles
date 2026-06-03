local msg = require "mp.msg"
local utils = require "mp.utils"

local home = os.getenv("HOME") or ""
local theme_file = os.getenv("OMARCHY_MPV_THEME_COLORS") or (home .. "/.config/omarchy/current/theme/colors.toml")
local osc_file = mp.command_native({ "expand-path", "~~/script-opts/niri_caelestia.conf" })
local last_mtime = nil

local fallback = {
  accent = "#7aa2f7",
  cursor = "#c0caf5",
  foreground = "#a9b1d6",
  background = "#1a1b26",
  selection_foreground = "#c0caf5",
  selection_background = "#32344a",
  color0 = "#32344a",
  color1 = "#f7768e",
  color2 = "#9ece6a",
  color8 = "#444b6a",
}

local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local text = file:read("*a")
  file:close()
  return text
end

local function write_if_changed(path, text)
  if read_file(path) == text then return end

  local file = io.open(path, "w")
  if not file then
    msg.warn("Could not write Omarchy mpv OSC theme: " .. path)
    return
  end

  file:write(text)
  file:close()
end

local function read_theme()
  local colors = {}
  for key, value in pairs(fallback) do
    colors[key] = value
  end

  local text = read_file(theme_file)
  if not text then
    msg.warn("Could not read Omarchy theme colors: " .. theme_file)
    return colors
  end

  for key, value in text:gmatch('([%w_]+)%s*=%s*"(#[%x]+)"') do
    colors[key] = value
  end

  return colors
end

local function osc_options(colors)
  return string.format([[
# Generated from ~/.config/omarchy/current/theme/colors.toml by 00_omarchy_theme.lua.

# Base
language=en
icon_theme=material
font=Inter
live_reload=yes
live_reload_interval=1

# Behavior
window_top_bar=yes
window_title=no
hidetimeout=1600
fadeduration=180
fadein=yes
bottomhover=yes
bottomhover_zone=96
osc_on_seek=yes
osc_keep_with_cursor=yes

# Scaling
vidscale=no
scalewindowed=0.92
scalefullscreen=1.0

# Layout
show_title=yes
title=${media-title}
title_font_size=22
show_chapter_title=yes
chapter_fmt=- %%s
timetotal=yes
time_format=dynamic
title_height=112
chapter_title_height=88

# Controls
jump_buttons=yes
jump_amount=10
chapter_skip_buttons=no
track_nextprev_buttons=yes
volume_control=yes
volume_control_type=linear
playlist_button=no
hide_empty_playlist_button=yes
speed_button=yes
speed_button_scroll=0.25
loop_button=yes
fullscreen_button=yes
info_button=no
ontop_button=no
screenshot_button=yes
download_button=no

# Omarchy palette
osc_color=%s
window_fade_alpha=0
fade_alpha=92
fade_blur_strength=0
fade_transparency_strength=50

# Progress
seek_handle_size=0.8
nibbles_style=bar
persistentprogress=no
seekbarfg_color=%s
seekbarbg_color=%s
seekbar_cache_color=%s
volumebar_match_seek_color=yes

# Text
title_color=%s
chapter_title_color=%s
time_color=%s
tooltip_text_color=%s
tooltip_font_size=14

# Menu
menu_bg_color=%s
menu_fg_color=%s
menu_alpha=24
menu_border_radius=8
menu_padding=14 18
menu_sel_color=%s
menu_sel_bg_color=%s
menu_sel_fg_color=%s
menu_sel_bg_alpha=34
menu_sel_bg_radius=4
menu_sel_padding=4 8

# Thumbnail
thumbnail_border=2
thumbnail_border_radius=4
thumbnail_border_color=%s
thumbnail_border_outline=%s

# Buttons
windowcontrols_close_hover=%s
windowcontrols_max_hover=%s
windowcontrols_min_hover=%s

playpause_color=%s
middle_buttons_color=%s
side_buttons_color=%s
held_element_color=%s

hover_effect=size,color
hover_button_size=112
hover_effect_color=%s

# User button 1 - playlist
usr_btn_1_icon= 󰷐
usr_btn_1_tooltip=playlist
usr_btn_1_mbtn_left_command=script-message-to niri_caelestia menu-toggle playlist; script-message-to niri_caelestia osc-hide
usr_btn_1_mbtn_right_command=
usr_btn_1_mbtn_mid_command=

# User button 2 - subtitles
usr_btn_2_icon= 
usr_btn_2_tooltip=subtitles
usr_btn_2_mbtn_left_command=script-message-to niri_caelestia menu-toggle sub; script-message-to niri_caelestia osc-hide
usr_btn_2_mbtn_right_command=cycle sub
usr_btn_2_mbtn_mid_command=cycle sub down
]],
    colors.background,
    colors.accent, colors.color0, colors.color8,
    colors.cursor, colors.foreground, colors.color8, colors.foreground,
    colors.background, colors.foreground,
    colors.accent, colors.color0, colors.selection_foreground,
    colors.color0, colors.background,
    colors.color1, colors.accent, colors.color2,
    colors.accent, colors.foreground, colors.color8, colors.color8,
    colors.accent
  )
end

local function apply_theme()
  local colors = read_theme()

  mp.set_property("osd-color", colors.foreground)
  mp.set_property("osd-border-color", colors.background)
  mp.set_property("osd-shadow-color", colors.background)
  mp.set_property("sub-color", colors.cursor)
  mp.set_property("sub-border-color", colors.background)
  mp.set_property("sub-shadow-color", colors.background)

  -- Keep video letterboxing pure black even while the controls follow Omarchy.
  mp.set_property("background-color", "#000000")

  write_if_changed(osc_file, osc_options(colors))
end

local function poll_theme()
  local info = utils.file_info(theme_file)
  local mtime = info and info.mtime or nil
  if mtime ~= last_mtime then
    last_mtime = mtime
    apply_theme()
  end
end

poll_theme()
mp.add_periodic_timer(1, poll_theme)
