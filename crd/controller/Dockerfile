FROM quay.io/gravitational/debian-tall:0.0.1
LABEL maintainer="Gravitational <admin@gravitational.com>"
LABEL description="Kubernetes controller for custom resource Nginx."
ADD ./controller /controller
ENTRYPOINT ["/controller"]
