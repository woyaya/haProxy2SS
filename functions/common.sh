
LOG(){
	echo "${EXEC}: $@"
}
WRN(){
	LOG "$@"
	logger -s "${EXEC}: $@"
}
ERR(){
	WRN "$@"
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
