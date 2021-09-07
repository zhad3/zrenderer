FROM alpine:3.14 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev openssl-dev ldc dub git && \
    mkdir /zrenderer && \
    cd /zrenderer && \
    git clone --depth=1 https://github.com/zhad3/zrenderer.git . && \
    git submodule update --init && \
    dub build --build=release --config=docker :server


FROM alpine:3.14

EXPOSE 11011

RUN apk update && \
    apk add --no-cache zlib openssl llvm-libunwind && \
    adduser --disabled-password zrenderer zrenderer

WORKDIR /home/zrenderer
COPY --from=build --chown=zrenderer:zrenderer /zrenderer/bin/zrenderer-server .
COPY --from=build --chown=zrenderer:zrenderer /zrenderer/resolver_data .
USER zrenderer

CMD ["./zrenderer-server"]
