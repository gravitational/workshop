#
# Build stage.
#
FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y gcc
ADD hello.c /build/hello.c
RUN gcc /build/hello.c -o /build/hello

#
# Run stage.
#
FROM quay.io/gravitational/debian-tall:0.0.1

COPY --from=0 /build/hello /hello
ENTRYPOINT ["/hello"]
