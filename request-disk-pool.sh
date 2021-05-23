#!/usr/bin/bash

# This script will be the first step of the DR.
# It'll allow you to define a random set of disks to requests for manual mounting

# 1. First definitions
home_user='/home/netbackup' # Home user for the netbackup installation home.
volmgr='/usr/openv/volmgr' # volmgr root directory
admincmd='/usr/openv/netbackup/bin/admincmd' # admincmd full path

# 1. List available disks
cd $admincmd
./bpimmedia -spanpools |grep "DISK POOL" |cut -f 3- -d " " |sed 's/ /\n/g' > $home_user/disks

# 2. Get a random extraction of two disks for the initial sample.
cd $home_user && shuf -n 2 disks > $home_user/disks_random

# 3. Sending a quick mail to the desired operation teams that will have to mount the disks to test.
cat $home_user/disks_random | mailx -s "Disastery Recovery Test NetBackup - Disks to Mount" mail@mail.com

exit $?
