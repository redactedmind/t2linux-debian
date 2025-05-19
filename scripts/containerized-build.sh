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
        die 1 "Invalid value for NO_BUILDAH_CTR: '${NO_BUILDAH_CTR}'. Must be 'true', 'false', '1', '0', or unset."
    fi
}
chk_env_vars

# Check if IMG_NAME is unset or empty
if [ -z "${IMG_NAME:-}" ]; then
    die 1 "IMG_NAME environment variable is not set or empty. Please set it before running."
fi


get_ctr_engine() {
    msg 'Finding required software'
    if command -v podman >/dev/null; then
        CTR_ENGINE="podman"
    elif command -v docker >/dev/null; then
        CTR_ENGINE="docker"
    else
        die 1 'No containerization platform commands were found: "podman", "docker"'
    fi
}
get_ctr_engine

get_buildah() {
    true # Placeholder for future buildah logic if not using pre-built container
}

run_containerized_build() {
    msg 'Building builah container'
    mkdir -p "$CTR_OUT_DIR"

    _build_container_name="${IMG_NAME}_buildah"
    _found_name=$("$CTR_ENGINE" ps -a --filter "name=^${_build_container_name}$" --format '{{.Names}}' 2>/dev/null)

    if [ "$_found_name" = "$_build_container_name" ]; then
        _user_wants_to_replace=false
        _prompt_text="Container '${_build_container_name}' already exists. Replace it? [y/N]: "
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
            msg "Removing existing container '${_build_container_name}'..."
            if ! "$CTR_ENGINE" rm "${_build_container_name}"; then
                die 1 "Failed to remove existing container '${_build_container_name}'. Aborting."
            fi
            msg "Container '${_build_container_name}' removed successfully."
        else
            die 0 "Build aborted by user. Container '${_build_container_name}' was not replaced."
        fi
    fi

    "$CTR_ENGINE" pull "docker://quay.io/buildah/stable:$BUILDAH_CTR_TAG"

    # --- Execute Build Script in Container ---
    # The following options are used for the container run:
    #   --rm: Remove the container automatically when it exits.
    #   --tty: Allocate a pseudo-TTY.
    #   --name="${_build_container_name}": Assign a name to the container.
    #   --env-file="${ROOT_DIR}/.env": Load environment variables from the .env file.
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

    msg "Running containerized build with $CTR_ENGINE (image: quay.io/buildah/stable:$BUILDAH_CTR_TAG)..."
    "$CTR_ENGINE" run \
        --rm \
        --tty \
        --name="${_build_container_name}" \
        --env-file="${ROOT_DIR}/.env" \
        --net=host \
        --security-opt label=disable \
        --security-opt seccomp=unconfined \
        --device /dev/fuse:rw \
        -v "${CTR_OUT_DIR}:/var/lib/containers:Z" \
        -v "${ROOT_DIR}:/mnt:Z" \
        stable \
        /bin/bash /mnt/scripts/buildah-build.bash
}
run_containerized_build
