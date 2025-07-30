# See https://github.com/influxdata/influxdata-docker/tree/master/telegraf

FROM alpine

# Set up architecture mapping for Telegraf downloads
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

# Install Raspberry Pi tools only for ARM architectures
RUN if [ "$TARGETARCH" = "arm" ] || [ "$TARGETARCH" = "arm64" ]; then \
        apk add raspberrypi && \
        ln -s /opt/vc/bin/vcgencmd /usr/bin/vcgencmd; \
    fi

RUN echo 'hosts: files dns' >> /etc/nsswitch.conf
RUN apk add --no-cache iputils ca-certificates net-snmp-tools procps lm_sensors tzdata && \
    update-ca-certificates

ENV TELEGRAF_VERSION 1.13.2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN set -ex && \
    case "$TARGETPLATFORM" in \
        "linux/amd64") ARCH="amd64" ;; \
        "linux/arm64") ARCH="arm64" ;; \
        "linux/arm/v7") ARCH="armhf" ;; \
        *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
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

