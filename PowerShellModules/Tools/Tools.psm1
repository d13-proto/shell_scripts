# 加载 Public/ 下所有函数；约定：文件名 = 函数名，导出清单见 Tools.psd1
Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}
