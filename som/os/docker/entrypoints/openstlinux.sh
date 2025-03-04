#!/bin/bash

cmd=$1
shift

export DISTRO=openstlinux-weston
export MACHINE=stm32mp1

source "layers/meta-st/scripts/envsetup.sh"

exec "$cmd"
