#!/bin/bash
# oddzen-tune.sh
# Applies oddzen runtime performance tuning at boot (Liquorix-postinst style).
# Safe to re-run; skips any setting that is not present on the system.
set -euo pipefail

# --- VM / memory: disable watermark boosting ---
sysctl -q vm.watermark_boost_factor=0 2>/dev/null || true

# --- CPU frequency governor tuning (Liquorix ondemand values) ---
# Applies only to CPU policies currently running the ondemand governor.
#  - sampling_down_factor=5: sample less often while loaded, less scheduler churn
#  - up_threshold=55: ramp CPU frequency sooner for responsiveness
for d in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$d" ] || continue
    [ -f "$d/scaling_governor" ] || continue
    [ "$(cat "$d/scaling_governor")" = "ondemand" ] || continue
    [ -d "$d/ondemand" ] || continue
    echo 5  > "$d/ondemand/sampling_down_factor" 2>/dev/null || true
    echo 55 > "$d/ondemand/up_threshold"         2>/dev/null || true
done

# --- I/O scheduler: prefer Kyber on NVMe (multi-queue) devices ---
# Kyber keeps queue depth low for low latency under mixed load.
# To revert a device to mq-deadline: echo mq-deadline > /sys/block/<dev>/queue/scheduler
for dev in /sys/block/nvme*; do
    [ -e "$dev/queue/scheduler" ] || continue
    echo kyber > "$dev/queue/scheduler" 2>/dev/null || true
done

echo "oddzen runtime tuning applied."
