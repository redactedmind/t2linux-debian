function Is-Sourced {
    # Check if the script is being dot-sourced
    $invocation = (Get-Variable MyInvocation -Scope 1).Value
    if ($invocation.Line -match '^\.\s+') {
        return $true
    }
    return $false
}

if (Is-Sourced) {
    Write-Error "E: This script isn't meant to be sourced, consider executing it" -ErrorAction Stop
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Set script paths
$SCRIPT_NAME = Split-Path -Leaf $MyInvocation.MyCommand.Path
$SCRIPTS_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LIBS_DIR = Join-Path $SCRIPTS_DIR "libs"
$ROOT_DIR = (Get-Item (Join-Path $SCRIPTS_DIR "..")).FullName
$CTR_OUT_DIR = Join-Path $ROOT_DIR "build/ctr"

$BUILDAH_TAG = 'v1.39.3'

# Import libraries
. (Join-Path $LIBS_DIR "lib_msg.ps1")

function Get-CtrEngine {
    Write-Msg 'Finding required software'
    if (Get-Command podman -ErrorAction SilentlyContinue) {
        $script:CTR_ENGINE = "podman"
    }
    elseif (Get-Command docker -ErrorAction SilentlyContinue) {
        $script:CTR_ENGINE = "docker"
    }
    else {
        Die 1 'No containerization platform commands were found: "podman", "docker"'
    }
}

Get-CtrEngine

function Run-ContainerizedBuild {
    param(
        [string]$IMG_NAME
    )

    Write-Msg 'Building build ctr'
    New-Item -Path $CTR_OUT_DIR -ItemType Directory -Force | Out-Null
    
    & $CTR_ENGINE pull "docker://quay.io/buildah/stable:$BUILDAH_TAG"
    
    $envArgs = @(
        "--rm",
        "--tty",
        "--replace",
        "--name=${IMG_NAME}_buildah",
        "--env-file=$(Join-Path $ROOT_DIR '.env')",
        "--net=host",
        "--security-opt", "label=disable",
        "--security-opt", "seccomp=unconfined",
        "--device", "/dev/fuse:rw",
        "-v", "$($CTR_OUT_DIR):/var/lib/containers:Z",
        "-v", "$($ROOT_DIR):/mnt:Z",
        "quay.io/buildah/stable:$BUILDAH_TAG",
        "/bin/bash", "/mnt/scripts/buildah-build.bash"
    )

    & $CTR_ENGINE run $envArgs
}