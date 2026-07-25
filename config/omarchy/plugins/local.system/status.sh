#!/usr/bin/env bash
set -uo pipefail

disk_path="${1:-/}"

# Host & Uptime Info
uptime_sec="$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)"
uptime_hrs=$((uptime_sec / 3600))
uptime_mins=$(((uptime_sec % 3600) / 60))
if [ "$uptime_hrs" -gt 0 ]; then
  uptime_str="${uptime_hrs}h ${uptime_mins}m"
else
  uptime_str="${uptime_mins}m"
fi
kernel_str="$(uname -r 2>/dev/null || echo 'Linux')"
host_name="$(hostname 2>/dev/null || echo 'localhost')"
printf "host\t%s\t%s\t%s\n" "$host_name" "$kernel_str" "$uptime_str"

# CPU Info & Cores
awk '
  NR == 1 {
    idle = $5
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    cores = 0
    while ((getline line < "/proc/cpuinfo") > 0) {
      if (line ~ /^processor[[:space:]]*:/) cores++
    }
    close("/proc/cpuinfo")
    if (cores < 1) cores = 1
    printf "cpu\t%s\t%s\t%s\n", idle, total, cores
  }
' /proc/stat

# Per-core raw ticks for QML delta calculation or single-sample core load
awk '
  /^cpu[0-9]+/ {
    idle = $5 + $6
    total = 0
    for (i = 2; i <= NF; i++) total += $i
    printf "cpucore\t%s\t%s\t%s\n", $1, idle, total
  }
' /proc/stat

# Memory & Swap Info (MemTotal, MemAvailable, MemFree, Cached+Buffers)
awk '
  /^MemTotal:/ { mem_total = $2 }
  /^MemAvailable:/ { mem_avail = $2 }
  /^MemFree:/ { mem_free = $2 }
  /^Buffers:/ { buffers = $2 }
  /^Cached:/ { cached = $2 }
  /^SReclaimable:/ { srec = $2 }
  /^SwapTotal:/ { swap_total = $2 }
  /^SwapFree:/ { swap_free = $2 }
  END {
    if (mem_total > 0) {
      mem_used = mem_total - mem_avail
      mem_pct = (mem_used / mem_total) * 100
      swap_used = swap_total - swap_free
      swap_pct = swap_total > 0 ? (swap_used / swap_total) * 100 : 0
      buf_cache = (cached + srec + buffers) / 1024 / 1024
      printf "memory\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\n", mem_pct, mem_used / 1024 / 1024, mem_total / 1024 / 1024, mem_avail / 1024 / 1024, mem_free / 1024 / 1024, buf_cache, swap_pct, swap_used / 1024 / 1024, swap_total / 1024 / 1024
    }
  }
' /proc/meminfo

# Load Average
awk '{ printf "load\t%s\t%s\t%s\n", $1, $2, $3 }' /proc/loadavg

# Disk Info
df -P -B1 "$disk_path" 2>/dev/null | awk 'NR == 2 {
  used = $3
  total = $2
  pct = total > 0 ? (used / total) * 100 : 0
  printf "disk\t%.2f\t%.2f\t%.2f\t%s\n", pct, used / 1024 / 1024 / 1024, total / 1024 / 1024 / 1024, $6
}'

# Network Info (Total RX / TX bytes)
awk 'NR > 2 { rx += $2; tx += $10 } END { printf "net\t%s\t%s\n", rx, tx }' /proc/net/dev 2>/dev/null || echo "net	0	0"

# Temperature Info (CPU Package / Highest Thermal Zone + GPU)
cpu_temp="$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -n 1 || echo 0)"
cpu_temp_c=$((cpu_temp / 1000))

gpu_temp=0
gpu_name="GPU"
gpu_busy=-1
gpu_used_mb=0
gpu_total_mb=0

if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_line="$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -n 1 || true)"
  if [[ "${gpu_line:-}" =~ ^[[:space:]]*[0-9]+([.][0-9]+)?[[:space:]]*, ]]; then
    gpu_busy="$(echo "$gpu_line" | awk -F ', ' '{print $1}')"
    gpu_used_mb="$(echo "$gpu_line" | awk -F ', ' '{print $2}')"
    gpu_total_mb="$(echo "$gpu_line" | awk -F ', ' '{print $3}')"
    gpu_temp="$(echo "$gpu_line" | awk -F ', ' '{print $4}')"
    gpu_name="$(echo "$gpu_line" | awk -F ', ' '{print $5}')"
  fi
fi

printf "temp\t%s\t%s\n" "$cpu_temp_c" "$gpu_temp"
printf "gpu\t%s\t%s\t%s\t%s\t%s\n" "$gpu_busy" "$gpu_used_mb" "$gpu_total_mb" "$gpu_temp" "$gpu_name"
