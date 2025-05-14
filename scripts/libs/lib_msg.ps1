# lib_msg.ps1

function Write-Err {
    param([string]$message)
    [Console]::Error.WriteLine("${SCRIPT_NAME}: E: ${message}")
}

function Write-ErrN {
    param([string]$message)
    [Console]::Error.Write("${SCRIPT_NAME}: E: ${message}")
}

function Write-Warn {
    param([string]$message)
    [Console]::Error.WriteLine("${SCRIPT_NAME}: W: ${message}")
}

function Write-WarnN {
    param([string]$message)
    [Console]::Error.Write("${SCRIPT_NAME}: W: ${message}")
}

function Die {
    param(
        [int]$exitCode,
        [string]$message
    )
    Write-Err $message
    exit $exitCode
}

function Write-Msg {
    param([string]$message)
    Write-Output "${SCRIPT_NAME}: ${message}"
}

function Write-MsgN {
    param([string]$message)
    [Console]::Write("${SCRIPT_NAME}: ${message}")
}