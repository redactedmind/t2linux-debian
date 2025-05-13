#!/bin/bash

set -euo pipefail

ctr="$(buildah from "$BASE_IMG_NAME:BASE_IMG_TAG")"

# Set noninteractive environment for apt
buildah config --env DEBIAN_FRONTEND=noninteractive "$ctr"

# Install package dependencies
buildah run "$ctr" -- sh -c "apt-get update && \
    apt-get install -y --no-install-recommends \
    lsb-release \
    build-essential \
    fakeroot \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    openssl \
    dkms \
    libudev-dev \
    libpci-dev \
    libiberty-dev \
    autoconf \
    wget \
    xz-utils \
    git \
    libcap-dev \
    bc \
    rsync \
    cpio \
    debhelper \
    kernel-wedge \
    curl \
    gawk \
    dwarves \
    zstd \
    python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*"

# Set working directory
buildah config --workingdir /root/work "$ctr"

# Copy and make build script executable
buildah copy "$ctr" "build_kernel.sh" "/usr/local/bin/"
buildah run "$ctr" -- chmod +x /usr/local/bin/build_kernel.sh

# Configure entrypoint
buildah config --entrypoint '["/usr/local/bin/build_kernel.sh"]' "$ctr"

# Commit the final image
buildah commit "$ctr" "$IMG_NAME:$IMG_TAG"

