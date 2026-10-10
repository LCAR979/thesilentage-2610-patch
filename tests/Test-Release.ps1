param([Parameter(Mandatory=$true)][string]$GamePath)
$fixtureSource=$GamePath
$repo=Split-Path $PSScriptRoot -Parent
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('tsa2610-release-test-'+[Guid]::NewGuid().ToString('N'))
$package=Join-Path $scratch 'package';$game=Join-Path $scratch 'game';$data=Join-Path $game 'thesilentage_Data'
Expand-Archive -LiteralPath (Join-Path $repo 'dist\TheSilentAge_Chinese_2610_v1.1.0.zip') -DestinationPath $package
$items=Get-Content -LiteralPath (Join-Path $package 'manifest.json') -Raw | ConvertFrom-Json
[IO.Directory]::CreateDirectory((Join-Path $data 'Managed')) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $game 'thesilentage.exe'),[byte[]]@())
foreach($item in $items){
 $source=Join-Path (Join-Path $fixtureSource 'thesilentage_Data') $item.path
 $candidate=$null
 foreach($path in @($source,($source+'.zh-original'),($source+'.backup'))){
  if((Test-Path -LiteralPath $path) -and (Get-FileHash -LiteralPath $path).Hash.ToLower() -eq $item.source){$candidate=$path;break}
 }
 if(!$candidate){throw "Missing official fixture: $($item.path)"}
 Copy-Item -LiteralPath $candidate -Destination (Join-Path $data $item.path)
}
function Check-Release([string]$Field){foreach($item in $items){if((Get-FileHash -LiteralPath (Join-Path $data $item.path)).Hash.ToLower() -ne $item.$Field){throw "Release mismatch: $Field $($item.path)"}}}
& (Join-Path $package 'Install.ps1') -GamePath $game
Check-Release 'target'
& (Join-Path $package 'Install.ps1') -GamePath $game
Check-Release 'target'
& (Join-Path $package 'extras\Extras.ps1') -Action InstallSpeed -GamePath $game
& (Join-Path $package 'extras\Extras.ps1') -Action RestoreSpeed -GamePath $game
Check-Release 'target'
& (Join-Path $package 'Restore.ps1') -GamePath $game
Check-Release 'source'
& (Join-Path $package 'Restore.ps1') -GamePath $game
Check-Release 'source'
& (Join-Path $package 'Install.ps1') -GamePath $game
Check-Release 'target'
Write-Output "ALL RELEASE TESTS PASSED. Fixtures retained at $scratch"
