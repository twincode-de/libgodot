#!/bin/bash

set -eux

BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

GODOT_DIR="$BASE_DIR/godot"
BUILD_DIR=$BASE_DIR/build
BUILD_GDEXTENSION_DIR="$BUILD_DIR/gdextension"

debug=0
host_build_options="vulkan=no d3d12=no"

host_system="$(uname -s)"
host_arch="$(uname -m)"
host_target="editor"
case "$host_system" in
    Linux)
        host_platform="linuxbsd"
    ;;
    Darwin)
        host_platform="macos"
    ;;
    *)
        echo "System $host_system is unsupported"
        exit 1
    ;;
esac

while [ "${1:-}" != "" ]
do
    case "$1" in
        --debug)
            debug=1
        ;;        
        --release)
            debug=0
        ;;
        *)
            echo "Usage: $0 [--debug] [--release]"
            exit 1
        ;;
    esac
    shift
done

mkdir -p $BUILD_DIR

host_godot_suffix="$host_platform.$host_target"
if [ $debug -eq 1 ]
then
    host_build_options="$host_build_options dev_build=yes"
    host_godot_suffix="$host_godot_suffix.dev"
fi
host_godot_suffix="$host_godot_suffix.$host_arch"
host_godot="$GODOT_DIR/bin/godot.$host_godot_suffix"
rm -f $host_godot
cd $GODOT_DIR
scons p=$host_platform target=$host_target arch=$host_arch $host_build_options
cp -vf $host_godot $BUILD_DIR/godot

mkdir -p $BUILD_GDEXTENSION_DIR
cd $BUILD_GDEXTENSION_DIR
$host_godot --headless --dump-extension-api
cp -v $GODOT_DIR/core/extension/gdextension_interface.h $BUILD_GDEXTENSION_DIR/

echo "Successfully updated the GDExtension API."