FROM ubuntu:latest

RUN apt-get update -qq && apt-get install --no-install-recommends -yq build-essential git ca-certificates

RUN apt-get install --no-install-recommends -yq curl unzip qemu-system-x86 qemu-system-aarch64
