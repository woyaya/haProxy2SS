#!/bin/sh

. ./functions/common.sh

USAGE(){
	echo "Usage: $1 -u URL -k KEY -t TAG -d DECODE -f DIST_FILE"
	echo "     URL: resource URL"
	echo "     KEY: KEY of resource"
	echo "     TAG: html TAG of resouce"
	echo "     DECODE: decode mathod"
	echo "     DIST_FILE: resource saved to this file"
	exit 1
}

#Functions
cleanup(){
	[ "$DEBUG" != "1" ] && rm -rf $PREFIX.dec $PREFIX.src
}

#Usage: SRC_GET FILE_NAME [CURL PARAM]
SRC_GET(){
	FILE="$1"
	PARAM="$2"
	local TYPE=`get_prefix "$URL"`
	echo "Download resource from $URL"
	[ "$TYPE" = "file" ] && {
		URL=`echo "$URL" | sed "s/.*:\/\///"`
		[ ! -f $URL ] && ERR "Can not find source file: $URL"
		cp -u $URL $FILE
		return 0
	}
	[ -z "$KEY$TAG" ] && {
		curl --max-filesize 2M -s $PARAM $URL >$FILE
	} || {
		[ -z "$KEY" -o -z "$TAG" ] && ERR "Both \"KEY\" and \"TAG\" should define"
		#eg:
		#  sed -e '/SS节点/,/<\/pre>/!d;/<pre>/,/<\/pre>/!d;s/.*<pre>//;s/<\/pre>.*//'
		SED_CMD="/$KEY/,/<\/$TAG>/!d;/<$TAG>/,/<\/$TAG>/!d;s/.*<$TAG>//;s/<\/$TAG>.*//"
		curl --max-filesize 2M -s $PARAM $URL | sed -e "${SED_CMD}" >$FILE
	}
	#check file size
	[ ! -s $FILE ] && return 1
	#Check if URL
	URL=`cat $FILE | head -n 1`
	IS_URL=`get_prefix "$URL"`
	[ -z "${IS_URL}" ] && return 0
	[ "${IS_URL}" != "http" -a "${IS_URL}" != "https" ] && return 0
	#Download from URL
	DBG "curl --max-filesize 2M -s $PARAM $URL >$FILE"
	curl --max-filesize 2M -s $PARAM $URL >$FILE
}
#Usage: SRC_DECODE source_file_name dist_file_name
SRC_DECODE(){
	SRC="$1"
	DST="$2"
	echo "Try decode $SRC with decoder \"$DECODE\""
	[ -z "$DECODE" -o "$DECODE" = "none" ] && cp $SRC $DST || {
		echo "cat $SRC | $DECODE >$DST"
		cat $SRC | $DECODE >$DST
	}
}
############################
#Chekc params
[ $# = 0 ] && {
	USAGE $0
}

while getopts ":f:k:t:u:d:" opt; do
	case $opt in
		f)
			DIST=$OPTARG
		;;
		k)
			KEY=$OPTARG
		;;
		t)
			TAG=$OPTARG
		;;
		u)
			URL=$OPTARG
		;;
		d)
			echo "$OPTARG"
			DECODE=$OPTARG
		;;
		*)
			USAGE $0
		;;
	esac
done

#Check varables
#KEY_LIST="KEY TAG URL DECODE"
KEY_LIST="URL"
for chk in $KEY_LIST;do
	eval val="\${$chk}"
	[ -z "$val" ] && ERR "Key \"$chk\" not defined"
done

EXEC=${EXEC:-`basename $0`}
WORK_DIR=${WORK_DIR:-/tmp/$EXEC}
PREFIX=${PREFIX:-$WORK_DIR/$$-$EXEC}
mkdir -p $WORK_DIR

trap cleanup EXIT

LOG "Try get resource from $URL, with key \"$KEY\" and tag \"$TAG\""
SRC_GET "$PREFIX.src"
[ "$?" != "0" ] && {
	WRN "Get resource fail, try get it via proxy"
	SRC_GET "$PREFIX.src" "-x socks5h://127.0.0.1:$LISTEN_PORT"
	[ "$?" != "0" ] && ERR "Get resource from $URL fail"
}
SRC_DECODE $PREFIX.src $PREFIX.dec
[ "$?" != 0 ] && ERR "Decode resource from $URL fail: $PREFIX.src"
cat $PREFIX.dec >>${DIST}
