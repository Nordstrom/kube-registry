FROM quay.io/nordstrom/baseimage-ubuntu:16.04
MAINTAINER Nordstrom Kubernetes Platform Team "techk8s@nordstrom.com"

ADD build/registry-monitor /usr/bin/registry-monitor

ENTRYPOINT ["/usr/bin/registry-monitor"]
