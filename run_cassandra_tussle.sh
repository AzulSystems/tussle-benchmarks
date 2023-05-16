#!/bin/bash
#
# Cassandra benchmark runner
#

BASE_DIR=$(cd $(dirname $0); pwd -P)
RUN_CMD=$(readlink -f $0)
BENCHMARK=cassandra-bench

source "${BASE_DIR}/tools/cassandra-utils.sh" || exit 1

BENCHMARK_WORKLOAD=
BENCHMARK_PARAMETERS=

process_args "${@}"
init_java_opts
make_abs_pathes

YCSB_HOME=${YCSB_HOME:-"ycsb-0.14.0"}
YCSB_JAVA_HOME=${YCSB_JAVA_HOME:-"zing20.08.0.0-4-jdk8.0.265-linux_x64"}
YCSB_JAVA_OPTS=${YCSB_JAVA_OPTS:-"-Xmx16g -Xms16g __JHICCUP__"}
YCSB_HOME_INSTALLED=false
YCSB_JAVA_HOME_INSTALLED=false
USE_HDR=${USE_HDR:-true}
COMPRESSION=${COMPRESSION:-false}
CLEANUP_DATA=${CLEANUP_DATA:-true}
RESTART_VM=${RESTART_VM:-true}
DIST_DIR=${DIST_DIR:-/home/dolphin/perflab-runner-artifacts/dist}
TLP_STRESS_HOME=${TLP_STRESS_HOME:-"tlp-stress-4.0.0m5"}
TLP_STRESS_HOME_INSTALLED=false
SCORES_FILE=${RESULTS_DIR}/scores.txt
SCORES_JSON=${RESULTS_DIR}/scores.json
SCENARIO=false
CQL_VER=
SLE_CONFIG=${SLE_CONFIG:-'[[50,1,10],[99,10,10],[99.9,50,60],[99.99,200,120],[100,1000,120]]'}

setup_cassandra_options

log JAVA_HOME=${JAVA_HOME:? Missing JAVA_HOME parameter}
#log JAVA_VERSION=${JAVA_VERSION:? Missing JAVA_VERSION parameter}
log MASTER_NODE=${MASTER_NODE:? Missing MASTER_NODE parameter}
log MASTER_PORT=${MASTER_PORT:? Missing MASTER_PORT parameter}

test -d ${JAVA_HOME} || fail "JAVA_HOME (${JAVA_HOME}) dir not found!"

print_node_info() {
    [[ "${USE_NODETOOL}" == true ]] || return 0
    local nodetool_log="${RESULTS_DIR}/nodetool.log"
    local title=$1
    log "Nodetool status at ${MASTER_NODE} $title..."
    cassandra_node_cmd nodeltool_cassandra_node ${MASTER_NODE} status >> "${nodetool_log}"
    cassandra_node_cmd nodeltool_cassandra_node ${MASTER_NODE} info >> "${nodetool_log}"
    cassandra_node_cmd nodeltool_cassandra_node ${MASTER_NODE} cfstats >> "${nodetool_log}"
    return 0
}

init_cassandra_ycsb_db() {
    local node=$1
    local app_home="$(get_data_dir ${node})/${APP_NAME}"
    ## --cqlshrc=${RESULTS_DIR}
    if [[ "${AWS_MCS}" == true ]]
    then
        local init_db_file=${BASE_DIR}/setup-ycsb.cqlsh
        log "Initializing Cassandra DB on AWS using setup $init_db_file..."
        host_cmd localhost "${cqlsh_extra_env} ${app_home}/bin/cqlsh -f ${init_db_file} ${cqlsh_extra_args}"
    else
        local init_db_file=${BASE_DIR}/setup-ycsb-nocompression.cqlsh
        [[ "${COMPRESSION}" = true ]] && init_db_file=${BASE_DIR}/setup-ycsb.cqlsh
        log "Initializing Cassandra DB on $node using setup $init_db_file..."
        host_cmd "$node" "${cqlsh_extra_env} ${app_home}/bin/cqlsh -f ${init_db_file} ${MASTER_NODE} ${cqlsh_extra_args}"
    fi
    print_node_info "on init DB"
}

init_cqlsh() {
    return # nothing TBD
    [[ -f "${RESULTS_DIR}/cqlshrc" ]] && return
    log "Initializing cqlshrc..."
    cat "${BASE_DIR}/cqlshrc" | sed "s|PORT|${MASTER_PORT}|g; " > "${RESULTS_DIR}/cqlshrc"
}

run_cqlsh() {
    local node=$MASTER_NODE
    local app_home="$(get_data_dir ${node})/${APP_NAME}"
    log "Running cql shell ${MASTER_NODE} ${MASTER_PORT} ${cqlsh_extra_args} ${@}..."
#    host_cmd "$node" "SSL_CERTFILE=${PEM_CERT} ${app_home}/bin/cqlsh --cqlshrc=${RESULTS_DIR} ${MASTER_NODE} ${@}"
    (
    EXT_SSH_ARGS+=" -t"
    host_cmd "$node" "${cqlsh_extra_env} ${app_home}/bin/cqlsh ${MASTER_NODE} ${MASTER_PORT} ${cqlsh_extra_args} ${@}"
    )
}

write_scores() {
    local stage=$1
    local log=$2
    local start=$3
    local finish=$4
    tail -100 "$log" | grep "\[OVERALL\], RunTime(ms)," -A300 | sed "s|\[|${stage} |; s|], | |; s|,|:|" | while read p
    do
        name=$(echo $p | sed "s|:.*||")
        value=$(echo $p | sed "s|.*: ||")
        scale=
        if [[ "$name" == *"(ms)" ]]
        then
            name=${name%(*}
            scale=milliseconds
        fi
        if [[ "$name" == *"(us)" ]]
        then
            name=${name%(*}
            scale=microseconds
        fi
        if [[ "$name" == *"(ops/sec)" ]]
        then
            name=${name%(*}
            scale=ops/sec
        fi
        if [[ "$name" == *"(%)" ]]
        then
            name=${name%(*}
            scale="%"
        fi
        $SCENARIO && name2=${name}
        $SCENARIO || name2=${name/${stage} /}
        name2=${name2// /_}
        write_score_json "$SCORES_JSON" "${name}" "${scale}" "${value}" "0" localhost $start $finish
        [[ "${stage}" == run* ]] && write_score_on "$SCORES_FILE" "${name2}" "${scale}" "${value}"
    done
}

ycsb_load_num=0

ycsb_load() {
    (( ycsb_load_num++ ))
    local skip_load=$(get_arg skip_load 0)
    if (( skip_load == 1 ))
    then
        log "Skipping load"
        return 0
    fi
    local workload=${1:-${BENCHMARK_WORKLOAD}}
    local fields=$(get_arg fields 20)
    local rownum=$(get_arg rownum 1000000)
    local load_threads=$(get_arg load_threads 48)
    local bench_dir="${RESULTS_DIR}/benchmarks_0"
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "$bench_dir" "ycsb_load")
    ycsb_java_opts+=" ${ycsb_java_opts_extra}"
    if [[ ! -f "${YCSB_HOME}/workloads/workload${workload}" ]]
    then
        log "YCSB load #$ycsb_load_num - workload file not found: ${YCSB_HOME}/workloads/workload${workload}!"
        return 1
    fi
    mkdir -p "${bench_dir}" || return 1
    print_node_info "before load #$ycsb_load_num"
    log "YCSB load #$ycsb_load_num workload '${workload}' ($NUMACTL_YCSB, $YCSB_JAVA_HOME)..."
    local start=$(date +%s)
    (
    cd ${bench_dir}
    export SSL_CERTFILE
    export YCSB_JAVA_HOME
    export JAVA_HOME=$YCSB_JAVA_HOME
    $NUMACTL_YCSB ${YCSB_HOME}/bin/ycsb load cassandra${CQL_VER}-cql -p hosts=${MASTER_NODE} -p port=${MASTER_PORT} \
        -threads ${load_threads} -p fieldcount=${fields} -p recordcount=${rownum} -p requestdistribution=zipfian -p core_workload_insertion_retry_limit=2 \
        -P "${YCSB_HOME}/workloads/workload${workload}" -s -p measurementtype=hdrhistogram -p status.interval=1 -jvm-args="$ycsb_java_opts" ${ycsb_extra} &> ycsb_load.log
    )
    local res=$?
    local finish=$(date +%s)
    write_scores load${ycsb_load_num} "${bench_dir}/ycsb_load.log" $start $finish
    print_node_info "after load #$ycsb_load_num"
    return $res
}

ycsb_warmup() {
    local warmups=$(get_arg warmups 10)
    local warmup_threads=$(get_arg warmup_threads 12)
    local warmup_delay=$(get_arg warmup_delay 30)
    local rownum=$(get_arg rownum 1000000)
    local connections=$(get_arg connections 12)
    if (( warmups == 0 ))
    then
        log "Skipping warmups"
        return 0
    fi
    if [[ ! -f "${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}" ]]
    then
        log "YCSB warmup - workload file not found: ${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}!"
        return 1
    fi
    local bench_dir="${RESULTS_DIR}/benchmarks_0"
    mkdir -p "${bench_dir}" || return 1
    print_node_info "before warmup"
    local res=0
    for (( i = 1; i <= warmups; i++))
    do
        local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "$bench_dir" "ycsb_warmup_${i}")
        ycsb_java_opts+=" ${ycsb_java_opts_extra}"
        local HDR_CONF
        if [[ "$USE_HDR" == true ]]
        then
            HDR_CONF="-p measurementtype=hdrhistogram -p measurement.interval=both"
        fi
        log "YCSB warmup ${i} workload '${BENCHMARK_WORKLOAD}' ($NUMACTL_YCSB, $YCSB_JAVA_HOME)..."
        (
        cd ${bench_dir}
        export YCSB_JAVA_HOME
        export JAVA_HOME=$YCSB_JAVA_HOME
        $NUMACTL_YCSB ${YCSB_HOME}/bin/ycsb run cassandra${CQL_VER}-cql -p hosts=${MASTER_NODE} -p port=${MASTER_PORT} -threads ${warmup_threads} -p cassandra.maxconnections=12 \
            -p cassandra.coreconnections=${connections} -p fieldcount=20 -p operationcount=100000 -p recordcount=${rownum} \
            -p requestdistribution=zipfian -P "${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}" -s -p status.interval=1 \
            -jvm-args="$ycsb_java_opts" ${HDR_CONF} ${ycsb_extra} &> ycsb_warmup_${i}.log
        ) || { res=1; break; }
        sleep "$warmup_delay"
    done
    print_node_info "after warmup"
    return $res
}

ycsb_run_num=0

ycsb_test() {
    (( ycsb_run_num++ ))
    local bench_dir="${RESULTS_DIR}/benchmarks_0"
    if [[ ! -f "${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}" ]]
    then
        log "YCSB run #$ycsb_run_num - workload file not found: ${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}!"
        return 1
    fi
    mkdir -p "${bench_dir}" || return 1
    local test_time=$(get_arg time 600)
    (( test_time == 0 )) && return 0
    local threads=$(get_arg threads 200)
    local rownum=$(get_arg rownum 1000000)
    local fields=$(get_arg fields 20)
    local opcount=10000000
    [[ "${YCSB_HOME}" == *ycsb-0.14.0* ]] && opcount=0
    opcount=$(get_arg opcount $opcount)
    local connections=$(get_arg connections 12)
    local target=$(get_arg target "")
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "$bench_dir" "ycsb_run")
    ycsb_java_opts+=" ${ycsb_java_opts_extra}"
    local HDR_CONF
    if [[ "$USE_HDR" == true ]]
    then
        HDR_CONF="-p measurementtype=hdrhistogram -p measurement.interval=both -p hdrhistogram.fileoutput=true -p hdrhistogram.output.path=${bench_dir}/${BENCHMARK_WORKLOAD}-ycsb-run${ycsb_run_num}-"
    fi
    [[ -n "${target}" ]] && target="-target ${target}"
    print_node_info "before run #$ycsb_run_num"
    log "YCSB run #$ycsb_run_num workload '${BENCHMARK_WORKLOAD}' ($NUMACTL_YCSB, $YCSB_JAVA_HOME)..."
    local out="${bench_dir}/ycsb_run${ycsb_run_num}.log"
    local start=$(date +%s)
    (
    cd "${bench_dir}"
    export YCSB_JAVA_HOME
    export JAVA_HOME=$YCSB_JAVA_HOME
    $NUMACTL_YCSB ${YCSB_HOME}/bin/ycsb run cassandra${CQL_VER}-cql -p hosts=${MASTER_NODE} -p port=${MASTER_PORT} -threads ${threads} ${target} -p cassandra.maxconnections=${connections} \
        -p cassandra.coreconnections=${connections} -p fieldcount=$fields -p operationcount=$opcount -p maxexecutiontime=${test_time} -p recordcount=${rownum} \
        -p requestdistribution=zipfian -P "${YCSB_HOME}/workloads/workload${BENCHMARK_WORKLOAD}" -s -p status.interval=1 \
        -jvm-args="$ycsb_java_opts" ${HDR_CONF} ${ycsb_extra} &> "${out}"
    )
    local res=$?
    local finish=$(date +%s)
    write_scores run${ycsb_run_num} "${out}" $start $finish
    print_node_info "after run #$ycsb_run_num"
    return $res
}

ycsb_default() {
    log "Running default scenario for ${BENCHMARK_WORKLOAD}..."
    if ycsb_load
    then
        [[ "${RESTART_VM}" == true ]] && { restart_cassandra || return 1; }
        ycsb_warmup && ycsb_test
    else
        log "YCSB load FAILED!"
    fi
}

ycsb_run() {
    local scenario
    [[ "${BENCHMARK_WORKLOAD}" == none ]] && return
    if [[ -f "${BENCHMARK_WORKLOAD}" ]]
    then
        scenario=${BENCHMARK_WORKLOAD}
    elif [[ -f "${BASE_DIR}/tests/${BENCHMARK_WORKLOAD}" ]]
    then
        scenario="${BASE_DIR}/tests/${BENCHMARK_WORKLOAD}"
    fi
    if [[ -f "${scenario}" ]]
    then
        log "Running scenario from file: ${scenario}..."
        SCENARIO=true
        cat "${scenario}" | while read -r p
        do
            log "Oeration: $p"
            if [[ "$p" == warmup* ]]
            then
                p=${p/warmup/}
                init_workload_name "$p"
                init_workload_args "$p"
                ycsb_warmup
            elif [[ "$p" == "load "* ]]
            then
                p=${p/load /}
                init_workload_name "$p"
                init_workload_args "$p"
                ycsb_load
            elif [[ "$p" == restart ]]
            then
                restart_cassandra || return 1
            elif [[ "$p" == "sleep "* ]]
            then
                p=${p/sleep /}
                log "Sleep $p..."
                sleep $p
            elif [[ "$p" == "#"* ]]
            then
                continue
            else
                init_workload_name "$p"
                init_workload_args "$p"
                ycsb_test
            fi
        done
    else
        ycsb_default
    fi
}

ycsb_install() {
    local node=$1
    local apps_dir="$(get_apps_dir ${node})"
    if [[ "${YCSB_HOME}" != */* ]]
    then
        install_artifact "${YCSB_HOME}-cassandra" "${apps_dir}" true || exit 1
        YCSB_HOME="${apps_dir}/${YCSB_HOME}-cassandra"
        YCSB_HOME_INSTALLED=true
    fi
    [[ -d "${YCSB_HOME}" ]] || fail "Missing YCSB_HOME path: ${YCSB_HOME}!"
    return 0
}

client_java_install() {
    local node=$1
    local apps_dir="$(get_apps_dir ${node})"
    if [[ "${YCSB_JAVA_HOME}" != */* ]]
    then
        install_artifact "${YCSB_JAVA_HOME}" "${apps_dir}" true || exit 1
        YCSB_JAVA_HOME="${apps_dir}/${YCSB_JAVA_HOME}"
        YCSB_JAVA_HOME_INSTALLED=true
    fi
    [[ -d "${YCSB_JAVA_HOME}" ]] || fail "Missing CLIENT_JAVA_HOME path: ${YCSB_JAVA_HOME}!"
    CLIENT_JAVA_HOME=${YCSB_JAVA_HOME}
    return 0
}

ycsb_init() {
    local node=$1
    log "Init YCSB benchmark..."
    ycsb_install $node
    client_java_install $node
    BENCHMARK=$(basename "${YCSB_HOME}")
    log "YCSB_HOME: ${YCSB_HOME} (installed: $YCSB_HOME_INSTALLED)"
    log "YCSB_JAVA_HOME: ${YCSB_JAVA_HOME} (installed: $YCSB_JAVA_HOME_INSTALLED)"
    log "BENCHMARK: ${BENCHMARK}"
    log "RESULTS_DIR: ${RESULTS_DIR}"
    [[ "${YCSB_HOME}" == *0.7.0* ]] && CQL_VER=2
}

tlp_stress_install() {
    local node=$1
    local apps_dir="$(get_apps_dir ${node})"
    if [[ "${TLP_STRESS_HOME}" != */* ]]
    then
        install_artifact "${TLP_STRESS_HOME}" "${apps_dir}" true || exit 1
        TLP_STRESS_HOME="${apps_dir}/${TLP_STRESS_HOME}"
        TLP_STRESS_HOME_INSTALLED=true
    fi
    [[ -d "${TLP_STRESS_HOME}" ]] || fail "Missing TLP_STRESS_HOME path: ${TLP_STRESS_HOME}!"
    return 0
}

tlp_stress_init() {
    local node=$1
    log "Init TLP-STRESS benchmark..."
    tlp_stress_install $node
    client_java_install $node
    BENCHMARK=$(basename "${TLP_STRESS_HOME}")
    log "TLP_STRESS_HOME: ${TLP_STRESS_HOME} (installed: $TLP_STRESS_HOME_INSTALLED)"
    log "YCSB_JAVA_HOME: ${YCSB_JAVA_HOME} (installed: $YCSB_JAVA_HOME_INSTALLED)"
    log "BENCHMARK: ${BENCHMARK}"
    log "RESULTS_DIR: ${RESULTS_DIR}"
}

cassandra_stress_init() {
    local node=$1
    log "Init CASSANDRA-STRESS benchmark..."
    client_java_install $node
}

get_tus_test_scores() {
    local log=${1:-${RESULTS_DIR}}/results.txt
    cat $log | grep "...high-bound found" | sed 's|.* ...high-bound found: |Score on HighBound: |g' | sed 's|$| msgs/s|g'
    cat $log | grep "...max rate found" | sed 's|.* ...max rate found: |Score on MaxRate: |g' | sed 's|$| msgs/s|g'
    cat $log | grep "SLA for" | grep "broken" | sed 's|.* SLA for |Score on ConformingRate_p|g' | sed 's| percentile = |_|g' | sed 's| ms in |ms_|' | sed 's| ms interval broken on |ms: |g'
}

var_bench_run_num=0

cassandra_tus_test() {
    local bench_dir="${RESULTS_DIR}/benchmarks_${var_bench_run_num}"
    (( var_bench_run_num++ ))
    local threads=$(get_arg threads 200)
    local startingRatePercent=$(get_arg startingRatePercent 50)
    local startingHighBound=$(get_arg startingHighBound 80000)
    local ratePercentStep=$(get_arg ratePercentStep 2)
    local rangeStartTime=$(get_arg rangeStartTime 0)
    local targetFactor=$(get_arg targetFactor 1.1)
    local time=$(get_arg time 300)
    local warmupTime=$(get_arg warmupTime 30)
    log "Cassandra Throughput Under SLA test..."
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "$bench_dir" "ycsb_run")
    local out="${bench_dir}/ycsb_run_tus.log"
    mkdir -p "${bench_dir}" || return 1
    cat $BASE_DIR/cassandra-tusla-config.yaml | sed "\
    s|^hosts: .*|hosts: [ \"${MASTER_NODE}\" ]|; \
    s|^port: .*|port: ${MASTER_PORT}|; \
    s|^threads: .*|threads: ${threads}|; \
    s|^slaConfig: .*|slaConfig: ${SLA_CONFIG}|; \
    s|^startingRatePercent: .*|startingRatePercent: ${startingRatePercent}|; \
    s|^rangeStartTime: .*|rangeStartTime: ${rangeStartTime}|; \
    s|^ratePercentStep: .*|ratePercentStep: ${ratePercentStep}|; \
    s|^startingHighBound: .*|startingHighBound: ${startingHighBound}|; \
    s|^targetFactor: .*|targetFactor: ${targetFactor}|; \
    s|^time: .*|time: ${time}|; \
    s|^warmupTime: .*|warmupTime: ${warmupTime}|; \
    s|^workload:  .*|workload:  $BASE_DIR/workloads/workloadc|; \
    "  > $bench_dir/cassandra-tusla-config.yaml.yaml
    if ycsb_load a
    then
        log "Starting TUSBenchRunner..."
        # [[ "${RESTART_VM}" == true ]] && { restart_cassandra || return 1; }
        (
        cd $bench_dir
        $NUMACTL_YCSB $YCSB_JAVA_HOME/bin/java -jar $BASE_DIR/TUSBenchRunner.jar CassandraYCSBBench cassandra-tusla-config.yaml &> "${out}"
        )
    else
        log "YCSB load FAILED!"
    fi
}

cassandra_stress_test() {
    local bench_dir="${RESULTS_DIR}/benchmarks_${var_bench_run_num}"
    (( var_bench_run_num++ ))
    local threads=$(get_arg threads 200)
    local op=$(get_arg op write)
    local n=$(get_arg n 1000000)
    local local_data_dir="$(get_data_dir localhost)"
    local local_app_home="${local_data_dir}/${APP_NAME}"
    mkdir -p "${bench_dir}" || return 1
    local out_file="${bench_dir}/stress-run${var_bench_run_num}-${op}.log"
    local hdr_file="${bench_dir}/stress-run${var_bench_run_num}-${op}.hdr"
    local start=$(date +%s)
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "$bench_dir" "ycsb_run")
    ycsb_java_opts+=" ${ycsb_java_opts_extra}"
    log "cassandra-stress run ${op} ($NUMACTL_YCSB, $YCSB_JAVA_HOME, ${ycsb_java_opts})..."
    (
    cd "${bench_dir}"
    export YCSB_JAVA_HOME
    export JAVA_HOME=${YCSB_JAVA_HOME}
    export JVM_OPTS=${ycsb_java_opts}
    $NUMACTL_YCSB ${local_app_home}/tools/bin/cassandra-stress $op n=$n cl=one -mode native cql3 -rate threads=${threads} \
        -node ${MASTER_NODE} -port native=${MASTER_PORT} -log "hdrfile=${hdr_file}" "file=${out_file}"
    )
    local finish=$(date +%s)
    sed -n "/Results:/,/END/p" "${out_file}"
}

tlp_stress_test() {
    local bench_dir="${RESULTS_DIR}/benchmarks_${var_bench_run_num}"
    (( var_bench_run_num++ ))
    local e_args=()
    local n=$(get_arg i 1000000)
    local d=$(get_arg time 30m)
    local p=$(get_arg p 200000)
    local c=$(get_arg c 50)
    local rr=$(get_arg rr 0.2)
    local pg=$(get_arg pg sequence)
    local target=$(get_arg target "")
    local threads=$(get_arg threads 8)
    local sync_mode=$(get_arg sm "")
    local replication=$(get_arg replication "")
    local strategy=$(get_arg strategy "")
    local rtw=$(get_arg rtw "")
    [[ "${sync_mode}" == true ]] && e_args+=("--sync-mode")
    if [[ -n "${replication}" || -n "${strategy}" ]]
    then
        e_args+=( "--replication" )
        e_args+=( "{'class': '${strategy:-SimpleStrategy}', 'replication_factor': ${replication:-3} }" )
    fi
    local wl=$(get_arg wl BasicTimeSeries)
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" "${bench_dir}" "tlp_stress")
    ycsb_java_opts+=" -Djava.util.concurrent.ForkJoinPool.common.parallelism=${threads} ${ycsb_java_opts_extra}"
    if [[ -n "${target}" ]]
    then
        target="--rate ${target}"
    else
        target="--iterations ${n}"
    fi
    if [[ -n "${rtw}" ]]
    then
        rtw="--response-time-warmup ${rtw}"
    fi
    mkdir -p "${bench_dir}" || return 1
    tlp_stress_init localhost
    log "tlp-stress run ($NUMACTL_YCSB, $YCSB_JAVA_HOME, ${ycsb_java_opts})..."
    (
    cd "${bench_dir}"
    bench_dir=.
    log Running TLP stress workload ${wl} \
        --duration ${d} --partitions 100M --threads ${threads} --populate ${p}  --readrate ${rr}  ${target} ${rtw} \
        --partitiongenerator ${pg} --concurrency ${c} --port ${MASTER_PORT} --host ${MASTER_NODE} \
        --csv ${bench_dir}/tlp_stress_metrics_${var_bench_run_num}.csv \
        --hdr ${bench_dir}/tlp_stress_metrics_${var_bench_run_num}.hdr "${e_args[@]}"
    $NUMACTL_YCSB $YCSB_JAVA_HOME/bin/java ${ycsb_java_opts} -cp "${TLP_STRESS_HOME}/lib/*" com.thelastpickle.tlpstress.MainKt run ${wl} \
        --duration ${d} --partitions 100M --threads ${threads} --populate ${p}  --readrate ${rr}  ${target} ${rtw} \
        --partitiongenerator ${pg} --concurrency ${c} --port ${MASTER_PORT} --host ${MASTER_NODE} \
        --csv ${bench_dir}/tlp_stress_metrics_${var_bench_run_num}.csv \
        --hdr ${bench_dir}/tlp_stress_metrics_${var_bench_run_num}.hdr "${e_args[@]}"
    )
}

nb_test() {
    local bench_dir="${RESULTS_DIR}/benchmarks_${var_bench_run_num}"
    (( var_bench_run_num++ ))
    mkdir -p "${bench_dir}" || return 1
    local threads=$(get_arg threads 500)
    local cycles=$(get_arg cycles 50000000)
    local rampup=$(get_arg rampup 1000)
    local d=$(get_arg d "1")
    local ycsb_java_opts=$(preprocess_java_opts "$YCSB_JAVA_OPTS" . "nosqlbench")
    ycsb_java_opts+=" ${ycsb_java_opts_extra}"
    log "Using nb_data_${d}_zip..."
    (
    cd "${bench_dir}"
    unzip ${BASE_DIR}/nb_data_${d}_zip
    bench_dir=.
    log "NoSQLBench run ($NUMACTL_YCSB, $YCSB_JAVA_HOME, ${ycsb_java_opts})..."
    log "  phase:schema:" 
    ${NUMACTL_YCSB} ${YCSB_JAVA_HOME}/bin/java ${ycsb_java_opts} -jar ${BASE_DIR}/nb-4.15.46.jar -v run driver=cql yaml=repbus tags=phase:schema host=${MASTER_NODE} username=${CASSANDRA_USERNAME} password=${CASSANDRA_PASSWORD} \
        --show-stacktraces
    log "  phase:rampup:"
    ${NUMACTL_YCSB} ${YCSB_JAVA_HOME}/bin/java ${ycsb_java_opts} -jar ${BASE_DIR}/nb-4.15.46.jar -v run driver=cql yaml=repbus tags=phase:rampup host=${MASTER_NODE} username=${CASSANDRA_USERNAME} password=${CASSANDRA_PASSWORD} \
        threads=${threads} cycles=${rampup} \
        --show-stacktraces
    log "  phase:main:"
    ${NUMACTL_YCSB} ${YCSB_JAVA_HOME}/bin/java ${ycsb_java_opts} -jar ${BASE_DIR}/nb-4.15.46.jar -v run driver=cql yaml=repbus tags=phase:main host=${MASTER_NODE} username=${CASSANDRA_USERNAME} password=${CASSANDRA_PASSWORD} \
        threads=${threads} cycles=${cycles} \
        --show-stacktraces \
        --report-csv-to ${bench_dir} \
        --log-histostats main-stats.csv \
        --log-histograms main-histodata.log
    )
}

run_workload() {
    log "run_workload: ${@}"
    init_workload_name "$1"
    init_workload_args "$1"
    local scenario
    if [[ "${MASTER_NODE}" != localhost ]]
    then
        mkdir -p "${RESULTS_DIR}/node_localhost"
        print_sys_info > "${RESULTS_DIR}/node_localhost/system_info1.log"
        start_monitor_tools "${RESULTS_DIR}/node_localhost"
    fi
    [[ "${BENCHMARK_WORKLOAD}" == none ]] && return
    if [[ -f "${BENCHMARK_WORKLOAD}" && "${BENCHMARK_WORKLOAD}" != nb ]]
    then
        scenario=${BENCHMARK_WORKLOAD}
    elif [[ -f "${BASE_DIR}/tests/${BENCHMARK_WORKLOAD}" ]]
    then
        scenario="${BASE_DIR}/tests/${BENCHMARK_WORKLOAD}"
    fi
    if [[ -f "${scenario}" ]]
    then
        local test_name=$(basename "${scenario}")
        SCENARIO=true
        if [[ "${test_name}" == stress* ]]
        then
            log "Running cassandra-stress scenario from file: ${scenario}..."
            cat "${scenario}" | while read -r p
            do
                log "Operation: $p"
                if [[ "$p" == warmup* ]]
                then
                    init_workload_name "cassandra-stress//op=write"
                    init_workload_args "cassandra-stress//op=write"
                    cassandra_stress_test
                elif [[ "$p" == load* ]]
                then
                    init_workload_name "cassandra-stress//op=write"
                    init_workload_args "cassandra-stress//op=write"
                    cassandra_stress_test
                elif [[ "$p" == restart ]]
                then
                    restart_cassandra || return 1
                elif [[ "$p" == "sleep "* ]]
                then
                    p=${p/sleep /}
                    log "Sleep $p..."
                    sleep $p
                else
                    init_workload_name "cassandra-stress//op=$p"
                    init_workload_args "cassandra-stress//op=$p"
                    cassandra_stress_test
                fi
            done
        else
            log "Running YCSB scenario from file: ${scenario}..."
            init_cassandra_ycsb_db localhost
            cat "${scenario}" | while read -r p
            do
                log "Operation: $p"
                if [[ "$p" == warmup* ]]
                then
                    p=${p/warmup/}
                    init_workload_name "$p"
                    init_workload_args "$p"
                    ycsb_warmup
                elif [[ "$p" == "load "* ]]
                then
                    p=${p/load /}
                    init_workload_name "$p"
                    init_workload_args "$p"
                    ycsb_load
                elif [[ "$p" == restart ]]
                then
                    restart_cassandra || return 1
                elif [[ "$p" == "sleep "* ]]
                then
                    p=${p/sleep /}
                    log "Sleep $p..."
                    sleep $p
                elif [[ "$p" == "#"* ]]
                then
                    continue
                else
                    init_workload_name "$p"
                    init_workload_args "$p"
                    ycsb_test
                fi
            done
        fi
    elif [[ "${BENCHMARK_WORKLOAD}" == cassandra-stress ]]
    then
        log "Running [$1]..."
        cassandra_stress_test
    elif [[ "${BENCHMARK_WORKLOAD}" == tlp-stress ]]
    then
        log "Running [$1]..."
        tlp_stress_test
    elif [[ "${BENCHMARK_WORKLOAD}" == cassandra-tus ]]
    then
        log "Running [$1]..."
        init_cassandra_ycsb_db localhost
        cassandra_tus_test
    elif [[ "${BENCHMARK_WORKLOAD}" == nb ]]
    then
        log "Running [$1]..."
        nb_test
    else
        log "Running [$1]..."
        init_cassandra_ycsb_db localhost
        ycsb_default
    fi
    if [[ "${MASTER_NODE}" != localhost ]]
    then
        stop_monitor_tools
    fi
}

init_workload() {
    log "init_workload: ${@}"
    init_workload_name "$1"
    init_workload_args "$1"
    if [[ "${BENCHMARK_WORKLOAD}" == *tlp-stress* ]]
    then
        tlp_stress_init localhost
    elif [[ "${BENCHMARK_WORKLOAD}" == *cassandra-stress* ]]
    then
        cassandra_stress_init localhost
    else
        ycsb_init localhost
    fi
}

deopt() {
    local ops=$1
    local method=$2
    local node
    for node in "${var_nodes[@]}"
    do
        cassandra_node_cmd deopt_cassandra_node "${node}" "${method}" "${ops}"
    done
}

par_deopt() {
    local wait_start=${1:-600}
    shift
    local wait_between=${1:-300}
    shift
    local ops=${1:-"resetc2"}
    shift
    local method=${1:-"org.apache.cassandra.service.reads.ReadCallback.awaitResults"}
    shift
    local ii=0
    sleep_for ${wait_start}
    while true
    do
        (( ii++ ))
        log "Deopt #${ii}..."
        deopt "${ops}" "${method}"
        sleep_for ${wait_between}
    done
}

start_par_job() {
    [[ -n "${RUN_PAR_JOB}" ]] || return
    log "Starting parallel job: par_${RUN_PAR_JOB//,/ }..."
    par_${RUN_PAR_JOB//,/ } &> "${RESULTS_DIR}/parallel_job.log" &
    PAR_PID=$!
}

stop_par_job() {
    [[ -n "$PAR_PID" ]] || return
    log "Stopping parallel job (pid: ${PAR_PID})..."
    kill $PAR_PID
    sleep 1
    kill -9 $PAR_PID
    unset PAR_PID
}

var_traps=0

trap_handler() {
    (( var_traps++ ))
    (( var_traps == 1 )) || return
    if [[ -d "${RESULTS_DIR}" ]]
    then
        echo "In trap... ${var_traps}" &>> "${RESULTS_DIR}/run.log"
        stop_par_job &>> "${RESULTS_DIR}/run.log"
        finish_cassandra "${CLEANUP_DATA}" &>> "${RESULTS_DIR}/run.log"
        [[ -f "${RESULTS_DIR}/time_out.log" ]] && log "Stopped" &>> "${RESULTS_DIR}/time_out.log"
    else
        echo "In trap ${var_traps}..."
        stop_par_job
        finish_cassandra "${CLEANUP_DATA}"
    fi
    STOP=true
    exit 1
}

run() {
    log
    log "--------------------------------------------"
    log "         Cassandra benchmark runner         "
    mkdir -p "${RESULTS_DIR}" || exit 1
    check_bc
    log "Start" &> "${RESULTS_DIR}/time_out.log"
    init_cqlsh
    init_workload "${@}"
    CONFIG=${CONFIG_DEF}
    [[ "${COMPRESSION}" == true ]] && CONFIG+=" compression"
    [[ -n "${NUM_TOKENS}" ]] && CONFIG+=" num_tokens${NUM_TOKENS}"
    if [[ "${AWS_MCS}" == true ]]
    then
        CONFIG+=" aws_mcs"
    elif [[ "${CLIENT_TLS}" == true ]]
    then
        CONFIG+=" ssl"
    fi
    if [[ -n "${CASSANDRA_PROPS}" ]]
    then
        CONFIG+=" ${CASSANDRA_PROPS}"
    fi
    local ycsb_ver=${YCSB_HOME##*/}
    ycsb_ver=${ycsb_ver#ycsb-}
    ycsb_ver=${ycsb_ver%-cassandra}
    CONFIG+=" ycsb_version${ycsb_ver}"
    create_run_properties "${RESULTS_DIR}"
    local local_data_dir="$(get_data_dir localhost)"
    install_artifact "${APP_NAME}" "${local_data_dir}" || exit 1
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Amazon MCS"
        run_workload "${@}"
    else
        log "  Node address: ${node_address}"
        cleanup_cassandra true
        init_cassandra || exit 1
        trap trap_handler INT QUIT TERM
        if start_cassandra
        then
            start_par_job
            run_workload "${@}"
            stop_par_job
        fi
        finish_cassandra "${CLEANUP_DATA}"
    fi
    log "Finish" &>> "${RESULTS_DIR}/time_out.log"
}

init_and_run_workload() {
    init_workload "$1"
    run_workload "$1"
}

cmd=${ARGS[0]}
unset ARGS[0]

if [[ "$cmd" == *_cassandra || "$cmd" == *_cassandra_node || "$cmd" == *_cqlsh || "$cmd" == run* || "$cmd" == init_* ]]
then
    $cmd ${ARGS[@]}
elif [[ "$cmd" == stop ]]
then
    stop_monitor_tools
    stop_cassandra_process
elif [[ "$cmd" == ycsb_*  || "$cmd" == tlp_* ]]
then
    init_workload ${ARGS[@]}
    ${cmd}
elif [[ "$cmd" == write_scores ]]
then
    write_scores ${ARGS[@]}
else
    run "$cmd" ${ARGS[@]}
fi
