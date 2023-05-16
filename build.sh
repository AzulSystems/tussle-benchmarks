#!/bin/bash
#
# Copyright (c) 2021, Azul Systems
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

_BASE_DIR=$(cd $(dirname $0); pwd)

make_proj() {
    local dir=$1
    (
    cd ${dir} || exit 1
    echo "Building $(pwd)..."
    mvn clean package -DskipTests && \
    from=$(find target -name "*.jar") && \
    to=../lib/${to##*/} && \
    cp -fv ${from} ${to} && \
    chmod 777 ${to}
    )
}

make_sb() {
    make_proj ${_BASE_DIR}/springboot-benchmark-app
}

make_cli() {
    make_proj  ${_BASE_DIR}/httpclient-benchmark-cli
    local cli=$(find ${_BASE_DIR}/httpclient-benchmark-cli/target -name "*.jar")
    echo "Installing built file '${cli}' ..."
    mvn install:install-file -Dfile=${cli} -DpomFile=pom.xml
}

make_io() {
    make_proj ${_BASE_DIR}/io-benchmark
}

make_sql() {
    make_proj ${_BASE_DIR}/sql-benchmark
}

mkdir -p lib
make_cli && make_sb && make_io && make_sql
