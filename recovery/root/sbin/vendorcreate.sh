#!/sbin/sh

# /sbin/sh runs out of TWRP.. use it.

PROGS="sgdisk_msm8996 toybox_msm8996 resize2fs e2fsck mke2fs"
RC=0
# Check for my needed programs
for PROG in ${PROGS} ; do
   if [ ! -x "/sbin/${PROG}" ] ; then
      echo "Missing: /sbin/${PROG}"
      RC=9
   fi
done
#
# all prebuilt
if [ ${RC} -ne 0 ] ; then
   echo "Aborting.."
   exit 7
fi

TOYBOX="/sbin/toybox"

# Get bootdevice.. don't assume /dev/block/sda
DISK=`${TOYBOX} readlink /dev/block/bootdevice/by-name/system | ${TOYBOX} sed -e's/[0-9]//g'`

# Check for /vendor existence
VENDOR=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep -c vendor`

if [ ${VENDOR} -ge 1 ] ; then
   if [ `${TOYBOX} blkid /dev/block/bootdevice/by-name/vendor | ${TOYBOX} egrep -c ext4` -eq 0 ] ; then
      /sbin/mke2fs -t ext4 /dev/block/bootdevice/by-name/vendor
   fi
# Got it, we're done...
   exit 0
fi

# Missing... need to create it..
${TOYBOX} echo "/vendor missing"
#
# Get next partition...
LAST=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} tail -1 | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f2`
NEXT=`${TOYBOX} expr ${LAST} + 1`
NUMPARTS=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep 'holds up to' | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f6`

# Check if we need to expand the partition table
RESIZETABLE=""
if [ ${NEXT} -gt ${NUMPARTS} ] ; then
   RESIZETABLE=" --resize-table=${NEXT}"
fi

# Get /system partition #, start, ending, code
SYSPARTNUM=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f2`
SYSSTART=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f3`
SYSEND=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f4`
SYSCODE=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep system | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f7`

# Get sector size
SECSIZE=`/sbin/sgdisk --pretend --print ${DISK} | ${TOYBOX} grep 'sector size' | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f4`

# Sanity check
if [ "${SYSPARTNUM}" = "" -o "${SYSSTART}" = "" -o "${SYSEND}" = "" -o "${SYSCODE}" = "" -o "${SECSIZE}" = "" ] ; then
   exit 9
fi

# 512 = 512mb..
VENDORSIZE=`${TOYBOX} expr 512 \* 1024 \* 1024 / ${SECSIZE}`

NEWEND=`${TOYBOX} expr ${SYSEND} - ${VENDORSIZE}`
VENDORSTART=`${TOYBOX} expr ${NEWEND} + 1`

NEWSYSSIZE=`${TOYBOX} expr ${NEWEND} - ${SYSSTART} + 1`
MINSYSSIZE=`/sbin/resize2fs -P /dev/block/bootdevice/by-name/system 2>/dev/null | ${TOYBOX} grep minimum | ${TOYBOX} tr -s ' ' | ${TOYBOX} cut -d' ' -f7`

# Check if /system will shrink to small
if [ ${NEWSYSSIZE} -lt 0 ] ; then
   echo "ERROR: /system will be smaller than 0."
   exit 9
fi
if [ ${NEWSYSSIZE} -lt ${MINSYSSIZE} ] ; then
   echo "ERROR: /system will be smaller than the minimum allowed."
   exit 9
fi
# Sanity checks
if [ "${NEWSYSSIZE}" = "" -o "${NEWEND}" = "" -o "${NEWSYSSIZE}" = "" ] ; then
   exit 9
fi

# Resize /system, this will preserve the data and shrink it.
${TOYBOX} echo "*********Resize /system to ${NEWSYSSIZE} = ${NEWEND} - ${SYSSTART} + 1 (inclusize) = ${NEWSYSSIZE}"

/sbin/e2fsck -y -f /dev/block/bootdevice/by-name/system
/sbin/resize2fs /dev/block/bootdevice/by-name/system ${NEWSYSSIZE}

/sbin/sgdisk ${RESIZETABLE} --delete=${SYSPARTNUM} --new=${SYSPARTNUM}:${SYSSTART}:${NEWEND} --change-name=${SYSPARTNUM}:system --new=${NEXT}:${VENDORSTART}:${SYSEND} --change-name=${NEXT}:vendor --print ${DISK} > /sbin/sg.out 2>&1

echo /sbin/sgdisk --pretend ${RESIZETABLE} --delete=${SYSPARTNUM} --new=${SYSPARTNUM}:${SYSSTART}:${NEWEND} --change-name=${SYSPARTNUM}:system --new=${NEXT}:${VENDORSTART}:${SYSEND} --change-name=${NEXT}:vendor --print ${DISK}

cat /sbin/sg.out

if [ -d /data/local/sbin ] ; then
   SAVEDIR=/data/local/sbin
fi
if [ -d /external_sd/Android ] ; then
   SAVEDIR=/external_sd
fi

echo "To revert /vendor back: " | ${TOYBOX} tee ${SAVEDIR}vendor.recover.txt
echo "**Wipe ext4 file system: " | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt
echo "dd if=/dev/zero of=/dev/block/bootdevice/by-name/vendor bs=512 count=32 conv=notrunc" | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt
echo "** Recover parition table: " | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt
echo "sgdisk --delete=${SYSPARTNUM} --delete=${NEXT} --new=${SYSPARTNUM}:${SYSSTART}:${SYSEND} --change-name=${SYSPARTNUM}:system --print ${DISK}" | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt
echo "**reboot recovery**, then resize2fs /system back to normal size:" | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt
echo "resize2fs /dev/block/bootdevice/by-name/system" | ${TOYBOX} tee -a ${SAVEDIR}/vendor.recover.txt

sleep 2
reboot recovery
