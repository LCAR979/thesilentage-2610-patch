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
 $currentHash=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower()
 $source=$null
 foreach($candidate in @($dest,(Get-BackupPath $dest),"$dest.zh-original","$dest.backup")) {
  if ((Test-Path -LiteralPath $candidate) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLower() -eq $item.source) {$source=$candidate;break}
 }
 if (!$source) {throw "Unsupported original file: $($item.path). Verify game files in Steam first."}
 $original=[IO.File]::ReadAllBytes($source)
 $inputStream=[IO.File]::OpenRead((Join-Path $PSScriptRoot $item.patch))
 $gzip=[IO.Compression.GZipStream]::new($inputStream,[IO.Compression.CompressionMode]::Decompress)
 $reader=[IO.BinaryReader]::new($gzip)
 $output=[IO.MemoryStream]::new()
 try {
  if ([Text.Encoding]::ASCII.GetString($reader.ReadBytes(5)) -ne 'TSAD1') {throw 'Invalid delta header'}
  while($true) {
   $op=$reader.ReadByte()
   if($op -eq 69) {break}
   if($op -eq 67) {$off=$reader.ReadUInt32();$len=$reader.ReadUInt32();$output.Write($original,$off,$len)}
   elseif($op -eq 82) {$off=$reader.ReadUInt32();$len=$reader.ReadUInt32();if($off+$len -gt $output.Length){throw 'Invalid repeat range'};$buffer=$output.GetBuffer();$output.Write($buffer,$off,$len)}
   elseif($op -eq 73) {$len=$reader.ReadUInt32();$bytes=$reader.ReadBytes($len);if($bytes.Length -ne $len){throw 'Truncated patch'};$output.Write($bytes,0,$len)}
   else {throw 'Invalid delta operation'}
  }
  $result=$output.ToArray()
 } finally {$reader.Dispose();$inputStream.Dispose();$output.Dispose()}
 $sha=[Security.Cryptography.SHA256]::Create()
 try {$hash=([BitConverter]::ToString($sha.ComputeHash($result))).Replace('-','').ToLower()} finally {$sha.Dispose()}
 if ($hash -ne $item.target) {throw "Output validation failed: $($item.path)"}
 $prepared+=@{dest=$dest;source=$source;result=$result;sourceHash=$item.source}
}
# All four inputs and outputs are validated before changing the game.
foreach($item in $prepared) {
 $backup=Get-BackupPath $item.dest
 if (Test-Path -LiteralPath $backup) {
  if ((Get-FileHash -LiteralPath $backup).Hash.ToLower() -ne $item.sourceHash) {throw "Backup conflict: $backup"}
 }
}
foreach($item in $prepared) {
 $backup=Get-BackupPath $item.dest
 if (!(Test-Path -LiteralPath $backup)) {[IO.File]::Copy($item.source,$backup)}
 [IO.File]::WriteAllBytes($item.dest,$item.result)
}
Write-Host 'Installed. Select the China flag for Simplified Chinese; UK flag for English.'

