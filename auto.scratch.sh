#!/bin/bash
# The absense of a round-robin-dns can make it sub-optimal for clients to 
# balance the load across VAST vips. this autofs script needs a list 
# (or hardcoded into the script) of NFS VIP addresses to which it will
# pick one, depending on the last octet of this client's IP address.
# this script is based off of the auto.net script which comes with autofs
# it is an executeable automount map which produces indirect map entries.
#  rob@vastdata.com  Jan '21
#
#  1) edit a couple variables below under the HERE section. (vip-pool IPs and EXPORT filter)
#  2) save this file as /etc/auto.scratch.sh    and chmod 755 it.
#  3) add the following two lines to /etc/auto.master which looks like this: (remove initial #)
## The following executeable map must be chmod 755
#/scratch  /etc/auto.scratch.sh
#  4) create views on vast which are named to match the EXPORT filter below.. eg: /scratch1 , /scratch2
#  5) restart automount with: sudo service autofs restart
# Note:  if you get errors when running ls at the top-level of the indirect-map entry (/vast above) like:
# ls: error while loading shared libraries: libselinux.so.1: cannot read file data: Error 21
# then the user who that is running may have a LD_LIBRARY_PATH set which does not include /lib
#### HERE are the variables you need to set particulat to your fileserver and vip-pool
#### below are the "vip pool names" or 200, 201, 202.. use them with:  cd /vast/200/scratch1

VAST_VIP_PREFIX=10.1.100   # this is the first three octets of your vip-pool
VAST_VIPS=$(seq 134 150)   # this is a sequence of numbers of the last octet of vip-pool
EXPORT=/scratch            # this filters from a list of views on vast. this script will showmount -e | grep EXPORT

# If you have more than one set of vip-pools, uncomment this
# case $1 in
#     200) VAST_VIP_PREFIX=172.200.1 ;   # this is the first three octets of your vip-pool
#          VAST_VIPS=$(seq 1 8)      ;   # this is a sequence of numbers of the last octet of vip-pool
#          EXPORT=/scratch           ;;    # this is your target mountpoint(s). this script will showmount -e | grep EXPORT
#     201) VAST_VIP_PREFIX=172.200.2 ;   # this is the first three octets of your vip-pool
#          VAST_VIPS=$(seq 1 8)      ;   # this is a sequence of numbers of the last octet of vip-pool
#          EXPORT=/scratch           ;;    # this is your target mountpoint(s). this script will showmount -e | grep EXPORT
#     202) VAST_VIP_PREFIX=172.200.6 ;   # this is the first three octets of your vip-pool
#          VAST_VIPS=$(seq 1 8)      ;   # this is a sequence of numbers of the last octet of vip-pool
#          EXPORT=/scratch           ;;    # this is your target mountpoint(s). this script will showmount -e | grep EXPORT
# esac
                              # in order to downselect which mounts to automount.
# Look at what a host is exporting to determine what we can mount.
# This is very simple, but it appears to work surprisingly well
# in auto.net this was the ip addr or name which the user changed directory to.
# in this script, it is the indirect directory name.  eg /vast200/scratch1 $key will be set to scratch1
key="$1"
if [ "x${1}" = "x" ]
then exit
fi
# add "nosymlink" here if you want to suppress symlinking local filesystems
# add "nonstrict" to make it OK for some filesystems to not mount
opts="-fstype=nfs,hard,intr,nodev,nosuid,nfsvers=3"
# Showmount comes in a number of names and varieties.  "showmount" is
# typically an older version which accepts the '--no-headers' flag
# but ignores it.  "kshowmount" is the newer version installed with knfsd,
# which both accepts and acts on the '--no-headers' flag.
#SHOWMOUNT="kshowmount --no-headers -e $key"
#SHOWMOUNT="showmount -e $key | tail -n +2"
for P in /bin /sbin /usr/bin /usr/sbin
do
        for M in showmount kshowmount
        do
                if [ -x $P/$M ]
                then
                        SMNT=$P/$M
                        break
                fi
        done
done
[ -x $SMNT ] || exit 1
# Newer distributions get this right
SHOWMOUNT="$SMNT --no-headers -e $VAST_VIP_PREFIX.$(echo $VAST_VIPS | cut -d ' ' -f1)"
###### end auto.net script basics
##############################################################################
###### start of function to has my last IP octet into the sequence of VIPS
declare -a vip_array
## get our last octet from our primary interface. works with selinux enabled, and does not use ifconfig or ip command.
LASTOCTET=$(cat /proc/net/fib_trie|grep '|--' | grep -vE ' 127|\.0[^0-9.]*$|\.255[^0-9.]*$' | head -1 | awk -F. '{print $NF}')
# Hash that to fit into our array of VAST_VIPS
while [[ index -lt 255 ]]
do
  for i in $VAST_VIPS
    do vip_array+=( $i )
   done
index=$((index+1))
done

HASHVIP=${VAST_VIP_PREFIX}.${vip_array[$LASTOCTET]}
##############################################################################
# Now we are back to the original auto.net, but replace $key with $HASHVIP
# Notice we filter by the EXPORT as specified at the top of this script.
# this way we don't try to automount things that normal clients should not mount.
# If you enable DEBUG, automount will break.. so only do this to test running it by hand.
DEBUG=false
$DEBUG &&(
echo Key=$key
echo EXPORT=$EXPORT
echo SHOWMOUNT=$SHOWMOUNT
echo HASHVIP=$HASHVIP
)
$DEBUG && set -x
#$SHOWMOUNT | LC_ALL=C cut -d' ' -f1 | LC_ALL=C sort -u | \
$SHOWMOUNT | LC_ALL=C cut -d' ' -f1 | LC_ALL=C sort -u | LC_ALL=C grep $EXPORT | \
        awk -v key="$HASHVIP" -v opts="$opts" -- '
        BEGIN   { ORS=""; first=1 }
                { if (first) { print opts; first=0 }; print " \\\n\t"  key ":" $1}
        END     { if (!first) print "\n"; else exit 1 }
        ' | sed 's/#/\\#/g'
