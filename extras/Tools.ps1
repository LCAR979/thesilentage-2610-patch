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
$form.ClientSize=New-Object Drawing.Size(660,456)
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10)
$label=New-Object Windows.Forms.Label;$label.Text='先退出游戏，再点击下面的按钮。';$label.Location=New-Object Drawing.Point(18,15);$label.AutoSize=$true;$form.Controls.Add($label)
$pathBox=New-Object Windows.Forms.TextBox;$pathBox.Location=New-Object Drawing.Point(18,48);$pathBox.Size=New-Object Drawing.Size(530,28);$pathBox.Text=Find-Game;$form.Controls.Add($pathBox)
$browse=New-Object Windows.Forms.Button;$browse.Text='浏览…';$browse.Location=New-Object Drawing.Point(557,46);$browse.Size=New-Object Drawing.Size(85,32)
$browse.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;$dialog.Description='在 Steam 中右键游戏 → 管理 → 浏览本地文件，选择打开的文件夹。';if($dialog.ShowDialog() -eq 'OK'){$pathBox.Text=$dialog.SelectedPath};$dialog.Dispose()});$form.Controls.Add($browse)
$script:statusBox=New-Object Windows.Forms.TextBox;$script:statusBox.Multiline=$true;$script:statusBox.ReadOnly=$true;$script:statusBox.ScrollBars='Vertical';$script:statusBox.Location=New-Object Drawing.Point(18,317);$script:statusBox.Size=New-Object Drawing.Size(624,120)
$script:statusBox.Text="第一次使用：点安装 / 更新汉化，完成后进游戏选中国国旗。`r`n想玩快一点，再点安装加速。第10章卡在医生房间时才需要修复结局。"
if(!$pathBox.Text){$script:statusBox.Text="没找到游戏？在 Steam 中右键 The Silent Age → 管理 → 浏览本地文件。`r`n点上面的浏览…，选择刚才打开的文件夹。"}
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
     $message='汉化装好了！进入游戏，选择中国国旗即可使用中文。想玩快一点，再点“安装加速”。'
    } else {$message=Invoke-Extra 'UpdateTranslation' $pathBox.Text}
   } elseif($operation -eq 'RestoreChinese'){
    Assert-GameClosed
    $selectedPath=$pathBox.Text.Trim().Trim('"');Get-DataPath $selectedPath | Out-Null
    $releaseRoot=Split-Path $script:ExtrasRoot -Parent
    $restoreScript=Join-Path $releaseRoot 'Restore.ps1'
    if(!(Test-Path -LiteralPath $restoreScript)){$restoreScript=Join-Path $releaseRoot 'scripts\Restore.ps1'}
    & $restoreScript -GamePath $selectedPath
    $message='已恢复原版英文。'
   } else {$message=Invoke-Extra $operation $pathBox.Text}
   $script:statusBox.Text=[string]$message
   [Windows.Forms.MessageBox]::Show([string]$message,'完成','OK','Information') | Out-Null
  } catch {
   $failure=$_.Exception.Message
   if($failure -match '校验|差分|译文长度|译文位置|Invalid|validation|Unsupported original|Backup conflict'){
    $failure='安装没能完成。请重新下载并完整解压补丁后再试；如果仍不行，请到补丁下载页反馈。'
   } elseif($failure -match 'denied|拒绝访问|Access|权限'){
    $failure='暂时无法修改游戏文件。请确认游戏已经退出；如果仍不行，请到补丁下载页反馈。'
   } elseif($failure -match 'not found|Could not find|找不到路径|路径.*不存在'){
    $failure='没找到需要的文件。请确认补丁已经全部解压，并选择正确的游戏文件夹。'
   } elseif($failure -match '[A-Za-z]{12,}|Exception|argument|parameter'){
    $failure='操作没能完成。请关闭游戏后重试；如果仍不行，请把工具箱截图发到补丁下载页反馈。'
   }
   $script:statusBox.Text=$failure
   [Windows.Forms.MessageBox]::Show($failure,'操作未完成','OK','Error') | Out-Null
  } finally {$form.Enabled=$true}
 });$form.Controls.Add($button)
}
Add-ToolButton '安装 / 更新汉化' 92 'Chinese'
Add-ToolButton '安装加速' 128 'InstallSpeed'
Add-ToolButton '卸载加速' 164 'RestoreSpeed'
Add-ToolButton '修复结局（第10章医生房间点不动）' 200 'FixEnding'
Add-ToolButton '撤销结局修复' 236 'RestoreEnding'
Add-ToolButton '恢复原版英文' 272 'RestoreChinese'
if($ValidateUI){
 $count=@($form.Controls | Where-Object {$_ -is [Windows.Forms.Button]}).Count
 if($count -ne 7){throw 'Unexpected button count'}
 Write-Output ('GUI validated; buttons='+$count+'; detected='+$pathBox.Text)
}else{[void]$form.ShowDialog()}
$form.Dispose()
