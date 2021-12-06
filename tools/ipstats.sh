#!/bin/bash

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

DELAY=${1:-5}
HOST=${2:-$HOSTNAME}
START=$(get_stamp)

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
