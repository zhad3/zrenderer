FROM alpine:3.14 AS build

RUN apk update && \
    apk add --no-cache build-base autoconf libtool zlib-dev openssl-dev ldc dub && \
    mkdir /zrenderer

WORKDIR /zrenderer
COPY . .
RUN dub clean && dub build --build=release --config=docker --force :server


FROM alpine:3.14

ENV ZREN_USER=zren
ENV ZREN_GROUP=zren

EXPOSE 11011

RUN apk update && \
    apk add --no-cache zlib openssl llvm-libunwind && \
    adduser --disabled-password zren zren

WORKDIR /zren
COPY --from=build --chown=$ZREN_USER:$ZREN_GROUP /zrenderer/bin/zrenderer-server .
COPY --from=build --chown=$ZREN_USER:$ZREN_GROUP /zrenderer/resolver_data ./resolver_data
USER zren

CMD ["./zrenderer-server"]
