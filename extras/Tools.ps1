param([switch]$ValidateUI)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Extras.ps1')
[Windows.Forms.Application]::EnableVisualStyles()
function Find-Game {
 $candidates=@();$steamRoots=@((${env:ProgramFiles(x86)}+'\Steam'),($env:ProgramFiles+'\Steam'))
 try {$steam=(Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath;if($steam){$steamRoots+= $steam}} catch {}
 foreach($root in $steamRoots){
  $candidates+=Join-Path $root 'steamapps\common\The Silent Age'
  $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
  if(Test-Path -LiteralPath $vdf){
   foreach($match in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')){
    $library=$match.Groups[1].Value.Replace('\\','\');$candidates+=Join-Path $library 'steamapps\common\The Silent Age'
   }
  }
 }
 foreach($drive in [IO.DriveInfo]::GetDrives()){
  if($drive.IsReady -and $drive.DriveType -eq 'Fixed'){$candidates+=Join-Path $drive.RootDirectory.FullName 'SteamLibrary\steamapps\common\The Silent Age'}
 }
 foreach($path in $candidates){if(Test-Path -LiteralPath (Join-Path $path 'thesilentage.exe')){return $path}}
 return ''
}
$form=New-Object Windows.Forms.Form
$form.Text='The Silent Age 中文 2610 工具箱 v1.1.0'
$form.ClientSize=New-Object Drawing.Size(660,420)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$label=New-Object Windows.Forms.Label;$label.Text='先退出游戏。选择游戏目录，再点击需要的功能。';$label.Location=New-Object Drawing.Point(18,15);$label.AutoSize=$true;$form.Controls.Add($label)
$pathBox=New-Object Windows.Forms.TextBox;$pathBox.Location=New-Object Drawing.Point(18,48);$pathBox.Size=New-Object Drawing.Size(530,28);$pathBox.Text=Find-Game;$form.Controls.Add($pathBox)
$browse=New-Object Windows.Forms.Button;$browse.Text='浏览…';$browse.Location=New-Object Drawing.Point(557,46);$browse.Size=New-Object Drawing.Size(85,32)
$browse.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;$dialog.Description='选择包含 thesilentage.exe 的游戏文件夹';if($dialog.ShowDialog() -eq 'OK'){$pathBox.Text=$dialog.SelectedPath};$dialog.Dispose()});$form.Controls.Add($browse)
$script:statusBox=New-Object Windows.Forms.TextBox;$script:statusBox.Multiline=$true;$script:statusBox.ReadOnly=$true;$script:statusBox.ScrollBars='Vertical';$script:statusBox.Location=New-Object Drawing.Point(18,281);$script:statusBox.Size=New-Object Drawing.Size(624,120)
$script:statusBox.Text="汉化安装/更新会修正骨灰→烟灰。加速默认开启，F6 切换。`r`n结局修复仅用于第10章医生房间点击无反应，自动备份存档。`r`n不要用管理员或其他 Windows 用户账户运行存档修复。"
$form.Controls.Add($script:statusBox)
function Add-ToolButton([string]$Text,[int]$Y,[string]$Operation) {
 $button=New-Object Windows.Forms.Button;$button.Text=$Text;$button.Location=New-Object Drawing.Point(18,$Y);$button.Size=New-Object Drawing.Size(624,33);$button.Tag=$Operation
 $button.Add_Click({
  $operation=$this.Tag
  try {
   $form.Enabled=$false;[Windows.Forms.Application]::DoEvents()
   if($operation -eq 'Chinese'){
    Assert-GameClosed
    $releaseRoot=Split-Path $script:ExtrasRoot -Parent
    if(Test-Path -LiteralPath (Join-Path $releaseRoot 'resources.assets.delta.gz')){
     $selectedPath=$pathBox.Text.Trim().Trim('"');Get-DataPath $selectedPath | Out-Null
     & (Join-Path $releaseRoot 'Install.ps1') -GamePath $selectedPath
     $message='汉化 v1.1.0 已安装（正常速度）。如需加速，点击下方“安装加速”。'
    } else {$message=Invoke-Extra 'UpdateTranslation' $pathBox.Text}
   } else {$message=Invoke-Extra $operation $pathBox.Text}
   $script:statusBox.Text=[string]$message
   [Windows.Forms.MessageBox]::Show([string]$message,'完成','OK','Information') | Out-Null
  } catch {
   $script:statusBox.Text=$_.Exception.Message
   [Windows.Forms.MessageBox]::Show($_.Exception.Message,'操作未完成','OK','Error') | Out-Null
  } finally {$form.Enabled=$true}
 });$form.Controls.Add($button)
}
Add-ToolButton '安装 / 更新汉化（修正烟灰译文）' 92 'Chinese'
Add-ToolButton '安装加速：行走约 2 倍，剧情与对白约 3 倍' 128 'InstallSpeed'
Add-ToolButton '卸载加速（保留汉化和存档）' 164 'RestoreSpeed'
Add-ToolButton '修复结局：第10章医生房间点击无反应' 200 'FixEnding'
Add-ToolButton '撤销最近一次结局修复（仅在原场景、未继续游戏时）' 236 'RestoreEnding'
if($ValidateUI){Write-Output ('GUI validated; buttons=6; detected='+$pathBox.Text)}else{[void]$form.ShowDialog()}
$form.Dispose()
