#!/bin/bash

# wrapper for ls ... ll  or  li  ... like the ls -lrt alias most people have already.
# this is solely to sort out what happens when people ‘ls’ in the same directory where they are performing writes.
#
# admins can put an alias in a global.bashrc which is maintained by the admins, stored in nfs or afs, (read only)
# and then sourced by each user before they source the rest of their profile. that alias points to this wrapper.

# function: this wrapper adds an automatic suffix to the share path, to workaround a NFS client behavior
#   where the stat of the directory will block until any outstanding client writes to files in that dir are finished.
#   sometimes this is extremly anoying and can be 30 seconds to a minute. the FIX is:
#   Simply stat(2)ing those files from a different NFS mount (we append -int for interactive) will return immediate results.
#   You MUST make a second automount map entry (with -int at the end) and mount it to a different VAST VIP.
#  you can probably extend this script to also bring benefit to things like rsync, find, etc, which can operate on a
#  read-only mount.. just change it up and let me know your new usecases.
# rob@vastdata.com 10/20/2020
#
# bugs:  can't currently handle multiple args. 
#        df can hang if there are nfs hung mounts on the client.

HERE=$(pwd)

if [ $# -lt 1 ]
then ARG=$HERE
else ARG=$1
fi

# If we dont have a full path, then make one
[ "$ARG" != "${ARG#/}" ] || ARG=${HERE}/${ARG}

# df can hang if there are any hung nfs mounts.. we should convert this to test mount(1)
SHARE=$(/bin/df -t nfs -h $ARG 2>/dev/null | grep -v Filesystem | tr -d '\n' | awk '{print $NF}' )

# Bail out if we are not in nfs
if [ "x${SHARE}" = "x" ]
then exec /bin/ls -lrt $ARG
fi

# Here we blatantly add on the -int name to the share.. this is where you create an additional entry 
# in your automount maps to be read-only and is only used for interactive stat() use. mounts from different VIP.
SHAREINT="${SHARE}-int"

# Check to make sure the admin added the additional  -int    (interactive) automount map entry
test -d $SHAREINT || echo "To use this wrapper, read the comments in the script:  $0"


# Sed in the above.
RELTOSHAREPATH=$(echo $ARG | sed -e "s%${SHARE}%/${SHAREINT}%" -e 's#//*#/#g')

ls -lrt $RELTOSHAREPATH
