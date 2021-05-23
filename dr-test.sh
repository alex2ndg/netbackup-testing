#!/usr/bin/bash

# This script will make the full DR Test for NetBackup.
# Disks should have been previously mounted on the Robot.

# 1. Initial variables
home_user='/home/netbackup' # NetBackup installer homedir
volmgr='/usr/openv/volmgr' # volmgr installation dir
admincmd='/usr/openv/netbackup/bin/admincmd' # admincmd dir for binaries
bincmd='/usr/openv/netbackup/bin' # netbackup root binaries dir

# 1. Let's first check if the disks are correctly mounted.
cd $volmgr/bin
for line in `cat $home_user/disks_random`; do
	resul=$(./vmquery -W -a |grep $line |awk -F ' ' '{print $7}')
	if [ "$resul" == "NONE" ]; then
		echo "Disk $line isn't correctly mounted. Please review."
		exit 3
	elif [ "$resul" == "TLD" ]; then
		echo "Disk $line is correctly mounted."
	else
		echo "Disk $line isn't correctly mounted. Please review."
		exit 5
	fi
done

# 2. Let's now list the volumes that are inside of each disk. Once listed, we'll grab randomly one of them.
cd $admincmd
> $home_user/$image-$line-header-files
for line in `cat $home_user/disks_random`; do
	./bpimmedia -l -mediaid $line | grep "^IMAGE" | awk {'print $4'} |grep '_bk' |shuf -n 1 |
	# 3. Listing the different files inside of each volume. We'll grab randonmly 5 files.
	while read image; do
		ctime=`echo $image | sed 's/^.*_//'`
		./bpflist -l -backupid $image -ut $ctime -rl 999 |cut -f 10- -d " " | shuf -n 5 > $home_user/$image-list-frandom
		# We'll remove the last 8 columns to keep only the real file
		awk '{NF-=8}1' $home_user/$image-list-frandom > $home_user/$image-list-frandom-real
		# 4. And now we'll grab the real backup date for future recovery.
		./bpflist -l -backupid $image -ut $ctime -rl 999 |grep "^FILES" |awk -F ' ' '{print $5}' >> $home_user/$image-$line-header-files
	done
	# And we'll leave only the unique ctime.
	cat $home_user/$image-$line-header-files |sort |uniq > $home_user/$image-$line-header-files-uniq
done

# 5. Let's now convert the ctime to the actual date...
for file in `ls $home_user/*-header-files-uniq`; do
	for line in `cat $file`; do
		cd $bincmd
		treal=`./bpdbm -ctime $line`
		echo $treal |awk -F '=' '{print $2}' > $file-2
	done
done

# 4. And now let's make the actual DR and make a recovery of the sample files and test the result. Logic of the binary:
# -C : From the original client
# -copy 2 : Making the copy to be for 2+ days to be from disk
# -D : To the original destination (same)
# -K : To not overwrite the production files if any
# -print_jobid : To save the jobid via stdout
# -R : To rename the original file to avoid again overwriting (using an specific file, see below)
# -priority : Maximum priority to allow this to end ASAP
# -L : Log file
# -t : Policy Type, see below:
## 0 = Standard
## 19 = NDMP - Please be aware if this is from a cabin you might encounter issues with this.
## 40 = VMware
# -s : Start date of the image
# -e : End date of the image (usually the same as -e)
cd $home_user
for file in `ls *-frandom-real`; do
	client=`echo $file |awk -F '_bk' '{print $1"_bk"}'`
	for line in `cat $file |grep -v "-"`; do
		> /home/admbackup/test.log
		cd $bincmd
		treal=`cat $client*header-files-uniq-2`
		# Using the date to ctime for NetBackup definition (month/date/year hour:minutes:seconds)
		treali=`date -d "$treal" +"%m/%d/%Y %H:%m:%S"`
		trealf=`date +"%m/%d/%Y %H:%m:%S"`
		echo "change $line to $line-recu" > $home_user/$file-rename-file # This will allow the renaming of the files.
		./bprestore -copy 2 -C $client -D $client -K -print_jobid -priority 90000 -s "$treali" -e "$trealf" -L /home/admbackup/test.log -R $home_user/$file-rename-file $line		
		cat /home/admbackup/test.log
	done
done

exit $?
