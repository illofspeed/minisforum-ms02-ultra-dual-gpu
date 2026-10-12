#!/bin/sh
# aer-quiet-tbport.sh - MS-02 Ultra: the Thunderbolt/USB4 root port 0000:80:1b.4 floods the kernel log with AER
# messages (ACSViol / UnsupReq / HeaderOF; ~20,000 lines after boot on BIOS 1.04). This masks those error types on
# that one port only; the GPUs and every other port keep normal AER reporting. It silences the noise, it does not fix
# the firmware. Check the port address on your unit first: lspci -s 80:1b.4
P=${1:-0000:80:1b.4}
[ -e /sys/bus/pci/devices/$P ] || exit 0
u=$(setpci -s $P ECAP_AER+0x08.l); setpci -s $P ECAP_AER+0x08.l=$(printf %08x $(( 0x$u | 0x00300000 )))
setpci -s $P ECAP_AER+0x14.l=0000ffff
logger -t aer-quiet "masked AER on $P (uncor mask $(setpci -s $P ECAP_AER+0x08.l), cor mask $(setpci -s $P ECAP_AER+0x14.l))"
