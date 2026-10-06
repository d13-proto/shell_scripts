# 同步 PowerShellModules/* 到 PowerShell 模块目录（自动加载，无需 profile 代码）
$docs = [Environment]::GetFolderPath('MyDocuments')
if (-not $docs) { $docs = "$env:USERPROFILE\Documents" }

$modulePaths = @(Join-Path $docs 'WindowsPowerShell\Modules')   # Windows PowerShell 5.1
if (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") {
    $modulePaths += Join-Path $docs 'PowerShell\Modules'        # PowerShell 7
}

foreach ($modulePath in $modulePaths) {
    if (-not (Test-Path $modulePath)) {
        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    }
    Get-ChildItem -Path "$PSScriptRoot\PowerShellModules" -Directory | ForEach-Object {
        try {
            Copy-Item -Path $_.FullName -Destination $modulePath -Recurse -Force -ErrorAction Stop
            Write-Host "已同步模块: $($_.Name) -> $modulePath"
        }
        catch {
            Write-Warning "同步模块 $($_.Name) 失败: $_"
        }
    }
}

# 同时同步 Linux/WSL 侧（WSL 通过 /mnt/c 直接读仓库；wslpath 负责转换路径）
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $wslRepo = (wsl -- wslpath "'$PSScriptRoot'").Trim()
    if ($wslRepo) {
        wsl -- bash "$wslRepo/sync_linux.sh"
        if ($LASTEXITCODE -ne 0) { Write-Warning "WSL 同步失败 (退出码 $LASTEXITCODE)" }
    }
    else {
        Write-Warning "wslpath 无法转换路径: $PSScriptRoot"
    }
}
