$ErrorActionPreference = "Continue"
$dir = "D:\codespace\3d-project-cube-lite-zero-assets"
$godot = "D:\portApp\Godot\Godot_v4.7-stable_win64_console.exe"
Remove-Item -LiteralPath "$dir\out_mp_block_host.txt","$dir\out_mp_block_client.txt" -ErrorAction SilentlyContinue

$hostProc = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",".","res://tools/test_mp_block_host.tscn") -RedirectStandardOutput "$dir\out_mp_block_host.txt" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 6

$clientProc = Start-Process -FilePath $godot -ArgumentList @("--headless","--path",".","res://tools/test_mp_block_client.tscn") -RedirectStandardOutput "$dir\out_mp_block_client.txt" -PassThru -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
    $h = Get-Process -Id $hostProc.Id -ErrorAction SilentlyContinue
    $c = Get-Process -Id $clientProc.Id -ErrorAction SilentlyContinue
    if (-not $h -and -not $c) { break }
    Start-Sleep -Seconds 1
}

foreach ($proc in @($hostProc, $clientProc)) {
    if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) { Stop-Process -Id $proc.Id -Force }
}
Start-Sleep -Seconds 1

Write-Output "==== HOST ===="
if (Test-Path "$dir\out_mp_block_host.txt") { Get-Content -LiteralPath "$dir\out_mp_block_host.txt" -Raw -Encoding UTF8 }
Write-Output "==== CLIENT ===="
if (Test-Path "$dir\out_mp_block_client.txt") { Get-Content -LiteralPath "$dir\out_mp_block_client.txt" -Raw -Encoding UTF8 }
