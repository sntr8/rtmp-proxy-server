FROM registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-base:devel

ENV RTMP_DELAYER_COMMIT 4df15636ec2d3c65ee1a603f792be2ae86baa4b7

COPY scripts/run-delayer.sh /run-delayer.sh
COPY scripts/entrypoint.sh /entrypoint.sh

RUN apt-get update && apt-get install -y \
    python3-dev \
    git && \
    cd /usr/local/bin && \
    ln -s /usr/bin/python3 python \
    && \

    mkdir -p /opt/rtmp/ && \
    cd /opt/rtmp/ && \
    git clone https://github.com/sntr8/rtmp_stream_delayer.git . && \
    git checkout --detach ${RTMP_DELAYER_COMMIT} && \
    rm delayer_settings.py nginx.conf && \
    chmod +x rtmp_stream_delayer.py && \
    mkdir -p /opt/rtmp/workdir && \
    chmod 777 /opt/rtmp/workdir && \
    rm -rf /var/lib/apt/lists/* \
    && \

    chmod +x /run-delayer.sh && \
    chmod +x /entrypoint.sh \
    && \

    apt-get remove --purge -y \
            git \
    && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /root/.cache && \
    rm -rf /root/.cargo && \
    rm -rf /var/lib/apt/lists/*

    COPY templates/nginx.conf /etc/nginx/nginx.conf.template
    COPY templates/delayer_settings.py /opt/rtmp/delayer_settings.py.template

ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
