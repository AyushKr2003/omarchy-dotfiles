local indicator = {}

function indicator.new(args)
  return function(ass, center_x, center_y, requested_size)
    local elapsed = mp.get_time()
    local rotation = (elapsed * 3) % (2 * math.pi) -- Rotate over time
    local size = requested_size or args.dp(48)
    local half = size / 2

    center_x = center_x or args.viewport().w / 2
    center_y = center_y or args.viewport().h / 2

    local cos_r = math.cos(rotation)
    local sin_r = math.sin(rotation)

    -- Mathematically rotate the square's corners around (0,0) to guarantee
    -- that the rotation pivot is exactly the center of the square.
    local function rot(px, py)
      return px * cos_r - py * sin_r, px * sin_r + py * cos_r
    end

    local x1, y1 = rot(-half, -half)
    local x2, y2 = rot(half, -half)
    local x3, y3 = rot(half, half)
    local x4, y4 = rot(-half, half)

    -- Draw a simple clean spinning square outline to represent buffering
    ass:new_event()
    ass:pos(center_x, center_y)
    ass:an(5) -- center alignment
    ass:append(string.format("{\\1c&H000000&\\1a&HFF&\\bord2.5\\3c&H%s&\\3a&H%s&\\shad0}",
      args.color(), args.alpha(0.95)))
    ass:draw_start()
    ass:move_to(x1, y1)
    ass:line_to(x2, y2)
    ass:line_to(x3, y3)
    ass:line_to(x4, y4)
    ass:line_to(x1, y1)
    ass:draw_stop()
  end
end

return indicator
