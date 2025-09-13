#! /bin/bash

# Check prerequisites
cd `dirname $0` || exit 1
test -x /usr/bin/install || { echo "Please install coreutils package and try again." && exit 1; }
test -x /usr/bin/curl || { echo "Please install curl package and try again." && exit 1; }
test -x /usr/sbin/cryptsetup || { echo "cryptsetup package does not seem to be installed, nothing to do here." && exit 1; }
test "`whoami`" = "root" || { echo "This needs to be run as root." && exit 1; }

# Disclaimer
read -e -p "By proceeding, you acknowledge that you are using this at your own risk. [y/N] " yesno
[ "$yesno" != "Y" -a "$yesno" != "y" ] && exit 0

# Figure out encrypted device
crypt_devices="`awk '/^[^#][^ ]+[ ]+[^ ]+[ ]+none/ {print $1}' /etc/crypttab 2> /dev/null`"
if [ `echo $crypt_devices | wc -w` -ne 1 ]; then
    echo "Need a single encrypted device, found: $crypt_devices"
    exit 1
fi
luks_device="`cryptsetup status $crypt_devices | awk '/device:/ { print $2 }'`"
if [ -z "$luks_device" -o ! -b "$luks_device" ]; then
    echo "Found $crypt_devices, but failed to find underlying block device."
    exit 1
fi
echo "Found $crypt_devices on $luks_device"

# Fetch key
if [ -r /etc/remotek-initramfs.conf ]; then
    . /etc/remotek-initramfs.conf
    key_url="$KEY_URL"
    if [ -n "$KEY_URL" ]; then
        echo "Using URL from /etc/remotek-initramfs.conf"
    else
        echo "No KEY_URL in /etc/remotek-initramfs.conf, please fix and re-run"
    fi
else
    key_url="$1"
    if [ -z $key_url ]; then
        read -e -p "Enter the remote key's URL: " -i "https://" key_url
    fi
fi
key_file=`mktemp --tmpdir=/dev/shm -t rk-XXXXXXX`
trap "rm -f $key_file" EXIT
echo -n "Fetching key.. "
code="`curl -s -w "%{stderr}%{http_code}" $key_url 2>&1 > $key_file`"
echo -n "Got $code.. "
if [ $code -eq 200 -a -n $key_file ]; then
    echo "looks good!"
else
    echo "no key to work with."
    exit 1
fi

# Check if key is already installed
echo -n "Checking key.. "
cryptsetup luksOpen $luks_device --test-passphrase --key-file $key_file
if [ $? -eq 0 ]; then
    echo "key already setup."
else
    read -e -p "Install key? [y/N] " yesno
    if [ "$yesno" != "Y" -a "$yesno" != "y" ]; then
        exit 0
    fi
    echo -n "Adding key.. "
    cryptsetup luksAddKey $luks_device $key_file || exit 1
    echo "Key successfull added."
fi

# Setup remotek
read -e -p "Install scripts? [y/N] " yesno
if [ "$yesno" != "Y" -a "$yesno" != "y" ]; then
    exit 0
fi

if [ ! -s /etc/remotek-initramfs.conf ]; then
    touch /etc/remotek-initramfs.conf && chmod 600 /etc/remotek-initramfs.conf
    echo "KEY_URL=\"$key_url\"" > /etc/remotek-initramfs.conf
    echo 'NAMESERVERS="8.8.8.8,8.8.4.4"' >> /etc/remotek-initramfs.conf
    echo "Wrote /etc/remotek-initramfs.conf"
fi
/usr/bin/install -v -c -m 0755 initramfs/hook /usr/share/initramfs-tools/hooks/remotek || exit 1
/usr/bin/install -v -c -m 0755 initramfs/init-premount /usr/share/initramfs-tools/scripts/init-premount/remotek || exit 1
/usr/bin/install -v -c -m 0755 initramfs/init-bottom /usr/share/initramfs-tools/scripts/init-bottom/remotek || exit 1

read -e -p "Update initramfs? [y/N] " yesno
if [ "$yesno" != "Y" -a "$yesno" != "y" ]; then
    exit 0
fi
update-initramfs -u -k all

exit 0
