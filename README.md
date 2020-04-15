## Automated LUKS network key retrieval on boot

These scripts enable a Linux system with a LUKS encrypted root
filesystem to boot without a user manually entering a LUKS key by
fetching the key from the network.

Is this secure? **Nope**, not in itself: anyone with access to the
device can easily find out the URL that the key is fetch from, and
download it. **The security of this setup depends entirely on the
server: it must only release the key when the end device is considered
to be secure.**

## Requirements

For the following to work, you need:

* a device
  * configured with LUKS encrypted root
  * capable of connecting to the working network in the initramfs
* a web server to respond with the device's LUKS key

## Installation

**Note that this has only been tested on Debian sid, and likely only
works for a single encrypted device.**

First, make sure that you have configured the initramfs with the
network parameters. This is normally done in the
`/etc/initramfs-tools/conf.d/ip` file, with a single line such as the
following to setup the interface `enp3s0` to use DHCP. See
[initramfs-tools(8)](https://manpages.debian.org/jessie/initramfs-tools/initramfs-tools.8.en.html)
for details.

```
ip=:::::enp3s0:dhcp
```

Once the above is done, run the following command to proceed with the
installation. Note that you **MUST** supply a URL from where to fetch
the key from.

```shell
$ sudo ./install.sh https://server.name/the/secret/key
Found sdc3_crypt on /dev/sdc3
Fetching key.. Got 200.. looks good!
Checking key.. No key available with this passphrase.
Install key? [y/N] y
Adding key.. Enter any existing passphrase:
Key successfull added.
Install scripts? [y/N] y
Wrote /etc/remotek-initramfs.conf
'initramfs/hook' -> '/usr/share/initramfs-tools/hooks/remotek'
'initramfs/init-premount' -> '/usr/share/initramfs-tools/scripts/init-premount/remotek'
'initramfs/init-bottom' -> '/usr/share/initramfs-tools/scripts/init-bottom/remotek'
Update initramfs? [y/N] y
update-initramfs: Generating /boot/initrd.img-5.5.0-1-amd64
update-initramfs: Generating /boot/initrd.img-4.19.0-8-amd64
```

The `install.sh` script is idempotent and therefore safe to run
multiple times.

## Uninstallation

```shell
$ sudo rm /etc/remotek-initramfs.conf
$ sudo update-initramfs -u -k all
```
