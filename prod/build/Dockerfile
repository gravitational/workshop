FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -y gcc
ADD hello.c /build/hello.c
RUN gcc /build/hello.c -o /build/hello
ENTRYPOINT ["/build/hello"]
