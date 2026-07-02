#!/usr/bin/env bash
set -euo pipefail

disk_path="${1:-/}"

awk '
  NR == 1 {
    idle = $5
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "cpu\t%s\t%s\n", idle, total
  }
' /proc/stat

awk '
  /^MemTotal:/ { total = $2 }
  /^MemAvailable:/ { avail = $2 }
  END {
    if (total > 0) {
      used = total - avail
      printf "memory\t%.2f\t%.2f\t%.2f\n", ((used / total) * 100), used / 1024 / 1024, total / 1024 / 1024
    }
  }
' /proc/meminfo

awk '{ printf "load\t%s\t%s\t%s\n", $1, $2, $3 }' /proc/loadavg

df -P -B1 "$disk_path" 2>/dev/null | awk 'NR == 2 {
  used = $3
  total = $2
  pct = total > 0 ? (used / total) * 100 : 0
  printf "disk\t%.2f\t%.2f\t%.2f\t%s\n", pct, used / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024, $6
}'

if command -v nvidia-smi >/dev/null 2>&1 &&
  gpu_line=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -n 1) &&
  [ -n "${gpu_line:-}" ]; then
  awk -F ', ' '{ printf "gpu\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5 }' <<<"$gpu_line"
elif [ -r /sys/class/drm/card0/device/gpu_busy_percent ]; then
  busy=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || true)
  name=$(cat /sys/class/drm/card0/device/uevent 2>/dev/null | awk -F= '/DRIVER/ { print $2; exit }')
  printf "gpu\t%s\t\t\t\t%s\n" "${busy:-0}" "${name:-GPU}"
else
  printf "gpu\t\t\t\t\tUnavailable\n"
fi
