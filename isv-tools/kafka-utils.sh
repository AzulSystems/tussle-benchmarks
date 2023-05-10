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
# Kafka utility methods
#

[[ "${DEBUG}" == true ]] && echo "BASH_SOURCE ${BASH_SOURCE[@]}"

KAFKA_SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd -P)
KAFKA_RUN_CMD=$(readlink -f ${BASH_SOURCE})

JAVA_OPTS=${JAVA_OPTS:-"-Xmx1g -Xms1g __JHICCUP__"}
ZK_JAVA_OPTS=${ZK_JAVA_OPTS:-"-Xmx1g -Xms1g __JHICCUP__"}
WORKER_JAVA_OPTS=${WORKER_JAVA_OPTS:-"-Xms4G -Xmx4G __JHICCUP__"}

PORT_DELTA=${PORT_DELTA:-100}
ZK_PORT=${ZK_PORT:-2181}
KAFKA_PORT=${KAFKA_PORT:-9092}
OMB_WORKER_PORT=${OMB_WORKER_PORT:-9190}

KAFKA_PROPS=${KAFKA_PROPS:-}
KAFKA_LOGGING_PROPS=${KAFKA_LOGGING_PROPS:-}
KAFKA_JMX_OPTS=${KAFKA_JMX_OPTS:-}
KAFKA_LOG4J_OPTS=${KAFKA_LOG4J_OPTS:-}

INSTALL_ONLY=${INSTALL_ONLY:-false}
PRE_CMD=${PRE_CMD:-}

source "${KAFKA_SCRIPT_DIR}/utils.sh" || exit 1

PROP_SEP="="
TOOLS_HOME=$(get_dir "${APPS_DIR}/kafka/tools")

var_init_kafka_done=false

get_servers_with_ports() {
    local start_port=${1}
    local nodes=${2}
    local sep=${3:-","}
    local prefix=${4}
    nodes=( $(print_nodes ${nodes}) )
    local node
    local hosts=""
    for node in "${nodes[@]}"
    do
        local host_name=${node/:*}
        local host_ip=$(resolve_hostname "${host_name}")
        host_ip=${host_ip:-${host_name}}
        local port_idx=0
        [[ "${node}" == *:* ]] && port_idx=${node/*:}
        local port=$((start_port + port_idx*PORT_DELTA))
        [[ -n "${hosts}" ]] && hosts+=${sep}
        hosts+="${prefix}${host_ip}:${port}"
    done
    echo ${hosts}
}

get_brokers_with_ports() {
    get_servers_with_ports "${KAFKA_PORT}" "${@}"
}

get_zookeepers_with_ports() {
    get_servers_with_ports "${ZK_PORT}" "${@}"
}

init_kafka_options() {
    ${var_init_kafka_done} && return
    APP_NAME=${APP_NAME:-kafka_2.13-3.3.2}
    APP_DIST=${APP_DIST:-${DIST_DIR}}
    JAVA_DIST=${JAVA_DIST:-${DIST_DIR}}
    OMB_NAME=${OMB_NAME:-openmessaging-benchmark-0.0.1}
    [[ "${CLIENT_JAVA_HOME}" == JAVA_HOME ]] && CLIENT_JAVA_HOME=${JAVA_HOME}
    WORKER_JAVA_HOME=${WORKER_JAVA_HOME:-$CLIENT_JAVA_HOME}
    TOOLS_HOME=$(get_dir "${APPS_DIR}/kafka/tools")
    REMOTE_UTILS_CMD=${TOOLS_HOME}/$(basename "${KAFKA_RUN_CMD}")
    NODES=${NODES:-localhost}
    MONITOR_DIRS=${DATA_DIRS}
    local nodes=( $(print_nodes ${NODES}) )
    local brokers_with_ports=$(get_brokers_with_ports ${NODES})
    local zk_hodes_with_ports=$(get_zookeepers_with_ports ${ZK_NODES})
    ZK_NODES=${ZK_NODES:-${nodes[0]}}
    NODE_OPTS+=( "SKIP_INIT=true" )
    NODE_OPTS+=( "PORT_DELTA=${PORT_DELTA}" )
    NODE_OPTS+=( "ZK_NODES=${ZK_NODES}" )
    NODE_OPTS+=( "ZK_PORT=${ZK_PORT}" )
    NODE_OPTS+=( "KAFKA_JMX_OPTS=${KAFKA_JMX_OPTS}" )
    NODE_OPTS+=( "KAFKA_LOG4J_OPTS=${KAFKA_LOG4J_OPTS}" )
    NODE_OPTS+=( "KAFKA_PORT=${KAFKA_PORT}" )
    NODE_OPTS+=( "OMB_WORKER_PORT=${OMB_WORKER_PORT}" )
    NODE_OPTS+=( "APP_DIST=${APP_DIST}" )
    NODE_OPTS+=( "JAVA_DIST=${JAVA_DIST}" )
    NODE_OPTS+=( "OMB_NAME=${OMB_NAME}" )
    NODE_OPTS+=( "WORKER_JAVA_HOME=${WORKER_JAVA_HOME}" )
    NODE_OPTS+=( "PRE_CMD=${PRE_CMD}" )
    local kafka_ver=${APP_NAME##*/}
    kafka_ver=${kafka_ver#*_}
    log "Kafka setup:"
    log "  Kafka: ${APP_NAME}"
    log "  Kafka version: ${kafka_ver}"
    log "  Kafka distr: ${APP_DIST}"
    log "  Kafka zookeepers: ${zk_hodes_with_ports}"
    log "  Kafka brokers: ${brokers_with_ports}"
    log "  Kafka props: ${KAFKA_PROPS}"
    log "  Kafka logging props: ${KAFKA_LOGGING_PROPS}"
    log "  Kafka SSL: ${KAFKA_SSL}"
    log "  Kafka Java options: ${JAVA_OPTS}"
    log "  Zookeeper Java options: ${ZK_JAVA_OPTS}"
    log "  Client JAVA_HOME: ${CLIENT_JAVA_HOME}"
    log "  Client Java options: ${CLIENT_JAVA_OPTS}"
    log "  Client working dir: ${CLIENT_DIR}"
    log "  JAVA_HOME: ${JAVA_HOME:? Missing JAVA_HOME parameter}"
    log "  APPS_DIR: ${APPS_DIR}"
    log "  DATA_DIRS: ${DATA_DIRS}"
    log "  PRE_CMD: ${PRE_CMD}"
    log "  RESULTS_DIR: ${RESULTS_DIR}"
    var_init_kafka_done=true
}

make_zookeeper_jaas() {
    cat <<EOF
Server {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    user_super="admin-secret"
    user_kafka="kafka-secret";
};
EOF
# Client {
#     org.apache.zookeeper.server.auth.DigestLoginModule required
#     username="kafka"
#     password="kafka-secret";
# };
}

make_broker_jaas() {
    cat <<EOF
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="kafkabroker"
    password="kafkabroker-secret"
    user_kafkabroker="kafkabroker-secret"
    user_kafka-broker-metric-reporter="kafkabroker-metric-reporter-secret"
    user_client="client-secret";
};
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="kafka"
    password="kafka-secret";
};
EOF
}

#
# Start Zookeeper
#
# nodes_cmd start_broker "${NODES}" true "${DATA_DIRS}" "${zk_hodes_with_ports}" "${JAVA_HOME}" "${JAVA_OPTS}" "${KAFKA_PROPS}" "${KAFKA_LOGGING_PROPS}" "${KAFKA_SSL}" "${INSTALL_ONLY}" || return 1
#
start_zookeeper() {
    log "start_zookeeper..."
    print_args "${@}" | logxd "  "
    local node=${1}
    local node_num=${2}
    local java_home=${3}
    local java_opts=${4}
    local use_ssl=${5:-false}
    local install_only=${6:-false}
    local host_name=${node/:*}
    local host_ip=$(resolve_hostname "${host_name}")
    host_ip=${host_ip:-${host_name}}
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local zk_id=${node_num}
    local app_home=$(get_dir "${APPS_DIR}/kafka")
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_zookeeper@${host_name}.$((port_idx + 1))")
    log "Initializing Zookeeper (${node} #${node_num})..."
    install_artifact "${APP_NAME}" "${APP_DIST}" "${app_home}" false || return 1
    app_home+="/${APP_NAME}"
    install_java "${java_home}" "${JAVA_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    rm -frv "${wrk_dir}"
    mkdir -p "${wrk_dir}/config" || return 1
    mkdir -p "${wrk_dir}/logs" || return 1
    mkdir -p "${wrk_dir}/data" || return 1
    clean_dir "${wrk_dir}/config"
    clean_dir "${wrk_dir}/logs"
    clean_dir "${wrk_dir}/data"
    echo ${zk_id} > "${wrk_dir}/data/myid"
    local zk_props=${wrk_dir}/config/zookeeper.properties
    local zk_log=${wrk_dir}/logs/zookeeper-server_out.log
    local zk_orig_props="${app_home}/config/zookeeper.properties"
    local port=$((ZK_PORT + port_idx*PORT_DELTA))
    [[ -f "${app_home}/etc/kafka/zookeeper.properties" ]] && zk_orig_props="${app_home}/etc/kafka/zookeeper.properties"
    cp -fv "${zk_orig_props}" "${zk_props}" |& logx "  "
    local zk_kafka_opts
    if is_true "${use_ssl}"
    then
        zk_kafka_opts="-Djava.security.auth.login.config=${wrk_dir}/config/zookeeper_jaas.conf"
        make_zookeeper_jaas > "${wrk_dir}/config/zookeeper_jaas.conf"
        set_property "${zk_props}" authProvider.sasl org.apache.zookeeper.server.auth.SASLAuthenticationProvider
    fi
    set_property "${zk_props}" dataDir "${wrk_dir}/data"
    set_property "${zk_props}" clientPort ${port}
    local zk_nodes=( $(print_nodes ${ZK_NODES}) )
    local zk_nodes_num=${#zk_nodes[@]}
    if (( zk_nodes_num > 1 ))
    then
        set_property "${zk_props}" tickTime 2000
        set_property "${zk_props}" initLimit 5
        set_property "${zk_props}" syncLimit 2
        for (( zk_idx = 0; zk_idx < zk_nodes_num; zk_idx++ ))
        do
            set_property "${zk_props}" server.$((zk_idx + 1)) ${zk_nodes[$zk_idx]}:$((2666 + zk_idx)):$((3666 + zk_idx))
        done
    fi
    java_opts=$(preprocess_java_opts "${java_opts}" . zk)
    java_opts="-Dproc.zookeeper ${java_opts}"
    log "  java_home: ${java_home}"
    log "  java_opts: ${java_opts}"
    log "  app_home: ${app_home}"
    log "  wrk_dir: ${wrk_dir}"
    is_true "${install_only}" && return
    check_monitors || start_monitors "${wrk_dir}/logs"
    local zcmd=${app_home}/bin/zookeeper-server-start.sh
    [[ -f ${app_home}/bin/zookeeper-server-start ]] && zcmd=${app_home}/bin/zookeeper-server-start
    log "Starting Zookeeper (${node}) [${zcmd}]..."
    (
        export LOG_DIR="${wrk_dir}/logs"
        export KAFKA_JVM_PERFORMANCE_OPTS="-Djava.awt.headless=true"
        export KAFKA_HEAP_OPTS="${java_opts}"
        export KAFKA_GC_LOG_OPTS="-Dplaceholder"
        export KAFKA_JMX_OPTS
        export KAFKA_LOG4J_OPTS
        export EXTRA_ARGS='-name zookeeper'
        export GC_LOG_ENABLED=false
        export JAVA_HOME=${java_home}
        export KAFKA_OPTS=${zk_kafka_opts}
        cd "${wrk_dir}/logs"
        "${zcmd}" "${zk_props}" &> "${zk_log}" &
    )
    check_jvm_log "${zk_log}" || return 1
    return
}

wait_zookeeper_node_started() {
    log "wait_zookeeper_node_started..."
    print_args "${@}" | logxd "  "
    local node=$1
    local host_name=${node/:*}
    local node_num=$2
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local port=$((ZK_PORT + port_idx*PORT_DELTA))
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_zookeeper@${host_name}.$((port_idx + 1))")
    local zk_log=${wrk_dir}/logs/zookeeper-server_out.log
    check_jvm_log "${zk_log}" || return 1
    wait_for_port ${port} Zookeeper || return 1
    return
}

#
# Start Kafka broker
#
# nodes_cmd start_broker "${NODES}" true "${DATA_DIRS}" "${zk_hodes_with_ports}" "${JAVA_HOME}" "${JAVA_OPTS}" "${KAFKA_PROPS}" "${KAFKA_LOGGING_PROPS}" "${KAFKA_SSL}" "${INSTALL_ONLY}" || return 1
#
start_broker() {
    log "start_broker..."
    print_args "${@}" | logxd "  "
    local node=${1}
    local host_name=${node/:*}
    local node_num=${2}
    local data_dirs=${3}
    local zk_hodes_with_ports=${4}
    local java_home=${5}
    local java_opts=${6}
    local kafka_props=${7}
    local kafka_logging_props=${8}
    local use_ssl=${9:-false}
    local install_only=${10:-false}
    local host_ip=$(resolve_hostname "${host_name}")
    host_ip=${host_ip:-${host_name}}
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_broker@${host_name}.$((port_idx+1))")
    local app_home=$(get_dir "${APPS_DIR}/kafka")
    data_dirs=${data_dirs:-"${wrk_dir}/data"}
    log "Initializing Kafka node (${node} #${node_num})..."
    install_artifact "${APP_NAME}" "${APP_DIST}" "${app_home}" false || return 1
    app_home+="/${APP_NAME}"
    install_java "${java_home}" "${JAVA_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    mkdir -p "${wrk_dir}/config" || return 1
    mkdir -p "${wrk_dir}/logs" || return 1
    clean_dir "${wrk_dir}/config"
    clean_dir "${wrk_dir}/logs"
    local ddir
    for ddir in ${data_dirs//,/ }
    do
        log "Kafke data dir: ${ddir}" 
        mkdir -p "${ddir}" || return 1
        clean_dir "${ddir}"
    done
    local server_props=${wrk_dir}/config/server.properties
    local log4j_props=${wrk_dir}/config/log4j.properties
    local log=${wrk_dir}/logs/kafka-server_out.log
    local port=$((KAFKA_PORT + port_idx*PORT_DELTA))
    local kb_orig_props="${app_home}/config/server.properties"
    [[ -f "${app_home}/etc/kafka/server.properties" ]] && kb_orig_props="${app_home}/etc/kafka/server.properties"
    cp -fv "${kb_orig_props}" "${server_props}" |& logx "  "
    set_property "${server_props}" broker.id "${node_num}"
    local server_kafka_opts
    local listeners
    local use_ssl_simple=false
    if is_true "${use_ssl}"
    then
        server_kafka_opts="-Djava.security.auth.login.config=${wrk_dir}/config/kafka_server_jaas.conf"
        make_broker_jaas > "${wrk_dir}/config/kafka_server_jaas.conf"
        local ssl_port=$((port))
        local sasl_ssl_port=$((port + 1))
        listeners="SSL://${host_ip}:${ssl_port},SASL_SSL://${host_ip}:${sasl_ssl_port}"
        if is_true "${use_ssl_simple}"
        then
            ssl_port=$((port + 1))
            sasl_ssl_port=$((port + 2))
            listeners="PLAINTEXT://${host_ip}:${port},SSL://${host_ip}:${ssl_port},SASL_SSL://${host_ip}:${sasl_ssl_port}"
        fi
        set_property "${server_props}" sasl.enabled.mechanisms SASL # PLAIN #
        set_property "${server_props}" sasl.mechanism.inter.broker.protocol PLAIN
        set_property "${server_props}" security.inter.broker.protocol SSL
        set_property "${server_props}" ssl.client.auth required
        set_property "${server_props}" ssl.keystore.location "${KAFKA_SCRIPT_DIR}/cert/kafka.server.keystore.jks"
        set_property "${server_props}" ssl.keystore.password testtest
        set_property "${server_props}" ssl.truststore.location "${KAFKA_SCRIPT_DIR}/cert/kafka.server.truststore.jks"
        set_property "${server_props}" ssl.truststore.password testtest
        set_property "${server_props}" ssl.key.password testtest
        set_property "${server_props}" ssl.endpoint.identification.algorithm ""
        set_property "${server_props}" authorizer.class.name kafka.security.authorizer.AclAuthorizer
        set_property "${server_props}" super.users "User:CN="
        set_property "${server_props}" zookeeper.set.acl true
    else
        listeners="PLAINTEXT://${host_ip}:${port}"
    fi
    set_property "${server_props}" listeners "${listeners}"
    set_property "${server_props}" advertised.listeners "${listeners}"
    set_property "${server_props}" host.name "${host_ip}"
    set_property "${server_props}" advertised.host.name "${host_ip}"
    set_property "${server_props}" zookeeper.connect "${zk_hodes_with_ports}"
    set_property "${server_props}" log.dirs "${data_dirs}"
    set_properties "${kafka_props}" "${server_props}" "${node_num}"
    if [[ -n "${kafka_logging_props}" ]]
    then
        local log4j_orig_props="${app_home}/config/log4j.properties"
        [[ -f "${app_home}/etc/kafka/log4j.properties" ]] && log4j_orig_props="${app_home}/etc/kafka/log4j.properties"
        cp -fv "${log4j_orig_props}" "${log4j_props}" |& logx "  "
        set_properties "${kafka_logging_props}" "${log4j_props}" "${node_num}"
    fi
    java_opts=$(preprocess_java_opts "${java_opts}" . broker)
    java_opts="-Dproc.broker${node_num} ${java_opts}"
    [[ -n "${kafka_logging_props}" ]] && \
    java_opts+=" -Dlog4j.configuration=${log4j_props}"
    log "  java_home: ${java_home}"
    log "  java_opts: ${java_opts}"
    log "  app_home: ${app_home}"
    log "  wrk_dir: ${wrk_dir}"
    log "  host_name: ${host_name}"
    log "  host_ip: ${host_ip}"
    log "  kafka_props: ${kafka_props}"
    log "  kafka_logging_props: ${kafka_logging_props}"
    is_true "${install_only}" && return
    check_monitors || start_monitors "${wrk_dir}/logs"
    local server_start_cmd=${app_home}/bin/kafka-server-start.sh
    [[ -f ${app_home}/bin/kafka-server-start ]] && server_start_cmd=${app_home}/bin/kafka-server-start
    log "Starting Kafka server node (${node}) ${PRE_CMD} [${server_start_cmd}]..."
    (
        export LOG_DIR="${wrk_dir}/logs"
        export KAFKA_JVM_PERFORMANCE_OPTS="-Djava.awt.headless=true"
        export KAFKA_HEAP_OPTS="${java_opts}"
        export KAFKA_GC_LOG_OPTS="-Dplaceholder"
        export KAFKA_JMX_OPTS
        export KAFKA_LOG4J_OPTS
        export EXTRA_ARGS='-name kafkaServer'
        export GC_LOG_ENABLED=false
        export JAVA_HOME=${java_home}
        export KAFKA_OPTS=${server_kafka_opts}
        cd "${wrk_dir}/logs"
        ${PRE_CMD} "${server_start_cmd}" "${server_props}" &> "${log}" &
    )
    sleep 3
    check_jvm_log "${log}" || return 1
    return
}

wait_broker_node_started() {
    log "wait_broker_node_started..."
    print_args "${@}" | logxd "  "
    local node=$1
    local host_name=${node/:*}
    local node_num=$2
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local port=$((KAFKA_PORT + port_idx*PORT_DELTA))
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_broker@${host_name}.$((port_idx+1))")
    local log=${wrk_dir}/logs/kafka-server_out.log
    check_jvm_log "${log}" || return 1
    wait_for_port ${port} Kafka || return 1
    return
}

cleanup_broker() {
    local node=${1}
    local host_name=${node/:*}
    local node_num=${2}
    local data_dirs=${3}
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_broker@${host_name}.$((port_idx+1))")
    data_dirs=${data_dirs:-${wrk_dir}/data}
    local ddir
    for ddir in ${data_dirs//,/ }
    do
        log "Cleaning Kafke data dir: ${ddir}" 
        mkdir -p "${ddir}" || return 1
        clean_dir "${ddir}" | logx "[clean_dir] " 10
    done
}

#
# Stop Zookeeper
#
stop_zookeeper() {
    log "stop_zookeeper: [${@}]"
    print_args "${@}" | logxd '  '
    local node=${1}
    local node_num=${2}
    stop_process -f "Dproc.zookeeper"
    stop_monitors
}

#
# Stop Kafka node
#
stop_kafka_broker() {
    log "stop_kafka_broker: [${@}]"
    print_args "${@}" | logxd '  '
    local node=${1}
    local node_num=${2}
    stop_process -f "Dproc.broker${node_num}"
    stop_monitors
}

var_kafka_start_num=0

setup_tools() {
    if (( var_kafka_start_num == 0 ))
    then
        local nodes="${ZK_NODES},${NODES},${WORKER_NODES}"
        log
        log ${APP_SEP}
        log "Pushing tools to remote hosts: ${nodes}"
        log ${APP_SEP}
        log
        nodes_func install_tools_node "${nodes}" true || return 1
        if is_true "${DROP_CACHES}"
        then
            log "Dropping caches on remote hosts: ${nodes}"
            nodes_cmd drop_caches "${nodes}"
            nodes_cmd stop_monitors "${nodes}"
        fi
    fi
    return 0
}

start_kafka_cluster() {
    (( var_kafka_start_num++ ))
    local zk_hodes_with_ports=$(get_zookeepers_with_ports ${ZK_NODES})
    log
    log ${APP_SEP}
    log "Starting Kafka cluster [${var_kafka_start_num}]"
    log ${APP_SEP}
    log
    nodes_cmd start_zookeeper "${ZK_NODES}" true "${JAVA_HOME}" "${ZK_JAVA_OPTS}" "${KAFKA_SSL}" "${INSTALL_ONLY}" || return 1
    nodes_cmd wait_zookeeper_node_started "${ZK_NODES}" true || return 1
    nodes_cmd start_broker "${NODES}" true "${DATA_DIRS}" "${zk_hodes_with_ports}" "${JAVA_HOME}" "${JAVA_OPTS}" "${KAFKA_PROPS}" "${KAFKA_LOGGING_PROPS}" "${KAFKA_SSL}" "${INSTALL_ONLY}" || return 1
    nodes_cmd wait_broker_node_started "${NODES}" true || return 1
    return
}

start_kafka_node() {
    local node=$1
    local node_num=$2
    log
    log ${APP_SEP}
    log "Starting Kafka node: ${node} - ${node_num}"
    log ${APP_SEP}
    log
    node_cmd start_broker "${node}" "${node_num}" "${JAVA_HOME}" "${JAVA_OPTS}" "${KAFKA_PROPS}" "${KAFKA_LOGGING_PROPS}" ${INSTALL_ONLY} || return 1
    return
}

cleanup_tools() {
    local nodes="${ZK_NODES},${NODES},${WORKER_NODES}"
    log
    log ${APP_SEP}
    log "Cleaning tools on remote hosts: ${nodes}"
    log ${APP_SEP}
    log
    nodes_cmd stop_monitors "${nodes}"
    nodes_func cleanup_tools_node "${nodes}" false
}

stop_kafka_cluster() {
    log
    log ${APP_SEP}
    log "Stopping Kafka cluster"
    log ${APP_SEP}
    log
    nodes_cmd stop_kafka_broker "${NODES}" false
    nodes_cmd stop_zookeeper "${ZK_NODES}" 0
}

cleanup_kafka() {
    log
    log ${APP_SEP}
    log "Cleaning Kafka cluster"
    log ${APP_SEP}
    log
    nodes_cmd cleanup_broker "${NODES}" false "${DATA_DIRS}"
    nodes_cmd cleanup_node "${ZK_NODES}" false kafka
    [[ -n "${WORKER_NODES}" ]] && \
    nodes_func cleanup_node "${WORKER_NODES}" false kafka
    return
}

fetch_kafka_logs() {
    log
    log ${APP_SEP}
    log "Fetching Kafka logs"
    log ${APP_SEP}
    log
    nodes_func fetch_logs_node "${ZK_NODES}" false kafka
    nodes_func fetch_logs_node "${NODES}" false kafka
    [[ -n "${WORKER_NODES}" ]] && \
    nodes_func fetch_logs_node "${WORKER_NODES}" false kafka
    return
}

start_kafka() {
    setup_tools || return 1
    start_kafka_cluster
}

stop_kafka() {
    setup_tools || return 1
    stop_kafka_cluster
}

finish_kafka() {
    stop_kafka_cluster
    fetch_kafka_logs
    cleanup_kafka
    cleanup_tools
}

# ACKS_DOC = 0 | 1 | all

var_app_home=""
var_omb_home=""

install_kafka_client() {
    [[ -d "${var_app_home}" ]] && return
    log "install_client_kafka..."
    local app_home=$(get_dir "${CLIENT_DIR}/kafka")
    install_artifact "${APP_NAME}" "${APP_DIST}" "${app_home}" false || return 1
    install_java "${CLIENT_JAVA_HOME}" "${APP_DIST}" "${app_home}" || return 1
    var_app_home="${app_home}/${APP_NAME}"
}

install_omb() {
    log "install_omb..."
    local app_home=$(get_dir "${CLIENT_DIR}/kafka")
    install_artifact "${OMB_NAME}" "${APP_DIST}" "${app_home}" true || return 1
    var_omb_home="${app_home}/${OMB_NAME}"
}

start_omb_worker() {
    log "start_omb_worker: [${@}]"
    print_args "${@}" | logxd '  '
    local node=${1:-localhost}
    local node_num=${2:-1}
    local java_home=${3:-$WORKER_JAVA_HOME}
    local java_opts=${4:-$WORKER_JAVA_OPTS}
    local install_only=${5:-false}
    local host_name=${node/:*}
    local port_idx=0
    [[ "${node}" == *:* ]] && port_idx=${node/*:}
    local wrk_dir=$(get_dir "${DATA_DIR}/kafka/node_ombworker@${host_name}.$((port_idx + 1))")
    local app_home=$(get_dir "${APPS_DIR}/kafka")
    log "Initializing OMB worker (${node} #${node_num})..."
    install_artifact "${OMB_NAME}" "${APP_DIST}" "${app_home}" false || return 1
    app_home+="/${OMB_NAME}"
    install_java "${java_home}" "${JAVA_DIST}" "${app_home}" || return 1
    java_home=${var_java_home}
    mkdir -p "${wrk_dir}/logs" || return 1
    clean_dir "${wrk_dir}/logs"
    java_opts=$(preprocess_java_opts "${java_opts}" . ombworker)
    java_opts="-Dproc.ombworker${node_num} ${java_opts}"
    log "  java_home: ${java_home}"
    log "  java_opts: ${java_opts}"
    log "  app_home: ${app_home}"
    log "  wrk_dir: ${wrk_dir}"
    log "  host_name: ${host_name}"
    is_true "${install_only}" && return
    check_monitors || start_monitors "${wrk_dir}/logs"
    local port=$((OMB_WORKER_PORT + port_idx*PORT_DELTA))
    local port2=$((OMB_WORKER_PORT + port_idx*PORT_DELTA + 300))
    local out_log=${wrk_dir}/logs/benchmark-worker.log
    log "Starting OMB worker  (${node}) [${zcmd}]..."
    (
        cd "${wrk_dir}/logs"
        ${var_java_home}/bin/java ${java_opts} -Duser.timezone=UTC -server -cp "${app_home}/lib/*" io.openmessaging.benchmark.worker.BenchmarkWorker --port ${port} --stats-port ${port2} &> /dev/null &
    )
    sleep 1
    check_jvm_log "${out_log}" || return 1
    wait_for_port ${port} ombworker || return 1
    return
}

stop_omb_worker() {
    log "stop_omb_worker: [${@}]"
    print_args "${@}" | logxd '  '
    local node=${1}
    local node_num=${2}
    stop_process -f "Dproc.ombworker${node_num}"
}

create_topic() {
    install_kafka_client || return 1
    log "create_topic: [${@}]"
    init_arg_list "${@}"
    local partitions=$(get_arg partitions 1)
    local rf=$(get_arg rf 1) # replication-factor
    local minInsync=$(get_arg minInsync "") # min.insync.replicas
    local topic=$(get_arg topic testtopic)
    local client_config
    if is_true "${KAFKA_SSL}"
    then
        mk_res_dir
        client_config="${RESULTS_DIR}/client_security.properties"
        create_client_security_properties > "${client_config}"
    fi
    local props
    [[ -n "${minInsync}" ]] && props+=" --config min.insync.replicas=${minInsync}"
    [[ -n "${client_config}" ]] && props+=" --command-config ${client_config}"
    local brokers=( $(get_brokers_with_ports "${NODES}" " ") )
    log "create_topic: topic=${topic} partitions=${partitions} replication-factor=${rf} ${props} bootstrap-server=${brokers[0]}..."
    local kcmd=${var_app_home}/bin/kafka-topics.sh
    [[ -f ${var_app_home}/bin/kafka-topics ]] && kcmd=${var_app_home}/bin/kafka-topics
    (
    export JAVA_HOME=${var_java_home}
    log "  Client JAVA_HOME: ${JAVA_HOME}"
    ${kcmd} --bootstrap-server ${brokers[0]} --create --topic "${topic}" --partitions ${partitions} --replication-factor ${rf} ${props}
    )
}

delete_topic() {
    install_kafka_client || return 1
    log "delete_topic: [${@}]"
    local topic=${1:-testtopic}
    local client_config
    if is_true "${KAFKA_SSL}"
    then
        mk_res_dir
        client_config="${RESULTS_DIR}/client_security.properties"
        create_client_security_properties > "${client_config}"
    fi
    [[ -n "${client_config}" ]] && client_config="--command-config ${client_config}"
    local brokers=( $(get_brokers_with_ports "${NODES}" " ") )
    log "delete_topic: topic=${topic} bootstrap-server=${brokers[0]}..."
    local kcmd=${var_app_home}/bin/kafka-topics.sh
    [[ -f ${var_app_home}/bin/kafka-topics ]] && kcmd=${var_app_home}/bin/kafka-topics
    (
    export JAVA_HOME=${var_java_home}
    log "  Client JAVA_HOME: ${JAVA_HOME}"
    ${kcmd} --bootstrap-server ${brokers[0]} --delete --topic ${topic} ${client_config}
    )
}

create_client_security_properties() {
    cat<<EOF
ssl.endpoint.identification.algorithm=
security.protocol=SASL_SSL
ssl.keystore.location=${KAFKA_SCRIPT_DIR}/cert/kafka.server.keystore.jks
ssl.keystore.password=testtest
ssl.truststore.location=${KAFKA_SCRIPT_DIR}/cert/kafka.client.truststore.jks
ssl.truststore.password=testtest
#sasl.mechanism=SASL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="client" password="client-secret2";
EOF
}

perf_producer() {
    install_kafka_client || return 1
    local step=$1
    shift
    local ipar=$1
    shift
    init_arg_list "${@}"
    local kafka_test_name=kafka-producer-perf-test
    log "[${kafka_test_name}] ${step}-${ipar} args: [${@}]"
    local topic=$(get_arg topic testtopic)
    local mcount=$(get_arg mcount 50000)
    local mlen=$(get_arg mlen 1024)
    local throughput=$(get_arg throughput -1)
    local acks=$(get_arg acks 1)
    local maxReqSize=$(get_arg maxReqSize "")
    local batchSize=$(get_arg batchSize "")
    local lingerMs=$(get_arg lingerMs "")
    local bro=$(get_arg bro "")
    local brokers
    if [[ "${bro}" == one ]]
    then
        brokers=( $(get_brokers_with_ports "${NODES}" " ") )
        local num_brokers=${#brokers[@]}
        local ipar0=$((ipar - 1))
        ipar0=$((ipar0 % num_brokers))
        brokers=${brokers[ipar0]}
    else
        brokers=( $(get_brokers_with_ports "${NODES}" ",") )
    fi
    local props="acks=${acks}"
    [[ -n "${batchSize}" ]] && props+=" batch.size=${batchSize}"
    [[ -n "${lingerMs}" ]] && props+=" linger.ms=${lingerMs}"
    [[ -n "${maxReqSize}" ]] && props+=" max.request.size=${maxReqSize}"
    props+=" bootstrap.servers=${brokers}"
    mk_res_dir
    local producer_config
    local client_config
    if is_true "${KAFKA_SSL}"
    then
        client_config="${RESULTS_DIR}/client_security.properties"
        create_client_security_properties > "${client_config}"
        producer_config="--producer.config ${client_config}"
    fi
    local out="${RESULTS_DIR}/perf_test_${step}_${ipar}.log"
    local kcmd=${var_app_home}/bin/${kafka_test_name}.sh
    [[ -f ${var_app_home}/bin/${kafka_test_name} ]] && kcmd=${var_app_home}/bin/${kafka_test_name}
    (
        export JAVA_HOME=${var_java_home}
        log "  Client JAVA_HOME: ${JAVA_HOME}"
        log "[${kafka_test_name}] ${step}-${ipar}: ${topic} ${mcount} ${mlen} ${throughput}  (producer-props: ${props}) ..." |& tee -a "${out}"
        ${kcmd} --topic ${topic} --num-records ${mcount} --record-size ${mlen} --throughput ${throughput} --producer-props ${props} --print-metrics ${producer_config} \
        >> "${out}"
    )
    log "[${kafka_test_name}] ${step}-${ipar}: ${topic} ${mcount} ${mlen} ${throughput}  FINISHED"
}

perf_consumer() {
    install_kafka_client || return 1
    local step=$1
    shift
    local ipar=$1
    shift
    init_arg_list "${@}"
    local kafka_test_name=kafka-consumer-perf-test
    log "[${kafka_test_name}] ${step}-${ipar} args: [${@}]"
    local topic=$(get_arg topic testtopic)
    local mcount=$(get_arg mcount 50000)
    local fetchSize=$(get_arg fetchSize 4000000)
    local brokers=$(get_brokers_with_ports ${NODES})
    mk_res_dir
    local out="${RESULTS_DIR}/perf_test.log"
    local kcmd=${var_app_home}/bin/${kafka_test_name}.sh
    [[ -f ${var_app_home}/bin/${kafka_test_name} ]] && kcmd=${var_app_home}/bin/${kafka_test_name}
    (
        export JAVA_HOME=${var_java_home}
        log "  Client JAVA_HOME: ${JAVA_HOME}"
        log "[${kafka_test_name}] ${step}-${ipar} : ${topic} ${mcount} ${fetchSize} ..." |& tee -a "${out}"
        ${kcmd} --broker-list ${brokers} --topic ${topic} --messages ${mcount} --fetch-size ${fetchSize} \
        >> "${out}"
    )
    log "[${kafka_test_name}] ${step}-${ipar} : ${topic} ${mcount}) FINISHED"
}

perf_end2end() {
    install_kafka_client || return 1
    local step=$1
    shift
    local ipar=$1
    shift
    init_arg_list "${@}"
    local kafka_test_name=kafka-end2end-perf-test
    log "[${kafka_test_name}] ${step}-${ipar} args: [${@}]"
    local topic=$(get_arg topic testtopic)
    local mcount=$(get_arg mcount 50000)
    local mlen=$(get_arg mlen 1024)
    local acks=$(get_arg acks 1)
    local brokers=$(get_brokers_with_ports ${NODES})
    mk_res_dir
    local out="${RESULTS_DIR}/perf_test.log"
    local kcmd=${var_app_home}/bin/kafka-run-class.sh
    [[ -f ${var_app_home}/bin/kafka-run-class ]] && kcmd=${var_app_home}/bin/kafka-run-class
    (
        export JAVA_HOME=${var_java_home}
        log "Client JAVA_HOME: ${JAVA_HOME}"
        log "[${kafka_test_name}] ${step}-${ipar}: ${topic} ${mcount} ${mlen}  (props: acks=${acks}) ..." |& tee -a "${out}"
        ${kcmd} kafka.tools.EndToEndLatency ${brokers} ${topic} ${mcount} ${acks} ${mlen} \
        >> "${out}"
    )
    log "[${kafka_test_name}] ${step}-${ipar}: ${topic} ${mcount} ${mlen}  (props: acks=${acks}) FINISHED"
}

if [[ "${BASH_SOURCE}" == "${0}" ]]
then
    process_args "${@}"
    is_true "${SKIP_INIT}" || init_kafka_options
    "${ARGS[@]}"
fi
