#!/bin/sh
# Clone the BGW320-505 ONT MAC onto UCG Fiber WAN2 and ensure the VLAN 0
# interface used by wpa_supplicant exists. Safe to run repeatedly.
#
# eth6.0-vlan.service runs this copy. UniFi OS upgrades have deleted
# /usr/local and custom udev rules while leaving /etc/wpa_supplicant in place.
set -eu

IFACE=eth6
VLAN_IFACE=eth6.0
MAC_FILE=/etc/wpa_supplicant/ont-mac

bring_up() {
  iface=$1
  n=0
  while [ "$n" -lt 15 ]; do
    if ip link set dev "$iface" up; then
      return 0
    fi
    n=$((n + 1))
    sleep 1
  done
  echo "could not bring ${iface} up" >&2
  return 1
}

if [ ! -f "$MAC_FILE" ]; then
  echo "missing $MAC_FILE (one line, the Internet/ONT MAC)" >&2
  exit 1
fi

MAC=$(tr 'A-F' 'a-f' < "$MAC_FILE" | tr -d '[:space:]')
case $MAC in
  [0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f])
    ;;
  *)
    echo "$MAC_FILE is not a MAC address" >&2
    exit 1
    ;;
esac

if [ ! -d "/sys/class/net/${IFACE}" ]; then
  echo "${IFACE} is not present" >&2
  exit 1
fi

current=$(cat "/sys/class/net/${IFACE}/address")
if [ "$current" != "$MAC" ]; then
  if ! ip link set dev "$IFACE" address "$MAC"; then
    ip link set dev "$IFACE" down || true
    ip link set dev "$IFACE" address "$MAC"
    bring_up "$IFACE"
  fi
fi

if [ ! -d "/sys/class/net/${VLAN_IFACE}" ]; then
  ip link add link "$IFACE" name "$VLAN_IFACE" type vlan id 0
fi
bring_up "$VLAN_IFACE"
