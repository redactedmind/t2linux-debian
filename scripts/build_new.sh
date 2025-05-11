#!/bin/env sh

err() {
	printf '%s: E: %s\n' "$SCRIPT_NAME" "$1" >&2
}

errn() {
	printf '%s: E: %s' "$SCRIPT_NAME" "$1" >&2
}

warn() {
	printf '%s: W: %s\n' "$SCRIPT_NAME" "$1" >&2
}

warnn() {
	printf '%s: W: %s' "$SCRIPT_NAME" "$1" >&2
}

die() {
	err "$2"
	exit $1
}

msg() {
	printf '%s: %s\n' "$SCRIPT_NAME" "$1"
}

msgn() {
	printf '%s: %s' "$SCRIPT_NAME" "$1"
}

get_req_cmds() {
	msg 'Finding required software'
	if ! command -v podman > /dev/null && ! command -v docker > /dev/null; then
		die 1 'No containerization platform commands were found: "podman", "docker"'
	fi	
}


SCRIPT_NAME="${0##*/}"
get_req_cmds
podman build 