#!/bin/bash

PRESET=$1

source tools/travis-common-vars.sh

# Print ct_progress_hook output
echo "" > /tmp/progress
tail -f /tmp/progress &

# Kill children
trap "trap - SIGTERM && kill -- -$$ 2> /dev/null" SIGINT SIGTERM EXIT

echo ${BASE}

EJD1=${BASE}/dev/mongooseim_node1
EJD2=${BASE}/dev/mongooseim_node2
EJD3=${BASE}/dev/mongooseim_node3
FED1=${BASE}/dev/mongooseim_fed1
EJD1CTL=${EJD1}/bin/mongooseimctl
EJD2CTL=${EJD2}/bin/mongooseimctl
EJD3CTL=${EJD3}/bin/mongooseimctl
FED1CTL=${FED1}/bin/mongooseimctl

NODES=(${EJD1CTL} ${EJD2CTL} ${EJD3CTL} ${FED1CTL})

start_node() {
	echo -n "${1} start: "
	${1} start && echo ok || echo failed
	${1} started
	${1} status
	echo
}

stop_node() {
	echo -n "${1} stop: "
	${1} stop
	${1} stopped
	echo
}

run_tests() {
	SUMMARIES_DIRS=${BASE}'/test/ejabberd_tests/ct_report/ct_run*'

	echo "############################"
	echo "Running embeded common tests"
	echo "############################"

    echo "Use SKIP_SMALL=1 to skip embeded common tests"
	[ "$SKIP_SMALL" = "1" ] || make ct
	
	SMALL_STATUS=$?
    echo ""
    echo "SMALL_STATUS=$SMALL_STATUS"

	echo "############################"
	echo "Running ejabberd_tests"
	echo "############################"


	for node in ${NODES[@]}; do
		start_node $node;
	done

	tools/print-dots.sh start
	make cover_test_preset TESTSPEC=default.spec PRESET=$PRESET
	tools/print-dots.sh stop

	RAN_TESTS=`cat /tmp/ct_count`

	for node in ${NODES[@]}; do
		stop_node $node;
	done

	if [ `uname` = "Darwin" ]; then
		SUMMARIES_DIR=`ls -dt ${SUMMARIES_DIRS} | head -n ${RAN_TESTS}`
	else
		SUMMARIES_DIR=`eval ls -d ${SUMMARIES_DIRS} --sort time | head -n ${RAN_TESTS}`
	fi

	${TOOLS}/summarise-ct-results ${SUMMARIES_DIR}
	BIG_STATUS=$?

	echo
	echo "All tests done."

	if [ $SMALL_STATUS -eq 0 -a $BIG_STATUS -eq 0 ]
	then
		RESULT=0
		echo "Build succeeded"
	else
		RESULT=1
		echo "Build failed:"
		[ $SMALL_STATUS -ne 0 ] && echo "    small tests failed"
		[ $BIG_STATUS -ne 0 ]   && echo "    big tests failed"
	fi

	exit ${RESULT}
}

if [ $PRESET == "dialyzer_only" ]; then
	make dialyzer

else
	run_tests
fi

