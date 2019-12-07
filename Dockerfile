# Kafka and Zookeeper
FROM alpine:3.9.2

RUN apk add --update openjdk8-jre supervisor bash

ENV ZOOKEEPER_VERSION 3.4.13
ENV ZOOKEEPER_HOME /opt/zookeeper-"$ZOOKEEPER_VERSION"

RUN wget -q http://archive.apache.org/dist/zookeeper/zookeeper-"$ZOOKEEPER_VERSION"/zookeeper-"$ZOOKEEPER_VERSION".tar.gz -O /tmp/zookeeper-"$ZOOKEEPER_VERSION".tgz
RUN ls -l /tmp/zookeeper-"$ZOOKEEPER_VERSION".tgz
RUN tar xfz /tmp/zookeeper-"$ZOOKEEPER_VERSION".tgz -C /opt && rm /tmp/zookeeper-"$ZOOKEEPER_VERSION".tgz
ADD assets/conf/zoo.cfg $ZOOKEEPER_HOME/conf

ENV SCALA_VERSION 2.12
ENV KAFKA_VERSION 2.3.1
ENV KAFKA_HOME /opt/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION"
ENV KAFKA_DOWNLOAD_URL https://archive.apache.org/dist/kafka/"$KAFKA_VERSION"/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz

RUN wget -q $KAFKA_DOWNLOAD_URL -O /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz
RUN tar xfz /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz -C /opt && rm /tmp/kafka_"$SCALA_VERSION"-"$KAFKA_VERSION".tgz

ARG CADDY_VERSION=v1.0.4
ARG CADDY_URL=https://github.com/mholt/caddy/releases/download/${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz
ENV CADDY_HOME /opt/caddy
RUN wget "$CADDY_URL" -O /opt/caddy.tgz \
    && mkdir -p $CADDY_HOME \
    && tar xzf /opt/caddy.tgz -C $CADDY_HOME \
    && rm -f /opt/caddy.tgz
ADD assets/conf/Caddyfile $CADDY_HOME

ADD assets/scripts/start-kafka.sh /usr/bin/start-kafka.sh
ADD assets/scripts/start-zookeeper.sh /usr/bin/start-zookeeper.sh
ADD assets/scripts/start-caddy.sh /usr/bin/start-caddy.sh

# Supervisor config
ADD assets/supervisor/kafka.ini assets/supervisor/zookeeper.ini assets/supervisor/caddy.ini /etc/supervisor.d/

ENV ADVERTISED_HOST 127.0.0.1
ENV ADVERTISED_PORT 9092

# 2181 is zookeeper, 9092 is kafka, 8080 is caddy
EXPOSE 2181 9092 8080

CMD ["supervisord", "-n"]
