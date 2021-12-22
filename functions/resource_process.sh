#!/bin/sh

. ./functions/common.sh

USAGE(){
	echo "Usage: $1 -c -r -i index -l listen -t timeout -f DIST resource"
	echo "     -c: check resource"
	echo "     -r: run with resource"
	echo "     index: parallel job index. default: 0"
	echo "     listen: listen this local port. default: 20001"
	echo "     timeout: timeout time. default: 2S"
	echo "     DIST: saved result to this file if success"
	echo "     resource: check this resource"
	EXIT
}

#Functions
############################
EXIT(){
	exit $index
}
############################
#Chekc params
[ $# = 0 ] && {
	USAGE $0
}

CHECK=""
RUN=""
while getopts ":l:t:f:i:rc" opt; do
	case $opt in
		f)
			DIST=$OPTARG
			shift 2
		;;
		l)
			LISTEN=$OPTARG
			shift 2
		;;
		t)
			TIMEOUT=$OPTARG
			shift 2
		;;
		i)
			index=$OPTARG
			shift 2
		;;
		c)
			CHECK=1
			RUN=""
			shift 1
		;;
		r)
			RUN=1;
			CHECK=""
			shift 1
		;;
		*)
			USAGE $0
		;;
	esac
done

resource="$@"
index=${index:-0}
LISTEN=${LISTEN:-20001}
TIMEOUT=${TIMEOUT:-2}
PROTO_DIR=${PROTO_DIR:-protocols}
URL="http://www.youtube.com/generate_204"
[ -z "$RUN$CHECK" ] && CHECK=1

#Check varables
KEY_LIST="resource"
for chk in $KEY_LIST;do
	eval val="\${$chk}"
	[ -z "$val" ] && EXIT "Key \"$chk\" not defined"
done

PREFIX=`get_prefix "$resource"`
[ ! -f "$PROTO_DIR/$PREFIX" ] && {
	WRN "Unsupport resource: $resource"
	EXIT
}
. $PROTO_DIR/$PREFIX

LOG "Try to parse resource: \"$resource\""
CONTENT=`echo $resource | sed 's/.*:\/\///;s/#.*//;s/ *$//'`
[ -z "$CONTENT" ] && EXIT "Invalid resource: $resource"
TEMP=`echo "$CONTENT" | $DECODER 2>/dev/null`
[ -n "$TEMP" ] && {
	BYTES=`echo -n "$TEMP" | base64 | wc -c`
	CONTENT=$TEMP`echo -n $CONTENT | cut -b ${BYTES}-`
}
DBG "CONTENT:$CONTENT"
#eg:
#	aes-256-gcm:CUndSZnYsPKcu6Kj8THVMBHD@103.156.50.107:39772
for c in $SEPARAT_LIST;do
	CONTENT=`echo $CONTENT | sed "s/$c/ /g"`
done

[ -n "$ALG_INDEX" ] && ALG=`echo $CONTENT | awk "{print \\$\$ALG_INDEX}"`
[ -n "$USR_INDEX" ] && USR=`echo $CONTENT | awk "{print \\$\$USR_INDEX}"`
[ -n "$PASSWD_INDEX" ] && PASSWD=`echo $CONTENT | awk "{print \\$\$PASSWD_INDEX}"`
[ -n "$IP_INDEX" ] && IP=`echo $CONTENT | awk "{print \\$\$IP_INDEX}"`
[ -n "$PORT_INDEX" ] && PORT=`echo $CONTENT | awk "{print \\$\$PORT_INDEX}"`

DBG "IP:$IP PORT:$PORT USR:$USR PASSWD:$PASSWD ALG:$ALG"

. $PROTO_DIR/$PREFIX

#Start server

[ "$CHECK" = "1" ] && {
	echo  "${EXECUTE}"
	${EXECUTE} >/dev/null 2>&1 &
	PID=$!

	TIMES=0
	RETRY=3
	TIME_THRESHOLD=`expr $TIMEOUT "*" $RETRY`
	TIME_THRESHOLD=`expr $TIME_THRESHOLD "*" 1000`

	sleep 0.5
	for i in `seq 1 $RETRY`;do
		BEGIN=`date +"%s%3N"`
		curl --max-time $TIMEOUT -s -x socks5h://127.0.0.1:$LISTEN $URL
		RESULT=$?
		[ "$RESULT" != "0" ] && {
			kill $PID 2>/dev/null
			EXIT
		}
		END=`date +"%s%3N"`
		COST=`expr $END "-" $BEGIN`
		TIMES=`expr $TIMES "+" $COST`
	done
	kill $PID 2>/dev/null
	#take more then 3S, ignore it
	[ $TIMES -gt $TIME_THRESHOLD ] && EXIT
	#TIMES=${TIMES:0-4}
	TIMES=`echo -n "00000$TIMES" | tail -c 5`
	LOG "$TIMES\t$resource"
	echo "$TIMES\t$resource" >>$DIST
}
[ "$RUN" = "1" ] && {
	[ "$DEBUG" != "1" ] && {
		REDIR=">/dev/null 2>&1"
		NOHUP=nohup
	} || {
		REDIR=""
		NOHUP=""
	}
	DBG "${NOHUP} ${EXECUTE} ${REDIR}"
	${NOHUP} ${EXECUTE} >/dev/null 2>&1 &
}

EXIT
