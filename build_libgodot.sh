#!/bin/bash

set -eux

function toupper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

function get_lib_suffix_from_library_type() {
    if [ "$1" = "static_library" ]
    then
        echo "a"
    elif [ "$1" = "shared_library" ]
    then
        echo "so"
    else
        echo "Unsupported library type: $1"
        exit 0
    fi
}

function godot_to_android_arch() {
    godot_arch="$1"
    case "$godot_arch" in
        arm64)
            echo "arm64-v8a"
            ;;
        arm32)
            echo "armeabi-v7a"
            ;;
        x86_64)
            echo "x86_64"
            ;;
        x86_32)
            echo "x86"
            ;;
        *)
            echo "Unsupported arch: $godot_arch"
            exit 1
    esac
}


BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

GODOT_DIR="$BASE_DIR/godot"
GODOT_CPP_DIR="$BASE_DIR/godot-cpp"
SWIFT_GODOT_DIR="$BASE_DIR/SwiftGodot"
SWIFT_GODOT_KIT_DIR="$BASE_DIR/SwiftGodotKit"
BUILD_DIR=$BASE_DIR/build
BUILD_GDEXTENSION_DIR="$BUILD_DIR/gdextension"

target=""
target_arch=""
target_build_options=""
debug=1
simulator=0
library_type="shared_library" # static_library or shared_library
angle_libs="$BASE_DIR/ANGLE"
profile=""

while [ "${1:-}" != "" ]
do
    case "$1" in
        --debug)
            debug=1
            target="template_debug"
        ;;
        --release)
            debug=0
            target="template_release"
        ;;
        --simulator)
            simulator=1
        ;;
        --library-type)
            shift
            library_type="${1:-}"
        ;;
        --target-platform)
            shift
            target_platform="${1:-}"
        ;;
        --target-arch)
            shift
            target_arch="${1:-}"
        ;;
        --profile)
            shift
            profile="${1:-}"
        ;;
        *)
            echo "Usage: $0 [--debug] [--release] [--simulator] [--target-platform <target platform>] [--target-arch <target arch>] [--library-type <library type>] [--profile <profile>]"
            exit 1
        ;;
    esac
    shift
done

lib_suffix=$(get_lib_suffix_from_library_type $library_type)
mkdir -p $BUILD_DIR

profile_env_name="LIBGODOT_PROFILE_$([ "$debug" -eq 1 ] && echo DEBUG || echo RELEASE)_$(toupper $target_platform)_$(toupper $target_arch)"
if [ ! "$profile" = "" ]
then
    target_build_options="$target_build_options profile=$profile"
elif [ ! -z "${!profile_env_name:-}" ]
then
    target_build_options="$target_build_options profile=${!profile_env_name}"
fi

target_build_options="$target_build_options library_type=$library_type"

if [ "$target_platform" = "ios" ]
then
    if [ $simulator -eq 1 ]
    then
        target_build_options="$target_build_options ios_simulator=true"
    fi
fi

if [ "$target_platform" = "android" ]
then
    target_build_options="$target_build_options angle_libs=$angle_libs swappy=yes"
fi

if [ $debug -eq 0 ]
then
    target_build_options="$target_build_options production=yes debug_symbols=no"
else
    target_build_options="$target_build_options production=no debug_symbols=yes"
fi


target_godot_suffix="$target_platform.$target.$target_arch"
target_godot="$GODOT_DIR/bin/libgodot.$target_godot_suffix.$lib_suffix"

if [ "$target_platform" = "" ]
then
    echo "No target selected."
    exit 0
fi

cd $GODOT_DIR
scons p=$target_platform target=$target arch=$target_arch $target_build_options

if [ "$target_platform" = "android" ]
then
    android_arch="$(godot_to_android_arch $target_arch)"
    android_build_type="release"
    android_target_build_type="release"
    if [ $debug -eq 1 ]
    then
        android_build_type="debug"
        android_target_build_type="debug"
    fi
    if [ "$library_type" = "shared_library" ]
    then
        target_godot="$GODOT_DIR/platform/android/java/lib/libs/$android_build_type/${android_arch}/libgodot_android.so"
    else
        target_godot="$GODOT_DIR/bin/libgodot.$target_godot_suffix.$lib_suffix"
    fi
    mkdir -p $BUILD_DIR/android/$android_target_build_type/${android_arch}
    rm -f $BUILD_DIR/android/$android_target_build_type/${android_arch}/libgodot_android.*
    cp -vf $target_godot $BUILD_DIR/android/$android_target_build_type/${android_arch}/libgodot_android.$lib_suffix
fi
