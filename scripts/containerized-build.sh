#!/bin/sh

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in *:file:*) return 0 ;; esac
    else # Add additional POSIX-compatible shell names here, if needed.
        case ${0##*/} in dash | -dash | bash | -bash | ksh | -ksh | sh | -sh) return 0 ;; esac
    fi
    return 1 # NOT sourced
}
if is_sourced; then
    printf 'E: This script isn'\''t meant to be sourced, consider executing it\n' >&2
    return 1
fi

set -eu

# shellcheck disable=SC2034
SCRIPT_NAME="${0##*/}"
SCRIPTS_DIR="${0%/*}"
LIBS_DIR="$SCRIPTS_DIR/libs"
ROOT_DIR="$SCRIPTS_DIR/.."
CTR_OUT_DIR="$ROOT_DIR/build/ctr"

# shellcheck disable=SC1091
. "$LIBS_DIR/lib_msg.sh"

check_req_cmds() {
    msg 'Finding required software'
    if command -v podman >/dev/null; then
        ctr_cmd="podman"
    elif command -v docker >/dev/null; then
        ctr_cmd="docker"
    else
        die 1 'No containerization platform commands were found: "podman", "docker"'
    fi
}
check_req_cmds

run_containerized_build() {
    msg 'Building build ctr'
    mkdir -p "$CTR_OUT_DIR"
    "$ctr_cmd" pull docker://quay.io/buildah/stable:latest
    "$ctr_cmd" run \
        --rm \
        --tty \
        --replace \
        --name=t2linux-debian_buildah \
        --env-file="$ROOT_DIR/.env" \
        --net=host \
        --security-opt label=disable \
        --security-opt seccomp=unconfined \
        --device /dev/fuse:rw \
        -v "$CTR_OUT_DIR":/var/lib/containers:Z \
        -v "$SCRIPTS_DIR":/mnt:Z \
        stable \
        /bin/bash /mnt/buildah-build.bash
}
run_containerized_build
