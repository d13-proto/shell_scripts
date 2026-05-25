# Sync bin/* to ~/.local/bin/ on Windows
$dest = "$env:USERPROFILE\.local\bin"

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force
}

Get-ChildItem -Path ".\bin" | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "$dest\" -Recurse -Force
    Write-Host "Copied: $($_.Name)"
}
