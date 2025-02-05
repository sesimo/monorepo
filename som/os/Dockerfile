
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential chrpath cpio debianutils diffstat file gawk gcc git \
    iputils-ping libacl1 liblz4-tool locales python3 python3-git \
    python3-jinja2 python3-pexpect python3-pip python3-subunit \
    socat texinfo unzip wget xz-utils zstd python3-venv

COPY requirements.txt /tmp/requirements.txt

RUN locale-gen "en_US.UTF-8"

RUN useradd -m ubuntu
USER ubuntu

ENV HOME=/home/ubuntu
RUN python3 -m venv ${HOME}/venv

ENV PATH=${HOME}/venv/bin:${PATH}
ENV VIRTUAL_ENV=${HOME}/venv
ENV WORKDIR=${HOME}/work

ARG KAS_WORK_DIR=_work
ENV KAS_WORK_DIR=${WORKDIR}/${KAS_WORK_DIR}

RUN pip install -r /tmp/requirements.txt

WORKDIR ${WORKDIR}
