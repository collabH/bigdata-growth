#!/usr/bin/env bash

type=$1

case ${type} in
    'start')
        kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties &
        kafka-server-start1.sh -daemon ${KAFKA_HOME}/config/server1.properties &
        kafka-server-start2.sh -daemon ${KAFKA_HOME}/config/server2.properties &
    ;;
    'stop')
        kafka-server-stop.sh $KAFKA_HOME/config/server.properties
        kafka-server-stop.sh $KAFKA_HOME/config/server1.properties
        kafka-server-stop.sh $KAFKA_HOME/config/server2.properties
    ;;
esac