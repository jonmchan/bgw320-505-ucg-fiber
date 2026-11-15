#!/bin/sh
# Repair the GPON EAP bypass after a UniFi OS upgrade, then start it.
#
# /etc/wpa_supplicant survives upgrades that delete /usr/local and custom
# udev rules. restore.sh refreshes the persist/ mirror from a checkout.
# This script is what runs on the gateway at boot, with no internet.
set -eu

PERSIST=/etc/wpa_supplicant/persist

restore_file() {
  src=$1
  dest=$2
  if [ -f "$src" ] && [ ! -e "$dest" ]; then
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
  fi
}

chmod_if() {
  if [ -e "$2" ]; then
    chmod "$1" "$2"
  fi
}

# A removed or foreign binary can still be executable and then fail to load.
# wpa_supplicant -v exits 0 only when the installed binary actually runs.
if ! /sbin/wpa_supplicant -v >/dev/null 2>&1; then
  if [ ! -r /etc/os-release ]; then
    echo "wpa_supplicant is missing and /etc/os-release is unreadable" >&2
    exit 1
  fi
  # shellcheck disable=SC1091
  . /etc/os-release
  dir=/etc/wpa_supplicant/packages
  case "${VERSION_CODENAME:-}" in
    bullseye)
      # Debian 11 / OpenSSL 1.1. These need libssl1.1 and do not configure on trixie.
      set -- "$dir"/libpcsclite1_1.*.deb "$dir"/wpasupplicant_2.9*.deb
      ;;
    trixie)
      # Debian 13 / OpenSSL 3. libssl3t64 and libreadline8t64 are already on the image.
      set -- "$dir"/libpcsclite1_2.*.deb "$dir"/wpasupplicant_2.10*.deb
      ;;
    *)
      echo "wpa_supplicant is missing and Debian ${VERSION_CODENAME:-unknown} has no cached debs" >&2
      exit 1
      ;;
  esac
  for deb in "$@"; do
    if [ ! -f "$deb" ]; then
      echo "missing cached package for ${VERSION_CODENAME}: $deb" >&2
      exit 1
    fi
  done
  # Do not dpkg -Ri the whole directory. That installs every cached release,
  # and the bullseye wpasupplicant cannot be configured on Debian 13.
  DEBIAN_FRONTEND=noninteractive dpkg --force-confdef --force-confold -i "$@"
fi

# OpenSSL 3 rejects the SHA1 AT&T CA unless the security level is lowered.
# wpa_supplicant 2.10 reads this global option. Leave it off on OpenSSL 1.1.
if openssl version 2>/dev/null | grep -q '^OpenSSL 3'; then
  conf=/etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf
  if [ -f "$conf" ] && ! grep -q '^openssl_ciphers=' "$conf"; then
    sed -i 's/^network={/openssl_ciphers=DEFAULT@SECLEVEL=0\nnetwork={/' "$conf"
  fi
fi

restore_file "$PERSIST/att-eap-wan-prep.sh" /etc/wpa_supplicant/att-eap-wan-prep.sh
restore_file "$PERSIST/sfp-admin-route.sh" /etc/wpa_supplicant/sfp-admin-route.sh
restore_file "$PERSIST/reinstall-wpa.sh" /etc/wpa_supplicant/reinstall-wpa.sh
restore_file "$PERSIST/ont-mac" /etc/wpa_supplicant/ont-mac
restore_file "$PERSIST/usr/local/sbin/att-eap-wan-prep.sh" /usr/local/sbin/att-eap-wan-prep.sh
restore_file "$PERSIST/usr/local/sbin/sfp-admin-route.sh" /usr/local/sbin/sfp-admin-route.sh
restore_file "$PERSIST/etc/udev/rules.d/99-att-wan-mac.rules" /etc/udev/rules.d/99-att-wan-mac.rules
restore_file "$PERSIST/etc/udev/rules.d/99-sfp-admin-route.rules" /etc/udev/rules.d/99-sfp-admin-route.rules
restore_file "$PERSIST/etc/systemd/system/eth6.0-vlan.service" /etc/systemd/system/eth6.0-vlan.service
restore_file "$PERSIST/etc/systemd/system/reinstall-wpa.service" /etc/systemd/system/reinstall-wpa.service
restore_file "$PERSIST/etc/systemd/system/sfp-admin-route.service" /etc/systemd/system/sfp-admin-route.service
restore_file "$PERSIST/etc/systemd/system/sfp-admin-route.timer" /etc/systemd/system/sfp-admin-route.timer
restore_file "$PERSIST/etc/systemd/system/wpa_supplicant-wired@.service.d/restart-on-failure.conf" \
  /etc/systemd/system/wpa_supplicant-wired@.service.d/restart-on-failure.conf
restore_file "$PERSIST/etc/network/if-up.d/changemac" /etc/network/if-up.d/changemac

if [ -f /etc/wpa_supplicant/att-eap-wan-prep.sh ] && [ ! -e /usr/local/sbin/att-eap-wan-prep.sh ]; then
  mkdir -p /usr/local/sbin
  cp -a /etc/wpa_supplicant/att-eap-wan-prep.sh /usr/local/sbin/att-eap-wan-prep.sh
fi
if [ -f /etc/wpa_supplicant/sfp-admin-route.sh ] && [ ! -e /usr/local/sbin/sfp-admin-route.sh ]; then
  mkdir -p /usr/local/sbin
  cp -a /etc/wpa_supplicant/sfp-admin-route.sh /usr/local/sbin/sfp-admin-route.sh
fi

chmod_if 755 /etc/wpa_supplicant/att-eap-wan-prep.sh
chmod_if 755 /etc/wpa_supplicant/sfp-admin-route.sh
chmod_if 755 /etc/wpa_supplicant/reinstall-wpa.sh
chmod_if 755 /usr/local/sbin/att-eap-wan-prep.sh
chmod_if 755 /usr/local/sbin/sfp-admin-route.sh
chmod_if 755 /etc/network/if-up.d/changemac
chmod_if 600 /etc/wpa_supplicant/ont-mac
chmod_if 600 /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf

# The package postinst enables the dbus supplicant. EAP uses the wired instance.
if systemctl is-enabled wpa_supplicant.service >/dev/null 2>&1; then
  systemctl disable --now wpa_supplicant.service >/dev/null 2>&1 || true
fi

systemctl daemon-reload
systemctl reset-failed eth6.0-vlan.service wpa_supplicant-wired@eth6.0.service >/dev/null 2>&1 || true
systemctl enable eth6.0-vlan.service >/dev/null 2>&1 || true
systemctl start eth6.0-vlan.service
systemctl enable wpa_supplicant-wired@eth6.0
systemctl start wpa_supplicant-wired@eth6.0

if [ -f /etc/systemd/system/sfp-admin-route.timer ]; then
  systemctl reset-failed sfp-admin-route.service >/dev/null 2>&1 || true
  systemctl enable sfp-admin-route.timer >/dev/null 2>&1 || true
  systemctl start sfp-admin-route.timer >/dev/null 2>&1 || true
  systemctl start sfp-admin-route.service >/dev/null 2>&1 || true
fi
if [ -f /etc/udev/rules.d/99-att-wan-mac.rules ]; then
  udevadm control --reload-rules >/dev/null 2>&1 || true
fi
