# Sync bin/* to WSL ~/.local/bin/
$files = Get-ChildItem -Path ".\bin" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -- cp -v "`$(wslpath $sourcePath)" ~/.local/bin/
    wsl -- chmod -v +x "~/.local/bin/$($file.Name)"
}

# Sync .bash_aliases to WSL ~/.bash_aliases
$sourcePath = (Resolve-Path .bash_aliases).Path -replace '\\', '/'
wsl -- cp -v "`$(wslpath $sourcePath)" ~/.bash_aliases

# Sync profile.d/*.sh to WSL /etc/profile.d/
$files = Get-ChildItem -Path ".\profile.d" -Filter "*.sh" -ErrorAction SilentlyContinue

foreach ($file in $files) {
    $sourcePath = $file.FullName -replace '\\', '/'
    wsl -u root -- cp -v "`$(wslpath $sourcePath)" /etc/profile.d/
}
