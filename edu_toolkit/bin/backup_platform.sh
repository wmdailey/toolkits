#!/bin/bash

# Copyright 2021 Cloudera, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Disclaimer
# This script is for training purposes only and is to be used only
# in support of approved training. The author assumes no liability
# for use outside of a training environments. Unless required by
# applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES
# OR CONDITIONS OF ANY KIND, either express or implied.

# Title: backup_platform.sh
# Author: WKD
# Date: 17MAR22
# Purpose: Run platform backups. This is required on a scheduled basis and prior 
# to an upgrade. This script backups important files for Cloudera Manager
# and CDP Runtime. Not all of the services are included in this example.
# It is important to note that this tool does not backup HDFS data.
# After running this script data center backups should be run on all host
# nodes. Another requirement not solved with this tool is gleaning out
# old backup files.

# DEBUG
#set -x
#set -eu
#set >> /tmp/setvar.txt

# VARIABLE
num_arg=$#
dir=${HOME}
date_now=$(date +%y%m%d)
backup_db_dir="${dir}/backup_db_${date_now}"
db_password=BadPass@1
host_file=${dir}/conf/list_host.txt
option=$1
logfile=${dir}/logs/backup_platform.log

# FUNCTIONS
function usage() {
        echo "Usage: $(basename $0) [OPTION]"
        exit
}

function get_help() {
# Help page

cat << EOF
SYNOPSIS
        backup_platform.sh [OPTION] 

DESCRIPTION
        This runs backups for CM, databases, hdfs, and hue.
	Run the --cm option to backup everything in one command.

        -h, --help
                help page
        -a, --all
		Backup all requirements 
	-c, --cm
		Backup cm server, cm services, and cm agents 
        -d, --databases
/               Backup all CM and CDP datatabases
        -f, --hdfs
		Backup HDFS
	-r, --remove
		Remove all backup directories
	-s, --stop
		Stop the Cloudera Manager server
	-t, --start
		Start the Cloudera Manager server
	-u, --hue
		Backup Hue
INSTRUCTIONS
	1. Always stop Cloudera Manager first
		run_cm_backups.sh -s
	2. Select the type of backup and run it.
		run_cm_backups.sh -c
	3. Verify the backup directories
		ls cdp_N.N.N_YYMMDD
		ls db	
EOF
        exit
}

function call_include() {
# Test for include script.

        if [ -f ${dir}/bin/include.sh ]; then
                source ${dir}/bin//include.sh
        else
                echo "ERROR: The file ${dir}/bin/include.sh not found."
                echo "This required file provides supporting functions."
                exit 1
        fi
}

function setup_log() {
# Open the log file

	exec 2> ${logfile}
	echo "---- Starting backup script for CM and CDP Runtime"
	echo "---- Disregard tar warnings below --------"
}

function stop_cm() {
# Stop CM

	echo "---- Stopping Cloudera Manager" | tee -a ${logfile}
	sudo systemctl stop cloudera-scm-server
}

function start_cm() {
# Stop CM

	echo "---- Starting Cloudera Manager" | tee -a ${logfile}
	sudo systemctl start cloudera-scm-server
}


function backup_cm_server() {
# Backup the CM server

  	echo "---- Backing up Cloudera Manager Server" | tee -a ${logfile}

	backup_cm_server="${dir}/backup_cm_server_${date_now}"

	if [ ! -d ${backup_cm_server} ]; then
			sudo mkdir -p ${backup_cm_server}
	fi

	sudo -E tar -cf ${backup_cm_server}/cloudera-scm-server_${date_now}.tar /etc/cloudera-scm-server /etc/default/cloudera-scm-server 
	sudo -E tar -cf ${backup_cm_server}/repository_server_${date_now}.tar /etc/yum.repos.d 

}

function backup_cm_services() {
# Backup Cloudera Management Services

	echo "---- Backing up Cloudera Management Services" | tee -a ${logfile}

	sudo cp -rp /var/lib/cloudera-host-monitor /var/lib/cloudera-host-monitor-${date_now}
	sudo cp -rp /var/lib/cloudera-service-monitor /var/lib/cloudera-service-monitor-${date_now}
	sudo cp -rp /var/lib/cloudera-scm-eventserver /var/lib/cloudera-scm-eventserver-${date_now}
}

function backup_cm_agent() {
# Back up CM agents

	echo "---- Backing up Cloudera Manager Agent and yum repo files" | tee -a ${logfile}

	backup_cm_agent="${dir}/backup_cm_agent_${date_now}"

	if [ ! -d ${backup_cm_agent} ]; then
		for host in $(cat ${host_file}); do
			ssh -tt ${host} sudo mkdir -p ${backup_cm_agent}
		done
	fi

	for host in $(cat ${host_file}); do
		ssh -tt ${host} sudo -E tar -cf ${backup_cm_agent}/${host}_agent_${date_now}.tar --exclude=*.sock /etc/cloudera-scm-agent /etc/default/cloudera-scm-agent /var/run/cloudera-scm-agent /var/lib/cloudera-scm-agent
		ssh -tt ${host} sudo -E tar -cf ${backup_cm_agent}/${host}_repository_${date_now}.tar /etc/yum.repos.d
	done
}

function backup_db() {
# Back up CDH databases
# Edit the list of databases as required

	echo "---- Backing up MySQL databases for scm, hue, and metastore" | tee -a ${logfile}

	backup_db="${dir}/backup_db_${date_now}"

	if [ ! -d ${backup_db} ]; then
		mkdir ${backup_db}
	fi

	mysqldump -uroot -p${db_password} --databases scm hue metastore > ${backup_db}/mysql_db_backup_${date_now}.sql
}


function backup_namenode() {
# Create backup directories on all NameNode hosts

	echo "---- Creating NameNode backup directories" | tee -a ${logfile}
	echo "---- HDFS should be configured for High Availability on three masters. If it is not configured then some of these commands will fail." | tee -a ${logfile}

	nn_list="master-1.example.com master-3.example.com"

	for host in $(echo ${nn_list}); do
		ssh -tt ${host} sudo mkdir -p /etc/hadoop/namenode_backup_${date_now}
		nn_dir=$(ssh -tt ${host} sudo "ls -t1 /var/run/cloudera-scm-agent/process | grep -e "NAMENODE\$" | head -1")
		nn_dir="${nn_dir%%[[:cntrl:]]}"
		ssh -tt ${host} sudo cp -rpf /var/run/cloudera-scm-agent/process/${nn_dir} /etc/hadoop/namenode_backup_${date_now}
		ssh -tt ${host} sudo rm /etc/hadoop/namenode_backup_${date_now}/${nn_dir}/log4j.properties
	done
}

function backup_journal() {
# Back up Journal Node data

	echo "---- Backing up Journal Node" | tee -a ${logfile}

	jn_list="master-1.example.com master-2.example.com master-3.example.com"

	for host in $(echo ${nn_list}); do
		ssh -tt ${host} sudo cp -rp /dfs/jn /dfs/jn_backup_${date_now}
	done
}

function backup_datanode() {
# Create backup directories on all DataNode hosts

	echo "---- Backing up DataNodes" | tee -a ${logfile}

	dn_list="worker-1.example.com worker-2.example.com worker-3.example.com "

	for host in $(echo ${dn_list}); do
		ssh -tt ${host} sudo mkdir -p /etc/hadoop/datanode_backup_${date_now}
		dn_dir=$(ssh -tt ${host} sudo "ls -t1 /var/run/cloudera-scm-agent/process | grep -e "DATANODE\$" | head -1")
		dn_dir="${dn_dir%%[[:cntrl:]]}"
		ssh -tt ${host} sudo cp -rpf /var/run/cloudera-scm-agent/process/${dn_dir} /etc/hadoop/datanode_backup_${date_now}
		ssh -tt ${host} sudo cp -pf /etc/hadoop/conf/log4j.properties /etc/hadoop/datanode_backup_${date_now}/${dn_dir}/
	done
}

function backup_zookeeper() {
# Back up zookeeper data

	echo "---- Backing up Zookeeper" | tee -a ${logfile}

	zk_list="master-1.example.com master-2.example.com master-3.example.com"

	for host in $(echo ${zk_list}); do
		ssh -tt ${host} sudo cp -rp /var/lib/zookeeper/ /var/lib/zookeeper_backup_${date_now}
	done
}

function backup_hue() {
# Back up Hue Server registry file on cmhost

	echo "---- Backing up Hue Server registry file" | tee -a ${logfile}

	hue_list="edge.example.com"

	for host in $(echo ${hue_list}); do
		ssh -tt ${host} sudo mkdir -p /opt/cloudera/parcels_backup/
		ssh -tt ${host} sudo cp -p /opt/cloudera/parcels/CDH/lib/hue/app.reg /opt/cloudera/parcels_backup/app.reg-${backup_file}
	done
}

function remove_backup() {
# Remove backup directory

	# Remove CM Server
	backup_cm_server="${dir}/backup_cm_server_${date_now}"
	if [ -d ${backup_cm_server} ]; then
		echo "---- Remove ${backup_cm_server}" | tee -a ${logfile}
		sudo rm -r ${backup_cm_server}
	fi

	# Remove CM Services
	backup_cm_agent="${dir}/backup_cm_agent_${date_now}"
	if [ -d ${backup_cm_agent} ]; then
		for host in $(cat ${host_file}); do
		echo "---- Remove ${host} ${backup_cm_agent}" | tee -a ${logfile}
			ssh -tt ${host} sudo rm -r ${backup_cm_agent}
		done
	fi

	# Remove Databases
	backup_db="${dir}/backup_db_${date_now}"
	if [ -d ${backup_db} ]; then
		echo "---- Remove ${backup_db}" | tee -a ${logfile}
		rm -r ${backup_db}
	fi

	# Remove NameNode
	echo "---- Remove backup for NameNode" | tee -a ${logfile}
	nn_list="master-1.example.com master-3.example.com"
	for host in $(echo ${nn_list}); do
		ssh -tt ${host} sudo rm -r /etc/hadoop/namenode_backup_${date_now}
	done

	# Remove JournalNode
	echo "---- Remove backup for JournalNode" | tee -a ${logfile}
	jn_list="master-1.example.com master-2.example.com master-3.example.com"
	for host in $(echo ${nn_list}); do
		ssh -tt ${host} sudo rm -r /dfs/jn_backup_${date_now}
	done

	# Remove DataNode
	echo "---- Remove backup for DataNodes" | tee -a ${logfile}
	dn_list="worker-1.example.com worker-2.example.com worker-3.example.com "
	for host in $(echo ${dn_list}); do
		ssh -tt ${host} sudo rm -r /etc/hadoop/datanode_backup_${date_now}
	done

	# Remove Zookeeper
	echo "---- Remove backup for Zookeeper" | tee -a ${logfile}
	zk_list="master-1.example.com master-2.example.com master-3.example.com"
	for host in $(echo ${zk_list}); do
		ssh -tt ${host} sudo rm -r /var/lib/zookeeper_backup_${date_now}
	done

	# Remove Hue
	echo "---- Remove backup for Hue Server registry file" | tee -a ${logfile}
	hue_list="edge.example.com"
	for host in $(echo ${hue_list}); do
		ssh -tt ${host} sudo rm -r /opt/cloudera/parcels_backup
	done
}

function msg_begin() {

	echo "----------------------------------------------" | tee -a ${logfile}
	echo "---- Begin Backup on ${date_now}" | tee -a ${logfile}
}

function msg_backup() {

	echo "---- Backups of important files are complete." | tee -a ${logfile}
	echo "---- Cloudera Manager and the CDP Runtime are ready for upgrade." | tee -a ${logfile}
	echo "---- Review log file at ${logfile}"
}

function run_option() {
# Case statement for options.

    case "${option}" in
	-h | --help)
		get_help
		;;
	-a | --all)
		check_arg 1	
		msg_begin
		backup_cm_server
		backup_cm_services
		backup_cm_agent
		backup_db
		backup_namenode
		backup_journal
		backup_zookeeper
		backup_datanode
		backup_cm_agent
		backup_hue
		msg_backup
		;;
	-c | --cm)
		check_arg 1
		msg_begin
		backup_cm_server
		backup_cm_services
		backup_cm_agent
		;;
	-d | --databases)
		check_arg 1
		msg_begin
		backup_db
		;;
	-f | --hdfs)
		check_arg 1
		msg_begin
		backup_namenode
		backup_journal
		backup_zookeeper
		backup_datanode
		;;
	-r | --remove)
		check_arg 1
		remove_backup
		;;
	-s | --stop)
		check_arg 1
		stop_cm
		;;
	-t | --start)
		check_arg 1
		start_cm
		;;
	-u | --hue)
		check_arg 1
		msg_begin
		backup_hue
		;;
        *)
            usage
            ;;
    esac
}

function main() {

	# Run checks
	call_include
	check_sudo
	setup_log

	# Run command
	run_option

}

#MAIN
main "$@"
exit 0
