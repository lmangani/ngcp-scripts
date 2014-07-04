#!/bin/bash
# Simple experimental script to send HEP Encapsulated NGCP Logs to HEP Server/Collector
# For more information: http://hep.sipcapture.org / hep@sipcapture.org
# Version 0.2 - ALPHA ONLY


# HEP Server 
hepserver=127.0.0.1
heport=9063
hepid=199
heptype=100
localip=$(/sbin/ip -4 -o addr show dev eth0| awk '{split($4,a,"/");print a[1]}')
syslogport=5514

# Bypass filter for CALL-ID (match=exclude)
skip="*127.0.0.1"
# Bypas filter for full log line (match=exclude)
skipline="*udp:127.0.0.1:5060*"

# script execution vars
script="tail -f"
netcat="nc -k -l ${syslogport}"
command=$script

# Usage
usage() {
	echo "Usage: $0 [-l </path/to/file.log>] [-a </path/to/logs>] [-x <string>]"
	echo
	echo "  -l <file>	:	Read specified Log file"
	echo "  -a <dir>	:	Read *.log in specified directory"
	echo "  -n <port>	:	Read lines from TCP socket"
	echo "  -x <*string>	:	Exclude all IDs matching Regex"
	1>&2; exit 1; 
}

while getopts ":n:l:a:xqh" o; do
    case "${o}" in
        n)
            n=${OPTARG}
            syslogport=${OPTARG}
            command="${netcat}"
	    log=""
		echo "--NETWORK MODE SELECTED, PORT ${syslogport}"
            ;;
        l)
            l=${OPTARG}
	    log=${OPTARG}
		echo "--LOG MODE SELECTED, READING FROM ${OPTARG}"
            ;;
        a)
            a=${OPTARG}
	    log=${OPTARG}/*.log
	    all=1
		echo "--ALL MODE SELECTED, READING ALL FROM DIRECTORY ${OPTARG}"
            ;;
        x)
            x=${OPTARG}
	    skip=${OPTARG}
		echo "--EXCLUDING IDs MATCHING: ${OPTARG}"
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [ -z "${l}" ] && [ -z "${a}" ] && [ -z "${n}" ] ; then
    usage
fi


# stats counters
sent=0
fail=0

# test for hepipe
if ! [ $(which hepipe) ]; then
	echo "ERROR: Please install HEPipe (https://github.com/sipcapture/hepipe)";
	exit;
fi

# If needed, check for existance of logs
if [[ $all == 1 ]] || [[ -f $log ]]; then

  #read through the file looking for the Call ID=
  while read line
  do
    echo $line | grep -q ID=
    if [ $? == 0 ]; then
    callid=`echo $line  | grep --line-buffered "ID=" | sed -u -e "s/.*ID=//" | sed -u -e "s/\"//g"`
	if [[ $callid == $skip ]]; then
		#echo " Skipping Call-ID..."
		fail=$[fail + 1];
	elif [[ $line == $skipline ]]; then
		#echo " Skipping Line..."
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

	    ## JSON Version
	    #echo "${ts};${tsu};${callid};${localip};514;${localip};514;{\"log\": \"${message}\"}" | hepipe  -s $hepserver -p $heport -i $hepid -t $heptype

	    ## STRING Version
	    echo "${ts};${tsu};${callid};${localip};${syslogport};${localip};${syslogport};${line}" | hepipe  -s $hepserver -p $heport -i $hepid -t $heptype
	fi
    fi
  done < <($command $log)

fi
