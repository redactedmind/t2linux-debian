#!/bin/bash

# echo "hello world"
# exit

set -euo pipefail

# shellcheck disable=SC2034
SCRIPT_NAME="${BASH_SOURCE##*/}"
SCRIPTS_DIR="${BASH_SOURCE%/*}"
LIBS_DIR="$SCRIPTS_DIR/libs"
ROOT_DIR="$SCRIPTS_DIR/.." # Root repo directory

source "$LIBS_DIR/lib_msg.sh"

case "$TGT_DISTRO" in
    debian)
        case "$TGT_RELEASE" in
            bookworm | trixie | bullseye)
                [[ -v BASE_IMG_NAME ]] || BASE_IMG_NAME="$TGT_DISTRO"
                [[ -v BASE_IMG_TAG ]] || BASE_IMG_TAG="$TGT_RELEASE"
                
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
ctr="$(buildah from "$BASE_IMG_NAME:$BASE_IMG_TAG")"
if $?; then
    die 1 "Could not find base image with name BASE_IMG_NAME=\"$BASE_IMG_NAME\" and tag BASE_IMG_TAG=\"$BASE_IMG_TAG\""
fi
# # Set noninteractive environment for apt
# buildah config --env DEBIAN_FRONTEND=noninteractive "$ctr"

# # Install package dependencies
# buildah run "$ctr" bash ./"$SCRIPTS_DIR"/

# # Set working directory
# buildah config --workingdir /root/work "$ctr"

# # Copy and make build script executable
# buildah copy "$ctr" "build_kernel.sh" "/usr/local/bin/"
# buildah run "$ctr" -- chmod +x /usr/local/bin/build_kernel.sh

# # Configure entrypoint
# buildah config --entrypoint '["/usr/local/bin/build_kernel.sh"]' "$ctr"

# # Commit the final image
# buildah commit "$ctr" "$IMG_NAME:$IMG_TAG"

