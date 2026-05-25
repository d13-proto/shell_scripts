<#
.SYNOPSIS
    Switches the primary monitor to 1080p@100% scale, runs a program, then restores the previous configuration.

.DESCRIPTION
    Uses MultiMonitorTool (https://www.nirsoft.net/utils/multi_monitor_tool.html) to:
    - Save current monitor configuration
    - Set primary monitor to 1920x1080 @ 100% scale
    - Launch the specified program and wait for it to exit
    - Restore the original resolution and scale

.EXAMPLE
    .\run-with-1080p.ps1 -ProgramPath "D:\Games\game.exe" -Arguments "-fullscreen" -Delay 5

    .\run-with-1080p.ps1 -ProgramPath notepad.exe -PreCommand "Stop-Process -Name browser -Force" -PostCommand "Start-Process browser"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ProgramPath,

    [string]$Arguments = "",

    [int]$Delay = 3,

    [string]$PreCommand = "",

    [string]$PostCommand = ""
)

$ErrorActionPreference = "Stop"

$resolvedPath = (Get-Command $ProgramPath -ErrorAction SilentlyContinue).Source
if (-not $resolvedPath) {
    Write-Error "Program not found: $ProgramPath"
    exit 1
}
$ProgramPath = $resolvedPath

if (-not (Get-Command "MultiMonitorTool.exe" -ErrorAction SilentlyContinue)) {
    Write-Error "MultiMonitorTool.exe not found"
    exit 1
}

function Invoke-Hook {
    param([string]$Command)
    Write-Host "Running: $Command" -ForegroundColor DarkGray
    $fileName = ($Command -split '\s')[0]
    if ($fileName -match '\.(cmd|bat)$') {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Command" -WindowStyle Hidden
    }
    elseif ($fileName -match '\.ps1$') {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File $Command"
    }
    else {
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -Command $Command"
    }
}

function Invoke-MultiMonitorTool {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Params)
    $commandLine = ($Params | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    Start-Process -FilePath "MultiMonitorTool.exe" -ArgumentList $commandLine -Wait | Out-Null
}

function Wait-ProcessStart {
    param([string]$Name, [int]$Timeout = 30)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.Elapsed.TotalSeconds -lt $Timeout) {
        if (Get-Process -Name $Name -ErrorAction SilentlyContinue) { return $true }
        Start-Sleep 1
    }
    return $false
}

if ($PreCommand) {
    Write-Host "Running pre-command..." -ForegroundColor Yellow
    Invoke-Hook $PreCommand
}

$ConfigFile = Join-Path $env:TEMP "ResolutionSwitch_$PID.cfg"
$CsvFile = Join-Path $env:TEMP "ResolutionSwitch_$PID.csv"

Write-Host "Detecting primary monitor..." -ForegroundColor Cyan
Invoke-MultiMonitorTool /scomma $CsvFile

if (-not (Test-Path $CsvFile)) {
    Write-Error "Failed to export monitor list."
    exit 1
}

$monitors = Import-Csv $CsvFile
Remove-Item -Force $CsvFile -ErrorAction SilentlyContinue

$headers = $monitors[0].PSObject.Properties.Name

$nameColumn = $headers | Where-Object { $_ -eq 'Name' -or $_ -eq 'Monitor Name' } | Select-Object -First 1
$primaryColumn = $headers | Where-Object { $_ -eq 'Primary' } | Select-Object -First 1
$scaleColumn = $headers | Where-Object { $_ -eq 'Current Scale' -or $_ -eq 'Scale' } | Select-Object -First 1

if (-not $nameColumn -or -not $primaryColumn) {
    Write-Error "Could not identify expected columns in CSV. Found: $($headers -join ', ')"
    exit 1
}

$primary = $monitors | Where-Object { $_.$primaryColumn -eq 'Yes' }
if (-not $primary) {
    Write-Error "No primary monitor detected."
    exit 1
}

$primaryName = $primary.$nameColumn
$originalScale = if ($scaleColumn) { [int]($primary.$scaleColumn -replace '%') } else { 0 }

Write-Host "Primary monitor: $primaryName (scale: ${originalScale}%)" -ForegroundColor Cyan

Write-Host "Saving monitor configuration..." -ForegroundColor Cyan
Invoke-MultiMonitorTool /SaveConfig $ConfigFile

if (-not (Test-Path $ConfigFile)) {
    Write-Error "Failed to save monitor configuration."
    exit 1
}

Write-Host "Switching resolution to 1920x1080 @ 100% scale..." -ForegroundColor Yellow
Invoke-MultiMonitorTool /SetMonitors "Name=$primaryName Width=1920 Height=1080"
Invoke-MultiMonitorTool /SetScale $primaryName 100

Write-Host "Waiting ${Delay}s for monitor to settle..." -ForegroundColor Cyan
Start-Sleep -Seconds $Delay

try {
    Write-Host "Launching: $ProgramPath $Arguments" -ForegroundColor Green
    $startParams = @{
        FilePath = $ProgramPath
        PassThru = $true
    }
    if ($Arguments) { $startParams.ArgumentList = $Arguments }
    $process = Start-Process @startParams
    $processName = $process.ProcessName

    Write-Host "Process: $processName ($PID)" -ForegroundColor Green

    $process.WaitForExit()
    Write-Host "Initial process exited (exit code: $($process.ExitCode)), waiting for [$processName] to start..." -ForegroundColor Green

    if (Wait-ProcessStart -Name $processName) {
        Write-Host "[$processName] started, waiting for exit..." -ForegroundColor Green
        Wait-Process -Name $processName -ErrorAction SilentlyContinue
        Write-Host "[$processName] exited." -ForegroundColor Green
    }
    else {
        Write-Host "[$processName] did not start within 30s, continuing..." -ForegroundColor Yellow
    }
}
finally {
    Write-Host "Restoring monitor configuration..." -ForegroundColor Yellow
    Invoke-MultiMonitorTool /LoadConfig $ConfigFile

    if ($scaleColumn -and $originalScale -gt 0) {
        Write-Host "Restoring scale..." -ForegroundColor Yellow
        Invoke-MultiMonitorTool /SetScale $primaryName $originalScale
    }

    Write-Host "Cleaning up temp files..." -ForegroundColor Cyan
    Remove-Item -Force $ConfigFile -ErrorAction SilentlyContinue
}

if ($PostCommand) {
    Write-Host "Running post-command..." -ForegroundColor Yellow
    Invoke-Hook $PostCommand
}
