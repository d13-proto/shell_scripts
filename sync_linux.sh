#!/usr/bin/env bash
# 将 bin/* 同步到 ~/.local/bin/，将 .bashrc.d/* 同步到 ~/.bashrc.d/
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 将 bin/* 同步到 ~/.local/bin/
if [ -d "$repo_dir/bin" ]; then
    mkdir -p ~/.local/bin
    for file in "$repo_dir"/bin/*; do
        [ -f "$file" ] || continue
        cp -v "$file" ~/.local/bin/
        chmod -v +x ~/.local/bin/"$(basename "$file")"
    done
fi

# 将 .bashrc.d/* 同步到 ~/.bashrc.d/
if [ -d "$repo_dir/.bashrc.d" ]; then
    mkdir -p ~/.bashrc.d
    for file in "$repo_dir"/.bashrc.d/*; do
        [ -f "$file" ] || continue
        ln -sfnv "$file" ~/.bashrc.d/"$(basename "$file")"
    done
fi
