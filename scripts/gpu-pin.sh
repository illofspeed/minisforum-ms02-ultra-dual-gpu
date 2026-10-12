#!/bin/bash
# gpu-pin.sh - give each Proxmox LXC container its own NVIDIA card when a host has two (or more) GPUs.
# The /dev/nvidiaN minor follows PCI enumeration, so it is read from the driver instead of assumed; moving or swapping
# cards then cannot hand a container the wrong GPU. Only the container's dev0 entry (/dev/nvidiaN) is changed;
# nvidiactl and nvidia-uvm stay shared. Dry run unless --apply; restart the container afterwards.
#
# usage: gpu-pin.sh [--apply] <CTID>="<model substring>" [<CTID>="<model substring>" ...]
#   e.g. gpu-pin.sh --apply 101="RTX PRO 4000" 102="RTX PRO 2000"
# If Docker inside a container still sees the other card, set NVIDIA_VISIBLE_DEVICES to the UUID printed below.
set -euo pipefail
APPLY=0; [ "${1:-}" = --apply ] && { APPLY=1; shift; }
[ $# -ge 1 ] || { sed -n 2,10p "$0"; exit 2; }
declare -A WANT MINOR UUID
for a in "$@"; do WANT[${a%%=*}]=${a#*=}; done
for f in /proc/driver/nvidia/gpus/*/information; do
    model=$(awk -F':[ \t]*' '/^Model/ {print $2}' "$f")
    minor=$(awk -F':[ \t]*' '/^Device Minor/ {print $2}' "$f")
    uuid=$(awk -F':[ \t]*' '/^GPU UUID/ {print $2}' "$f")
    echo "GPU minor $minor: $model $uuid (${f%/information})"
    for ct in "${!WANT[@]}"; do
        case $model in *"${WANT[$ct]}"*) MINOR[$ct]=$minor; UUID[$ct]=$uuid;; esac
    done
done
for ct in "${!WANT[@]}"; do
    [ -n "${MINOR[$ct]:-}" ] || { echo "CT $ct: no GPU matching '${WANT[$ct]}' - skipped"; continue; }
    conf=$(ls /etc/pve/nodes/*/lxc/$ct.conf 2>/dev/null | head -1)
    [ -n "$conf" ] || { echo "CT $ct: no config found"; continue; }
    cur=$(awk '/^dev0:/ {print $2}' "$conf" | head -1)
    want=/dev/nvidia${MINOR[$ct]}
    echo "CT $ct: dev0 ${cur:-<none>} -> $want  (${WANT[$ct]}, ${UUID[$ct]})"
    if [ "$cur" != "$want" ] && [ $APPLY = 1 ]; then
        node=$(echo "$conf" | cut -d/ -f5)
        [ "$node" = "$(hostname)" ] || { echo "  CT $ct lives on $node, not on this host - skipped"; continue; }
        pct set "$ct" --dev0 "$want"
    fi
done
[ $APPLY = 1 ] || echo "(dry run - add --apply)"
