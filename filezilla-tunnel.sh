#!/bin/bash
# Title: filezilla-tunnel.sh
# Version: 0.1
# Author: Frédéric CHEVALIER <fcheval@txbiomed.org>
# Created in: 2022-01-23
# Modified in: 2023-03-18
# Licence : GPL v3



#======#
# Aims #
#======#

aim="Create a SSH tunnel and start Filezilla to connect to it."



#==========#
# Versions #
#==========#

# v0.1 - 2023-03-18: add dependency tests
# v0.0 - 2022-01-23: creation

version=$(grep -i -m 1 "version" "$0" | cut -d ":" -f 2 | sed "s/^ *//g")



#===========#
# Functions #
#===========#

# Usage message
function usage {
    echo -e "
    \e[32m ${0##*/} \e[00m -u|--username string -h1|--host1 host -h2|--host2 host2 -s|--ssha -p|--sshp -h|--help

Aim: $aim

Version: $version

Options:
    -u,  --username   username to connect to the servers [default: $USER]
    -h1, --host1      first host to connect to set the tunnel up
    -h2, --host2      second host to connect 
    -s,  --ssha       force the creation of a new ssh agent
    -p,  --pass       use sshpass to store ssh password
    -h,  --help       this message
    "
}


# Info message
function info {
    if [[ -t 1 ]]
    then
        echo -e "\e[32mInfo:\e[00m $1"
    else
        echo -e "Info: $1"
    fi
}


# Warning message
function warning {
    if [[ -t 1 ]]
    then
        echo -e "\e[33mWarning:\e[00m $1"
    else
        echo -e "Warning: $1"
    fi
}


# Error message
## usage: error "message" exit_code
## exit code optional (no exit allowing downstream steps)
function error {
    if [[ -t 1 ]]
    then
        echo -e "\e[31mError:\e[00m $1"
    else
        echo -e "Error: $1"
    fi

    if [[ -n $2 ]]
    then
        exit $2
    fi
}


# Dependency test
function test_dep {
    which $1 &> /dev/null
    if [[ $? != 0 ]]
    then
        error "$1 not found. Exiting..." 1
    fi
}




#==============#
# Dependencies #
#==============#

test_dep ssh
test_dep filezilla
test_dep netstat



#===========#
# Variables #
#===========#

# Options
while [[ $# -gt 0 ]]
do
    case $1 in
        -u|--username ) user="$2"    ; shift 2 ;;
        -h1|--host1   ) host1="$2"   ; shift 2 ;;
        -h2|--host2   ) host2="$2"   ; shift 2 ;;
        -s|--ssha     ) ssha=1       ; shift   ;;
        -p|--sshp     ) sshp=1       ; shift   ;;
        -h|--help     ) usage ; exit 0 ;;
        *             ) error "Invalid option: $1\n$(usage)" 1 ;;
    esac
done

# Check mandatory options
[[ -z $host1 ]] && error "host1 missing. Exiting..." 1
[[ -z $host2 ]] && error "host2 missing. Exiting..." 1

# Default values
[[ -z $user ]] && user=$USER

# SHH agent
[[ -z "$SSH_AUTH_SOCK" || -n "$ssha" ]] && sshk=1 && eval $(ssh-agent) &> /dev/null

# SSH password
if [[ -n "$sshp" ]]
then
    test_dep sshpass
    read -sp "Enter SSH password: " SSHPASS
    export SSHPASS
    echo ""
    myssh="sshpass -e ssh"
else
    myssh=ssh
fi



#============#
# Processing #
#============#

# Check connectivity
mytest=$($myssh -q -A -4 $host1 echo 0)
[[ -z "$mytest" ]] && error "Wrong password or no connection. Exiting..." 1

# Set bash options to stop script if a command exit with non-zero status
set -e
set -o pipefail

# Select port on localhost
myport_l=25000
port_list=$(netstat -ant | tail -n +3 | sed "s/  */\t/g" | cut -f 4 | cut -d ":" -f 2 | sort | uniq)
for ((i=$myport_l ; i <= 40000 ; i++))
do
    [[ $(echo "$port_list" | grep -w $i) ]] || break
done
myport_l=$i
info "Port used on localhost: $myport_l"

# Create tunnel (must deactivate set -e using set +e otherwise script exits)
set +e

mysocket=/tmp/${USER}_filezilla_socket_$RANDOM
$myssh -q -M -S $mysocket -fA -o ServerAliveInterval=60 -N $host1 -L ${myport_l}:$host2:22

# Create trap to close ssh tunnel when interrupt
#trap "pkill -f \"ssh.* ServerAliveInterval=60 -N $host1 -L ${myport_l}:$host2:22\"" EXIT
trap "$myssh -q -S $mysocket -O exit $host1" EXIT

# Start Filezilla
if [[ -n "$sshp" ]]
then
    filezilla sftp://$user:$SSHPASS@localhost:${myport_l} &>> /dev/null
else
    filezilla -l ask sftp://$user@localhost:${myport_l} &>> /dev/null
fi
mypid=$!

# Wait until Filezilla is closed
wait $mypid

# Reactivate error detection
set -e

# Kill SSH agent if it was started with the script
[[ -n "$sshk" ]] && ssh-agent -k

exit 0
