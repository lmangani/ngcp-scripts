#!/bin/bash
# Simple experimental script to send HEP Encapsulated NGCP Logs to HEP Server/Collector from RSyslog/omprog
# For more information: http://hep.sipcapture.org / hep@sipcapture.org
# Version 0.1 - ALPHA ONLY

# RSYSLOG Example Conf:
#
# 	Module (load="omprog") # needed only once in entire config
#	if $rawmsg contains "ID=" then
#		 action(type="omprog"
#			binary="/path/to/this.script")
#

# HEP Server Configuration
hepserver=127.0.0.1
heport=9069
hepid=199
heptype=100
localip=$(/sbin/ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')

# Exclude patterns
skip="*127.0.0.1"
skipline="*udp:127.0.0.1:5060*"

#test for hepipe
if ! [ $(which hepipe) ]; then
	echo "ERROR: Please install HEPipe (https://github.com/sipcapture/hepipe)";
	exit;
fi

  #read through the file looking for the Call ID=
  while read line
  do
    echo $line | grep -q ID=
    if [ $? == 0 ]; then
    callid=`echo $line  | grep --line-buffered "ID=" | sed -u -e "s/.*ID=//" | sed -u -e "s/\"//g"`
	if [[ $callid == $skip ]]; then
		#echo " Skipping..."
		fail=$[fail + 1];
	elif [[ $line == $skipline ]]; then
	#elif grep -q $skip <<<$line; then
		#echo " Skipping..."
		fail=$[fail + 1];
	else
	    sent=$[sent + 1];
	    line="${line//$'\r'/$'\n'}" 
	    #message=`echo $line | awk '{ s = ""; for (i = 4; i <= NF; i++) s = s $i " "; print s }'`
	    #proc=`echo $line | awk '{print $4, $5}'`
	    logdate=`echo $line | awk '{print $1, $2, $3}'`
	    ts=$(date --date="$logdate" +%s)
	    tsu=$(date --date="$logdate" +%4N)
	    
	    #### HEPipe HEADER PARAMS: #############################################################################################
	    #### timesec;timeusec;correlationid;source_ip;source_port;destination_ip;destinaton_port;payload in json OR string  ####
	    ########################################################################################################################

      ## STRING Version
	    echo "${ts};${tsu};${callid};${localip};514;${localip};514;${line}" | hepipe  -s $hepserver -p $heport -i $hepid -t $heptype 1>&2 > /dev/null

	    ## JSON Version
	    #echo "${ts};${tsu};${callid};${localip};514;${localip};514;{\"log\": \"${message}\"}" | hepipe  -s $hepserver -p $heport -i $hepid -t $heptype 1>&2 > /dev/null

	fi
    else
	echo "No ID found!"
    fi
  done

