#!/bin/bash
#
# Common Cassandra utility methods
#

CASSANDRA_SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd -P)
CASSANDRA_RUN_CMD=$(readlink -f ${BASH_SOURCE[0]})

source "${CASSANDRA_SCRIPT_DIR}/utils.sh" || exit 1

cqlsh_extra_env=${CQLSH_EXTRA_ENV:-""}
cqlsh_extra_args=${CQLSH_EXTRA_ARGS:-""}
ycsb_extra=${YCSB_EXTRA_OPTS:-""}
ycsb_java_opts_extra=${YCSB_JAVA_EXTRA_OPTS:-""}

APP_NAME=${APP_NAME:-cassandra-4.0.1}
JAVA_OPTS=${JAVA_OPTS:-${DEFAULT_JAVA_OPTS}}
RESULTS_DIR=${RESULTS_DIR:-}
NUMACTL_YCSB=${NUMACTL_YCSB:-"numactl -N 0 -m 0"}
NUMACTL_ARGS=${NUMACTL_ARGS:-"-N 1 -m 1"}
CLIENT_TLS=${CLIENT_TLS:-false}
SERVER_TLS=${SERVER_TLS:-false}
NUMACTL_ARGS=${NUMACTL_ARGS:-"-N 1 -m 1"}
MASTER_PORT=${MASTER_PORT:-9042}
CASSANDRA_USERNAME=${CASSANDRA_USERNAME:-cassandra}
CASSANDRA_PASSWORD=${CASSANDRA_PASSWORD:-cassandra}
CASSANDRA_PROPS=${CASSANDRA_PROPS:-}
USE_NODETOOL=${USE_NODETOOL:-false}
AWS_MCS=${AWS_MCS:-false}
JAVA_BASE_OPTS="-ea -XX:+HeapDumpOnOutOfMemoryError -Xss256k -XX:StringTableSize=1000003 -Djava.net.preferIPv4Stack=true"
DEFAULT_JAVA_OPTS="-Xmx1g -Xms1g"
NUM_TOKENS=${NUM_TOKENS:-}
DOCKER=${DOCKER:-false}
NODE_CPU=${NODE_CPU:-false}
DOCKER_MEM=${DOCKER_MEM:-}
DOCKER_CPUS=${DOCKER_CPUS:-}
COLLECT=${COLLECT:-}
ZVR_SECONDS=${ZVR_SECONDS:-300}

setup_cassandra_options() {
    log "Initializing basic Cassandra options..."
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Using AWS MCS..."
        USE_NODETOOL=false
        CLIENT_TLS=true
        MASTER_NODE=cassandra.us-east-1.amazonaws.com
        MASTER_PORT=9142
    else
        parse_nodes Cassandra
        MASTER_NODE=$(get_master_node true)
    fi
    if [[ "${CLIENT_TLS}" == true ]]
    then
        if [[ "${AWS_MCS}" == true ]]
        then
            CASSANDRA_USERNAME=rscherba-at-290938441671
            CASSANDRA_PASSWORD=zWPr95I1sR7k4ATjiS7H2G6R8YPYED9u9/hyzd61CiM=
            PEM_CERT=${CASSANDRA_SCRIPT_DIR}/cert/AmazonRootCA1.pem
            ycsb_java_opts_extra+=" -Djavax.net.ssl.trustStore=${CASSANDRA_SCRIPT_DIR}/cert/AmazonRootCA1.cassandra.truststore -Djavax.net.ssl.trustStorePassword=cassandra"
        else
            PEM_CERT=${CASSANDRA_SCRIPT_DIR}/cert/test_CLIENT.cer.pem
            ycsb_java_opts_extra+=" -Djavax.net.ssl.trustStore=${CASSANDRA_SCRIPT_DIR}/cert/cassandra.truststore -Djavax.net.ssl.trustStorePassword=cassandra"
        fi
        ycsb_extra+=" -p cassandra.useSSL=true -p cassandra.username=${CASSANDRA_USERNAME} -p cassandra.password=${CASSANDRA_PASSWORD}"
        cqlsh_extra_env+=" SSL_CERTFILE=${PEM_CERT}"
        [[ "${AWS_MCS}" == true ]] && cqlsh_extra_args+=" -u ${CASSANDRA_USERNAME} -p ${CASSANDRA_PASSWORD}"
        cqlsh_extra_args+=" --ssl"
    fi
    which numactl &> /dev/null || NUMACTL_YCSB=""
    [[ "${NUMACTL_YCSB}" == none ]] && NUMACTL_YCSB=""
}

stop_cassandra_process() {
    local node_num=1
    stop_process -f ".*ZVRobot.prop"
    if [[ "${DOCKER}" == true ]]
    then
        log "Stopping Cassandra process in docker cassandra-node-${node_num}..."
        docker stop "cassandra-node-${node_num}"
    else
        stop_process -f "Dcassandra.logdir="
    fi
}

stop_start_node() {
    stop_process -f ".*ZVRobot.prop"
    stop_process -f init_cassandra_node
    stop_process -f start_cassandra_node
    stop_process -f wait_cassandra_node_started
}

cleanup_cassandra_node() {
    local node=$1
    local delete_data=$2
    local data_dir="$(get_data_dir ${node})"
    local app_home="${data_dir}/${APP_NAME}"
    stop_start_node
    stop_cassandra_process
    stop_monitor_tools
    #clean_dev_shm
    drop_caches
    if [[ "${delete_data}" == true ]]
    then
        log_cmd "Cleaning Cassandra data..." rm -fr "${app_home}"
        rmdir "${data_dir}" &> /dev/null
    fi
}

#
# arg 1 - node name
# arg 2 - node number
# arg 3 - seeds list
#
init_cassandra_node() {
    local node=$1
    local node_num=$2
    local node_num_=$((node_num - 1))
    local seeds=$3
    local node_dir="${RESULTS_DIR}/node_${node}"
    local java_opts=$(get_java_opts . cassandra)
    local node_address=$(resolve_hostname "$node")
    local data_dir="$(get_data_dir ${node})"
    local app_home="${data_dir}/${APP_NAME}"
    local cass_ver=${APP_NAME##*/}
    cass_ver=${cass_ver#*-}
    local jvm_options_file=jvm.options
    local ARTAPort
    echo "${java_opts}" | grep -q ARTAPort && ARTAPort=(${java_opts/*ARTAPort=/})
    log "Initializing Cassandra node '$node'..."
    log "  Cassandra home: ${app_home}"
    log "  Cluster name: ${CLUSTER_NAME}"
    log "  Seeds: ${seeds}"
    log "  JAVA HOME: ${JAVA_HOME}"
    log "  JAVA version: ${JAVA_VERSION}"
    log "  JAVA OPTS: ${JAVA_OPTS}"
    log "  JAVA OPTS expanded: ${java_opts}"
    log "  Cassandra version: ${cass_ver}"
    log "  Cassandra props: ${CASSANDRA_PROPS}"
    log "  Node: ${node}"
    log "  Node number: ${node_num}"
    log "  Node address: ${node_address}"
    log "  ARTAPort: ${ARTAPort}"
    install_artifact "${APP_NAME}" "${data_dir}" || exit 1
    if [[ -z "${node_address}" ]]
    then
        log "Empty node address!"
        exit 1
    fi
    mkdir -p "${node_dir}/logs" || exit 1
    mkdir -p "${node_dir}/config" || exit 1
    chmod -R 777 "${node_dir}"
    log "Cleaning previous Cassandra logs and data..."
    rm -fr "${app_home}/data"
    rm -fr "${app_home}/logs"
    mkdir "${app_home}/data"
    mkdir "${app_home}/logs"
    chmod 777 "${app_home}/data"
    chmod 777 "${app_home}/logs"
    log "Setting Cassandra node properties..."
    cp -f "${app_home}/conf/cassandra.yaml" "${node_dir}/config/cassandra.yaml.orig"
    set_property "${app_home}/conf/cassandra.yaml" cluster_name "'${CLUSTER_NAME}'"
    set_property "${app_home}/conf/cassandra.yaml" listen_address "${node_address}"
    set_property "${app_home}/conf/cassandra.yaml" rpc_address "${node_address}"
    set_property_s "${app_home}/conf/cassandra.yaml" "- seeds" "${seeds}"
    [[ "${SERVER_TLS}" == true ]] && perl -i -0pe "s|server_encryption_options:\n\s+internode_encryption:.*\n|server_encryption_options:\n    internode_encryption: all\n|" "${app_home}/conf/cassandra.yaml"
    [[ "${CLIENT_TLS}" == true ]] && perl -i -0pe "s|client_encryption_options:\n\s+enabled:.*\n|client_encryption_options:\n    enabled: true\n|" "${app_home}/conf/cassandra.yaml"
    [[ -n "${NUM_TOKENS}" ]] && set_property "${app_home}/conf/cassandra.yaml" num_tokens "${NUM_TOKENS}"
    if [[ -n "${CASSANDRA_PROPS}" ]]
    then
        local cpar
        for cpar in ${CASSANDRA_PROPS//,/ }
        do 
            local nv=( ${cpar/=/ } )
            local pname=${nv[0]}
            local pvalue=${nv[1]}
            if [[ "${pname}" == *@* ]]
            then
                local idx=${pname/*@}
                pname=${pname/@*}
                if (( idx == node_num ))
                then
                    log "Setting Cassandra property at specific node #${node_num}: [${pname} = ${pvalue}]"
                    set_property "${app_home}/conf/cassandra.yaml" "${pname}" "${pvalue}"
                else
                    log "Skipping Cassandra property at specific node #${node_num}: [${pname} = ${pvalue}]"
                fi
            else
                log "Setting Cassandra property: [${pname} = ${pvalue}]"
                set_property "${app_home}/conf/cassandra.yaml" "${pname}" "${pvalue}"
            fi
        done
    fi
    if [[ "${SERVER_TLS}" == true || "${CLIENT_TLS}" == true ]]
    then
        perl -i -pe "s|conf/.truststore|${CASSANDRA_SCRIPT_DIR}/cert/cassandra.truststore|g" "${app_home}/conf/cassandra.yaml"
        perl -i -pe "s|conf/.keystore|${CASSANDRA_SCRIPT_DIR}/cert/cassandra.keystore|g" "${app_home}/conf/cassandra.yaml"
    fi
    echo " ${java_opts} " | tr ' ' '\n' > "${app_home}/conf/${jvm_options_file}"
    cp -f "${app_home}/conf/cassandra.yaml" "${node_dir}/config"
    cp -f "${app_home}/conf/${jvm_options_file}" "${node_dir}/config"
    if [[ -f "${app_home}/conf/jvm11-server.options" ]]
    then
        log "Using new vm options files..."
        cp -fv "${app_home}/conf/${jvm_options_file}" "${app_home}/conf/jvm8-server.options"
        cp -fv "${app_home}/conf/${jvm_options_file}" "${app_home}/conf/jvm11-server.options"
        cat >> "${app_home}/conf/jvm11-server.options" <<EOF

-Djdk.attach.allowAttachSelf=true
--add-exports java.base/jdk.internal.misc=ALL-UNNAMED
--add-exports java.base/jdk.internal.ref=ALL-UNNAMED
--add-exports java.base/sun.nio.ch=ALL-UNNAMED
--add-exports java.management.rmi/com.sun.jmx.remote.internal.rmi=ALL-UNNAMED
--add-exports java.rmi/sun.rmi.registry=ALL-UNNAMED
--add-exports java.rmi/sun.rmi.server=ALL-UNNAMED
--add-exports java.sql/java.sql=ALL-UNNAMED

--add-opens java.base/java.lang.module=ALL-UNNAMED
--add-opens java.base/jdk.internal.loader=ALL-UNNAMED
--add-opens java.base/jdk.internal.ref=ALL-UNNAMED
--add-opens java.base/jdk.internal.reflect=ALL-UNNAMED
--add-opens java.base/jdk.internal.math=ALL-UNNAMED
--add-opens java.base/jdk.internal.module=ALL-UNNAMED
--add-opens java.base/jdk.internal.util.jar=ALL-UNNAMED
--add-opens jdk.management/com.sun.management.internal=ALL-UNNAMED

EOF
    fi
    cp -fv "${app_home}/conf/"*.options "${node_dir}/config/"
    if [[ -d "${RESULTS_DIR}/pmem-partitions" ]]
    then
        cp -r "${RESULTS_DIR}/pmem-partitions" "${node_dir}" 
        chmod -R 777 "${node_dir}/pmem-partitions" &> /dev/null
    fi
    if [[ -n "${ARTAPort}" && -f "${JAVA_HOME}/etc/ZVRobot.zip" ]]
    then
        log "Unpacking ZVRobot..."
        mkdir -p "${node_dir}/ZVRobot"
        unzip -o "${JAVA_HOME}/etc/ZVRobot.zip" -d "${node_dir}/ZVRobot"
        local props="${node_dir}/ZVRobot/ZVRobot.prop"
        log "ZVR HOST: ${node}, PORT: ${ARTAPort}, SECONDS: ${ZVR_SECONDS}"
        sed --in-place "s|\(.*\bZVRobotVars.HOST\b\)=.*|\1=${node}|" "${props}"
        sed --in-place "s|\(.*\bZVRobotVars.PORT\b\)=.*|\1=${ARTAPort}|" "${props}"
        sed --in-place "s|\(.*\bZVRobotVars.SECONDS\b\)=.*|\1=${ZVR_SECONDS}|" "${props}"
    fi
    print_disk_usage "Disk usage after Cassandra node initialization" "${data_dir}" |& logx "### "
    return 0
}

#
# arg 1 - node name
# arg 2 - node number
# arg 3 - start number
#
start_cassandra_node() {
    local node=$1
    local node_num=$2
    local node_num_=$((node_num - 1))
    local start_num=$3
    local node_dir="${RESULTS_DIR}/node_${node}"
    local data_dir="$(get_data_dir ${node})"
    local app_home="${data_dir}/${APP_NAME}"
    local java_opts=$(get_java_opts . cassandra)
    local cass_ver=${APP_NAME##*/}
    cass_ver=${cass_ver#*-}
    (( start_num == 1 )) && print_sys_info > "${node_dir}/system_info1.log"
    local heap=1
    if echo ${java_opts} | grep -- -Xmx
    then
        heap=$( echo ${java_opts} | grep -- -Xmx | sed "s|.*-Xmx||; s|g.*||" )
    fi
    local dock_mem=$(( heap + 4 ))
    [[ -n "$DOCKER_MEM" ]] && dock_mem=$DOCKER_MEM
    local dock_args="--memory-swappiness=0 --memory=${dock_mem}g"
    [[ -d /localhome ]] && dock_args+=" -v /localhome:/localhome"
    if [[ "${NODE_CPU}" == true ]]
    then
        local cpu_args=$(lscpu | grep "NUMA node${node_num_}" | sed "s|.*:||") 
        cpu_args=$(echo $cpu_args)
        dock_args+=" --cpuset-cpus=$cpu_args --cpuset-mems=${node_num_}"
    fi
    [[ -n "${DOCKER_CPUS}" ]] && dock_args+=" --cpus=${DOCKER_CPUS}"
    [[ -d /etc/zing ]] && dock_args+=" -v /etc/zing:/etc/zing"
    local ARTAPort
    echo "${java_opts}" | grep -q ARTAPort && ARTAPort=(${java_opts/*ARTAPort=/})
    local cmdx
    [[ "${DOCKER}" == true ]] && cmdx="docker run --rm \
        ${dock_args} \
        --name=cassandra-node-${node_num} \
        --network=host \
        -v /etc/group:/etc/group:ro -v /etc/passwd:/etc/passwd:ro -v /var/lib/localuser:/var/lib/localuser --user $(id -u localuser):$(id -g localuser) \
        -v ${DATA_DIR}:${DATA_DIR} -v ${RESULTS_DIR}:${RESULTS_DIR} -v ${data_dir}:${data_dir} \
        -v /home:/home -w ${node_dir} \
        -e JAVA_HOME=${JAVA_HOME} -e JVM_OPTS= \
        centos bash ${CASSANDRA_SCRIPT_DIR}/umask_run.sh "
    log "Starting Cassandra node '$node'..."
    log "  Start number: ${start_num}"
    log "  Cassandra home: ${app_home}"
    log "  JAVA HOME: ${JAVA_HOME}"
    log "  JAVA version: ${JAVA_VERSION}"
    log "  JAVA OPTS: ${JAVA_OPTS}"
    log "  JAVA OPTS expanded: ${java_opts}"
    log "  Cassandra version: ${cass_ver}"
    log "  Cassandra props: ${CASSANDRA_PROPS}"
    log "  Node: ${node}"
    log "  Node number: ${node_num}"
    log "  ARTAPort: ${ARTAPort}"
    log "  COLLECT: ${COLLECT}"
    local out="${node_dir}/cassandra${node_num}_out.log"
    (
        if [[ "${DOCKER}" == true ]]
        then
            log "  DOCKER: ${DOCKER}"
            log "  DOCKER_MEM: ${DOCKER_MEM}"
            log "  DOCKER_CPUS: ${DOCKER_CPUS}"
            log "  dock_mem: ${dock_mem}"
        else
            export NUMACTL_ARGS
            export NUMACTL="numactl ${NUMACTL_ARGS}"
            export JAVA_HOME
            export COLLECT
            unset JVM_OPTS
        fi
        log "  NUMACTL: ${NUMACTL}"
        log "  NUMACTL_ARGS: ${NUMACTL_ARGS}"
        log "  cmdx: ${cmdx}"
        cd "${node_dir}"
        ${cmdx} ${app_home}/bin/cassandra -f &> "${out}" &
    )
}

wait_cassandra_node_started() {
    local node=$1
    local node_num=$2
    local node_num_=$((node_num - 1))
    local start_num=$3
    local node_dir="${RESULTS_DIR}/node_${node}"
    local data_dir="$(get_data_dir ${node})"
    local app_home="${data_dir}/${APP_NAME}"
    local java_opts=$(get_java_opts . cassandra)
    local out="${node_dir}/cassandra${node_num}_out.log"
    local ARTAPort
    echo "${java_opts}" | grep -q ARTAPort && ARTAPort=(${java_opts/*ARTAPort=/})
    ##sleep 10
    wait_for_app_start "Cassandra" "${out}" "Starting listening for CQL clients on" || return 1
    log_cmd "ZST info after Cassandra start" "zing-ps -V && zing-ps -s"
    (( start_num == 1 )) && start_monitor_tools "${node_dir}"
    if [[ -n "${ARTAPort}" && -f "${JAVA_HOME}/etc/ZVRobot.zip" ]]
    then
        local props="${node_dir}/ZVRobot/ZVRobot.prop"
        log "Startig ZVRobot: ${CLIENT_JAVA_HOME}/bin/java -jar "${node_dir}/ZVRobot"/*.jar ${node_dir} ${props}"
        nohup ${CLIENT_JAVA_HOME}/bin/java -jar "${node_dir}/ZVRobot"/ZVRobot-*.jar "${node_dir}" "${props}" &> "${node_dir}/ZVRobot_out.log" &
    fi
    return 0
}

#
# arg 1 - node name
#
nodeltool_cassandra_node() {
    local node=$1
    shift
    local app_home="$(get_data_dir ${node})/${APP_NAME}"
    local nodetool="${app_home}/bin/nodetool"
    log "Nodetool: ${@}"
    (
        export JAVA_HOME
        $nodetool ${@}
    ) 2>&1
}

#
# arg 1 - node name
#
stop_cassandra_node() {
    local node=$1
    log "Stopping Cassandra node $node..."
    stop_start_node
    stop_cassandra_process
}

#
# arg 1 - node name
# arg 2 - delete cassandra data
#
finish_cassandra_node() {
    local node=$1
    local delete_data=$2
    local node_dir="${RESULTS_DIR}/node_${node}"
    local data_dir="$(get_data_dir ${node})"
    local app_home="${data_dir}/${APP_NAME}"
    log "Finishing Cassandra node $node..."
    print_disk_usage "Disk usage before Cassandra node finish" "${data_dir}" |& logx "### "
    log_cmd "Copying Cassandra logs" "cp -v ${app_home}/logs/* '${node_dir}/logs'"
    cleanup_cassandra_node "${node}" "${delete_data}"
    [[ -d "${data_dir}" ]] && print_disk_usage "Disk usage after Cassandra node finish" "${data_dir}" |& logx "### "
    print_sys_info > "${node_dir}/system_info2.log"
    log "Cassandra node finished"
}

deopt_cassandra_node() {
    local node=$1
    local method=$2
    local ops=$3
    local pid=$( find_process -f "Dcassandra.logdir=" )
    if [[ -n "${pid}" ]]
    then
        log "Performing Cassandra compiler ops: pid=${pid} method=${method} ops=${ops}"
        local op
        for op in ${ops//+/ }
        do
            log "jcmd ${pid} Compiler {${method}}(${op})"
            ${JAVA_HOME}/bin/jcmd ${pid} "Compiler {${method}}(${op})"
        done
    else
        log "Failed to detect Cassandra pid"
    fi
}

cassandra_utils_cmd() {
    log "cassandra_utils_cmd: ${@}"
    process_args "${@}"
    "${ARGS[@]}"
}

cassandra_node_cmd() {
    logd "cassandra_node_cmd [${@}]"
    local func=$1
    shift
    local node=$1
    shift
    if [[ "$node" == localhost ]]
    then
        $func $node ${@}
    else
        host_cmd "$node" "bash '${CASSANDRA_RUN_CMD}' cassandra_utils_cmd 'DEBUG=${DEBUG}' 'RESULTS_DIR=${RESULTS_DIR}' \
        'APPS_DIR=${APPS_DIR}' 'DATA_DIR=${DATA_DIR}' 'APP_NAME=${APP_NAME}' 'DIST_DIR=${DIST_DIR}' 'HOSTS_FILE=${HOSTS_FILE}' \
        'DOCKER=${DOCKER}' 'NODE_CPU=${NODE_CPU}' 'DOCKER_MEM=${DOCKER_MEM}' 'DOCKER_CPUS=${DOCKER_CPUS}' 'USE_TOP=${USE_TOP}' \
        'NUM_TOKENS=${NUM_TOKENS}' 'CLIENT_TLS=${CLIENT_TLS}' 'SERVER_TLS=${SERVER_TLS}' 'NUMACTL_ARGS=${NUMACTL_ARGS}' \
        'JAVA_HOME=${JAVA_HOME}' 'JAVA_VERSION=${JAVA_VERSION}' 'JAVA_OPTS=${JAVA_OPTS}' 'CASSANDRA_PROPS=${CASSANDRA_PROPS}' 'COLLECT=${COLLECT}' 'ZVR_SECONDS=${ZVR_SECONDS}' \
        $func $node ${@}"
    fi
}

var_cassandra_start_num=0

init_cassandra() {
    log "Initializing Cassandra cluster..."
    init_nodes Cassandra "cassandra_node_cmd init_cassandra_node" "${NODES_IP}" || return 1
}

start_cassandra() {
    (( var_cassandra_start_num++ ))
    log "Starting Cassandra nodes [${var_cassandra_start_num}]..."
    start_nodes Cassandra "cassandra_node_cmd start_cassandra_node" ${var_cassandra_start_num} || return 1
    log "Waiting for Cassandra nodes started [${var_cassandra_start_num}]..."
    start_nodes Cassandra "cassandra_node_cmd wait_cassandra_node_started" ${var_cassandra_start_num} || return 1
    return 0
}

stop_cassandra() {
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Stopping Cassandra cluster - not applicable for AWS MCS"
        return
    fi
    log "Stopping Cassandra cluster [$@]..."
    finish_nodes Cassandra "cassandra_node_cmd stop_cassandra_node" $@
}

finish_cassandra() {
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Finishing Cassandra cluster - not applicable for AWS MCS"
        return
    fi
    log "Nodetool ${MASTER_NODE} proxyhistograms..."
    cassandra_node_cmd nodeltool_cassandra_node ${MASTER_NODE} proxyhistograms >> "${RESULTS_DIR}/proxyhistograms_${var_cassandra_start_num}.log"
    log "Finishing Cassandra cluster [$@]..."
    finish_nodes Cassandra "cassandra_node_cmd finish_cassandra_node" $@
}

cleanup_cassandra() {
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Cleaning Cassandra cluster - not applicable for AWS MCS"
        return
    fi
    log "Cleaning Cassandra cluster [$@]..."
    init_nodes Cassandra "cassandra_node_cmd cleanup_cassandra_node" $@
}

restart_cassandra() {
    if [[ "${AWS_MCS}" == true ]]
    then
        log "Restarting Cassandra cluster - not applicable for AWS MCS"
        return
    fi
    log "Restarting Cassandra cluster..."
    stop_cassandra true
    sleep 10
    start_cassandra
    local res=$?
    sleep 10
    return $res
}

init_and_start_cassandra() {
    init_cassandra
    start_cassandra $1
}

if [[ "$BASH_SOURCE" == "$0" ]]
then
    "$@"
fi
