FROM ubuntu:latest

RUN <<EOF
apt-get update -qq

apt-get install --no-install-recommends -yq \
  build-essential git ca-certificates &&
  curl unzip qemu-system-x86 qemu-system-aarch64 ovmf

cp /usr/share/ovmf/OVMF.fd resources/ovmf.fd

curl -LO https://releases.hashicorp.com/packer/1.8.2/packer_1.8.2_linux_amd64.zip

unzip -x packer_1.8.2_linux_amd64.zip -o /usr/local/bin packer

EOF
