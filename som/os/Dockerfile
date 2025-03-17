FROM ubuntu:22.04 AS yocto-build-base

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/ubuntu

ENV WORKDIR=${HOME}/work

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales curl python3 python3-pip python3-venv ssh tree meld geany \
    make xsltproc docbook-utils fop dblatex xmlto file sudo

RUN locale-gen "en_US.UTF-8"

# Install repo utility
RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > \
    /bin/repo
RUN chmod +x /bin/repo

# Change user
RUN adduser --disabled-password ubuntu
RUN adduser ubuntu sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER ubuntu

WORKDIR ${WORKDIR}

# Setup venv
RUN python3 -m venv ${HOME}/venv

ENV PATH=${HOME}/venv/bin:${PATH}
ENV VIRTUAL_ENV=${HOME}/venv

# STM32MP specific
FROM yocto-build-base AS yocto-build-st

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    bsdmainutils build-essential chrpath cpio debianutils diffstat gawk \
    gcc-multilib git git-lfs iputils-ping libegl1-mesa libgmp-dev libmpc-dev \
    libsdl1.2-dev libssl-dev libusb-1.0-0 lz4 pylint python3 python3-git \
    python3-jinja2 python3-pexpect python3-pip socat texinfo unzip wget \
    xterm xz-utils zstd
USER ubuntu
