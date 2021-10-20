FROM alpine:3.14 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev openssl-dev ldc dub && \
    mkdir /zrenderer

WORKDIR /zrenderer
COPY . .
RUN dub clean && dub build --build=release --config=docker --force :server


FROM alpine:3.14

EXPOSE 11011

RUN apk update && \
    apk add --no-cache zlib openssl llvm-libunwind && \
    adduser --disabled-password zrenderer zrenderer

WORKDIR /home/zrenderer
COPY --from=build --chown=zrenderer:zrenderer /zrenderer/bin/zrenderer-server .
COPY --from=build --chown=zrenderer:zrenderer /zrenderer/resolver_data ./resolver_data
USER zrenderer

CMD ["./zrenderer-server"]