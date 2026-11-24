[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Set-RoxyLoudness {
    param([string]$FFmpeg, [string]$Source, [string]$Target)

    $report = & $FFmpeg -hide_banner -nostdin -nostats -i $Source -af 'loudnorm=I=-18:TP=-1.5:LRA=11:print_format=json' -f null - 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $report -notmatch '(?s)\{\s*"input_i".*?\}') {
        throw 'FFmpeg could not measure the generated audio.'
    }
    $levels = $Matches[0] | ConvertFrom-Json
    if ($levels.input_i -eq '-inf' -or $levels.input_tp -eq '-inf') {
        return $Source
    }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $loudness = [double]::Parse($levels.input_i, $culture)
    $peak = [double]::Parse($levels.input_tp, $culture)
    # A constant gain preserves the dynamics while leaving true-peak headroom.
    $gainDb = [Math]::Min(-18.0 - $loudness, -1.5 - $peak)
    $gainFilter = 'volume=' + $gainDb.ToString('F2', $culture) + 'dB'
    & $FFmpeg -hide_banner -nostdin -v error -i $Source -af $gainFilter -c:a pcm_s16le $Target
    if ($LASTEXITCODE -ne 0) { throw 'FFmpeg could not adjust the generated audio.' }
    return $Target
}

[Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
$text = if ($InputPath) { [IO.File]::ReadAllText($InputPath).Trim() } else { [Console]::In.ReadToEnd().Trim() }
if (-not $text) { throw 'No text was selected.' }
$configPath = Join-Path $PSScriptRoot 'settings.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ($localAppData) { $configPath = Join-Path $localAppData 'RoxyReader/settings.json' }
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw 'Local Roxy voice is not configured. See the README for settings.json setup.'
}
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$configDirectory = Split-Path -Parent $configPath
if (-not $config.referenceAudio -or -not $config.referenceText) {
    throw 'A reference WAV and its Japanese transcript are required.'
}
$reference = [IO.Path]::GetFullPath($config.referenceAudio, $configDirectory)
if (-not (Test-Path -LiteralPath $reference -PathType Leaf)) {
    throw 'The configured reference audio file does not exist.'
}
$ffmpeg = if ($config.ffmpegPath) {
    [IO.Path]::GetFullPath($config.ffmpegPath, $configDirectory)
}
if ($ffmpeg -and -not (Test-Path -LiteralPath $ffmpeg -PathType Leaf)) {
    throw 'The configured FFmpeg path does not exist.'
}
if ($config.launcherPath) {
    $launcher = [IO.Path]::GetFullPath($config.launcherPath, $configDirectory)
    & $launcher -ServiceOnly
}

$splitMethod = if ($config.textSplitMethod) { $config.textSplitMethod } else { 'cut5' }
$request = @{
    text = $text
    text_lang = $config.textLanguage
    ref_audio_path = $reference
    prompt_lang = 'ja'
    prompt_text = $config.referenceText
    media_type = 'wav'
    text_split_method = $splitMethod
    streaming_mode = $false
} | ConvertTo-Json -Compress
$destination = if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) }
$directory = [IO.Path]::GetTempPath()
if ($destination) {
    $directory = [IO.Path]::GetDirectoryName($destination)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}
$wav = Join-Path $directory ("roxy-" + [guid]::NewGuid() + ".wav")
$normalized = [IO.Path]::ChangeExtension($wav, '.normalized.wav')
try {
    Invoke-WebRequest -Uri 'http://127.0.0.1:9880/tts' -Method Post -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($request)) -OutFile $wav -TimeoutSec 180
    $audio = if ($ffmpeg) { Set-RoxyLoudness -FFmpeg $ffmpeg -Source $wav -Target $normalized } else { $wav }
    if ($destination) {
        $stream = [IO.File]::OpenRead($audio)
        try {
            $header = [byte[]]::new(12)
            if ($stream.Length -le 44 -or $stream.Read($header, 0, $header.Length) -ne $header.Length -or
                [Text.Encoding]::ASCII.GetString($header, 0, 4) -ne 'RIFF' -or
                [Text.Encoding]::ASCII.GetString($header, 8, 4) -ne 'WAVE') {
                throw 'Roxy Reader did not receive a valid WAV file.'
            }
        } finally {
            $stream.Dispose()
        }
        [IO.File]::Move($audio, $destination)
        Write-Output $destination
        return
    }
    $player = [System.Media.SoundPlayer]::new($audio)
    try { $player.PlaySync() } finally { $player.Dispose() }
} finally {
    foreach ($temporary in $wav, $normalized) {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
    }
}

