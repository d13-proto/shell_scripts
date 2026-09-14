# Sync bin/* to WSL ~/.local/bin/
$files = Get-ChildItem -Path ".\bin" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -- cp -v "`$(wslpath $sourcePath)" ~/.local/bin/
    wsl -- chmod -v +x "~/.local/bin/$($file.Name)"
}

# Sync .bashrc.d/* to WSL ~/.bashrc.d/
$files = Get-ChildItem -Path ".\.bashrc.d" -ErrorAction SilentlyContinue

if ($files) {
    wsl -- mkdir -p ~/.bashrc.d
}

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -- cp -v "`$(wslpath $sourcePath)" ~/.bashrc.d/
}
