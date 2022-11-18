#!/bin/bash
#
# Copyright (c) 2018-2022 Azul Systems
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
# Network monitor
#

SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)

if echo "1 + 2" | bc > /dev/null 2>&1
then
    bc=bc
else
    bc="${SCRIPT_DIR}/bc"
fi

get_stamp() {
    local p=$(date -u "+%Y-%m-%d %H:%M:%S,%N")
    echo ${p::23},UTC
}

START=$(get_stamp)
DELAY=${1:-5}
HOST=${2:-$HOSTNAME}
no=0

echo "DELAY: ${DELAY}"
echo "START: ${START}"
echo "HOST: ${HOST}"
echo
echo "RX bytes, RX packets, TX bytes, TX packets"

while true
do
    (( no++ ))
    mapfile <<EOF data
$(ip -s link)
EOF
    line_count=${#data[@]}
    RX_bytes=0
    RX_packets=0
    TX_bytes=0
    TX_packets=0
    for (( i = 0; i < line_count; i += 6 ))
    do
        line=${data[$i]}
        name=($line)
        name=${name[1]}
        name=${name%:}
        [[ "$name" == lo ]] && continue
        RX=${data[$((i + 3))]}
        RX=($RX)
        RX_bytes_=${RX[0]}
        RX_packets_=${RX[1]}
        TX=${data[$((i + 5))]}
        TX=($TX)
        TX_bytes_=${TX[0]}
        TX_packets_=${TX[1]}
        (( RX_bytes_ == 0 )) && continue
        RX_bytes=$( echo "$RX_bytes + $RX_bytes_" | $bc )
        RX_packets=$( echo "$RX_packets + $RX_packets_" | $bc )
        TX_bytes=$( echo "$TX_bytes + $TX_bytes_" | $bc )
        TX_packets=$( echo "$TX_packets + $TX_packets_" | $bc )
    done
    if [[ -n "$RX_bytes_prev" ]]
    then
        rxb=$( echo "$RX_bytes - $RX_bytes_prev" | $bc )
        rxp=$( echo "$RX_packets - $RX_packets_prev" | $bc )
        txb=$( echo "$TX_bytes - $TX_bytes_prev" | $bc )
        txp=$( echo "$TX_packets - $TX_packets_prev" | $bc )
        echo "$rxb, $rxp, $txb, $txp"
#    else
#        echo "$RX_bytes, $RX_packets, $TX_bytes, $TX_packets"
    fi
    RX_bytes_prev=$RX_bytes
    RX_packets_prev=$RX_packets
    TX_bytes_prev=$TX_bytes
    TX_packets_prev=$TX_packets
    sleep "$DELAY"
done
