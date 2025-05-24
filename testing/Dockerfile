## T2 Linux Builder Dockerfile

# Base Image
ARG BASE_IMG_NAME
ARG BASE_IMG_TAG
FROM ${BASE_IMG_NAME}:${BASE_IMG_TAG}

ARG CONT_PKGS
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -euo pipefail &&\
    rm -f /etc/apt/apt.conf.d/docker-clean &&\
    echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache &&\
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections &&\
    apt-get -qq update &&\
    apt-get -qq --no-install-recommends upgrade &&\
    apt-get -qq --no-install-recommends install $CONT_PKGS &&\
    apt-get -qq --no-install-recommends clean &&\
    rm -fr /var/lib/apt/lists/*
