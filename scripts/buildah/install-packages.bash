#!/bin/bash
set -euo pipefail

rm -f /etc/apt/apt.conf.d/docker-clean
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
apt-get -qq update
apt-get -qq --no-install-recommends upgrade
apt-get -qq --no-install-recommends install $CONT_BASE_PKGS $CONT_PKGS
apt-get -qq --no-install-recommends clean
rm -fr /var/lib/apt/lists/*