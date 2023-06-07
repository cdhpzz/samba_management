#!/bin/bash

readonly config_file="/etc/samba/smb.conf"
readonly fselinux="/etc/selinux/config"

function createFile(){
	local namef="$1"
	mkdir -p /$namef
}

function createConfigSamba(){
	echo -e "[Global]
\n	workgroup = WORKGROUP 
\n	server string = Samba Server %v 
\n	netbios name = centos 
\n	map to guest = bad user 
\n	dns proxy = no 
\n	ntlm auth = yes" > $config_file
}

function ConfigSambaAnon(){
	local namef="$1"
	echo -e " 
\n	[${namef##*/}] 
\n	path = /$namef 
\n	browsable = yes 
\n	writable = yes 
\n	guest ok = yes 
\n	read only = no" >> $config_file
}

function ConfigSambaSecu(){
	local namef="$1"
	echo -e " 
\n	[${namef##*/}] 
\n	path = /$namef 
\n	browsable = yes 
\n	writable = yes 
\n	guest ok = no
\n	valid user = @samba 
\n	read only = no" >> $config_file
}


function startSamba(){
	systemctl start smb.service
	systemctl start nmb.service
	systemctl enable smb.service
	systemctl enable nmb.service
	systemctl stop firewalld
	systemctl disable firewalld
}

function stopSelinux(){
	echo -e "# This file controls the state of SELinux on the system.
\n	# SELINUX= can take one of these three values:
\n	# enforcing - SELinux security policy is enforced.
\n	# permissive - SELinux prints warnings instead of enforcing.
\n	# disabled - No SELinux policy is loadded.
\n	SELINUX=disabled # Change this from enforcing to disabled
\n	# SELINUXTYPE= can take one of these three values:
\n	# targeted - Targeted processes are protected,
\n	# minimum - Modification of targeted policy. Only selected 
\n	processes are protected
\n	# mls - Multi Level Security protection.
\n	SELINUXTYPE=targeted" >| $fselinux
}

function anonymous(){
	local input=1
	while ((input!=0)); do
		echo -e "\n-----Please choose option-----\n1.Create new directory.\n2.Share directory with path.\n0.Exit."
		read input
		case $input in
		1)
			echo -n "Input directory name: "
			read namef
			createFile $namef
			break
			;;
		2)
			echo -n "Input path: "
			read namef
			break
			;;
		esac
	done
	ConfigSambaAnon $namef

	startSamba
	stopSelinux
	
	chmod -R 0555 /$namef
	chown -R nobody:nobody /$namef
}

function security(){

	local input=1
	while ((input!=0)); do
		echo -e "\n-----Please choose option-----\n1.Create new directory.\n2.Share directory with path.\n0.Exit."
		read input
		case $input in
		1)
			echo -n "Input directory name: "
			read namef
			createFile $namef
			break
			;;
		2)
			echo -n "Input path: "
			read namef
			break
			;;
		esac
	done

	echo -n "Input user name: "
	read username
	useradd $username
	passwd $username
	groupadd samba
	usermod -a -G samba $username

	chgrp samba /$namef

	local input=1
	local user=0
	local group=0
	local other=0

	while ((input!=0)); do
		echo -e "\n-----Please choose permission-----\n1.User.\n2.Group.\n3.Other.\n0.Exit."
		read input
		if [ $input != 0 ]; then
		echo -e "\n-----Please choose mode-----\n1.Execute only.\n2.Write only.\n3.Write and excute.\n4.Read only.\n5.Read and excute. \n6.Read and write.\n7.Read, write and execute.\n0.Exit."
		fi
		case $input in
		1)
			read user
			;;
		2)
			read group
			;;
		3)
			read other
			;;
		esac
		
	done

	chmod -R $user$group$other /$namef
	smbpasswd -a $username

	ConfigSambaSecu $namef
	startSamba
	stopSelinux
}


function main(){
	local input=1
	while ((input!=0)); do
		echo -e "\n-----Please choose option-----\n1.Share file with anonymous.\n2.Share file with security.\n0.Exit."
		read input
		case $input in
		1)
			anonymous
			;;
		2)
			security
			;;
		esac
	done
}
createConfigSamba
main
