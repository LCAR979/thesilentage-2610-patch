# 开发与测试说明

面向维护者；普通玩家只需阅读首页或发布包内的使用说明。

## 适用版本

Steam Windows build 3358273 / Unity 2018.2.9f1；运行脚本使用 Windows PowerShell 5.1。
加速工具仅接受本项目 v1.0.0/v1.1.0 的普通速度 DLL，也识别已安装的本项目加速 DLL。
安装、恢复前检查文件 SHA256，并保留原文件备份。不覆盖不匹配的备份或第三方修改。
完整汉化安装会恢复普通速度，之后可再次安装加速。

首次安装需要 Releases 完整包。源码 ZIP 不含完整汉化差分；已安装 v1.0.0 的用户可使用源码包中的 Tools.cmd 更新译文及安装加速。
第一章烟灰缸修订记录见 [translation-fix.json](../extras/translation-fix.json)。原文用 urn 夸张灰的量；按维护者要求将“骨灰”明确改为“烟灰”，其余对白不变。

## 结局恢复范围

要求 CurrentChapter=10、CurrentLevel=115_sanatorium_office、wall_avoid_clicks=1。
操作前导出完整注册表存档，并保存以下三个字段的存在性、类型和原始值：

- wall_avoid_clicks_h4165810459 → DWORD -1。
- trigger_start_dialogue_doctor_01_h311298789 → DWORD -1。
- DialogControllerMessageObj_h3817982429 → 二进制 00。

不修改章节、物品及成就。修复后需手动点击医生。
撤销只恢复上述三个字段，要求仍在原场景且修复后的字段未改变；原本不存在的字段会删除。
完整 .reg 备份可用于手动恢复，但导入会覆盖其中记录的游戏偏好和进度。
备份目录：`%LOCALAPPDATA%\TheSilentAge2610\Backups`。必须用平时玩游戏的同一 Windows 用户运行。
三个字段同时修改后，已知卡住存档能够继续通关；确切根因尚未证明，没有证据认定是汉化导致。
这是一项按需存档恢复，不声称解决所有结局问题或消除所有触发时序问题。

## 加速实现与构建

全局时间倍率3；HeroController.FixedUpdate 中位移因子2/3，因此行走约2倍。
主语音 AudioSource.pitch 跟随倍率，声音会变尖；背景音乐不变。F6为KeyCode 287，每次启动默认加速。
Unity时间为0时不主动解除暂停；全局时间加速仍可能影响时序敏感场景，医生房间建议使用正常速度。

构建源码：`src/SpeedModBuilder`（.NET 8、Mono.Cecil 0.11.6）。输入为本项目汉化 DLL，Unity依赖需在同一目录。

```powershell
dotnet run --project src/SpeedModBuilder -- "游戏目录\thesilentage_Data\Managed\Assembly-CSharp.dll" "输出目录\Assembly-CSharp.dll"
python tools/make_speed_delta.py "原汉化DLL" "加速DLL" extras/speedmod.delta.gz
python tools/build_release.py
```

发布包构建从固定 SHA256 的 v1.0.0 包取用原汉化差分，加入新版脚本和小型加速差分，不分发完整游戏 DLL。
输出至 dist/；SHA256SUMS.txt 对应实际生成的 ZIP。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Extras.ps1 -GamePath "游戏目录"
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Release.ps1 -GamePath "游戏目录"
powershell -NoProfile -STA -ExecutionPolicy Bypass -File extras/Tools.ps1 -ValidateUI
```

测试只复制游戏文件到临时目录，存档测试使用模拟注册表，不改实际游戏与存档。
覆盖差分重建、精确译文更改、重复安装/恢复、损坏备份拒绝、错误版本拒绝、结局修复/撤销、部分写入失败回滚和继续游戏后的撤销拒绝。
已测试加速构建倍率、F6重载及最终DLL哈希；工具箱构造测试不代替真实桌面视觉验证。
原汉化已检查25个文本资源、12,120个可翻译单元格及控制标记、字形覆盖；实测4K标题、介绍换行和语言切换。
尚未逐场景验证十章全部内容；贴图里的英文招牌未重绘，也未在所有Windows环境完成GUI及加速时序回归。
