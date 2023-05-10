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
# HADOOP utility methods
#

#echo "BASH_SOURCE ${BASH_SOURCE[@]} -- ${0}"
HADOOP_SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd -P)
HADOOP_RUN_CMD=$(readlink -f ${BASH_SOURCE})

source "${HADOOP_SCRIPT_DIR}/utils.sh" || exit 1

INSTALL_ONLY=${INSTALL_ONLY:-false}
PRE_CMD=${PRE_CMD:-}
DATA_REPLICATION=${DATA_REPLICATION:-}
MIN_BLOCK_SIZE=${MIN_BLOCK_SIZE:-16}
MASTER_PORT=${MASTER_PORT:-9000}
PROP_SEP="="
TOOLS_HOME=$(get_dir "${APPS_DIR}/hadoop/tools")

var_init_hadoop_done=false

init_hadoop_options() {
    ${var_init_hadoop_done} && return
    APP_NAME=${APP_NAME:-hadoop-3.3.4}
    APP_DIST=${APP_DIST:-${DIST_DIR}}
    JAVA_DIST=${JAVA_DIST:-${DIST_DIR}}
    [[ "${CLIENT_JAVA_HOME}" == JAVA_HOME ]] && CLIENT_JAVA_HOME=${JAVA_HOME}
    REMOTE_UTILS_CMD=${TOOLS_HOME}/$(basename "${HADOOP_RUN_CMD}")
    NODES=${NODES:-localhost}
    local nodes=( $( print_nodes ${NODES} ) )
    MASTER_HOST=${MASTER_HOST:-${nodes[0]}}
    NODE_OPTS+=( "SKIP_INIT=true" )
    NODE_OPTS+=( "MASTER_HOST=${MASTER_HOST}" )
    NODE_OPTS+=( "MASTER_PORT=${MASTER_PORT}" )
    NODE_OPTS+=( "APP_DIST=${APP_DIST}" )
    NODE_OPTS+=( "JAVA_DIST=${JAVA_DIST}" )
    NODE_OPTS+=( "PRE_CMD=${PRE_CMD}" )
    NODE_OPTS+=( "DATA_REPLICATION=${DATA_REPLICATION}" )
    local hadoop_ver=${APP_NAME##*/}
    hadoop_ver=${hadoop_ver#*_}
    log "Hadoop setup:"
    log "hadoop setup:"
    log "  hadoop: ${APP_NAME}"
    log "  hadoop version: ${hadoop_ver}"
    log "  hadoop distr: ${APP_DIST}"
    log "  JAVA_HOME: ${JAVA_HOME:? Missing JAVA_HOME parameter}"
    log "  JAVA_OPTS: ${JAVA_OPTS}"
    log "  Client JAVA_HOME: ${CLIENT_JAVA_HOME}"
    log "  Client JAVA_OPTS: ${CLIENT_JAVA_OPTS}"
    log "  APPS_DIR: ${APPS_DIR}"
    log "  DATA_DIR: ${DATA_DIR}"
    log "  PRE_CMD: ${PRE_CMD}"
    log "  RESULTS_DIR: ${RESULTS_DIR}"
    var_init_hadoop_done=true
}

create_core_config() {
    local master=$1
    local tmpDir=$2
    cat<<____EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${master}/</value>
        <description>NameNode URI</description>
    </property>
    <property>
        <name>fs.default.name</name>
        <value>hdfs://${master}/</value>
        <description>NameNode URI</description>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>${tmpDir}</value>
    </property>
</configuration>
____EOF
}

create_hdfs_config() {
    local dataDir=$1
    local dfsReplication=$2
    local minBlockSize=$3
    cat<<____EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
____EOF
    cat<<____EOF
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file://${dataDir}</value>
        <description>DataNode directory for storing data chunks.</description>
    </property>
____EOF
    cat<<____EOF
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file://${dataDir}</value>
        <description>NameNode directory for namespace and transaction logs storage.</description>
    </property>
____EOF
    [[ -n "${dfsReplication}" ]] && cat<<____EOF
    <property>
        <name>dfs.replication</name>
        <value>dfsReplication</value>
        <description>Number of replication for each chunk.</description>
    </property>
____EOF
    [[ -n "${minBlockSize}" ]] && cat<<____EOF
    <property>
        <name>dfs.namenode.fs-limits.min-block-size</name>
        <value>${minBlockSize}</value>
        <description>Minimum block size in bytes, enforced by the Namenode at create time.</description>
    </property>
____EOF
    cat<<____EOF
</configuration>
____EOF
}

create_yarn_config() {
    local yarnHostname=$1
    cat<<____EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>${yarnHostname}</value>
        <description>The hostname of the ResourceManager</description>
    </property>
<!--
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
        <description>shuffle service for MapReduce</description>
    </property>
    <property>
        <name>yarn.resourcemanager.nodemanagers.heartbeat-interval-ms</name>
        <value>50</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>32000</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-vcores</name>
        <value>32</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.class</name>
        <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>40000</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>40</value>
    </property>
-->
</configuration>
____EOF
}

install_hadoop() {
    if [[ -d "${HADOOP_HOME}" ]]
    then
        log "Using existing Hadoop installation: ${HADOOP_HOME}"
    else
        log "Hadoop has not been installed, re-installing..."
        local app_home=$(get_dir "${APPS_DIR}/hadoop")
        install_artifact "${APP_NAME}" "${APP_DIST}" "${app_home}" false || return 1
        app_home+="/${APP_NAME}"
        HADOOP_HOME=${app_home}
    fi
    export HADOOP_HOME
}

#
# Start Hadoop broker node
#
# nodes_cmd start_broker "${NODES}" true "node" "${JAVA_HOME}" "${JAVA_OPTS}" false "${INSTALL_ONLY}" || return 1
#
start_hadoop_node() {
    log "start_hadoop_node..."
    print_args "${@}" | logxd "  "
    local host=${1}
    local node_num=${2}
    local node=${3}
    local java_home=${4}
    local java_opts=${5}
    local sync_run=${6:-false}
    local install_only=${7:-false}
    local app_home=$(get_dir "${APPS_DIR}/hadoop")
    local wrk_dir=$(get_dir "${DATA_DIR}/hadoop/node_${node}@${host}.${node_num}")
    local data_dir=$(get_data_dir "${node}@${host}.${node_num}")
    local tool=hdfs
    [[ "${node}" == *manager ]] && tool=yarn
#    logd "Cleaning hadoop tmp files: /tmp/hadoop*"
#    rm -vfr /tmp/hadoop*
    log "Initializing Hadoop node '${node}'..."
    install_artifact "${APP_NAME}" "${APP_DIST}" "${app_home}" false || return 1
    install_java "${java_home}" "${JAVA_DIST}" "${app_home}" || return 1
    app_home+="/${APP_NAME}"
    java_home=${var_java_home}
    mkdir -p "${wrk_dir}/config" || return 1
    mkdir -p "${wrk_dir}/data" || return 1
    mkdir -p "${wrk_dir}/logs" || return 1
    mkdir -p "${wrk_dir}/tmp" || return 1
    create_core_config "${MASTER_HOST}:${MASTER_PORT}" "${wrk_dir}/tmp" > "${wrk_dir}/config/core-site.xml"
    create_hdfs_config "${wrk_dir}/data" "${DATA_REP3LICATION}" "${MIN_BLOCK_SIZE}"  > "${wrk_dir}/config/hdfs-site.xml"
    create_yarn_config "${MASTER_HOST}" "${wrk_dir}/tmp" > "${wrk_dir}/config/yarn-site.xml"
    cp -v "${app_home}/etc/hadoop/log4j.properties" "${wrk_dir}/config/"
    cp -v "${app_home}/etc/hadoop/capacity-scheduler.xml" "${wrk_dir}/config/"
    is_true "${install_only}" && return
    check_monitors || start_monitors "${wrk_dir}/logs"
    #TODO? drop_caches
    java_opts=$(preprocess_java_opts "${java_opts}" . ${node})
    java_opts="-Dproc.${node}.${node_num} ${java_opts}"
    local log="${wrk_dir}/logs/${node}-server_out.log"
    (
        cd "${wrk_dir}/logs"
        export JAVA_HOME=${java_home}
        export HADOOP_HOME=${app_home}
        export HADOOP_CONF_DIR="${wrk_dir}/config"
        export HADOOP_LOG_DIR="${wrk_dir}/logs"
        export HADOOP_OPTS="${java_opts}"
        export HDFS_AUDIT_LOGGER=INFO,console
        if [[ "${node}" == namenode ]]
        then
            log "Formatting namenode..."
            ${app_home}/bin/hdfs namenode -format -nonInteractive &> "${wrk_dir}/logs/${node}_format.log"
        fi
        log "Starting Hadoop node ${tool} ${node}@${host} ${PRE_CMD} ..."
        if is_true "${sync_run}"
        then
            ${PRE_CMD} ${app_home}/bin/${tool} ${node} |& tee "${log}"
        else
            ${PRE_CMD} ${app_home}/bin/${tool} ${node} &> "${log}" &
        fi
    )
    wait_for_app_start "${node}" "${log}" "ipc.Server: IPC Server listener on" || return 1
    return
}

#
# Stop Hadoop node
#
stop_hadoop_node() {
    log "stop_hadoop_broker: [$@]"
    print_args "${@}" | logxd "  "
    local host=${1}
    local node_num=${2}
    local node=${3}
    stop_process -f "Dproc.${node}.${node_num}"
    stop_monitors
    drop_caches
}

var_hadoop_start_num=0

setup_tools() {
    if (( var_hadoop_start_num == 0 ))
    then
        log
        log ${APP_SEP}
        log "Pushing tools to remote hosts: ${NODES}"
        log ${APP_SEP}
        log
        nodes_func install_tools_node "${NODES}" true || return 1
    fi
    return 0
}

start_hadoop_cluster() {
    local to_start=${1:-all}
    (( var_hadoop_start_num++ ))
    log
    log ${APP_SEP}
    log "Starting Hadoop cluster [${var_hadoop_start_num}]"
    log ${APP_SEP}
    log
    if [[ "$to_start" == all || "$to_start" == *namenode* || "$to_start" == *hdfs* ]]
    then
        node_cmd start_hadoop_node "${MASTER_HOST}" 1 namenode "${JAVA_HOME}" "${JAVA_OPTS}" false "${INSTALL_ONLY}" || return 1
    fi
    if [[ "$to_start" == all || "$to_start" == *datanode* || "$to_start" == *hdfs* ]]
    then
        nodes_cmd start_hadoop_node "${NODES}" true datanode "${JAVA_HOME}" "${JAVA_OPTS}" false "${INSTALL_ONLY}" || return 1
    fi
    if [[ "$to_start" == all || "$to_start" == *resourcemanager* || "$to_start" == *yarn* ]]
    then
        node_cmd start_hadoop_node "${MASTER_HOST}" 1 resourcemanager "${JAVA_HOME}" "${JAVA_OPTS}" false "${INSTALL_ONLY}" || return 1
    fi
    if [[ "$to_start" == all || "$to_start" == *nodemanager* || "$to_start" == *yarn* ]]
    then
        nodes_cmd start_hadoop_node "${NODES}" true nodemanager "${JAVA_HOME}" "${JAVA_OPTS}" false "${INSTALL_ONLY}" || return 1
    fi
    return 0
}

cleanup_tools() {
    log
    log ${APP_SEP}
    log "Cleaning tools on remote hosts"
    log ${APP_SEP}
    log
    nodes_func cleanup_tools_node "${NODES} ${MASTER_HOST}" false
}

stop_hadoop_cluster() {
    log
    log ${APP_SEP}
    log "Stopping Hadoop cluster"
    log ${APP_SEP}
    log
    nodes_cmd stop_hadoop_node "${NODES}" false nodemanager
    nodes_cmd stop_hadoop_node "${NODES}" false datanode
    node_cmd stop_hadoop_node "${MASTER_HOST}" 1 resourcemanager
    node_cmd stop_hadoop_node "${MASTER_HOST}" 1 namenode
}

cleanup_hadoop() {
    log
    log ${APP_SEP}
    log "Cleaning Hadoop cluster"
    log ${APP_SEP}
    log
    nodes_cmd cleanup_node "${NODES} ${MASTER_HOST}" false hadoop
}

fetch_hadoop_logs() {
    log
    log ${APP_SEP}
    log "Fetching Hadoop logs"
    log ${APP_SEP}
    log
    nodes_func fetch_logs_node "${MASTER_HOST} ${NODES}" false hadoop
}

start_hadoop() {
    setup_tools || return 1
    start_hadoop_cluster
}

stop_hadoop() {
    setup_tools || return 1
    stop_hadoop_cluster
}

finish_hadoop() {
    stop_hadoop_cluster
    fetch_hadoop_logs
    cleanup_hadoop
    cleanup_tools
}

if [[ "${BASH_SOURCE}" == "${0}" ]]
then
    process_args "${@}"
    is_true "${SKIP_INIT}" || init_hadoop_options
    "${ARGS[@]}"
fi
