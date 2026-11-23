# Builds nginx from source at a chosen version.
#   NGINX_VERSION=1.31.8  -> vulnerable (last mainline before the fix)
#   NGINX_VERSION=1.31.9  -> patched mainline
#   ASAN=1                -> AddressSanitizer build: memory errors are reported
#                            with a stack trace in `docker logs` instead of a
#                            silent worker crash.
FROM debian:bookworm-slim AS build

ARG NGINX_VERSION=1.31.8
ARG ASAN=0

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential ca-certificates curl libpcre2-dev zlib1g-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN curl -fsSLO https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
    && tar xzf nginx-${NGINX_VERSION}.tar.gz

WORKDIR /src/nginx-${NGINX_VERSION}
RUN set -e; \
    if [ "$ASAN" = "1" ]; then \
        CC_OPT="-g -O1 -fno-omit-frame-pointer -fsanitize=address"; \
        LD_OPT="-fsanitize=address"; \
    else \
        CC_OPT="-g -O2"; LD_OPT=""; \
    fi; \
    ./configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/dev/stderr \
        --http-log-path=/dev/stdout \
        --pid-path=/run/nginx.pid \
        --user=nginx --group=nginx \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_v3_module \
        --with-mail --with-mail_ssl_module \
        --with-cc-opt="$CC_OPT" \
        --with-ld-opt="$LD_OPT" \
    && make -j"$(nproc)" && make install

# ---------------------------------------------------------------------------
FROM debian:bookworm-slim

ARG ASAN=0
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpcre2-8-0 zlib1g libssl3 openssl curl \
        $( [ "$ASAN" = "1" ] && echo libasan8 ) \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -s /usr/sbin/nologin nginx

COPY --from=build /etc/nginx /etc/nginx
COPY --from=build /usr/sbin/nginx /usr/sbin/nginx

# Self-signed cert so HTTP/2 over TLS (h2) can be negotiated.
RUN mkdir -p /etc/nginx/certs \
    && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
        -subj "/CN=nginx2root-lab" \
        -keyout /etc/nginx/certs/lab.key -out /etc/nginx/certs/lab.crt

COPY site/ /usr/share/nginx/html/

# Leak detection off: nginx frees little at exit and the noise hides real bugs.
ENV ASAN_OPTIONS=detect_leaks=0:abort_on_error=0:print_legend=0

EXPOSE 443/tcp 443/udp
CMD ["nginx", "-g", "daemon off;"]
