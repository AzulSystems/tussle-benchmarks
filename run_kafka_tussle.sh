#!/bin/bash
#
# Copyright (c) 2018-2023 Azul Systems
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
# Kafka utils and benchmarks package
#

[[ "${DEBUG}" == true ]] && echo "BASH_SOURCE ${BASH_SOURCE[@]}"

BASE_NAME=$(basename $0)
BASE_DIR=$(cd $(dirname $0); pwd)
BENCHMARK=kafka-bench
SLE_CONFIG_DEF="[[50,5,10],[99,10,10],[99,20,10],[99.9,20,60],[99.9,50,60],[99.99,200,300],[100,1000,300]]"
SLE_CONFIG=${SLE_CONFIG:-${SLE_CONFIG_DEF}}
TUSSLE_VERSION=${TUSSLE_VERSION:-1.4.7}

source "${BASE_DIR}/isv-tools/kafka-utils.sh" || exit 1

BENCHMARK_WORKLOAD=
BENCHMARK_PARAMETERS=
var_benchmark_step=0

run_consumers() {
    local factor=${1:-1000}
    local N=${2:-3}
    local start=${3:-1}
    local end=${4:-8}
    local size=${5:-100}
    log "Consumers: $factor $N $start $end"
    local topic=testP${end}R1
    create_topic $topic $end 1
    perf_producer $topic $((1000*factor)) $size -1 1
    perf_producer $topic $((1000*factor)) $size -1 0
    perf_producer $topic $((1000*factor)) $size -1 1
    for (( i = 1; i <= N; i++ ))
    do
        for (( t = start; t <= end; t *= 2 ))
        do
            perf_consumer $topic $((1000*factor)) $t
        done
    done
}

run_linkedin1() {
    init_arg_list "${@}"
    local factor=$(get_arg factor 1000)
    local short=$(get_arg short false)
    local parts=$(get_arg parts 1)
    local rf=$(get_arg rf 1) # replication-factor
    log "Linkedin: ${@}"
    create_topic test61 6 1
    create_topic test6N 6 ${rf}
    perf_producer test61 $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    perf_producer test6N $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    perf_producer test6N $((50000*factor)) 100 -1 0 buffer.memory=67108864 batch.size=64000
    perf_producer test6N $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    is_true "$short" && return
#    log "Throughput Versus Stored Data"
#    perf_producer test $((50000000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    for i in 10 100 1000 10000 100000
    do
        log "# Effect of message size $i"
        perf_producer test61 $((factor*1024*1024/$i)) $i -1 1 buffer.memory=67108864 batch.size=128000
    done
    perf_consumer test61 $((50000*factor)) 1
    perf_end2end test61 $((100*factor)) 100 1
    perf_producer test6N $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    perf_consumer test6N $((50000*factor)) 1
    perf_end2end test6N $((100*factor)) 100 1
    perf_consumer test61 $((50000*factor)) 2
    perf_consumer test6N $((50000*factor)) 2
    perf_producer test61 $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    perf_producer test6N $((50000*factor)) 100 -1 1 buffer.memory=67108864 batch.size=8196
    perf_consumer test61 $((50000*factor)) 4
    perf_consumer test6N $((50000*factor)) 4
}

perf_simple() {
    install_kafka_client || return 1
    log "perf_simple: [${@}]"
    init_arg_list "${@}"
    mk_res_dir
    local factor=$(get_arg factor 1)
    local threads=$(get_arg threads 1)
    local size=$(get_arg size 1000)
    local topic=testP${threads}R1
    create_topic $topic $threads 1
    perf_producer $topic $((1000*factor)) $size -1 1
    perf_consumer $topic $((1000*factor)) $threads
    perf_consumer $topic $((1000*factor)) $threads
}

make_kafka_config() {
    log "make_kafka_config: [${@}]"
    local config_file=$1
    local brokers=$(get_brokers_with_ports ${NODES})
    local nodes=( $(print_nodes ${NODES}) )
    local num_nodes=${#nodes[@]}
    local topic=$(get_arg topic test)
    local acks=$(get_arg acks 1)
    local rf=$(get_arg rf 1)
    local topics=$(get_arg topics 1)
    local partitions=$(get_arg partitions ${num_nodes})
    local producers=$(get_arg producers ${num_nodes})
    local consumers=$(get_arg consumers ${num_nodes})
    local compression=$(get_arg compression null)
    local topicCompression=$(get_arg topicCompression null)
    local batchSize=$(get_arg batchSize 0)
    local lingerMs=$(get_arg lingerMs -1)
    local idempotence=$(get_arg idempotence false)
    local probeTopic=$(get_arg probeTopic false)
    local messageLength=$(get_arg mlen 1024)
    local messageLengthMax=$(get_arg mlenMax 0)
    local wd=$(get_arg wd 10)
    local rt=$(get_arg rt -1)
    local pt=$(get_arg pt 10000)
    local throttleMode=$(get_arg throttleMode null)
    local retentionMs=$(get_arg retentionMs -1)
    local retentionBytes=$(get_arg retentionBytes -1)
    local insyncReplicas=$(get_arg insyncReplicas -1)
    cat <<EOF > "${config_file}"
brokerList: ${brokers}
topic: ${topic}
topics: ${topics}
partitions: ${partitions}
replicationFactor: ${rf}
acks: ${acks}
producers: ${producers}
consumers: ${consumers}
batchSize: ${batchSize}
lingerMs: ${lingerMs}
compression: ${compression}
topicCompression: ${topicCompression}
idempotence: ${idempotence}
probeTopics: ${probeTopic}
messageLength: ${messageLength}
messageLengthMax: ${messageLengthMax}
waitAfterDeleteTopic: ${wd}
requestTimeoutMs: ${rt}
pollTimeoutMs: ${pt}
throttleMode: ${throttleMode}
retentionMs: ${retentionMs}
retentionBytes: ${retentionBytes}
minInsyncReplicas: ${insyncReplicas}
EOF
}

kafka_e2e() {
    install_kafka_client || return 1
    log "kafka_e2e: [${@}]"
    init_arg_list "${@}"
    mk_res_dir
    log "  Client JAVA_HOME: ${var_java_home}"
    local brokers=$(get_brokers_with_ports ${NODES})
    local nodes=( $(print_nodes ${NODES}) )
    local num_nodes=${#nodes[@]}
    local time=$(get_arg time 60)
    local warmupTime=$(get_arg warmup 0)
    local targetRate=$(get_arg targetRate 1k)
    local runSteps=$(get_arg steps 1)
    local bench_dir="${RESULTS_DIR}/benchmark_${var_benchmark_step}"
    mkdir -p "${bench_dir}" || return 1
    make_kafka_config "${bench_dir}/kafka-config.yaml"
    cat<<EOF > "${bench_dir}/tussle-runner-config.yaml"
reportDir: ../report
runTime: ${time}
runSteps: ${runSteps}
warmupTime: ${warmupTime}
targetRate: ${targetRate}
EOF
    local java_opts=$(preprocess_java_opts "${CLIENT_JAVA_OPTS}" . kafka-e2e-benchmark)
    log "  CLIENT_JAVA_OPTS: ${CLIENT_JAVA_OPTS}"
    log "  CLIENT_JAVA_OPTS expanded: ${java_opts}"
    (
    cd "${bench_dir}"
    ${var_java_home}/bin/java ${java_opts} -Duser.timezone=UTC -jar ${BASE_DIR}/isv-tools/kafka-benchmark-${TUSSLE_VERSION}.jar -f kafka-config.yaml \
        --runner BasicRunner -f tussle-runner-config.yaml
    )
}

kafka_scn() {
    install_kafka_client || return 1
    log "kafka_scn: [${@}]"
    init_arg_list "${@}"
    mk_res_dir
    log "  Client JAVA_HOME: ${var_java_home}"
    local brokers=$(get_brokers_with_ports ${NODES})
    local nodes=( $(print_nodes ${NODES}) )
    local num_nodes=${#nodes[@]}
    local scenario=$(get_arg scenario)
    local def=$(get_arg def)
    local bench_dir="${RESULTS_DIR}/benchmark_${var_benchmark_step}"
    mkdir -p "${bench_dir}" || return 1
    make_kafka_config "${bench_dir}/kafka-config.yaml"
    cat<<EOF > "${bench_dir}/tussle-runner-config.yaml"
reportDir: ../report
scenario: ${scenario}
def: ${def}
EOF
    local java_opts=$(preprocess_java_opts "${CLIENT_JAVA_OPTS}" . kafka-scn-benchmark)
    log "  CLIENT_JAVA_OPTS: ${CLIENT_JAVA_OPTS}"
    log "  CLIENT_JAVA_OPTS expanded: ${java_opts}"
    (
    cd "${bench_dir}"
    ${var_java_home}/bin/java ${java_opts} -Duser.timezone=UTC -jar ${BASE_DIR}/isv-tools/kafka-benchmark-${TUSSLE_VERSION}.jar -f kafka-config.yaml \
        --runner ScenarioRunner -f tussle-runner-config.yaml
    )
}

get_tussle_scores() {
    local json=${1}
    local names=$($jq -r '.metrics[] | select(.name == ''"conforming rate"'') | .operation' "${json}" | sed "s| |_|g;")
    local units=$($jq -r '.metrics[] | select(.name == ''"conforming rate"'') | .units' "${json}")
    local values=$($jq -r '.metrics[] | select(.name == ''"conforming rate"'') | .value' "${json}")
    names=( ${names[@]} )
    units=( ${units[@]} )
    values=( ${values[@]} )
    local n=${#names[@]}
    local name
    local value
    local unit
    for (( i = 0; i < n ; i++ ))
    do
        #echo "$i: ${names[i]} = ${values[i]} ${units[i]}"
        name=$(echo ${names[i]} | sed "s|\\.0$||; s|_(unbroken)||; s|(serv)|serv|; s|(resp)|resp|; ")
        value=$(echo ${values[i]})
        unit=$(echo ${units[i]})
        echo "Score on ConformingRate_${name}: ${value} ${unit}"
    done
    value=$($jq -r '.metrics[] | select(.name == ''"high bound"'') | .value' "${json}")
    unit=$($jq -r '.metrics[] | select(.name == ''"high bound"'') | .units' "${json}")
    echo "Score on HighBound: ${value} ${unit}"
    value=$($jq -r '.metrics[] | select(.name == ''"max rate"'') | .value' "${json}")
    unit=$($jq -r '.metrics[] | select(.name == ''"max rate"'') | .units' "${json}")
    echo "Score on MaxRate: ${value} ${unit}"
}

kafka_tussle() {
    install_kafka_client || return 1
    log "kafka_tussle: [${@}]"
    init_arg_list "${@}"
    mk_res_dir
    log "  Client JAVA_HOME: ${var_java_home}"
    local brokers=$(get_brokers_with_ports ${NODES})
    local nodes=( $(print_nodes ${NODES}) )
    local num_nodes=${#nodes[@]}
    local time=$(get_arg time 60)
    local warmupTime=$(get_arg warmup 0)
    local highBound=$(get_arg highBound 0)
    local highBoundOnly=$(get_arg hbOnly false)
    local initialWarmupTime=$(get_arg startWarmup 20)
    local initialTargetRate=$(get_arg startTarget 1k)
    local startingRatePercent=$(get_arg rateStart 50)
    local finishingRatePercent=$(get_arg rateFinish 110)
    local rateStepPercent=$(get_arg rateStep 10)
    local retriesMax=$(get_arg retries 2)
    local bench_dir="${RESULTS_DIR}/benchmark_${var_benchmark_step}"
    mkdir -p "${bench_dir}" || return 1
    make_kafka_config "${bench_dir}/kafka-config.yaml"
    cat<<EOF > "${bench_dir}/tussle-runner-config.yaml"
runTime: ${time}
warmupTime: ${warmupTime}
initialWarmupTime: ${initialWarmupTime}
initialTargetRate: ${initialTargetRate}
highBound: ${highBound}
highBoundOnly: ${highBoundOnly}
retriesMax: ${retriesMax}
startingRatePercent: ${startingRatePercent}
finishingRatePercent: ${finishingRatePercent}
rateStepPercent: ${rateStepPercent}
sleConfig: ${SLE_CONFIG}
histogramsDir: ${bench_dir}/histograms
reportDir: ${bench_dir}/report
makeReport: true
EOF
    local java_opts=$(preprocess_java_opts "${CLIENT_JAVA_OPTS}" . kafka-tussle-steprater)
    log "  CLIENT_JAVA_OPTS: ${CLIENT_JAVA_OPTS}"
    log "  CLIENT_JAVA_OPTS expanded: ${java_opts}"
    (
    cd "${bench_dir}"
    ${var_java_home}/bin/java ${java_opts} -Duser.timezone=UTC -jar ${BASE_DIR}/isv-tools/kafka-benchmark-${TUSSLE_VERSION}.jar -f kafka-config.yaml \
        --runner StepRater -f tussle-runner-config.yaml
    )
    local metrics_json=$(find "${bench_dir}" -name metrics.json)
    [[ -f "${metrics_json}" ]] && get_tussle_scores "${metrics_json}" > "${RESULTS_DIR}/scores.txt"
}

kafka_omb() {
    install_kafka_client || return 1
    install_omb || return 1
    local step=$1
    shift
    local ipar_ignore=$1
    shift
    init_arg_list "${@}"
    local kafka_test_name=kafka-omb
    log "[${kafka_test_name}] ${step} args: [${@}]"
    mk_res_dir
    log "  Client JAVA_HOME: ${var_java_home}"
    local brokers=$(get_brokers_with_ports ${NODES})
    local nodes=( $(print_nodes ${NODES}) )
    local num_nodes=${#nodes[@]}
    local testDurationMinutes=$(get_arg time 60)
    testDurationMinutes=$(parse_time $testDurationMinutes)
    testDurationMinutes=$((testDurationMinutes / 60))
    local warmupDurationMinutes=$(get_arg warmup 0)
    warmupDurationMinutes=$(parse_time $warmupDurationMinutes)
    warmupDurationMinutes=$((warmupDurationMinutes / 60))
    local targetRate=$(parse_value $(get_arg targetRate 1k))
    targetRate=$(parse_value $targetRate)
    local acks=$(get_arg acks 1)
    local rf=$(get_arg rf 1)
    local topics=$(get_arg topics 1)
    local partitions=$(get_arg partitions ${num_nodes})
    local producers=$(get_arg producers ${num_nodes})
    local subscriptions=$(get_arg subscriptions 1)
    local consumers=$(get_arg consumers 1)
    local messageLength=$(get_arg mlen 1024)
    local batchSize=$(get_arg batchSize 0)
    local lingerMs=$(get_arg lingerMs 0)
    local autoOffset=$(get_arg autoOffset earliest)
    local autoCommit=$(get_arg autoCommit true)
    local insyncReplicas=$(get_arg insyncReplicas 1)
    local idempotence=$(get_arg idempotence false)
    local fetchBytes=$(get_arg fetchBytes 10485760)
    local bench_dir="${RESULTS_DIR}/benchmark_${var_benchmark_step}"
    mkdir -p "${bench_dir}" || return 1
    cat<<EOF > "${bench_dir}/driver.yaml"
name: OMB-${step}
driverClass: io.openmessaging.benchmark.driver.kafka.KafkaBenchmarkDriver
# Kafka client-specific configuration
replicationFactor: ${rf}
reset: true
topicConfig: |
  min.insync.replicas=${insyncReplicas}
commonConfig: |
  bootstrap.servers=${brokers}
  request.timeout.ms=120000
producerConfig: |
  max.in.flight.requests.per.connection=1
  enable.idempotence=${idempotence}
  batch.size=${batchSize}
  linger.ms=${lingerMs}
  retries=2147483647
  acks=${acks}
consumerConfig: |
  max.partition.fetch.bytes=${fetchBytes}
  enable.auto.commit=${autoCommit}
  auto.offset.reset=${autoOffset}
EOF
    local payload_file=payload-${messageLength}b.data
    > "${bench_dir}/${payload_file}"
    for (( n = 0; n < messageLength; n++ ))
    do
        echo -n 'Z' >> "${bench_dir}/${payload_file}"
    done
    cat<<EOF > "${bench_dir}/workload.yaml"
name: ${step} / ${topics} topic(s) / ${partitions} partition(s) / ${messageLength}b
topics: ${topics}
messageSize: ${messageLength}
payloadFile: ${payload_file}
partitionsPerTopic: ${partitions}
subscriptionsPerTopic: ${subscriptions}
consumerPerSubscription: ${consumers}
producersPerTopic: ${producers}
producerRate: ${targetRate}
consumerBacklogSizeGB: 0
warmupDurationMinutes: ${warmupDurationMinutes}
testDurationMinutes: ${testDurationMinutes}
EOF
    cat<<EOF > "${bench_dir}/log4j2.yaml"
Configuration:
  status: INFO
  name: messaging-benchmark
  Appenders:
    Console:
      name: Console
      target: SYSTEM_OUT
      PatternLayout:
        Pattern: "%d{yyyy-MM-dd HH:mm:ss.SSS},UTC [%t] %-4level %c{1} - %msg%n"
    RollingFile:
      name: RollingFile
      fileName: benchmark-worker.log
      filePattern: benchmark-worker.log.%d{yyyy-MM-dd-hh-mm-ss}.gz
      PatternLayout:
        Pattern: "%d{yyyy-MM-dd HH:mm:ss.SSS},UTC [%t] %-4level %c{1} - %msg%n"
      Policies:
        SizeBasedTriggeringPolicy:
          size: 100MB
      DefaultRollOverStrategy:
        max: 10
  Loggers:
    Root:
      level: info
      additivity: false
      AppenderRef:
        - ref: Console
        - ref: RollingFile
EOF
    local omb_args="--drivers driver.yaml workload.yaml"
    local worker_list
    if [[ -n "${WORKER_NODES}" ]]
    then
        worker_list=$(get_servers_with_ports "${OMB_WORKER_PORT}" "${WORKER_NODES}" "," "http://")
        log "Stating workers: ${WORKER_NODES} -- ${worker_list} ..."
        nodes_cmd start_omb_worker "${WORKER_NODES}" true || return 1
        omb_args+=" --workers ${worker_list}"
    fi
    local java_opts=$(preprocess_java_opts "${CLIENT_JAVA_OPTS}" . kafka-omb)
    java_opts+=" -Dlog4j2.configurationFile=log4j2.yaml"
    log "  CLIENT_JAVA_OPTS: ${CLIENT_JAVA_OPTS}"
    log "  CLIENT_JAVA_OPTS expanded: ${java_opts}"
    (
    cd "${bench_dir}"
    ${var_java_home}/bin/java ${java_opts} -Duser.timezone=UTC -server -cp "${var_omb_home}/lib/*" io.openmessaging.benchmark.Benchmark ${omb_args}
    )
    if [[ -n "${WORKER_NODES}" ]]
    then
        log "Stopping workers: ${WORKER_NODES} ..."
        nodes_cmd stop_omb_worker "${WORKER_NODES}" false
    fi
    log "[${kafka_test_name}] ${step}:  FINISHED" 
}

init_workload() {
    log "init_workload: '${1}'"
    init_workload_name "${1}"
    init_workload_args "${1}"
    local b=${BENCHMARK_WORKLOAD}
    if [[ "${b}" == kafka_tussle || "${b}" == kafka_e2e || "${b}" == kafka_scn || "${b}" == kafka_omb || "${b}" == perf_simple || "${b}" == perf_end2end || "${b}" == perf_consumer || "${b}" == perf_producer ]]
    then
        return 0
    fi
    log "Unknown workload: ${BENCHMARK_WORKLOAD}!"
    return 1
}

run_workload() {
    init_workload "${1}" || return 1
    local b=${BENCHMARK_WORKLOAD}
    if [[ "${b}" == kafka_tussle || "${b}" == kafka_e2e || "${b}" == kafka_scn ]]
    then
        log "Running workload: ${BENCHMARK_WORKLOAD} [${BENCHMARK_PARAMETERS}]..."
        ${BENCHMARK_WORKLOAD} ${BENCHMARK_PARAMETERS}
        (( var_benchmark_step++ ))
    else
        local par=$(get_arg par 0)
        local del=$(get_arg del true)
        local steps=$(get_arg steps 1)
        local topic=$(get_arg topic testtopic)
        local create=$(get_arg create true)
        if [[ "${b}" == kafka_omb ]]
        then
            create=false
            del=false
        fi
        local step
        for (( step = 1; step <= steps; step++ ))
        do
            if is_true "${create}"
            then
                create_topic ${BENCHMARK_PARAMETERS} || return 1
            fi
            if (( par > 1 ))
            then
                local pids=()
                for (( ipar = 1; ipar <= par; ipar++ ))
                do
                    log "Starting workload in parallel: ${BENCHMARK_WORKLOAD} [${BENCHMARK_PARAMETERS}] (step #${step}, ipar #${ipar})..."
                    ${BENCHMARK_WORKLOAD} ${step} ${ipar} ${BENCHMARK_PARAMETERS} &
                    pids+=( $! )
                done
                log "Waiting for parallel tests to finish: ${pids[@]}..."
                wait ${pids[@]}
                log "Wait done"
            else
                log "Running workload: ${BENCHMARK_WORKLOAD} [${BENCHMARK_PARAMETERS}] (step #${step})..."
                ${BENCHMARK_WORKLOAD} ${step} 1 ${BENCHMARK_PARAMETERS}
            fi
            if is_true "${del}"
            then
                delete_topic "${topic}" || break
            else
                create=false
            fi
            (( var_benchmark_step++ ))
        done
    fi
}

run_workloads() {
    local monitors_started=false
    if ! check_monitors
    then
        local bench_dir="${RESULTS_DIR}/benchmark_${var_benchmark_step}"
        mkdir -p "${bench_dir}" || return 1
        start_monitors "${bench_dir}"
        monitors_started=true
    fi
    while [[ -n "${1}" ]]
    do
        run_workload "${1}" || return 1
        shift
    done
    ${monitors_started} && stop_monitors
    return
} 

var_traps=0

trap_handler() {
    (( var_traps++ ))
    (( var_traps == 1 )) || return
    if [[ -d "${RESULTS_DIR}" ]]
    then
        {
        echo "In trap... ${var_traps}"
        finish_kafka
        } |& tee -a "${RESULTS_DIR}/run.log"
        [[ -f "${RESULTS_DIR}/time_out.log" ]] && log "Stopped" &>> "${RESULTS_DIR}/time_out.log"
    else
        echo "In trap ${var_traps}..."
        stop_kafka
    fi
    exit 1
}

par_add_nodes() {
    local delay=${1}
    shift
    local nodes=${@}
    nodes=( $(print_nodes ${nodes}) )
    local node
    local brokers=""
    for node in "${nodes[@]}"
    do
        log "[par_job] Sleeping ${delay}s..."
        sleep "${delay}"
        log "Starting new node: ${node}..."
        start_kafka_node "${node}" 1
    done
    echo ${brokers}
}

start_par_job() {
    [[ -n "${PAR_JOB}" ]] || return
    log "Starting parallel job: par_${PAR_JOB//,/ }..."
    par_${PAR_JOB//,/ } &> "${RESULTS_DIR}/parallel_job.log" &
    PAR_PID=$!
}

stop_par_job() {
    [[ -n "${PAR_PID}" ]] || return
    log "Stopping parallel job (pid: ${PAR_PID})..."
    kill "${PAR_PID}"
    sleep 1
    kill -9 "${PAR_PID}"
    unset PAR_PID
}

run() {
    log "run: [${@}]"
    init_workload "${1}" || return 1
    mk_res_dir
    logt "${START_TIME}" "Start" &> "${RESULTS_DIR}/time_out.log"
    CONFIG=${CONFIG_DEF}
    [[ -n "${KAFKA_PROPS}" ]] && CONFIG+=" ${KAFKA_PROPS}"
    [[ -n "${PRE_CMD}" ]] && CONFIG+=" ${PRE_CMD// /_}"
    create_run_properties "${RESULTS_DIR}"
    stop_kafka # delete previous Kafka setup
    trap trap_handler INT QUIT TERM EXIT
    {
        if start_kafka
        then
            start_par_job
            log --------------------------------------------------
            log ---------------- RUNNING WORKLOAD ----------------
            log --------------------------------------------------
            run_workloads "${@}"
            stop_par_job
        fi
        finish_kafka
    } |& tee -a "${RESULTS_DIR}/run.log"
    log "Finish" &>> "${RESULTS_DIR}/time_out.log"
    (( var_traps++ ))
}

init_and_start_kafka() {
    mk_res_dir
    start_kafka |& tee "${RESULTS_DIR}/start_kafka.log"
}

test_args() {
    log TEST ARGS
    init_workload "${1}"
    mk_res_dir
    create_run_properties "${RESULTS_DIR}"
}

if [[ "${BASH_SOURCE}" == "${0}" ]]
then
    process_args "${@}"
    init_java_opts
    init_kafka_options
    if [[ "${ARGS[0]}" == *//* ]]
    then
        p=${ARGS[0]}
        ${p%//*} ${p#*//}
    else
        "${ARGS[@]}"
    fi
fi
