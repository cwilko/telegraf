# See https://github.com/influxdata/influxdata-docker/tree/master/telegraf

FROM arm64v8/alpine as target-arm64

ENV ARCH arm64

FROM arm32v7/alpine as target-armv7

ENV ARCH armhf

FROM target-$TARGETARCH$TARGETVARIANT as builder

RUN apk add raspberrypi
RUN ln -s /opt/vc/bin/vcgencmd /usr/bin/vcgencmd

RUN echo 'hosts: files dns' >> /etc/nsswitch.conf
RUN apk add --no-cache iputils ca-certificates net-snmp-tools procps lm_sensors tzdata && \
    update-ca-certificates

ENV TELEGRAF_VERSION 1.13.2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN set -ex && \
    apk add --no-cache --virtual .build-deps wget gnupg tar && \
    for key in \
        9D539D90D3328DC7D6C8D3B9D8FF8E1F7DF8B07E ; \
    do \
        gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys "$key" ; \
    done && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz.asc && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz && \
    gpg --batch --verify telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz.asc telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz && \
    mkdir -p /usr/src /etc/telegraf && \
    tar -C /usr/src -xzf telegraf-${TELEGRAF_VERSION}_linux_${ARCH}.tar.gz && \
    mv /usr/src/telegraf/etc/telegraf/telegraf.conf /etc/telegraf/ && \
    chmod +x /usr/src/telegraf/usr/bin/telegraf && \
    cp -a /usr/src/telegraf/usr/bin/telegraf /usr/bin/ && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps

EXPOSE 8125/udp 8092/udp 8094

ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]

