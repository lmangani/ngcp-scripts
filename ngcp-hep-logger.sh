#!/bin/bash
# Simple experimental script to send HEP Encapsulated NGCP Logs to HEP Server/Collector
# For more information: http://hep.sipcapture.org / hep@sipcapture.org
# Version 0.1 - ALPHA ONLY


# HEP Server 
hepserver=127.0.0.1
heport=9069
hepid=199
heptype=35

# Specify NGCP Log file to monitor (ie: /var/log/ngcp/kamailio-lb.log) or all logs NGCP logs
if ! [ $1 ]; then
	echo "Missing Argument! USAGE EXAMPLE:"; echo;
	echo "SINGLE LOG:    $0 /path/to/application.log";
	echo "ALL LOGS  :    $0 --all";
	exit;
fi

if [ $1 = "--all" ] || [ $1 = "-a" ]; then
	log=/var/log/ngcp/*.log
	all=1
else 
	log=$1
fi


#test for hepipe
if ! [ $(which hepipe) ]; then
	echo "ERROR: Please install HEPipe (https://github.com/sipcapture/hepipe)";
	exit;
fi

#test for existence of the log file
if [ $all = 1 ] || [ -f $log ]; then

  #read through the file looking for the Call ID=
  while read line
  do
    echo $line | grep -q ID=
    if [ $? == 0 ]; then
    callid=`echo $line  | grep --line-buffered "ID=" | sed -u -e "s/.*ID=//" | sed -u -e "s/\"//g"`
    logdate=`echo $line | awk '{print $1, $2, $3}'`
    ts=$(date --date="$logdate" +%s)
    tsu=$(date --date="$logdate" +%4N)
    #### timesec;timeusec;correlationid;source_ip;source_port;destination_ip;destinaton_port;payload in json
    #echo "${ts};${tsu};${callid};127.0.0.1;5060;10.0.0.1;5060;{\"log\": \"${line}\"}"
    echo "${ts};${tsu};${callid};127.0.0.1;5060;10.0.0.1;5060;{\"log\": \"${line}\"}" | hepipe  -s $hepserver -p $heport -i $hepid -t $heptype 
    fi
  done < <(tail -f $log)

fi
