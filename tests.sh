#!/bin/bash

Z11=/home/buildmaster/nightly/ZVM/dev/in_progress/zvm-dev-3540/sandbox/azlinux/jdk11/x86_64/product
ZULU_11=/home/buildmaster/sw/j2sdk/zulu11.0.9/linux/x86_64

export JAVA_OPTS="-Xmx16g -Xms16g"
export JAVA_HOME=$Z11
./run.sh

export JAVA_OPTS="-Xmx16g -Xms16g -XX:+UseConcMarkSweepGC"
export JAVA_HOME=$ZULU_11
./run.sh

export JAVA_OPTS="-Xmx16g -Xms16g -XX:+UseG1GC"
export JAVA_HOME=$ZULU_11
./run.sh
