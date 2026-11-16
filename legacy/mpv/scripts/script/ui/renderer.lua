local renderer = {}

function renderer.new(args)
  local runtime, opts = args.runtime, args.opts
  local function load_omarchy_colors()
    local colors = {
      accent = "#898fa9",
      background = "#2b2e3b",
      dark_background = "#20232c",
      darker_background = "#16171e",
      lighter_background = "#3a3e50",
      selection = "#3a3e50",
      muted = "#64687a",
      foreground = "#cbccd8"
    }
    local home = os.getenv("HOME")
    if not home then return colors end
    local path = home .. "/.local/state/omarchy/current/theme/colors.toml"
    local f = io.open(path, "r")
    if not f then return colors end
    for line in f:lines() do
      local key, val = line:match("^([%a_]+)%s*=%s*[\"'](#[%da-fA-F]+)[\"']")
      if key and val then
        colors[key] = val
      end
    end
    f:close()
    return colors
  end

  local colors = load_omarchy_colors()

  local function map_color(hex)
    if not hex then return "#FFFFFF" end
    local clean = hex:upper()
    if clean == "#050708" or clean == "#1A1B26" or clean == "#16171E" or clean == "#E8E8E8" then
      return colors.dark_background
    elseif clean == "#00BBFF" or clean == "#FF9800" or clean == "#0078D7" then
      return colors.accent
    elseif clean == "#CAC4D0" or clean == "#202020" then
      return colors.foreground
    elseif clean == "#FFFFFF" then
      return colors.foreground
    end
    return hex
  end

  local service = {
    default_text_font = "JetBrainsMono Nerd Font",
    icon_text_size = 30,
    normal_text_size = 24
  }

  function service:clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
  end

  function service:dpi_scale()
    if opts.dpi_scale ~= "auto" then
      return self:clamp(tonumber(opts.dpi_scale) or 1, 0.5, 4)
    end
    return self:clamp(runtime.viewport.dpi or 1, 0.5, 4)
  end

  function service:dp(value) return value * self:dpi_scale() end

  function service:scale_font(value)
    return math.max(1, math.floor(self:dp(value) + 0.5))
  end

  function service:ass_color(hex)
    local mapped = map_color(hex)
    local r, g, b = mapped:match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return "FFFFFF" end
    return b .. g .. r
  end

  function service:fade_alpha(alpha)
    local base = tonumber(alpha or "00", 16) or 0
    local opacity = self:clamp(runtime.controller.opacity.value, 0, 1)
    return string.format("%02X", math.floor(255 - (255 - base) * opacity + 0.5))
  end

  function service:alpha(opacity)
    return string.format("%02X",
      math.floor(255 - 255 * self:clamp(opacity, 0, 1) + 0.5))
  end

  function service:draw_box(ass, x1, y1, x2, y2, radius, color, alpha)
    if x2 <= x1 or y2 <= y1 then return end
    ass:new_event(); ass:pos(x1, y1); ass:an(7)
    ass:append(string.format("{\\1c&H%s&\\1a&H%s&\\bord0\\shad0}",
      self:ass_color(color), self:fade_alpha(alpha)))
    ass:draw_start()
    ass:round_rect_cw(0, 0, x2 - x1, y2 - y1, 0)
    ass:draw_stop()
  end

  function service:draw_round_box(ass, x1, y1, x2, y2,
      top_radius, bottom_radius, color, alpha)
    self:draw_box(ass, x1, y1, x2, y2, 0, color, alpha)
  end

  function service:draw_rect(ass, x1, y1, x2, y2, color, alpha)
    self:draw_box(ass, x1, y1, x2, y2, 0, color, alpha)
  end

  function service:draw_text(ass, x, y, value, size, color, alpha, font, alignment,
      bold, ignore_controller_fade)
    ass:new_event(); ass:pos(x, y); ass:an(alignment or 5)
    local rendered_alpha = ignore_controller_fade and (alpha or "00") or
      self:fade_alpha(alpha)
    ass:append(string.format("{\\bord0\\shad0\\fs%d\\fn%s%s\\1c&H%s&\\1a&H%s&}",
      self:scale_font(size or 22), font or self.default_text_font,
      bold and "\\b1" or "", self:ass_color(color or "#FFFFFF"),
      rendered_alpha))
    ass:append(mp.command_native({"escape-ass", value or ""}))
  end

  function service:draw_shadowed_text(ass, x, y, value, size, color, alpha, font, alignment)
    local text_size = self:scale_font(size or 22)
    local text_font = font or self.default_text_font
    local escaped_value = mp.command_native({"escape-ass", value or ""})
    ass:new_event()
    ass:pos(x + self:dp(1.2), y + self:dp(1.5))
    ass:an(alignment or 5)
    ass:append(string.format(
      "{\\bord1.4\\blur4\\shad0\\fs%d\\fn%s\\1c&H000000&\\3c&H000000&\\1a&H%s&\\3a&H%s&}",
      text_size, text_font, self:fade_alpha("58"), self:fade_alpha("58")))
    ass:append(escaped_value)
    self:draw_text(ass, x, y, value, size, color, alpha, font, alignment)
  end

  function service:draw_icon(ass, x, y, icon, color, size, alpha,
      ignore_controller_fade)
    self:draw_text(ass, x, y, icon, size or self.icon_text_size, color, alpha,
      "Material Symbols Rounded", nil, nil, ignore_controller_fade)
  end

  return service
end

return renderer
