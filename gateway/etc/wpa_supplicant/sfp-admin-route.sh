#!/bin/sh
# Reach the DFP-34X-2C2 admin page at 192.168.1.1.
# UniFi's SFPDevice route binds 192.168.1.1/32 to the customer VLAN interface
# (eth6.<vid>). The stick answers on the SFP port itself (eth6).
# Safe to run repeatedly.
set -eu

IFACE=eth6
ADDR=192.168.1.2/24
SRC=192.168.1.2
STICK=192.168.1.1

if [ ! -d "/sys/class/net/${IFACE}" ]; then
  exit 0
fi

ip addr replace "${ADDR}" dev "${IFACE}"
ip route replace "${STICK}/32" dev "${IFACE}" src "${SRC}"

if ! iptables -t nat -C POSTROUTING -o "${IFACE}" -d "${STICK}/32" -j SNAT --to-source "${SRC}" 2>/dev/null; then
  iptables -t nat -A POSTROUTING -o "${IFACE}" -d "${STICK}/32" -j SNAT --to-source "${SRC}"
fi
