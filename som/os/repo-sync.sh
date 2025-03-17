
script=$0

if [ ! -d "$(dirname $script)/.repo" ]; then
    echo "Running repo initialization"
    repo init -u https://github.com/STMicroelectronics/oe-manifest.git \
        -b scarthgap
else
    echo "Skipping repo initialization"
fi

repo sync -j16
