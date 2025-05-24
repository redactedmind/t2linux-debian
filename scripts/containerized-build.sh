#!/bin/sh

is_sourced() {
    if [ -n "$ZSH_VERSION" ]; then
        case $ZSH_EVAL_CONTEXT in *:file:*) return 0 ;; esac
    else # Add additional POSIX-compatible shell names here, if needed.
        case ${0##*/} in dash | -dash | bash | -bash | ksh | -ksh | sh | -sh) return 0 ;; esac
    fi
    return 1
}
# Abort sourced script executions to prevent $0 being messed up, and let it always be the path to current script
if is_sourced; then
    echo "E: This script isn't meant to be sourced, consider executing it" >&2
    return 1 # Use return instead of exit to prevent exiting from the process that sourced the script 
fi

set -eu

# Used by lib_msg.sh for context in messages # shellcheck disable=SC2034
# shellcheck disable=SC2034
SCRIPT_NAME="${0##*/}" 
SCRIPTS_DIR="${0%/*}"
LIBS_DIR="$SCRIPTS_DIR/libs"
ROOT_DIR="$SCRIPTS_DIR/.." # Root repo directory
CTR_OUT_DIR="$ROOT_DIR/build/ctr"


. "$ROOT_DIR/.env"
. "$LIBS_DIR/lib_msg.sh"


chk_env_vars() {
    # Default to empty string if unset for the conditions.
    if [ "${NO_BUILDAH_CTR:-}" = "true" ]; then
        # Discourage BUILDAH_CTR_TAG to be set with NO_BUILDAH_CTR
        if [ -n "${BUILDAH_CTR_TAG:-}" ]; then
            warn "NO_BUILDAH_CTR=\"$NO_BUILDAH_CTR\" and BUILDAH_CTR_TAG=\"$BUILDAH_CTR_TAG\" were both set. These are mutually exclusive. BUILDAH_CTR_TAG will be ignored."
        fi
        BUILDAH_CTR_TAG=""
    elif [ "${NO_BUILDAH_CTR:-}" = "false" ] || [ -z "${NO_BUILDAH_CTR:-}" ]; then
        NO_BUILDAH_CTR="false"
        # Set BUILDAH_CTR_TAG to its environment value, or the default if it was unset/empty.
        BUILDAH_CTR_TAG="${BUILDAH_CTR_TAG:-v1.39.3}"
    else
        die 1 "Invalid value for NO_BUILDAH_CTR: \"${NO_BUILDAH_CTR}\". Must be 'true', 'false', or unset ()."
    fi
}
chk_env_vars

# Check if TGT_CTR_IMG_NAME is unset or empty
if [ -z "${TGT_CTR_IMG_NAME:-}" ]; then
    die 1 "TGT_CTR_IMG_NAME environment variable is not set or empty. Please set it before running."
fi


get_ctr_engine() {
    msg 'Detecting container engine'
    if command -v podman >/dev/null; then
        CTR_ENGINE="podman"
    elif command -v docker >/dev/null; then
        CTR_ENGINE="docker"
    else
        die 1 'No containerization platform commands were found: "podman", "docker"'
    fi
}
get_ctr_engine

# if NO_BUILDAH_CTR is true, we are on host and we need to check dependencies
chk_ctr_build_cmds() {
    msg 'Detecting container build software' # All the software required for buildah-build.bash 
    for _cmd in buildah awk; do
        if ! command -v $_cmd >/dev/null; then
            err "$_cmd was not found"
            _cmd_not_found='true'
        fi
    done
    if [ -z "${_cmd_not_found:-}" ]; then
        die 1 "Some of container build software was not found"
    fi
}
if [ "${NO_BUILDAH_CTR}" = 'true' ]; then
    chk_ctr_build_cmds
fi

run_containerized_build() {
    msg 'Building buildah container'
    mkdir -p "$CTR_OUT_DIR"

    _build_container_name="${TGT_CTR_IMG_NAME}_buildah"
    _found_name=$("$CTR_ENGINE" ps -a --filter "name=^${_build_container_name}$" --format '{{.Names}}' 2>/dev/null)

    if [ "$_found_name" = "$_build_container_name" ]; then
        _user_wants_to_replace=false
        _prompt_text="Container '${_build_container_name}' already exists. Do you want to replace it? [y/N]: "
        _tries=0
        while [ "$_tries" -lt 3 ]; do
            warn -n "${_prompt_text}"
            read -r _ans < /dev/tty
            case "$_ans" in
                [Yy] | [Yy][Ee][Ss])
                    _user_wants_to_replace=true
                    break # Valid input, exit loop
                    ;;
                [Nn] | [Nn][Oo] | "" | " ")
                    _user_wants_to_replace=false
                    break # Valid input, exit loop
                    ;;
                *)
                    _tries=$((_tries + 1))
                    if [ "$_tries" -ge 3 ]; then
                        die 1 "Too many invalid attempts. Aborting."
                    fi
                    warn "Invalid input. Please enter 'y', 'n', space, or press Enter. ($_tries/3 attempts)"
                    ;;
            esac
        done

        if $_user_wants_to_replace; then
            # warn "" # Add additional foolproof? (replacing existing container would delete the former one)
            msg "Removing existing container '${_build_container_name}'..."
            if ! "$CTR_ENGINE" rm "${_build_container_name}"; then
                die 1 "Failed to remove existing container '${_build_container_name}'. Aborting."
            fi
            msg "Container '${_build_container_name}' removed successfully."
        else
            die 0 "Build aborted by user. Container '${_build_container_name}' was not replaced."
        fi
    fi

    _buildah_img_tag="docker://quay.io/buildah/stable:$BUILDAH_CTR_TAG"

    "$CTR_ENGINE" pull "$_buildah_img_tag"
    
    # --- Execute Build Script in Container ---

    msg "Running containerized build with $CTR_ENGINE (image $_buildah_img_tag)..."
    "$CTR_ENGINE" run \
        --rm \
        --tty \
        --name="$_build_container_name" \
        --net=host \
        --security-opt label=disable \
        --security-opt seccomp=unconfined \
        --device /dev/fuse:rw \
        -v "${CTR_OUT_DIR}:/var/lib/containers:Z" \
        -v "${ROOT_DIR}:/mnt:Z" \
        "$_buildah_img_tag" \
        /bin/bash /mnt/scripts/buildah-build.bash

    ## The following options are used for the container run:
    #   --rm: Remove the container automatically when it exits.
    #   --tty: Allocate a pseudo-TTY.
    #   --name="${_build_container_name}": Assign a name to the container.
    #   --net=host: Use the host's network stack (less isolation, but often needed for builds).
    #   --security-opt label=disable: Disable SELinux separation (reduces security, may be needed for Buildah).
    #   --security-opt seccomp=unconfined: Disable seccomp filtering (reduces security, grants more syscalls).
    #   --device /dev/fuse:rw: Grant read-write access to /dev/fuse (for FUSE filesystems used by Buildah).
    #   -v "${CTR_OUT_DIR}:/var/lib/containers:Z": Mount the build output directory into the container.
    #     ':Z' manages SELinux labels for shared volumes.
    #   -v "${ROOT_DIR}:/mnt:Z": Mount the project root directory into the container.
    #     ':Z' manages SELinux labels for shared volumes.
    #   stable: The image name (referring to quay.io/buildah/stable).
    #   /bin/bash /mnt/scripts/buildah-build.bash: The command to run inside the container.
    #
    ## Note on --env-file
    # The usual `docker run` workflow isn't used here, the --env-file option doesn't strip double quotes ("") and other similar shell syntax. 
    # The .env file is sourced inside the target script (started by `docker run`).
}

if [ "$NO_BUILDAH_CTR" = 'true' ]; then
    die 0 "Target container builds on host are not yet implemented" # TODO implement this
else
    run_containerized_build
fi
