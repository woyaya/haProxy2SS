
LOG_LEVEL=${LOG_LEVEL:-2}

LOG(){
	[ $LOG_LEVEL -ge 3 ] && echo "${EXEC}: $@"
}
WRN(){
	[ $LOG_LEVEL -ge 2 ] && {
		LOG "$@"
		logger -s "${EXEC}: $@"
	}
}
ERR(){
	[ $LOG_LEVEL -ge 1 ] && WRN "$@"
	exit 1
}

wait_childs(){
	local children="$@"
	local EXIT=0
	for job in ${children[@]}; do
		CODE=0;
		wait ${job} || CODE=$?
		LOG "PID ${job} exit code: $CODE"
		[ "${CODE}" != "0" ] && EXIT=1
	done
	return $EXIT
}
