#!/bin/sh

# Optional ENV variables:
# * ADVERTISED_HOST: the external ip for the container, e.g. `docker-machine ip \`docker-machine active\``
# * ADVERTISED_PORT: the external port for Kafka, e.g. 9092
# * ZK_CHROOT: the zookeeper chroot that's used by Kafka (without / prefix), e.g. "kafka"
# * LOG_RETENTION_HOURS: the minimum age of a log file in hours to be eligible for deletion (default is 168, for 1 week)
# * LOG_RETENTION_BYTES: configure the size at which segments are pruned from the log, (default is 1073741824, for 1GB)
# * NUM_PARTITIONS: configure the default number of log partitions per topic

# Configure advertised host/port if we run in helios
propertiesFile="$KAFKA_HOME/config/server.properties"

if [ -n "$HELIOS_PORT_kafka" ]; then
    ADVERTISED_HOST=$(echo "$HELIOS_PORT_kafka" | cut -d':' -f 1 | xargs -n 1 dig +short | tail -n 1)
    ADVERTISED_PORT=$(echo "$HELIOS_PORT_kafka" | cut -d':' -f 2)
fi

# Set the external host and port
if [ -n "$ADVERTISED_HOST_CMD" ]; then
    ADVERTISED_HOST=$(eval "$ADVERTISED_HOST_CMD")
fi

if [ -n "$ADVERTISED_HOST" ]; then
    echo "advertised host: $ADVERTISED_HOST"
    # Uncomment advertised.listeners
    sed -r -i 's/^(#)(advertised.listeners)/\2/g' "$propertiesFile"

    # Replace your.host.name with $ADVERTISED_HOST
    sed -r -i "s/your.host.name/$ADVERTISED_HOST/g" "$propertiesFile"
fi
if [ -n "$ADVERTISED_PORT" ]; then
    echo "advertised port: $ADVERTISED_PORT"
    sed -r -i "s/(.*)(advertised.listeners)=(.*):.*/\2=\3:$ADVERTISED_PORT/g" "$propertiesFile"
fi

if [ -n "$ADVERTISED_LISTENERS" ]; then
    echo "advertised listerners: $ADVERTISED_LISTENERS"
    sed -r -i "s|^(.*)(advertised.listeners).*|\2=${ADVERTISED_LISTENERS}|g" "$propertiesFile"
fi

if [ -n "$NUM_PARTITIONS" ]; then
    echo "Num Partitions: $NUM_PARTITIONS"
    sed -r -i "s/#(num.partitions)=(.*)/\1=$NUM_PARTITIONS/g" "$propertiesFile"
fi

# Set the zookeeper chroot
if [ -n "$ZK_CHROOT" ]; then
    # wait for zookeeper to start up
    until /usr/share/zookeeper/bin/zkServer.sh status; do
        sleep 0.1
    done

    # create the chroot node
    echo "create /$ZK_CHROOT \"\"" | /usr/share/zookeeper/bin/zkCli.sh || {
        echo "can't create chroot in zookeeper, exit"
        exit 1
    }

    # configure kafka
    sed -r -i "s/(zookeeper.connect)=(.*)/\1=localhost:2181\/$ZK_CHROOT/g" "$propertiesFile"
fi

# Allow specification of log retention policies
if [ -n "$LOG_RETENTION_HOURS" ]; then
    echo "log retention hours: $LOG_RETENTION_HOURS"
    sed -r -i "s/(log.retention.hours)=(.*)/\1=$LOG_RETENTION_HOURS/g" "$propertiesFile"
fi
if [ -n "$LOG_RETENTION_BYTES" ]; then
    echo "log retention bytes: $LOG_RETENTION_BYTES"
    sed -r -i "s/#(log.retention.bytes)=(.*)/\1=$LOG_RETENTION_BYTES/g" "$propertiesFile"
fi

# Configure the default number of log partitions per topic
if [ -n "$NUM_PARTITIONS" ]; then
    echo "default number of partition: $NUM_PARTITIONS"
    sed -r -i "s/(num.partitions)=(.*)/\1=$NUM_PARTITIONS/g" "$propertiesFile"
fi

# Enable/disable auto creation of topics
if [ -n "$AUTO_CREATE_TOPICS" ]; then
    echo "auto.create.topics.enable: $AUTO_CREATE_TOPICS"
    if grep -q "auto.create.topics.enable" "$propertiesFile"; then
        sed -r -i "s/(auto.create.topics.enable=(.*)/\1=$AUTO_CREATE_TOPICS/g" "$propertiesFile"
    else
        echo "" >> "$propertiesFile"
        echo "auto.create.topics.enable=$AUTO_CREATE_TOPICS" >> "$propertiesFile"
    fi
fi

# Run Kafka
$KAFKA_HOME/bin/kafka-server-start.sh "$propertiesFile"
