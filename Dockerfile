# See https://github.com/influxdata/influxdata-docker/tree/master/telegraf

# Use different base images per architecture
FROM ubuntu:22.04 AS base-amd64
FROM alpine AS base-arm64  
FROM alpine AS base-arm

# Use the appropriate base
FROM base-${TARGETARCH} AS final

# Set up architecture mapping for Telegraf downloads
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

# Install packages based on architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            wget gnupg ca-certificates iputils-ping net-tools procps tzdata lm-sensors && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        apk update && \
        apk add --no-cache wget gnupg iputils ca-certificates net-snmp-tools procps lm_sensors tzdata raspberrypi raspberrypi-utils-vcgencmd && \
        update-ca-certificates; \
    fi


# Set up DNS resolution for Alpine
RUN if [ "$TARGETARCH" != "amd64" ]; then \
        echo 'hosts: files dns' >> /etc/nsswitch.conf; \
    fi

ENV TELEGRAF_VERSION=1.35.2

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN set -ex && \
    case "$TARGETPLATFORM" in \
        "linux/amd64") ARCH="amd64" ;; \
        "linux/arm64") ARCH="arm64" ;; \
        "linux/arm/v7") ARCH="armhf" ;; \
        *) echo "Unsupported platform: $TARGETPLATFORM" && exit 1 ;; \
    esac && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        apt-get update && apt-get install -y --no-install-recommends tar && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        apk add --no-cache --virtual .build-deps tar; \
    fi && \
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
    find /usr/src -name "telegraf.conf" -exec cp {} /etc/telegraf/ \; || echo "No default config found, will need to provide one" && \
    find /usr/src -name "telegraf" -type f -executable -exec cp {} /usr/bin/telegraf \; && \
    chmod +x /usr/bin/telegraf && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    if [ "$TARGETARCH" != "amd64" ]; then \
        apk del .build-deps; \
    fi

EXPOSE 8125/udp 8092/udp 8094

ENTRYPOINT ["/entrypoint.sh"]
CMD ["telegraf"]

