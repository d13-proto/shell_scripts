# Sync all .sh files from scripts directory to WSL /etc/profile.d/
$scriptFiles = Get-ChildItem -Path ".\scripts" -Filter "*.sh" -ErrorAction SilentlyContinue

if ($scriptFiles.Count -eq 0) {
    Write-Host "Warning: No .sh files found in ./scripts directory" -ForegroundColor Yellow
    exit 0
}

foreach ($file in $scriptFiles) {
    Write-Host "Copying: $($file.Name) ..." -ForegroundColor Cyan
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -u root -- cp "`$(wslpath $sourcePath)" /etc/profile.d/
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully copied: $($file.Name)" -ForegroundColor Green
    } else {
        Write-Host "Failed to copy: $($file.Name)" -ForegroundColor Red
    }
}

Write-Host "Sync complete!" -ForegroundColor Green
