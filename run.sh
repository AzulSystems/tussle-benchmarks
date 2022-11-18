#!/bin/bash
#
# Copyright 2021-2022 Azul Systems Inc.  All Rights Reserved.
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name of [project] nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 

#
# Springboot TUSSLE benchmarking script
#

BASE_NAME=$(basename $0)
BASE_DIR=$(cd $(dirname $0); pwd)
BENCHMARK=springboot-bench
SLA_CONFIG_DEF='[[50,1,10000], [99,10,10000], [99.9,50,60000], [99.99,200,120000], [100,1000,120000]]'
SLA_CONFIG=${SLA_CONFIG:-${SLA_CONFIG_DEF}}
TUSSLE_VERSION=${TUSLA_VERSION:-1.4.6}

source "${BASE_DIR}/isv-tools/utils.sh" || exit 1

BENCHMARK_WORKLOAD=
BENCHMARK_PARAMETERS=

SERVER_HOST=${SERVER_HOST:-builtin}
SERVER_PORT=${SERVER_PORT:-8080}

start_server() {
    [[ "${SERVER_HOST}" == builtin ]] && return
    local wrk_dir="${RESULTS_DIR}/node_${SERVER_HOST}"
    mkdir -p "${wrk_dir}" || return 1
    local app_home=$(get_dir "${APPS_DIR}/springboot_tussle")
    install_java "${JAVA_HOME}" "${APP_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    local java_opts=$(preprocess_java_opts "${JAVA_OPTS}" . springboot-tussle)
    local server_log=${wrk_dir}/springboot_server_out.log
    log "Starting Springboot server (${SERVER_HOST}:${SERVER_PORT})..."
    log "  JAVA_HOME: ${java_home}"
    log "  JAVA_OPTS: ${java_opts}"
    (
    cd "${wrk_dir}"
    ${java_home}/bin/java -Dproc.springboot ${java_opts} -jar ${BASE_DIR}/lib/springboot-benchmark-app-${TUSSLE_VERSION}.jar -server -start ${SERVER_PORT} &> "${server_log}" &
    )
    sleep 3
    check_jvm_log "${server_log}" || return 1
    wait_for_port ${SERVER_PORT} Springboot || return 1
    start_monitor_tools "${wrk_dir}"
}

stop_server() {
    [[ "${SERVER_HOST}" == builtin ]] && return
    local wrk_dir="${RESULTS_DIR}/node_${SERVER_HOST}"
    stop_monitor_tools "${wrk_dir}"
    stop_process -f Dproc.springboot
}

springboot_tussle() {
    log "springboot_tussle: [${@}]"
    init_arg_list "${1#*//}"
    local bench_dir="${RESULTS_DIR}/benchmark_0"
    local t=$(get_arg time 60)
    local warmupTime=$(get_arg warmup 20)
    local startingWarmupTime=$(get_arg startWarmup 60)
    local threads=$(get_arg threads 8)
    local retriesMax=$(get_arg retries 2)
    local highBound=$(get_arg highBound 0)
    local startingRatePercent=$(get_arg rateStart 20)
    local finishingRatePercent=$(get_arg rateFinish 110)
    local ratePercentStep=$(get_arg rateStep 5)
    mkdir -p "${bench_dir}" || return 1
    local java_home=${JAVA_HOME}
    local java_opts=${JAVA_OPTS}
    local tussle_spring_jar
    local runner=BasicRunner
    cat<<EOF > "${bench_dir}/benchmark-config.yaml"
threads: ${threads}
EOF
    if [[ "${runner}" == StepRater ]]
    then
        cat<<EOF > "${bench_dir}/tussle-runner-config.yaml"
reportDir: ${RESULTS_DIR}/report
startingWarmupTime: ${startingWarmupTime}
runTime: ${t}
warmupTime: ${warmupTime}
retriesMax: ${retriesMax}
highBound: ${highBound}
startingRatePercent: ${startingRatePercent}
finishingRatePercent: ${finishingRatePercent}
ratePercentStep: ${ratePercentStep}
slaConfig: ${SLA_CONFIG}
EOF
    else
        cat<<EOF > "${bench_dir}/tussle-runner-config.yaml"
reportDir: ${RESULTS_DIR}/report
runTime: ${t}
warmupTime: ${warmupTime}
EOF
    fi
    if [[ "${SERVER_HOST}" == builtin ]]
    then
        tussle_spring_jar=${BASE_DIR}/lib/springboot-benchmark-app-${TUSSLE_VERSION}.jar
        java_opts=$(preprocess_java_opts "${java_opts}" . springboot-tussle)
        start_monitor_tools "${bench_dir}"
        log "Benchmarking built-in Springboot server"
    else
        tussle_spring_jar=${BASE_DIR}/lib/httpclient-benchmark-cli-${TUSSLE_VERSION}.jar
        java_home=${CLIENT_JAVA_HOME}
        java_opts=${CLIENT_JAVA_OPTS}
        java_opts=$(preprocess_java_opts "${java_opts}" . springboot-tussle-client)
        echo "testServer: ${testServer}" >> "${bench_dir}/config.yaml"
        log "Using separate client java for benchmarking external Springboot server '${SERVER_HOST}'"
    fi
    local app_home=$(get_dir "${APPS_DIR}/springboot_tussle")
    install_java "${java_home}" "${APP_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    log "  JAVA_HOME: ${java_home}"
    log "  JAVA_OPTS: ${java_opts}"
    (
    cd "${bench_dir}"
    ${java_home}/bin/java ${java_opts} -jar ${tussle_spring_jar} -f benchmark-config.yaml \
        --runner ${runner} -f tussle-runner-config.yaml
    )
    local res=$?
    [[ "${SERVER_HOST}" == builtin ]] && stop_monitor_tools
    local metrics_json=$(find "${bench_dir}" -name metrics.json)
    [[ -f "${metrics_json}" ]] && get_tussle_scores "${metrics_json}" > "${RESULTS_DIR}/scores.txt"
    return $res
}

var_traps=0

trap_handler() {
    (( var_traps++ ))
    (( var_traps == 1 )) || return
    if [[ -d "${RESULTS_DIR}" ]]
    then
        echo "In trap... ${var_traps}" |& tee -a "${RESULTS_DIR}/run.log"
        stop_server |& tee -a "${RESULTS_DIR}/run.log"
        [[ -f "${RESULTS_DIR}/time_out.log" ]] && log "Stopped" >> "${RESULTS_DIR}/time_out.log" 2>&1
    else
        echo "In trap ${var_traps}..."
        stop_server
    fi
    [[ "${SERVER_HOST}" == builtin ]] && stop_monitor_tools
    exit 1
}

cleanup() {
    local app_home=$(get_dir "${APPS_DIR}/springboot_tussle")
    [[ -d "${app_home}" ]] && cleanup_artifacts "${app_home}"
}

usage() {
    cat<<____EOF
USAGE
$ $(basename "${0}") WORKLOAD
where WORKLOAD 
____EOF
    exit 1
}

main() {
    [[ "${1}" == --help ]] && usage
    log "main: [${@}]"
    mk_res_dir
    log "Start" &> "${RESULTS_DIR}/time_out.log"
    CONFIG=${CONFIG_DEF}
    CONFIG+=" node_${SERVER_HOST}"
    init_workload_name "${1}"
    init_workload_args "${1}"
    create_run_properties "${RESULTS_DIR}"
    trap trap_handler INT QUIT TERM EXIT
    {
    start_server
    springboot_tussle "${1}"
    stop_server
    cleanup
    } |& tee -a "${RESULTS_DIR}/run.log"
    log "Finish" >> "${RESULTS_DIR}/time_out.log" 2>&1
    (( var_traps++ ))
}

if [[ "${BASH_SOURCE}" == "${0}" ]]
then
    process_args "${@}"
    main "${ARGS[@]}"
fi
