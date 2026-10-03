param([string]$GamePath)
$ErrorActionPreference='Stop'
function Get-BackupPath([string]$Path) {
 $folder=[IO.Path]::GetDirectoryName($Path)
 $stem=[IO.Path]::GetFileNameWithoutExtension($Path)
 $ext=[IO.Path]::GetExtension($Path)
 return Join-Path $folder ($stem+'-backup'+$ext)
}
if (!$GamePath -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'thesilentage_Data'))) {$GamePath=$PSScriptRoot}
if (!$GamePath) {$GamePath=Read-Host 'Enter game folder path (or drag the folder here)'}
$GamePath=$GamePath.Trim('"')
$data=Join-Path $GamePath 'thesilentage_Data'
if (!(Test-Path -LiteralPath $data)) {throw 'Game data folder not found'}
if (Get-Process thesilentage -ErrorAction SilentlyContinue) {throw 'Please close the game first'}
$items=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$prepared=@()
foreach($item in $items) {
 $dest=Join-Path $data $item.path
 $backup=Get-BackupPath $dest
 if (!(Test-Path -LiteralPath $backup)) {throw "Backup missing: $backup"}
 $bytes=[IO.File]::ReadAllBytes($backup)
 $sha=[Security.Cryptography.SHA256]::Create()
 try {$hash=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLower()} finally {$sha.Dispose()}
 if ($hash -ne $item.source) {throw "Backup validation failed: $backup"}
 if (Test-Path -LiteralPath $dest) {
  $current=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower()
  if ($current -ne $item.source -and $current -ne $item.target) {throw "Game file changed by another patch: $dest"}
 }
 $prepared+=@{dest=$dest;bytes=$bytes}
}
# Validate every backup and destination before restoring any file.
foreach($item in $prepared) {[IO.File]::WriteAllBytes($item.dest,$item.bytes)}
Write-Host 'Original game files restored. Backup files have been kept.'
