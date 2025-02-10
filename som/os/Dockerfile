FROM ubuntu:22.04

ARG BASE=poky

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/ubuntu

ENV WORKDIR=${HOME}/work

COPY docker/packages/${BASE}.txt /tmp/packages.txt

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    locales curl python3 python3-pip python3-venv ssh tree meld geany \
    make xsltproc docbook-utils fop dblatex xmlto file \
    $(cat /tmp/packages.txt)

RUN locale-gen "en_US.UTF-8"

RUN curl http://commondatastorage.googleapis.com/git-repo-downloads/repo > \
    /bin/repo

RUN chmod +x /bin/repo

COPY docker/entrypoints/${BASE}.sh /tmp/entrypoint.sh
RUN chmod +x /tmp/entrypoint.sh

COPY docker/setup/${BASE}.sh /tmp/setup.sh
RUN chmod +x /tmp/setup.sh

RUN useradd -m ubuntu
USER ubuntu

COPY requirements.txt ${HOME}/src/requirements.txt

RUN python3 -m venv ${HOME}/venv

ENV PATH=${HOME}/venv/bin:${PATH}
ENV VIRTUAL_ENV=${HOME}/venv

WORKDIR ${WORKDIR}

#RUN /tmp/setup.sh

#SHELL [ "/bin/bash", "/tmp/entrypoint.sh", "/bin/bash", "-c" ]
#ENTRYPOINT [ "/bin/bash", "/tmp/entrypoint.sh" ]
