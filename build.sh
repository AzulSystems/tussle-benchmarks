#!/bin/bash

_BASE_DIR=$(cd $(dirname $0); pwd)

make_sb() {(
    cd ${_BASE_DIR}/springboot-benchmark-app || exit 1
    echo "Building $(pwd)..."
    mvn clean
    mvn package -DskipTests && \
    from=$(find target -name *.jar) && \
    to=${from/-jar-with-dependencies/} && \
    to=../lib/${to##*/} && \
    cp -fv ${from} ${to} && \
    chmod 777 ${to}
)}

make_cli() {(
    bash "${_BASE_DIR}/../benchmarks-common/build.sh" || exit 1
    cd ${_BASE_DIR}/springboot-benchmark-cli || exit 1
    echo "Building $(pwd)..."
    mvn clean 
    mvn package -DskipTests && \
    from=$(find target -name *-jar-with-dependencies.jar) && \
    to=${from/-jar-with-dependencies/} && \
    to=../lib/${to##*/} && \
    cp -fv ${from} ${to} && \
    chmod 777 ${to}
    echo "Installing built file '${to}' ..."
    mvn install:install-file -Dfile=${to} -DpomFile=pom.xml
)}

mkdir -p lib
make_cli && make_sb
