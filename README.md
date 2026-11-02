# BGW320-505 GPON bypass on UniFi Cloud Gateway Fiber

Replace an Arris **BGW320-505** on **AT&T GPON** with a UniFi Cloud Gateway Fiber and a Luleey **LL-XS2510** XPON SFP stick (the ODI DFP-34X-2C2). AT&T still requires 802.1X EAP-TLS. The gateway runs `wpa_supplicant` with certificates extracted from that BGW320-505.

This is a GPON install (1310 nm, the SFP that lives in the BGW320). It is the path used when the fiber goes into a stick in the gateway, the stick reaches ONU state O5, and `omcicli mib get 171` shows that the OLT still requires EAP.

```text
AT&T GPON → LL-XS2510, SC APC (UCG Fiber SFP+ port 7, eth6) → EAP-TLS on eth6.0 → DHCP on eth6.<vid>
```

Two VLANs are in play, and they are different jobs:

- **EAP** is priority-tagged VLAN 0. Create `eth6.0` and run `wpa_supplicant` there.
- **Customer traffic** uses the VID the OLT programmed onto the stick. Read it with `omcicli mib get 84` and set that VID on the UniFi WAN. A published BGW320-500 example used VID 722. Yours will differ. Read the stick.

Checked on UniFi OS 5.1.33 and, after an upgrade, 5.1.34. Both were Debian 11, OpenSSL 1.1.1, aarch64, with `wpasupplicant` 2.9. A later UniFi OS that moves the gateway to Debian 13 / OpenSSL 3 needs the matching packages and one extra config line, below.

Doing this can take the circuit offline, and it can conflict with AT&T's terms. The certificates authenticate as your ONT. They are not in this repository.

## What you need

- Arris BGW320-505 (Nokia). The Humax model is the BGW320-500. The flash identity and the firmware-downgrade images are different.
- The SFP stick from [Luleey’s 2.5G XPON SFP ONU listing](https://www.luleey.com/product/2-5g-xpon-stick-sfp-onu/). This install ordered one module with **Hardware Version: Generic** and **Connector Type: SC APC**. The page lists that module as model **LL-XS2510**, chipset Realtek RTL9601D. That is the ODI stick this guide and the DFP-34X-2C2 firmware image call a DFP-34X-2C2. Generic and Enhanced DDM are the same GPON stick; Enhanced DDM adds a DDM chip for optical readings in RouterOS, which this UCG Fiber path does not use. The connector is the green angled SC APC plug. Order SC UPC only if your fiber jumper is blue and flat.
- UniFi Cloud Gateway Fiber. The SFP+ WAN is physical port 7, interface `eth6`. Confirm with `ip -br link` after the stick is inserted.
- The BGW's ONT serial, hardware version, software version, and WAN MAC, copied down **before** you pull the fiber.
- A machine that can SSH to the gateway as `root` while the LAN is up. Enable SSH under Control Plane → Console, or Settings → System → Advanced → Device Authentication. A user key often fails; `root` with the device password works.

The BGW and the stick must not be on the fiber at the same time. The stick presents the BGW's ONU identity.

If your UniFi LAN is already `192.168.1.0/24`, change it before using the stick's admin address. The stick is `192.168.1.1`.

## References

These are the documents this install followed, plus the pages those documents send you to.

| | |
| --- | --- |
| [evie-lau/Unifi-gateway-wpa-supplicant](https://github.com/evie-lau/Unifi-gateway-wpa-supplicant/blob/main/README.md) | Install `wpasupplicant`, cert layout, MAC clone, the wired systemd instance, the restart drop-in, and caching the `.deb` files so an upgrade can reinstall them with no internet. Written for `eth1` on a UXG Lite. On this gateway every `eth1` becomes `eth6`, and EAP runs on `eth6.0`. |
| [drifterxe: BGW320-500 on UCG Fiber](https://github.com/drifterxe/Bypassing-AT-T-s-BGW320-500-Gateway-with-Unifi-Cloud-Gateway-UCG-Fiber-Using-wpa_supplicant) | Same gateway and the same stick family. Port 7 is `eth6`. EAP is a VLAN 0 subinterface. Customer VID comes from `omcicli mib get 84`. EAP required or not comes from `omcicli mib get 171`. The flash block in that guide is for a **Humax BGW320-500**. |
| [0x888e/certs](https://github.com/0x888e/certs) | Pull `calibration_01.bin` and the CA `.der` files off the BGW. Use the **BGW320-505 (Nokia)** downgrade section. |
| [mfg_dat_decode (devicelocksmith)](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html) | Turns `calibration_01.bin` into the three PEM files and a `wpa_supplicant.conf`. This install used that tool, version 1.06. Open rewrite: [abrender/mfgdat](https://github.com/abrender/mfgdat). |
| [PON Madness — AT&T GPON ONT cloning](https://docs.google.com/document/d/1gcT0sJKLmV816LK0lROCoywk9lXbPQ7l_4jhzGIgoTo/edit) | 8311 community notes for getting a stick to O5 on AT&T GPON, including the ODI firmware image. The drifterxe guide follows this for the 320-500. |
| [pon.wiki: masquerade as a BGW320-500/505](https://pon.wiki/guides/masquerade-as-the-att-inc-bgw320-500-505-with-the-was-110/) | Identity table for a 505 (NOKA serial, equipment id, hardware version). Written for a WAS-110, so the commands differ from `flash set` on a DFP-34X-2C2. The identity strings are what the OLT expects. |
| [Anime4000/RTL960x](https://github.com/Anime4000/RTL960x) and the [ODI image](https://github.com/rajkosto/RTL960x/blob/main/Firmware/DFP-34X-2C2/M110_sfp_ODI_220923FS.tar) | Stick firmware (`M110_sfp_ODI_220923FS.tar`) and `flash set` field notes. `OMCI_OLT_MODE 21` is what lets a custom software version survive reboot on this stick. |
| [Luleey LL-XS2510](https://www.luleey.com/product/2-5g-xpon-stick-sfp-onu/) | The stick this install used: 2.5G XPON SFP ONU Stick for FTTH, one module, Hardware Version Generic, Connector Type SC APC. |
| [Debian wpasupplicant](https://packages.debian.org/bullseye/arm64/wpasupplicant) / [libpcsclite1](https://packages.debian.org/bullseye/arm64/libpcsclite1) | Packages cached on the gateway. Trixie equivalents are linked in the install step. |

Evie's guide also points at the older [USG writeup](https://wells.ee/journal/2020-03-01-bypassing-att-fiber-modem-unifi-usg/), the [Arch Wiki `wpa_supplicant` page](https://wiki.archlinux.org/title/Wpa_supplicant), [this MAC-clone note](https://www.xmodulo.com/spoof-mac-address-network-interface-linux.html), [DigitalOcean's systemd unit guide](https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files), and [this UniFi OS 3.2 thread](https://www.reddit.com/r/Ubiquiti/comments/18rc0ag/att_modem_bypass_and_unifios_32x_guide/).

The 8311 Discord is where the PON Madness notes and the drifterxe guide came from. There is no single durable invite link; the Google Doc and the two GitHub guides above are the stable citations.

## 1. Write down the BGW320-505 identity

Do this while the BGW still has the fiber and a LAN port you can open.

1. Browse to `http://192.168.1.254/`.
2. Open the fiber status page: `http://192.168.1.254/cgi-bin/fiberstat.ha`.
3. Photograph the bottom label and the System Information page.

Keep these. They are per gateway. Do not publish them.

| Field | Where it goes |
| --- | --- |
| ONT ID / serial | `GPON_SN` on the stick. A 505 label serial starts with `NOKA`. |
| Hardware version | `HW_HWVER`. The 505 community value is `BGW320-505_2.2`. |
| Software version | `OMCI_SW_VER1` and `OMCI_SW_VER2`. Copy the string from your fiber status page. Published examples (`BGW320_4.27.7`, `BGW320_3.21.4`, `BGW320_3.20.5`) are other people's versions. |
| Equipment id | `GPON_ONU_MODEL`. pon.wiki lists `iONT320505X` for a 505. Another stick guide lists `iONT320505G`. Use the equipment id your OLT already accepted. If the stick is already at O5, do not change it. |
| WAN / ONT MAC | `identity=` in `wpa_supplicant`, the UniFi MAC clone, and `/etc/wpa_supplicant/ont-mac`. The extraction tool prints this. It is the MAC on the BGW WAN, not the MAC printed on the UCG. |

The Humax 320-500 block is a different device: vendor `HUMA`, model `iONT320500G`, hardware `BGW320-500_2.1`, serial `HUMA…`. Pasting that onto a 505 will not come up as your ONT.

## 2. Bring the GPON stick to O5

The stick in this install was already at **Operation State (O5)** before EAP was configured. The firmware was left alone after that. Re-flash only when `diag gpon get onu-state` is not O5.

Program the stick from a media converter, or from a spare SFP port, at `http://192.168.1.1/` (host `192.168.1.10/24`). The drifterxe guide flashes `M110_sfp_ODI_220923FS.tar` twice, resets to defaults, and sets VLAN mode to **Manual → Transparent** so the stick does not strip the OLT's VLAN.

Then telnet to `192.168.1.1` and set the 505 identity. This is the drifterxe / PON Madness command list with the 505 fields. Replace the three values that are yours:

```text
flash set OMCC_VER 160
flash set GPON_PLOAM_FORMAT 1
flash set GPON_PLOAM_PASSWD 44454641554c54000000
flash set OMCI_OLT_MODE 21
flash set OMCI_FAKE_OK 1
flash set VLAN_CFG_TYPE 1
flash set VLAN_MANU_MODE 0
flash set PON_VENDOR_ID NOKA
flash set GPON_ONU_MODEL iONT320505X
flash set GPON_SN NOKAxxxxxxxx
flash set HW_HWVER BGW320-505_2.2
flash set OMCI_SW_VER1 BGW320_x.x.x
flash set OMCI_SW_VER2 BGW320_x.x.x
reboot
```

`GPON_PLOAM_PASSWD 44454641554c54000000` is the value published in the BGW320-500 guide (the ASCII PLOAM password `DEFAULT`, hex-encoded, padded). `OMCI_OLT_MODE 21` is what stops this stick's `checkomci` from wiping `OMCI_SW_VER1` on boot. `GPON_ONU_MODEL` may need to be `iONT320505G` instead of `iONT320505X`; that string is not consistent across the WAS-110 table and the older SFP-stick notes. If you already have O5, skip this whole block.

Plug in the fiber with the BGW unplugged from it. Telnet back in:

```text
diag gpon get onu-state
```

O5 means the OLT accepted the stick. Anything else is still an identity or optical problem. Fix that before touching `wpa_supplicant`.

### Is EAP required?

```text
omcicli mib get 171
```

- Five rules, indexes 0–4: the OLT requires EAP. That is the case this guide covers.
- Seven rules, indexes 0–6: EAP is not required. Put the customer VID on the UniFi WAN and stop. You do not need certificates.

### Customer VLAN

```text
omcicli mib get 84
```

Read `VID` on the bridge filter entries. That number is the UniFi WAN VLAN. The 320-500 writeup's sample output shows 722. Use the number on your stick. Leave EAP on VLAN 0 either way.

You can move the stick into UCG Fiber port 7 after O5. You can also leave it in the media converter until the certificates are ready. Do the `apt` work in the next section while the BGW still has the fiber, so the gateway still has internet.

## 3. Extract the certificates

Nothing in this repository is a certificate or a private key. Extract them from your own BGW and keep them on your machine.

Follow [0x888e/certs](https://github.com/0x888e/certs). Summary, so the 505 path is obvious:

1. Take the fiber out of the BGW. The only cables left in it are power and one Ethernet cable from your computer to LAN1.
2. Give that computer a static address `192.168.1.11/24`, gateway `192.168.1.254`. Python 3.12 or newer.
3. Downgrade with the **BGW320-505 (Nokia)** image pair, in the order that README lists. The Humax 320-500 images are the other section. The BGW320 reboots on a short timer during the downgrade; the 0x888e notes say to have the access code ready and to upload in the second window where ping answers. Community mirrors move. Check the file against the hashes published in that README for the 505 pair:

   | Order | SHA1 | MD5 |
   | --- | --- | --- |
   | First | `0fd668617ff0a723379380a9f5d167f2a6015ef8` | `d3d9bc9d76d5331659176ae4cfe744af` |
   | Second | `2e81363a1cc0784c82e3f5305668c88b49e33561` | `63d74cda47de1dde22303f1d99328803` |

4. Run `python download.py` from that repo. For a BGW320 it writes `calibration_01.bin` and about three CA `.der` files.
5. Decode `calibration_01.bin` with [mfg_dat_decode](https://www.devicelocksmith.com/2018/12/eap-tls-credentials-decoder-for-nvg-and.html) or [mfgdat](https://github.com/abrender/mfgdat).

The decoder emits:

- `CA_<id>.pem`
- `Client_<id>.pem`
- `PrivateKey_PKCS1_<id>.pem` (no passphrase)
- `wpa_supplicant.conf` with **relative** paths
- a short readme that tells you the Internet (ONT) MAC to clone

`identity=` in that generated config is the MAC. It must match the MAC on `eth6`. The private key has no passphrase. If `wpa_supplicant` later asks for one, a certificate failed to load.

Put the three PEM files in `local/certs/` in a checkout of this repo. Do not commit them. `.gitignore` ignores `local/` and `*.pem`.

When you are done you can let the BGW take the fiber again and pick up a current image from AT&T. You need the certificates, not the downgraded BGW, for the rest of this guide.

## 4. Fill in the local files

From a checkout:

```bash
mkdir -p local/certs local/packages
# copy the three PEM files into local/certs/
cp examples/ont-mac local/ont-mac
cp examples/wpa_supplicant-wired-eth6.0.conf local/wpa_supplicant-wired-eth6.0.conf
```

Edit `local/ont-mac` so it is one line, the ONT MAC, with colons.

Edit `local/wpa_supplicant-wired-eth6.0.conf`:

- Set the three `*_cert` / `private_key` paths to the real filenames under `/etc/wpa_supplicant/certs/`.
- Set `identity` to the same MAC, uppercase or lowercase. The extraction tool's line is the one to keep.
- Paths must be absolute. Relative names work in the decoder's output directory and fail on the gateway (`fopen: No such file or directory`).

On Debian 11 / OpenSSL 1.1, do not add `openssl_ciphers`. On Debian 13 / OpenSSL 3, either add this **above** `network={` or let `reinstall-wpa.sh` insert it:

```ini
openssl_ciphers=DEFAULT@SECLEVEL=0
```

AT&T's CA is SHA1. OpenSSL 3 rejects it at the default security level (`ca md too weak`). The bogus private-key prompt comes after that failure. Putting `openssl_ciphers` inside `network={}` does nothing useful on wpa_supplicant 2.10.

## 5. Install wpa_supplicant while you still have internet

SSH to the gateway as `root`.

```bash
grep PRETTY_NAME /etc/os-release
openssl version
uname -m
```

Cache **one** Debian release under `/etc/wpa_supplicant/packages`. `dpkg -Ri` installs every `.deb` in that directory. A bullseye `wpasupplicant` cannot run on trixie.

Debian 11 (bullseye), OpenSSL 1.1 — this is what 5.1.33 and 5.1.34 were:

```bash
mkdir -p /etc/wpa_supplicant/packages
cd /etc/wpa_supplicant/packages
wget http://security.debian.org/debian-security/pool/updates/main/w/wpa/wpasupplicant_2.9.0-21+deb11u3_arm64.deb
wget http://ftp.us.debian.org/debian/pool/main/p/pcsc-lite/libpcsclite1_1.9.1-1_arm64.deb
dpkg -i ./*.deb
```

Debian 13 (trixie), OpenSSL 3:

```bash
mkdir -p /etc/wpa_supplicant/packages
cd /etc/wpa_supplicant/packages
wget http://ftp.us.debian.org/debian/pool/main/w/wpa/wpasupplicant_2.10-24_arm64.deb
wget http://ftp.us.debian.org/debian/pool/main/p/pcsc-lite/libpcsclite1_2.3.3-1_arm64.deb
dpkg -i ./*.deb
```

Package indexes move. The download pages are [bullseye wpasupplicant](https://packages.debian.org/bullseye/arm64/wpasupplicant/download), [bullseye libpcsclite1](https://packages.debian.org/bullseye/arm64/libpcsclite1/download), [trixie wpasupplicant](https://packages.debian.org/trixie/arm64/wpasupplicant/download), and [trixie libpcsclite1](https://packages.debian.org/trixie/arm64/libpcsclite1/download).

Confirm the binary has the wired driver:

```bash
wpa_supplicant -h 2>&1 | head -n 40
```

Copy those same `.deb` files into `local/packages/` on the laptop. `restore.sh` uploads them. After an upgrade the gateway cannot `apt-get` them, because the WAN is what those packages authenticate.

`dpkg` enables the stock `wpa_supplicant.service` (the Wi-Fi / dbus instance). EAP uses `wpa_supplicant-wired@eth6.0` instead. `reinstall-wpa.sh` disables the stock unit so the two do not fight.

## 6. UniFi WAN settings

In the UniFi network settings, open the Internet entry bound to port 7. It can stay hidden until the SFP has link. Show pre-configured WAN entries if you do not see it.

- MAC Address Clone: the ONT MAC from `identity=`.
- VLAN ID: the VID from `omcicli mib get 84`.

Evie's guide sets the UniFi WAN VLAN to 0. That step is for an external AT&T ONT handing off Ethernet. With this SFP stick, VLAN 0 exists only as the `eth6.0` interface the supplicant binds to. The customer VID goes on the UniFi WAN.

The dashboard clone is the one that survives a UniFi reprovision. `changemac`, the udev rule, and `att-eap-wan-prep.sh` set the same address from `/etc/wpa_supplicant/ont-mac` when the interface comes up.

## 7. Cut over

1. Pull the fiber from the BGW.
2. Seat the LL-XS2510 in port 7 and connect the fiber. The jumper and the stick are both SC APC.
3. From the laptop checkout, with `local/` filled in:

   ```bash
   ./restore.sh root@<gateway-lan-address>
   ```

   `restore.sh` copies `gateway/` onto the gateway root, uploads `local/certs`, `local/ont-mac`, `local/wpa_supplicant-wired-eth6.0.conf`, and `local/packages` when those exist, refreshes `/etc/wpa_supplicant/persist/`, and runs `reinstall-wpa.sh`.

To do the same steps by hand:

```bash
mkdir -p /etc/wpa_supplicant/certs
# copy the three PEM files to /etc/wpa_supplicant/certs/ and chmod 600
# copy ont-mac to /etc/wpa_supplicant/ont-mac and chmod 600
# copy the filled-in conf to /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf and chmod 600

ip -br link
ip link add link eth6 name eth6.0 type vlan id 0
ip link set dev eth6.0 up
ip link set dev eth6 address <ont-mac>
wpa_supplicant -i eth6.0 -D wired -c /etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf
```

Success is `CTRL-EVENT-EAP-SUCCESS` and then `CTRL-EVENT-CONNECTED`. Ctrl-C stops the foreground test. `-B` is only for a temporary background run.

Then enable the units in `gateway/etc/systemd/system/` (or just run `restore.sh`, which does this):

- `eth6.0-vlan.service` runs `/etc/wpa_supplicant/att-eap-wan-prep.sh` before `wpa_supplicant-wired@eth6.0`.
- The config filename `wpa_supplicant-wired-eth6.0.conf` is what the template unit `wpa_supplicant-wired@.service` looks for.
- `systemctl enable --now wpa_supplicant-wired@eth6.0`
- `restart-on-failure.conf` is the drop-in from Evie's guide (10 tries, 10 seconds apart, inside 3 minutes).
- `reinstall-wpa.service` runs `/etc/wpa_supplicant/reinstall-wpa.sh` at boot.

`wpa_cli -i eth6.0 status` should show `wpa_state=COMPLETED`, `EAP state=SUCCESS`, and `suppPortStatus=Authorized`. DHCP then appears on `eth6.<vid>`, where `<vid>` is the customer VLAN. IPv6 router advertisements show up on that same interface after EAP succeeds.

`restore.sh` waits for that DHCP address and prints the default route. A reboot with these units enabled reconnects on its own.

## 8. Reach the stick afterward

UniFi installs a host route for `192.168.1.1/32` on the WAN VLAN interface (`eth6.<vid>`). The stick answers on `eth6`, so that route never arrives.

`sfp-admin-route.sh` puts `192.168.1.2/24` on `eth6`, replaces the host route out `eth6`, and source-NATs LAN clients to `192.168.1.2`. The stick only answers that subnet. `sfp-admin-route.timer` runs it every minute because UniFi puts the route back on the VLAN interface. A udev rule runs it when `eth6` appears.

From a LAN client, `http://192.168.1.1/` is the stick. This collides with a LAN that already uses `192.168.1.0/24`.

## 9. After a UniFi OS upgrade

This is the part that actually restores connectivity.

UniFi OS 5.1.34 deleted `/usr/local/sbin` and the custom udev rules. It left `/etc/wpa_supplicant` (certificates, config, cached debs, and this script) and the systemd units. `eth6.0-vlan.service` failed because `att-eap-wan-prep.sh` had lived under `/usr/local/sbin`, so `eth6.0` was never created. `wpa_supplicant-wired@eth6.0` then failed its device dependency. The WAN VLAN interface had no lease. The LAN stayed up.

Evie's `reinstall-wpa.service` only installs the cached debs when `/sbin/wpa_supplicant` is missing, and it starts `wpa_supplicant-wired@eth1`. On this upgrade the binary was still there (or got reinstalled) and the missing piece was `eth6.0`. Installing the package also enables the stock dbus `wpa_supplicant.service`.

`/etc/wpa_supplicant/reinstall-wpa.sh` runs at every boot from `reinstall-wpa.service`:

1. If `/sbin/wpa_supplicant` is gone, `dpkg -Ri /etc/wpa_supplicant/packages`.
2. On OpenSSL 3, insert the global `openssl_ciphers` line when the wired config does not have it.
3. Copy anything missing back from `/etc/wpa_supplicant/persist/`.
4. Copy the prep and stick-admin scripts out to `/usr/local/sbin` when that directory was wiped.
5. Disable the stock `wpa_supplicant.service`.
6. Start `eth6.0-vlan.service`, then `wpa_supplicant-wired@eth6.0`.

The service unit points at `/etc/wpa_supplicant/att-eap-wan-prep.sh` on purpose. That directory is the one 5.1.34 left in place. A later upgrade that only deletes `/usr/local` can create `eth6.0` and start EAP without a laptop.

If an upgrade removes `/etc/wpa_supplicant` as well, the boot script is gone with it. From a machine on the LAN:

```bash
./restore.sh root@<gateway-lan-address>
```

The internet is not required for that. The script uses the checkout and SSH. Certificates can come from `local/certs` or from files still on the gateway.

Keep the cached debs in one Debian release. After an upgrade, re-check `openssl version`. If it moved from OpenSSL 1.1 to OpenSSL 3, delete the bullseye debs from `/etc/wpa_supplicant/packages`, download the trixie pair, and run `reinstall-wpa.sh` again.

## Layout

```text
restore.sh                 push gateway/ and local/ over SSH, then start EAP
examples/                  ont-mac and wpa_supplicant templates, no real values
gateway/etc/wpa_supplicant/att-eap-wan-prep.sh
gateway/etc/wpa_supplicant/sfp-admin-route.sh
gateway/etc/wpa_supplicant/reinstall-wpa.sh
gateway/etc/systemd/system/eth6.0-vlan.service
gateway/etc/systemd/system/reinstall-wpa.service
gateway/etc/systemd/system/sfp-admin-route.service
gateway/etc/systemd/system/sfp-admin-route.timer
gateway/etc/systemd/system/wpa_supplicant-wired@.service.d/restart-on-failure.conf
gateway/etc/udev/rules.d/99-att-wan-mac.rules
gateway/etc/udev/rules.d/99-sfp-admin-route.rules
gateway/etc/network/if-up.d/changemac
local/                     gitignored. Your PEM files, ont-mac, filled-in conf, cached debs
```

On the gateway, after `restore.sh`:

```text
/etc/wpa_supplicant/wpa_supplicant-wired-eth6.0.conf
/etc/wpa_supplicant/ont-mac
/etc/wpa_supplicant/certs/*.pem
/etc/wpa_supplicant/packages/*.deb
/etc/wpa_supplicant/persist/          mirror used by the boot script
/etc/wpa_supplicant/reinstall-wpa.sh
/etc/wpa_supplicant/att-eap-wan-prep.sh
/etc/wpa_supplicant/sfp-admin-route.sh
```

## Troubleshooting

| What you see | What it means |
| --- | --- |
| `EAP state=IDLE`, `suppPortStatus=Unauthorized`, no carrier on `eth6` | The stick is not in port 7, or the fiber is not in the stick. |
| `onu-state` is not O5 | The OLT has not accepted the stick. Fix the GPON identity before EAP. Five rules on MIB 171 still means EAP is required once O5 is up. |
| `fopen: No such file or directory` on a cert | Paths in the supplicant config are still relative. |
| `ca md too weak`, then a passphrase prompt | OpenSSL 3. Add the global `openssl_ciphers=DEFAULT@SECLEVEL=0` line. The key has no passphrase. |
| `eth6.0-vlan.service` status 203 after an upgrade | The prep script was deleted. Run `/etc/wpa_supplicant/reinstall-wpa.sh`, or `restore.sh` from the LAN. |
| Stock `wpa_supplicant.service` is active next to the wired one | `dpkg` enabled it. `reinstall-wpa.sh` disables it. |
| `eth6.<vid>` never gets a lease, EAP is `Authorized` | The UniFi WAN VLAN is not the VID from `omcicli mib get 84`, or the MAC clone is not the `identity=` MAC. |
| Stick admin page does not load | `sfp-admin-route.timer` is not running, or the LAN is `192.168.1.0/24`. |

`journalctl -u eth6.0-vlan.service -u wpa_supplicant-wired@eth6.0 -u reinstall-wpa.service` is the boot log for this path.
