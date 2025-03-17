#!/bin/bash

here=$(dirname $0)

if [ ! -d "$here/.repo" ]; then
    ./repo-sync.sh
fi

cmd=$1
shift

export DISTRO=openstlinux-weston
export MACHINE=stm32mp1

source "layers/meta-st/scripts/envsetup.sh"

exec "$cmd"
