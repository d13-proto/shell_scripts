# Sync all files from bin directory to WSL /usr/local/bin/
$files = Get-ChildItem -Path ".\bin" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -u root -- cp -v "`$(wslpath $sourcePath)" /usr/local/bin/
    wsl -u root -- chmod -v +x "/usr/local/bin/$($file.Name)"
}

# Sync all .sh files from profile.d directory to WSL /etc/profile.d/
$files = Get-ChildItem -Path ".\profile.d" -Filter "*.sh" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -u root -- cp -v "`$(wslpath $sourcePath)" /etc/profile.d/
}
