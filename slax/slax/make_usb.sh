#!/bin/bash
# ---------------------------------------------------
# Script to create bootable USB in Linux
# usage: make_usb.sh [ <device_file> | <vmdk_file> ]
# author: evoltech@march-hare.org
# ---------------------------------------------------

if [ "$1" = "--help" -o "$1" = "-h" ]; then
  echo "This script will create bootable USB from files in curent directory."
  echo "Current directory must be writable."
  echo "example: $0 /home/evoltech/slax.vmdk"
  echo "example: $0 /dev/sdd"
  exit
fi

VERBOSE=1

CDLABEL="SLAX"
ISONAME=$(readlink -f "$1")

cd $(dirname $0)

if [ "$ISONAME" = "" ]; then
   SUGGEST=$(readlink -f ../../$(basename $(pwd)).vmdk)
   echo -ne "Target USB device [ Hit enter for $SUGGEST ]: "
   read ISONAME
   if [ "$ISONAME" = "" ]; then ISONAME="$SUGGEST"; fi
fi

MOUNT=mount
if [[ $ISONAME =~ \.vmdk$ ]]; then
  MOUNT=`which vmware-mount`
  if [ 0 != $? ]; then
    echo "vmware-mount is not installed"
    exit
  fi
  echo "You are using a vmdk file.  We are assuming that you have already" \
    " configured this device to be bootable, as we will just be copying the" \
    " new content over to it."
fi

# TODO: integrate the "Install SLAX on USB" tool

# mount the device
TARGET=`dirname $SUGGEST`/tmp
DELTARGET=1
if [ -d $TARGET ]; then
  DELTARGET=0
fi
if [ $VERBOSE -gt 0 ]; then
  echo $MOUNT $SUGGEST $TARGET
fi
$MOUNT $SUGGEST $TARGET
if [ 0 != $? ]; then
  echo "Sorry we were not able to mount the device"
  exit;
fi

# copy the new data to the device
echo "Copying distro to target..."
cp -r `pwd`/../* $TARGET

# umount the directory
if [[ $MOUNT =~ vmware-mount ]]; then
  if [ $VERBOSE -gt 0 ]; then
    echo $MOUNT -d $TARGET
  fi
  $MOUNT -d $TARGET
else
  if [ $VERBOSE -gt 0 ]; then
    echo umount $TARGET
  fi
  umount $TARGET
  # TODO: verify this was succesful
fi

# clean up the target tmp directory we used
if [ $DELTARGET == 1 ]; then
  if [ $VERBOSE -gt 0 ]; then
    echo rmdir $TARGET
  fi
  rmdir $TARGET
fi
