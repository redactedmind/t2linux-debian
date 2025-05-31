#!/bin/bash

set -euo pipefail

# shellcheck disable=SC2034
SCRIPT_NAME="${BASH_SOURCE##*/}"
SCRIPTS_DIR="${BASH_SOURCE%/*}"
LIBS_DIR="$SCRIPTS_DIR/libs"
# TODO check if readlink fails
ROOT_DIR="$(readlink -f "$SCRIPTS_DIR/..")" # Root repo directory

IN_CTR_ROOT_DIR="/mnt"
IN_CTR_SCRIPTS_DIR="$IN_CTR_ROOT_DIR/scripts"
IN_CTR_BUILDAH_SCRIPTS_DIR="$IN_CTR_SCRIPTS_DIR/buildah"

source "$ROOT_DIR/.env"
source "$LIBS_DIR/lib_msg.sh"

case "$TGT_DISTRO" in
    debian)
        case "$TGT_RELEASE" in
            bookworm | trixie | bullseye)
                [[ -v TGT_CTR_BASE_IMG_NAME ]] || TGT_CTR_BASE_IMG_NAME="$TGT_DISTRO"
                [[ -v TGT_CTR_BASE_IMG_TAG ]] || TGT_CTR_BASE_IMG_TAG="$TGT_RELEASE"
                
                ;;
            *)
                die 1 "Build for \"$TGT_DISTRO\" distribution of \"$TGT_RELEASE\" release isn't supported"
                ;;
        esac
    ;;
    *)
        die 1 "Build for \"$TGT_DISTRO\" distribution isn't supported"
        ;;
esac

msg "Starting to build target (builder) container"
msg "Trying to peform FROM"
CTR_NAME="$(buildah from "$TGT_CTR_BASE_IMG_NAME:$TGT_CTR_BASE_IMG_TAG")" || \
    die 1 "Could not find base image with name TGT_CTR_BASE_IMG_NAME=\"$TGT_CTR_BASE_IMG_NAME\" and tag TGT_CTR_BASE_IMG_TAG=\"$TGT_CTR_BASE_IMG_TAG\""

msg "Installing packages"
buildah run \
    --mount "type=bind,source=$ROOT_DIR,destination=$IN_CTR_ROOT_DIR" \
    --env CTR_PKGS="$CTR_PKGS" \
    "$CTR_NAME" \
    bash "$IN_CTR_BUILDAH_SCRIPTS_DIR/install-packages.bash"

msg "Creating and setting workdir"
buildah run "$CTR_NAME" mkdir -p "$TGT_CTR_WORK_DIR" # TODO check if -p is necessary
buildah config --workingdir "$TGT_CTR_WORK_DIR" "$CTR_NAME"

msg "Configuring entrypoint"
buildah config --entrypoint '["/bin/bash"]' "$CTR_NAME"

msg "Committing the final image"
# Debug information
# msg "DEBUG: TGT_CTR_BASE_IMG_NAME=$TGT_CTR_BASE_IMG_NAME"
# msg "DEBUG: TGT_CTR_BASE_IMG_TAG=$TGT_CTR_BASE_IMG_TAG"
# msg "DEBUG: TGT_CTR_IMG_NAME=$TGT_CTR_IMG_NAME"
# msg "DEBUG: TGT_CTR_IMG_TAG=$TGT_CTR_IMG_TAG"
# msg "DEBUG: Full image name:tag would be: $TGT_CTR_IMG_NAME:$TGT_CTR_IMG_TAG"
buildah commit "$CTR_NAME" "$TGT_CTR_BASE_IMG_NAME:$TGT_CTR_BASE_IMG_TAG"

