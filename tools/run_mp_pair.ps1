param([string]$HostScene = "", [string]$ClientScene = "", [int]$SleepSec = 6, [int]$MaxWait = 60)
$ErrorActionPreference = "Continue"
$dir = "D:\codespace\3d-project-cube-lite-zero-assets"
$godot = "D:\portApp\Godot\Godot_v4.7-stable_win64_console.exe"
Remove-Item -LiteralPath "$dir\out_mp_host.txt","$dir\out_mp_client.txt" -ErrorAction SilentlyContinue

$argsList = @()
if ($HostScene -ne "") {
    $hostProc = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",".","res://tools/$HostScene") -RedirectStandardOutput "$dir\out_mp_host.txt" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds $SleepSec
}
if ($ClientScene -ne "") {
    $clientProc = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",".","res://tools/$ClientScene") -RedirectStandardOutput "$dir\out_mp_client.txt" -PassThru -WindowStyle Hidden
}

$deadline = (Get-Date).AddSeconds($MaxWait)
while ((Get-Date) -lt $deadline) {
    $anyAlive = $false
    if ($HostScene -ne "" -and (Get-Process -Id $hostProc.Id -ErrorAction SilentlyContinue)) { $anyAlive = $true }
    if ($ClientScene -ne "" -and (Get-Process -Id $clientProc.Id -ErrorAction SilentlyContinue)) { $anyAlive = $true }
    if (-not $anyAlive) { break }
    Start-Sleep -Seconds 1
}
foreach ($p in @($hostProc, $clientProc)) {
    if ($p -and (Get-Process -Id $p.Id -ErrorAction SilentlyContinue)) { Stop-Process -Id $p.Id -Force }
}
Start-Sleep -Seconds 1
Write-Output "==== HOST ===="
if (Test-Path "$dir\out_mp_host.txt") { Get-Content -LiteralPath "$dir\out_mp_host.txt" -Raw -Encoding UTF8 }
Write-Output "==== CLIENT ===="
if (Test-Path "$dir\out_mp_client.txt") { Get-Content -LiteralPath "$dir\out_mp_client.txt" -Raw -Encoding UTF8 }
