#!/bin/bash
#
# Copyright 2021-2021 Azul Systems Inc.  All Rights Reserved.
#
# Please contact Azul Systems, 385 Moffett Park Drive, Suite 115,
# Sunnyvale, CA 94089 USA or visit www.azul.com if you need additional
# information or have any questions.
#
# Springboot TUSLA benchmark runner v1.0
#

BASE_NAME=$(basename $0)
BASE_DIR=$(cd $(dirname $0); pwd)
BENCHMARK=springboot-bench
SLA_CONFIG_DEF='[[50,1,10000], [99,10,10000], [99.9,50,60000], [99.99,200,120000], [100,1000,120000]]'
SLA_CONFIG=${SLA_CONFIG:-${SLA_CONFIG_DEF}}
TUSLA_VERSION=${TUSLA_VERSION:-1.2.3}

source "${BASE_DIR}/tools/utils.sh" || exit 1

BENCHMARK_WORKLOAD=
BENCHMARK_PARAMETERS=

SERVER_HOST=${SERVER_HOST:-builtin}
SERVER_PORT=${SERVER_PORT:-8080}

start_server() {
    [[ "${SERVER_HOST}" == builtin ]] && return
    local wrk_dir="${RESULTS_DIR}/node_${SERVER_HOST}"
    mkdir -p "${wrk_dir}" || return 1
    local app_home=$(get_dir "${APPS_DIR}/springboot_tusla")
    install_java "${JAVA_HOME}" "${APP_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    local java_opts=$(preprocess_java_opts "${JAVA_OPTS}" . springboot-tusla)
    local server_log=${wrk_dir}/springboot_server_out.log
    log "Starting Springboot server (${SERVER_HOST}:${SERVER_PORT})..."
    log "  JAVA_HOME: ${java_home}"
    log "  JAVA_OPTS: ${java_opts}"
    (
    cd "${wrk_dir}"
    ${java_home}/bin/java -Dproc.springboot ${java_opts} -jar ${BASE_DIR}/lib/springboot-benchmark-app-${TUSLA_VERSION}.jar -start ${SERVER_PORT} &> "${server_log}" &
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

springboot_tusla() {
    log "springboot_tusla: [${@}]"
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
    local tus_spring_jar
    cat<<EOF > "${bench_dir}/config.yaml"
reportDir: ${RESULTS_DIR}/report
slaConfig: ${SLA_CONFIG}
startingWarmupTime: ${startingWarmupTime}
warmupTime: ${warmupTime}
retriesMax: ${retriesMax}
time: ${t}
threads: ${threads}
highBound: ${highBound}
startingRatePercent: ${startingRatePercent}
finishingRatePercent: ${finishingRatePercent}
ratePercentStep: ${ratePercentStep}
EOF
    if [[ "${SERVER_HOST}" == builtin ]]
    then
        tus_spring_jar=${BASE_DIR}/lib/springboot-benchmark-app-${TUSLA_VERSION}.jar
        java_opts=$(preprocess_java_opts "${java_opts}" . springboot-tusla)
        start_monitor_tools "${bench_dir}"
        log "Benchmarking built-in Springboot server"
    else
        tus_spring_jar=${BASE_DIR}/lib/tusla-springboot-cli-${TUSLA_VERSION}.jar
        java_home=${CLIENT_JAVA_HOME}
        java_opts=${CLIENT_JAVA_OPTS}
        java_opts=$(preprocess_java_opts "${java_opts}" . springboot-tusla-client)
        echo "testServer: ${testServer}" >> "${bench_dir}/config.yaml"
        log "Using separate client java for benchmarking external Springboot server '${SERVER_HOST}'"
    fi
    local app_home=$(get_dir "${APPS_DIR}/springboot_tusla")
    install_java "${java_home}" "${APP_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    log "  JAVA_HOME: ${java_home}"
    log "  JAVA_OPTS: ${java_opts}"
    (
    cd "${bench_dir}"
    ${java_home}/bin/java ${java_opts} -jar ${tus_spring_jar} config.yaml
    )
    local res=$?
    [[ "${SERVER_HOST}" == builtin ]] && stop_monitor_tools
    local metrics_json=$(find "${bench_dir}" -name metrics.json)
    [[ -f "${metrics_json}" ]] && get_tusla_scores "${metrics_json}" > "${RESULTS_DIR}/scores.txt"
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
    local app_home=$(get_dir "${APPS_DIR}/springboot_tusla")
    [[ -d "${app_home}" ]] && cleanup_artifacts "${app_home}"
}

main() {
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
    springboot_tusla "${1}"
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
