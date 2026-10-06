# 把视频压到指定大小上限内：AV1 + Opus/WebM，两遍编码，可选高质量降采样。
# 用法:
#   Compress-ToSize -InputFile "xxx.mp4" -MaxSizeMB 30 -Height 540
function Compress-ToSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$InputFile,
        [Parameter(Mandatory, Position = 1)][double]$MaxSizeMB,
        [int]$AudioKbps = 96,                    # Opus 目标码率（语音 64-96 足够）
        [ValidateRange(0, 13)][int]$Preset = 4,  # SVT-AV1 预设，越大越快、同码率质量越低
        [ValidateSet('libplacebo', 'zscale', 'swscale', 'none')][string]$Scaler = 'libplacebo',
        [int]$Height,                            # 目标高度；省略则保持原始分辨率
        [double]$OverheadPercent = 2,            # 封装与安全余量
        [string]$SvtAv1Params = 'tune=0',        # SVT-AV1 附加参数；tune=0 偏向主观画质而非 PSNR
        [string]$OutputFile
    )

    # --- 基础检查 ---
    if (-not (Test-Path $InputFile)) { throw "找不到输入文件: $InputFile" }
    foreach ($tool in 'ffmpeg', 'ffprobe') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "缺少 $tool，请先安装并加入 PATH" }
    }
    $InputFile = (Resolve-Path $InputFile).Path

    # --- 读取时长与分辨率 ---
    $durationText = ffprobe -v error -show_entries format=duration -of csv=p=0 $InputFile
    if ($LASTEXITCODE -ne 0) { throw "ffprobe 无法读取文件（可能已损坏或不是视频）: $InputFile" }
    $durationSeconds = [double]::Parse($durationText, [Globalization.CultureInfo]::InvariantCulture)
    if ($durationSeconds -le 0) { throw "无法读取视频时长" }

    $dimensionText = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $InputFile
    if ($LASTEXITCODE -ne 0) { throw "ffprobe 无法读取视频分辨率: $InputFile" }
    $dimensionParts = $dimensionText -split ','
    [int]$sourceWidth, [int]$sourceHeight = $dimensionParts[0], $dimensionParts[1]

    # --- 目标尺寸（保持比例，宽高取偶，yuv420p 要求宽高均为偶数） ---
    if (-not $Height) { $Height = $sourceHeight }
    if ($Height -gt $sourceHeight) { $Height = $sourceHeight }
    $Height = 2 * [math]::Floor($Height / 2)
    $targetWidth = 2 * [math]::Round($Height * $sourceWidth / $sourceHeight / 2)

    # --- 计算目标视频码率 ---
    $totalKbps = $MaxSizeMB * 8.389 * 1000 / $durationSeconds    # 大小上限换算成平均总码率
    $videoBitrateKbps = [int]($totalKbps * (1 - $OverheadPercent / 100) - $AudioKbps)
    if ($videoBitrateKbps -lt 50) {
        throw "码率预算只剩 ${videoBitrateKbps}kbps，压不出可用画质。请调大 -MaxSizeMB 或用 -Height 降分辨率。"
    }
    if ($videoBitrateKbps -lt 150) {
        Write-Warning "视频码率仅 ${videoBitrateKbps}kbps，建议加 -Height 降分辨率换取清晰度（低码率下干净的小图 > 模糊的大图）"
    }

    # --- 输出路径 ---
    if (-not $OutputFile) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($InputFile)
        $OutputFile = [IO.Path]::Combine((Split-Path $InputFile), "${baseName}_${MaxSizeMB}MB.webm")
    }

    # --- 缩放滤镜 ---
    $scaleFilter = $null
    if ($Scaler -ne 'none' -and ($targetWidth -ne $sourceWidth -or $Height -ne $sourceHeight)) {
        $scaleFilter = switch ($Scaler) {
            'libplacebo' { "libplacebo=w=${targetWidth}:h=${Height}:downscaler=ewa_lanczos" }
            'zscale'     { "zscale=w=${targetWidth}:h=${Height}:filter=spline36" }
            'swscale'    { "scale=w=${targetWidth}:h=${Height}:flags=lanczos+accurate_rnd+full_chroma_int" }
        }
    }

    $videoArgs = @('-c:v', 'libsvtav1', '-b:v', "${videoBitrateKbps}k", '-preset', "$Preset")
    if ($SvtAv1Params) { $videoArgs += @('-svtav1-params', $SvtAv1Params) }
    if ($scaleFilter) { $videoArgs = @('-vf', $scaleFilter) + $videoArgs }

    Write-Host "时长 $($durationSeconds.ToString('0.0'))s | 尺寸 ${sourceWidth}x${sourceHeight} -> ${targetWidth}x${Height} | 视频 ${videoBitrateKbps}kbps + 音频 ${AudioKbps}kbps"

    # --- 两遍编码（统计文件放临时目录，避免污染工作目录与并行任务互相覆盖） ---
    $passLogPrefix = Join-Path $env:TEMP "compress_tosize_$([guid]::NewGuid().ToString('N'))"
    try {
        ffmpeg -y -hide_banner -stats -loglevel warning -i $InputFile @videoArgs -pass 1 -passlogfile $passLogPrefix -an -f null NUL
        if ($LASTEXITCODE -ne 0) { throw "第一遍编码失败" }
        ffmpeg -y -hide_banner -stats -loglevel warning -i $InputFile @videoArgs -pass 2 -passlogfile $passLogPrefix -c:a libopus -b:a "${AudioKbps}k" -ac 2 $OutputFile
        if ($LASTEXITCODE -ne 0) { throw "第二遍编码失败" }
    }
    finally {
        Remove-Item "${passLogPrefix}*" -ErrorAction SilentlyContinue
    }

    $outputSizeMB = [math]::Round((Get-Item $OutputFile).Length / 1MB, 1)
    if ($outputSizeMB -gt $MaxSizeMB) {
        Write-Warning "输出 ${outputSizeMB}MB 超出上限 ${MaxSizeMB}MB，可调大 -OverheadPercent 或减小 -AudioKbps 后重试"
    }
    else {
        Write-Host "完成: $OutputFile ($outputSizeMB MB)" -ForegroundColor Green
    }
}
