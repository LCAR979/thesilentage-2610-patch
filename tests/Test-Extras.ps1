param([Parameter(Mandatory=$true)][string]$GamePath)
$fixtureSource=$GamePath
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'extras\Extras.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('tsa2610-test-'+[Guid]::NewGuid().ToString('N'))
$testData=Join-Path $testRoot 'thesilentage_Data'
[IO.Directory]::CreateDirectory((Join-Path $testData 'Managed')) | Out-Null
[IO.File]::WriteAllBytes((Join-Path $testRoot 'thesilentage.exe'),[byte[]]@())
function Check($Condition,[string]$Message){if(!$Condition){throw "TEST FAILED: $Message"};Write-Output "PASS: $Message"}
function Reject([scriptblock]$Operation,[string]$Message){$rejected=$false;try{& $Operation | Out-Null}catch{$rejected=$true};Check $rejected $Message}
function Find-Fixture([string[]]$Paths,[string]$Hash){foreach($p in $Paths){if((Test-Path -LiteralPath $p) -and (Get-Hash $p) -eq $Hash){return $p}};throw "Missing fixture $Hash"}
$fixtureData=Join-Path $fixtureSource 'thesilentage_Data'
$normal=Find-Fixture @((Join-Path $fixtureData 'Managed\Assembly-CSharp.dll.speedmod-backup'),(Join-Path $fixtureData 'Managed\Assembly-CSharp.dll')) $script:NormalHash
$resource=Find-Fixture @((Join-Path $fixtureData 'resources.assets'),(Join-Path $fixtureData 'resources.assets.2610-v1.0.0-backup')) 'cec2da353e0df951be98b8a9f7486c06c6b3f3bece857d83ac609e3787cecc5e'
$dest=Join-Path $testData 'Managed\Assembly-CSharp.dll'
Copy-Item -LiteralPath $normal -Destination $dest
Copy-Item -LiteralPath $resource -Destination (Join-Path $testData 'resources.assets')
Install-Speed $testRoot | Out-Null
Check ((Get-Hash $dest) -eq $script:SpeedHash) 'delta reconstructs exact tested speed DLL'
Install-Speed $testRoot | Out-Null
Restore-Speed $testRoot | Out-Null
Restore-Speed $testRoot | Out-Null
Check ((Get-Hash $dest) -eq $script:NormalHash) 'repeated install/restore is safe'
[IO.File]::WriteAllBytes(($dest+'.speedmod-backup'),[byte[]]@(0,1,2))
Reject {Install-Speed $testRoot} 'corrupt speed backup rejected'
Check ((Get-Hash $dest) -eq $script:NormalHash) 'corrupt backup does not change game'
[IO.File]::WriteAllBytes($dest,[byte[]]@(1,2,3))
Reject {Install-Speed $testRoot} 'unsupported DLL rejected'
Update-Translation $testRoot | Out-Null
$resourceDest=Join-Path $testData 'resources.assets'
Check ((Get-Hash $resourceDest) -eq '81f610c038affbc699574686bf12c965e6650db7c5a102b61ed5de599b44e1f7') 'only intended translation bytes changed'
Update-Translation $testRoot | Out-Null
$bytes=[IO.File]::ReadAllBytes($resourceDest);$bytes[0]=$bytes[0] -bxor 1;[IO.File]::WriteAllBytes($resourceDest,$bytes)
Reject {Update-Translation $testRoot} 'unsupported resources rejected'

# Fake registry: same methods as RegistryKey, no writes to the real player save.
$script:fake=New-Object PSObject -Property @{Values=@{};FailOnce=$false}
$script:fake | Add-Member ScriptMethod GetValueNames {return [string[]]@($this.Values.Keys)}
$script:fake | Add-Member ScriptMethod GetValue {param($name,$default=$null);if($this.Values.ContainsKey($name)){return ,$this.Values[$name].value};return $default}
$script:fake | Add-Member ScriptMethod GetValueKind {param($name);return [Microsoft.Win32.RegistryValueKind]::$($this.Values[$name].kind)}
$script:fake | Add-Member ScriptMethod SetValue {param($name,$value,$kind);if($this.FailOnce -and $name -like 'trigger_start*'){$this.FailOnce=$false;throw 'Injected write failure'};$this.Values[$name]=@{value=$value;kind=$kind.ToString()}}
$script:fake | Add-Member ScriptMethod DeleteValue {param($name,$unused);$this.Values.Remove($name)}
$script:fake | Add-Member ScriptMethod Dispose {}
function Get-SaveKey {return $script:fake}
function Get-BackupDirectory {$path=Join-Path $testRoot 'save-backups';[IO.Directory]::CreateDirectory($path)|Out-Null;return $path}
function Export-SaveBackup([string]$Path){'FAKE COMPLETE SAVE EXPORT' | Set-Content -LiteralPath $Path}
function Initialize-FakeSave {
 $script:fake.Values=@{
  'CurrentChapter_h1'=@{value=10;kind='DWord'}
  'CurrentLevel_h2'=@{value=[Text.Encoding]::UTF8.GetBytes("115_sanatorium_office`0");kind='Binary'}
  'wall_avoid_clicks_h4165810459'=@{value=1;kind='DWord'}
  'DialogControllerMessageObj_h3817982429'=@{value=[Text.Encoding]::UTF8.GetBytes("couch_sanatorium_office`0");kind='Binary'}
  'UnlockedChaptersEPTwo_h3'=@{value=10;kind='DWord'}
 }
}
Initialize-FakeSave
Fix-Ending | Out-Null
Check ($script:fake.GetValue('wall_avoid_clicks_h4165810459') -eq -1) 'matching ending blocker repaired'
Check ($script:fake.GetValue('UnlockedChaptersEPTwo_h3') -eq 10) 'chapter unlocks untouched'
Restore-Ending | Out-Null
Check ($script:fake.GetValue('wall_avoid_clicks_h4165810459') -eq 1) 'blocker original value restored'
Check ($script:fake.GetValueNames() -notcontains 'trigger_start_dialogue_doctor_01_h311298789') 'originally absent trigger deleted on restore'
Check ((Get-PlayerPref $script:fake 'DialogControllerMessageObj') -eq 'couch_sanatorium_office') 'binary dialogue state restored exactly'
$script:fake.Values['CurrentChapter_h1'].value=9
Reject {Fix-Ending} 'non-ending save rejected'
Initialize-FakeSave;$script:fake.Values['wall_avoid_clicks_h4165810459'].value=-1
Reject {Fix-Ending} 'save without known blocker rejected'
Initialize-FakeSave;$script:fake.FailOnce=$true
Reject {Fix-Ending} 'partial registry write failure rejected'
Check ($script:fake.GetValue('wall_avoid_clicks_h4165810459') -eq 1) 'partial failure rolls back changed field'
Initialize-FakeSave;Fix-Ending | Out-Null
$script:fake.Values['CurrentLevel_h2'].value=[Text.Encoding]::UTF8.GetBytes("credits`0")
Reject {Restore-Ending} 'progress after repair cannot be overwritten'
Write-Output "ALL EXTRAS TESTS PASSED. Fixtures retained at $testRoot"
