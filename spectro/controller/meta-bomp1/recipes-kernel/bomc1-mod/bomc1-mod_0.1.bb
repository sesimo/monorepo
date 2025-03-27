SUMMARY = "Kernel module for interfacing with BOMC1 Spectrometer"
DESCRIPTION = "${SUMMARY}"
LICENSE = "CLOSED"
LIC_FILES_CHKSUM = ""

inherit module

FILESEXTRAPATHS:prepend = "/home/ubuntu/manifest:"
SRC_URI = "file://kmod-bomc1"

S = "${WORKDIR}/kmod-bomc1"
