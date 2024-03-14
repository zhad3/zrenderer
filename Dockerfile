FROM alpine:3.19 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev openssl-dev ldc dub && \
    mkdir /zrenderer

WORKDIR /zrenderer
COPY . .
RUN dub clean && dub build --build=release --config=docker --force :server


FROM alpine:3.19

EXPOSE 11011

RUN apk update && \
    apk add --no-cache zlib openssl llvm-libunwind && \
    mkdir /zren && \
    adduser --disabled-password -h /zren -s /bin/sh zren zren

WORKDIR /zren
COPY --from=build --chown=zren:zren /zrenderer/bin/zrenderer-server .
COPY --from=build --chown=zren:zren /zrenderer/resolver_data ./resolver_data

USER zren

CMD ["./zrenderer-server"]
