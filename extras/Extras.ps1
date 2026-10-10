param(
 [ValidateSet('UpdateTranslation','InstallSpeed','RestoreSpeed','FixEnding','RestoreEnding')][string]$Action,
 [string]$GamePath
)
$ErrorActionPreference='Stop'
$script:ExtrasRoot=$PSScriptRoot
$script:NormalHash='08489c29167625d19e7aa76f1b42500782ebf979fe9b840360d72a76d17c6b36'
$script:SpeedHash='e0a896fa66e362db4f74fe778cd15c78bb5d993bf17358f0d6f05a512ea9e597'
$script:SavePath='Software\House on Fire\The Silent Age'
function Assert-GameClosed {
 if(Get-Process -Name thesilentage -ErrorAction SilentlyContinue){throw '请先完全退出 The Silent Age，再执行操作。'}
}
function Get-Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-BytesHash([byte[]]$Bytes) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try { ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() } finally {$sha.Dispose()}
}
function Get-DataPath([string]$Path) {
 if(!$Path){throw '请选择包含 thesilentage.exe 的游戏文件夹。'}
 $Path=$Path.Trim().Trim('"')
 if(!(Test-Path -LiteralPath (Join-Path $Path 'thesilentage.exe') -PathType Leaf)){throw '游戏目录不正确：需要选择包含 thesilentage.exe 的文件夹。'}
 Join-Path $Path 'thesilentage_Data'
}
function Write-VerifiedFile([string]$Path,[byte[]]$Bytes,[string]$Expected) {
 if((Get-BytesHash $Bytes) -ne $Expected){throw '生成文件校验失败，未修改游戏。'}
 $stage=$Path+'.2610-stage-'+[Guid]::NewGuid().ToString('N')
 $rollback=$stage+'.rollback'
 try {
  [IO.File]::WriteAllBytes($stage,$Bytes)
  if((Get-Hash $stage) -ne $Expected){throw '临时文件校验失败。'}
  [IO.File]::Copy($Path,$rollback)
  try {
   [IO.File]::Copy($stage,$Path,$true)
   if((Get-Hash $Path) -ne $Expected){throw '写入校验失败。'}
  } catch {[IO.File]::Copy($rollback,$Path,$true);throw}
 } finally {
  if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage}
  if(Test-Path -LiteralPath $rollback){Remove-Item -LiteralPath $rollback}
 }
}
function Read-SpeedDelta([byte[]]$Original) {
 $stream=[IO.File]::OpenRead((Join-Path $script:ExtrasRoot 'speedmod.delta.gz'))
 $gzip=[IO.Compression.GZipStream]::new($stream,[IO.Compression.CompressionMode]::Decompress)
 $reader=[IO.BinaryReader]::new($gzip);$output=[IO.MemoryStream]::new()
 try {
  if([Text.Encoding]::ASCII.GetString($reader.ReadBytes(5)) -ne 'TSAD1'){throw '加速补丁格式错误。'}
  while($true){
   $op=$reader.ReadByte()
   if($op -eq 69){break}
   if($op -eq 67){$off=$reader.ReadUInt32();$len=$reader.ReadUInt32();if([long]$off+$len -gt $Original.Length){throw '差分范围错误。'};$output.Write($Original,$off,$len)}
   elseif($op -eq 73){$len=$reader.ReadUInt32();$b=$reader.ReadBytes($len);if($b.Length -ne $len){throw '差分数据不完整。'};$output.Write($b,0,$len)}
   else {throw '未知差分指令。'}
   if($output.Length -gt 432640){throw '差分输出长度错误。'}
  }
  return ,$output.ToArray()
 } finally {$reader.Dispose();$stream.Dispose();$output.Dispose()}
}
function Update-Translation([string]$Path) {
 Assert-GameClosed
 $dest=Join-Path (Get-DataPath $Path) 'resources.assets'
 $fix=Get-Content -LiteralPath (Join-Path $script:ExtrasRoot 'translation-fix.json') -Raw -Encoding UTF8 | ConvertFrom-Json
 $hash=Get-Hash $dest
 if($hash -eq $fix.target){return '译文已经是修正版。'}
 if($hash -ne $fix.source){throw '此译文更新需要中文 2610 v1.0.0。请下载完整 v1.1.0 发布包安装；未修改游戏。'}
 $bytes=[IO.File]::ReadAllBytes($dest);$old=[Text.Encoding]::UTF8.GetBytes($fix.before);$new=[Text.Encoding]::UTF8.GetBytes($fix.after)
 if($old.Length -ne $new.Length){throw '译文长度不匹配。'}
 for($i=0;$i -lt $old.Length;$i++){if($bytes[$fix.offset+$i] -ne $old[$i]){throw '译文位置校验失败。'}}
 $backup=$dest+'.2610-v1.0.0-backup'
 if(Test-Path -LiteralPath $backup){if((Get-Hash $backup) -ne $fix.source){throw '已有译文备份冲突。'}}else{[IO.File]::Copy($dest,$backup)}
 [Array]::Copy($new,0,$bytes,$fix.offset,$new.Length)
 Write-VerifiedFile $dest $bytes $fix.target
 return '已修正第一章烟灰缸的“骨灰”为“烟灰”。'
}
function Install-Speed([string]$Path) {
 Assert-GameClosed;$dest=Join-Path (Get-DataPath $Path) 'Managed\Assembly-CSharp.dll'
 $hash=Get-Hash $dest
 if($hash -eq $script:SpeedHash){return '加速 Mod 已安装。游戏中按 F6 切换正常/加速。'}
 if($hash -ne $script:NormalHash){throw '加速 Mod 需要中文 2610 v1.0.0 或 v1.1.0 的脚本文件。其他版本未被修改。'}
 $backup=$dest+'.speedmod-backup'
 if(Test-Path -LiteralPath $backup){if((Get-Hash $backup) -ne $script:NormalHash){throw '已有加速备份冲突。'}}else{[IO.File]::Copy($dest,$backup)}
 $result=Read-SpeedDelta ([IO.File]::ReadAllBytes($dest))
 Write-VerifiedFile $dest $result $script:SpeedHash
 return '已安装：行走约 2 倍，剧情/对白约 3 倍；F6 切换。语音音调会变高。'
}
function Restore-Speed([string]$Path) {
 Assert-GameClosed;$dest=Join-Path (Get-DataPath $Path) 'Managed\Assembly-CSharp.dll'
 $hash=Get-Hash $dest
 if($hash -eq $script:NormalHash){return '当前已经是正常速度的汉化脚本。'}
 if($hash -ne $script:SpeedHash){throw '当前文件不是本项目加速 Mod，为避免覆盖其他修改，恢复已停止。'}
 $backup=$dest+'.speedmod-backup'
 if(!(Test-Path -LiteralPath $backup) -or (Get-Hash $backup) -ne $script:NormalHash){throw '加速备份缺失或损坏，未修改游戏。'}
 Write-VerifiedFile $dest ([IO.File]::ReadAllBytes($backup)) $script:NormalHash
 return '已卸载加速 Mod，保留汉化和存档。'
}
function Get-SaveKey { [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($script:SavePath,$true) }
function Get-PlayerPref($Key,[string]$Name) {
 $names=@($Key.GetValueNames() | Where-Object {$_ -match ('^'+[regex]::Escape($Name)+'_h\d+$')})
 if($names.Count -ne 1){throw "找不到唯一存档字段：$Name。"}
 $value=$Key.GetValue($names[0])
 if($value -is [byte[]]){return [Text.Encoding]::UTF8.GetString($value).TrimEnd([char]0)}
 return $value
}
function Assert-EndingScene($Key) {
 if((Get-PlayerPref $Key 'CurrentChapter') -ne 10 -or (Get-PlayerPref $Key 'CurrentLevel') -ne '115_sanatorium_office'){
  throw '只支持第10章医生房间（115_sanatorium_office）卡住的存档。当前场景不匹配，未修改存档。'
 }
}
function Get-EndingEdits {
 @(
  @{name='wall_avoid_clicks_h4165810459';kind='DWord';value=-1},
  @{name='trigger_start_dialogue_doctor_01_h311298789';kind='DWord';value=-1},
  @{name='DialogControllerMessageObj_h3817982429';kind='Binary';value=[byte[]]@(0)}
 )
}
function Export-SaveBackup([string]$Path) {
 & reg.exe export ('HKCU\'+$script:SavePath) $Path /y | Out-Null
 if($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $Path)){throw '完整存档备份失败，未修改存档。'}
}
function Get-BackupDirectory {
 $dir=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TheSilentAge2610\Backups'
 [IO.Directory]::CreateDirectory($dir) | Out-Null
 return $dir
}
function Restore-SnapshotValues($Key,$Values) {
 foreach($v in $Values){
  if(!$v.exists){$Key.DeleteValue($v.name,$false)}
  else {
   $data=$v.value
   if($v.kind -eq 'Binary'){$data=[Convert]::FromBase64String([string]$data)}
   elseif($v.kind -eq 'DWord'){$data=[int]$data}
   $Key.SetValue($v.name,$data,[Microsoft.Win32.RegistryValueKind]::$($v.kind))
  }
 }
}
function Fix-Ending {
 Assert-GameClosed;$key=Get-SaveKey
 if(!$key){throw '未找到当前 Windows 用户的游戏存档。请用平时玩游戏的账户运行。'}
 try {
  Assert-EndingScene $key
  $wall=$key.GetValue('wall_avoid_clicks_h4165810459',$null)
  if($wall -ne 1){throw '未检测到本次排查确认的点击阻挡状态，未修改存档。'}
  $dir=Get-BackupDirectory;$stem='ending-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N')
  $reg=Join-Path $dir ($stem+'.reg');$json=Join-Path $dir ($stem+'.json')
  Export-SaveBackup $reg
  $snapshot=@()
  foreach($edit in (Get-EndingEdits)){
   $exists=$key.GetValueNames() -contains $edit.name;$kind=$null;$value=$null
   if($exists){$kind=$key.GetValueKind($edit.name).ToString();$value=$key.GetValue($edit.name);if($kind -eq 'Binary'){$value=[Convert]::ToBase64String($value)}}
   $snapshot+=@{name=$edit.name;exists=$exists;kind=$kind;value=$value}
  }
  @{version=1;scene='115_sanatorium_office';registry=$script:SavePath;values=$snapshot;fullBackup=$reg} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $json -Encoding UTF8
  try {
   foreach($edit in (Get-EndingEdits)){$key.SetValue($edit.name,$edit.value,[Microsoft.Win32.RegistryValueKind]::$($edit.kind))}
   Assert-PatchedEnding $key
  } catch {Restore-SnapshotValues $key $snapshot;throw}
  return "已解除点击阻挡。重新启动游戏，继续并手动点击医生。建议先按 F6 切回正常速度。完整备份：$reg"
 } finally {$key.Dispose()}
}
function Assert-PatchedEnding($Key) {
 foreach($edit in (Get-EndingEdits)){
  $value=$Key.GetValue($edit.name,$null)
  if($Key.GetValueNames() -notcontains $edit.name -or $Key.GetValueKind($edit.name).ToString() -ne $edit.kind){throw '存档字段类型不匹配。'}
  if($edit.kind -eq 'Binary'){if(!($value -is [byte[]]) -or $value.Length -ne 1 -or $value[0] -ne 0){throw '对白状态已改变，未恢复旧状态。'}}
  elseif($value -ne $edit.value){throw '存档状态已改变，未恢复旧状态。'}
 }
}
function Restore-Ending {
 Assert-GameClosed;$dir=Get-BackupDirectory
 $file=Get-ChildItem -LiteralPath $dir -Filter 'ending-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 if(!$file){throw '没有本工具生成的结局修复备份。'}
 $snapshot=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
 if($snapshot.version -ne 1 -or $snapshot.registry -ne $script:SavePath -or $snapshot.values.Count -ne 3){throw '备份格式错误。'}
 $expected=@((Get-EndingEdits).name)
 if(@($snapshot.values.name | Sort-Object -Unique).Count -ne 3){throw '备份字段重复。'}
 foreach($v in $snapshot.values){if($expected -notcontains $v.name){throw '备份字段不属于本次修复。'};if($v.exists -and $v.kind -notin @('DWord','Binary')){throw '备份字段类型错误。'}}
 $key=Get-SaveKey
 if(!$key){throw '未找到存档。'}
 try {Assert-EndingScene $key;Assert-PatchedEnding $key;Restore-SnapshotValues $key $snapshot.values} finally {$key.Dispose()}
 return '已撤销最近一次结局修复，仅恢复三个字段；其他存档进度未被覆盖。'
}
function Invoke-Extra([string]$Operation,[string]$Path) {
 switch($Operation){
  'UpdateTranslation' {Update-Translation $Path}
  'InstallSpeed' {Install-Speed $Path}
  'RestoreSpeed' {Restore-Speed $Path}
  'FixEnding' {Fix-Ending}
  'RestoreEnding' {Restore-Ending}
 }
}
if($Action){Invoke-Extra $Action $GamePath}
