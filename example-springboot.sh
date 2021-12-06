#!/bin/bash

BASE_DIR=$(cd $(dirname $0); pwd)
RESULTS_DIR=${RESULTS_DIR:-"$(pwd)/results_$(date -u '+%Y%m%d_%H%M%S')"}

echo "JAVA_HOME: ${JAVA_HOME?Missing JAVA_HOME}"

mkdir -p "${RESULTS_DIR}" || exit 1
cd "${RESULTS_DIR}"

${JAVA_HOME}/bin/java -jar ${BASE_DIR}/lib/springboot-benchmark-app-*.jar rawData=true makeReport=true "${@}"
