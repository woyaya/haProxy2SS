#!/bin/bash

#haProxy configs
LISTEN_PORT=10801	#haproxy service port
LISTEN_IP=127.0.0.1	#or 0.0.0.0 or something else
SERVER_PORT=20000
PARALLEL_COUNT=100

#common proxy configs
TIMEOUT=1

#common configs
EXEC=`basename $0`
export EXEC

#Dir && files
WORK_DIR=/tmp/$EXEC
SRC_DIR=sources
FUN_DIR=functions
PROTO_DIR=protocols
mkdir -p $WORK_DIR

FUNTIONS="$FUN_DIR/resource_get.sh $FUN_DIR/common.sh"
for file in $FUNTIONS;do
	[ ! -f $file ] && ERR "Can not find file $file"
done

. ./$FUN_DIR/common.sh

function cleanup() {
	LOG "Cleanup $WORK_DIR"
#	rm  -rf $WORK_DIR
}
trap cleanup EXIT

DEPS="curl haproxy logger sed awk uniq sort wc"
#Check deps
for name in $DEPS;do
	EXIST=`which $name 2>/dev/null`
	[ -z "$EXIST" ] && ERR "Can not find $name, install it first"
done
SOURCES=`ls $SRC_DIR/* 2>/dev/null`
[ -z "$SOURCES" ] && ERR "Can not find source file @ dir \"./$SRC_DIR\""

childs=()
resource_list=$WORK_DIR/resource.lst
rm -rf $resource_list
for src in $SOURCES;do
	LOG "Processing $src"
	. $src
	KEY_LIST="KEY TAG URL"
	for chk in $KEY_LIST;do
		eval val="\${$chk}"
		[ -z "$val" ] && ERR "Key \"$chk\" not defined @ $src"
	done
	export DECODE
	$FUN_DIR/resource_get.sh -u "$URL" -k "$KEY" -t "$TAG" -f "$resource_list" &
	childs+=("$!")
done

LOG "Waiting for child(s): ${childs[@]}"
wait_childs ${childs[@]}

#Check if any resource ready
[ -s ${resource_list} ] || ERR "Fail: no resource find"
#Check if resource valid
valid=$WORK_DIR/valid.lst
rm -rf $valid

TIME_OUT=1
for timeout in `seq 1 5`;do
	count=0
	port=$SERVER_PORT
	while read line;do
		PREFIX=`echo "$line" | sed 's/:\/\/.*//'`
		[ ! -f $PROTO_DIR/${PREFIX} ] && {
			LOG "Unsupported protocol \"$PREFIX\""
			continue
		}
		
		index=`expr $port "-" $SERVER_PORT`
		$FUN_DIR/resource_process.sh -c -i $index -l $port -t $timeout -f $valid "$line" &
		count=`expr $count "+" 1`
		[ "$count" -lt $PARALLEL_COUNT ] && {
			port=`expr $port "+" 1`
			continue
		} || {
			wait -n
			port=$?
			port=`expr $SERVER_PORT "+" $port`
		}
	done <$resource_list
	#wait all jobs finished
	wait
	#check valid resource size
	[ -s $valid ] || {
		ERR "Fail: no proxy works in ${timeout}S"
		continue
	}
	LINES=`cat $valid | sed 's/^[0-9]\t//' | sort | uniq | wc -l`
	[ $LINES -ge $SERVER_COUNT ] && break
done

LOG "Get server count and port list from haproxy config file"
set +H
PORT_LIST=`cat /etc/haproxy/haproxy.cfg | sed "s/^[ \t]*//g;/^server/!d;s/.*$LISTEN_IP://;s/ .*//"`
[ -z "$PORT_LIST" ] && ERR "Can not find valid haproxy server info"
PORT_COUNT=`echo $PORT_LIST | wc -w`
FILTER_PARAM=`echo $PORT_LIST | sed 's/ /\\\\|/g'`
KILL_LIST=`sudo netstat -lt4np | grep $FILTER_PARAM | awk '{print $7}' | sed 's/\/.*//'`
cat $valid | sort | sed 's/^[0-9]\t//'  | uniq | head -n $PORT_COUNT >$resource_list
index=0
PORT_ARRAY=($PORT_LIST)
while read line;do
	PORT=${PORT_ARRAY[$index]}
	[ -z "$PORT" ] && break
	$FUN_DIR/resource_process.sh -r -l $PORT "$line" &
	index=`exprt $index "+" 1`
done <$resource_list