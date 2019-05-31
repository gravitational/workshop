FROM golang:1.12-stretch
ADD memhog.go /build/memhog.go
RUN go build -o /build/memhog /build/memhog.go

FROM quay.io/gravitational/debian-tall:0.0.1
COPY --from=0 /build/memhog /memhog
ENTRYPOINT ["/usr/bin/dumb-init", "/memhog"]
