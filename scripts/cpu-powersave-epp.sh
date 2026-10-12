#!/bin/sh
# cpu-powersave-epp.sh - intel_pstate (active, HWP): governor powersave + EPP balance_performance.
# The CPU still boosts to full turbo on demand; it only lowers clocks and voltage when idle or lightly loaded.
# Proxmox defaults to the performance governor; revert by writing "performance" to scaling_governor.
for c in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
    echo powersave > "$c/scaling_governor"
    echo balance_performance > "$c/energy_performance_preference"
done
