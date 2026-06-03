#!/usr/bin/env bash

ICON="$($HOME/.config/waybar/weather-icon)"
TEMP="$($HOME/.config/waybar/weather-status \
  | sed -En 's/.*Temp ([0-9]+°C).*/\1/p')"

printf '%s %s\n' "$ICON" "$TEMP"
