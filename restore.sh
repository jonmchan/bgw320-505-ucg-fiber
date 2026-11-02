#!/bin/sh
# Push this tree to a UCG Fiber and start EAP.
# The internet is not required. A machine on the gateway LAN is enough.
#
#   ./restore.sh root@<gateway>
#
# Certificates, the ONT MAC, and the filled-in supplicant config are not in
# git. Put them under ./local/ before the first install. Later upgrades can
# use the copies already on the gateway. See README.md.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ $# -ne 1 ]; then
  echo "usage: $0 root@gateway" >&2
  exit 2
fi
TARGET=$1
LOCAL=$ROOT/local

if [ ! -f "$ROOT/gateway/etc/wpa_supplicant/reinstall-wpa.sh" ]; then
  echo "missing $ROOT/gateway/etc/wpa_supplicant/reinstall-wpa.sh" >&2
  exit 1
fi

echo "restoring $ROOT onto $TARGET"
ssh -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" true

# macOS tags these files with provenance xattrs, which the gateway tar warns about.
if command -v xattr >/dev/null 2>&1; then
  if [ -d "$LOCAL" ]; then
    xattr -cr "$ROOT/gateway" "$LOCAL" 2>/dev/null || true
  else
    xattr -cr "$ROOT/gateway" 2>/dev/null || true
  fi
fi

# Apple tar adds resource-fork files unless this is set.
COPYFILE_DISABLE=1
export COPYFILE_DISABLE

tar -C "$ROOT/gateway" -cf - . \
  | ssh "$TARGET" 'tar --no-same-owner -C / -xf -'

if [ -d "$LOCAL/certs" ] && ls "$LOCAL/certs/"*.pem >/dev/null 2>&1; then
  tar -C "$LOCAL/certs" -cf - . \
    | ssh "$TARGET" 'mkdir -p /etc/wpa_supplicant/certs && tar --no-same-owner -C /etc/wpa_supplicant/certs -xf - && chmod 600 /etc/wpa_supplicant/certs/*.pem'
else
  echo "no pems in $LOCAL/certs; leaving certificates already on the gateway" >&2
fi

if [ -f "$LOCAL/ont-mac" ]; then
  ssh "$TARGET" 'cat > /etc/wpa_supplicant/ont-mac && chmod 600 /etc/wpa_supplicant/ont-mac' < "$LOCAL/ont-mac"
fi

if [ -f "$LOCAL/wpa_supplicant-wired-eth6.0.conf" ]; then
  ssh "$TARGET" 'cat > /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf && chmod 600 /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf' < "$LOCAL/wpa_supplicant-wired-eth6.0.conf"
fi

if [ -d "$LOCAL/packages" ] && ls "$LOCAL/packages/"*.deb >/dev/null 2>&1; then
  tar -C "$LOCAL/packages" -cf - . \
    | ssh "$TARGET" 'mkdir -p /etc/wpa_supplicant/packages && tar --no-same-owner -C /etc/wpa_supplicant/packages -xf -'
else
  echo "no debs in $LOCAL/packages; using the cache already on the gateway" >&2
fi

ssh "$TARGET" 'sh -s' <<'EOF'
set -eu

if [ ! -f /etc/wpa_supplicant/ont-mac ]; then
  echo "missing /etc/wpa_supplicant/ont-mac" >&2
  exit 1
fi
if [ ! -f /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf ]; then
  echo "missing /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf" >&2
  exit 1
fi
if ! ls /etc/wpa_supplicant/certs/*.pem >/dev/null 2>&1; then
  echo "missing certificates in /etc/wpa_supplicant/certs" >&2
  exit 1
fi

mkdir -p /usr/local/sbin
cp -a /etc/wpa_supplicant/att-eap-wan-prep.sh /usr/local/sbin/att-eap-wan-prep.sh
cp -a /etc/wpa_supplicant/sfp-admin-route.sh /usr/local/sbin/sfp-admin-route.sh
chmod 755 /etc/wpa_supplicant/att-eap-wan-prep.sh \
  /etc/wpa_supplicant/sfp-admin-route.sh \
  /etc/wpa_supplicant/reinstall-wpa.sh \
  /usr/local/sbin/att-eap-wan-prep.sh \
  /usr/local/sbin/sfp-admin-route.sh \
  /etc/network/if-up.d/changemac
chmod 600 /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf \
  /etc/wpa_supplicant/ont-mac \
  /etc/wpa_supplicant/certs/*.pem

p=/etc/wpa_supplicant/persist
rm -rf "$p"
mkdir -p "$p/usr/local/sbin" \
  "$p/etc/udev/rules.d" \
  "$p/etc/systemd/system/wpa_supplicant-wired@.service.d" \
  "$p/etc/network/if-up.d"
cp -a /usr/local/sbin/att-eap-wan-prep.sh \
      /usr/local/sbin/sfp-admin-route.sh \
      "$p/usr/local/sbin/"
cp -a /etc/wpa_supplicant/att-eap-wan-prep.sh "$p/att-eap-wan-prep.sh"
cp -a /etc/wpa_supplicant/sfp-admin-route.sh "$p/sfp-admin-route.sh"
cp -a /etc/wpa_supplicant/reinstall-wpa.sh "$p/reinstall-wpa.sh"
cp -a /etc/wpa_supplicant/ont-mac "$p/ont-mac"
cp -a /etc/udev/rules.d/99-att-wan-mac.rules \
      /etc/udev/rules.d/99-sfp-admin-route.rules \
      "$p/etc/udev/rules.d/"
cp -a /etc/systemd/system/eth6.0-vlan.service \
      /etc/systemd/system/reinstall-wpa.service \
      /etc/systemd/system/sfp-admin-route.service \
      /etc/systemd/system/sfp-admin-route.timer \
      "$p/etc/systemd/system/"
mkdir -p "$p/etc/systemd/system/wpa_supplicant-wired@.service.d"
cp -a /etc/systemd/system/wpa_supplicant-wired@.service.d/restart-on-failure.conf \
      "$p/etc/systemd/system/wpa_supplicant-wired@.service.d/"
cp -a /etc/network/if-up.d/changemac "$p/etc/network/if-up.d/"
chmod 755 "$p/att-eap-wan-prep.sh" "$p/sfp-admin-route.sh" "$p/reinstall-wpa.sh" \
  "$p/usr/local/sbin/"*
chmod 600 "$p/ont-mac"

systemctl daemon-reload
systemctl enable eth6.0-vlan.service
systemctl enable reinstall-wpa.service
systemctl enable sfp-admin-route.timer
systemctl enable wpa_supplicant-wired@eth6.0
systemctl start sfp-admin-route.timer
/etc/wpa_supplicant/reinstall-wpa.sh
EOF

echo "waiting for EAP and a DHCPv4 lease on the customer VLAN"
ssh "$TARGET" 'sh -s' <<'EOF'
set -eu
i=0
while [ "$i" -lt 30 ]; do
  state=$(wpa_cli -i eth6.0 status 2>/dev/null | awk -F= '/^wpa_state=/{print $2}' || true)
  port=$(wpa_cli -i eth6.0 status 2>/dev/null | awk -F= '/^suppPortStatus=/{print $2}' || true)
  addr=$(ip -4 -br addr show | awk '$1 ~ /^eth6\./ && $1 != "eth6.0" {print $1 "=" $3}' || true)
  echo "wpa_state=${state:-none} suppPortStatus=${port:-none} ${addr:-no-dhcp}"
  if [ "$state" = COMPLETED ] && [ "$port" = Authorized ] && [ -n "${addr:-}" ]; then
    echo "WAN is up"
    ip route show table all | awk '/^default/'
    exit 0
  fi
  i=$((i + 1))
  sleep 3
done
echo "WAN did not come up" >&2
wpa_cli -i eth6.0 status || true
ip -br link show | awk '/eth6/ {print}' || true
ip -br addr show | awk '/eth6/ {print}' || true
systemctl --failed --no-pager || true
journalctl -u eth6.0-vlan.service -u wpa_supplicant-wired@eth6.0 -u reinstall-wpa.service --no-pager -n 40 || true
exit 1
EOF
