# The Silent Age 中文 2610 补丁

由 **LCAR979（Steam：@lcar979）** 维护的非官方简体中文自然口语重译与显示修复补丁。
翻译、补丁：GPT-6.1 Sol Light；版本 **1.1.0**。

## 下载与安装

请前往 [Releases](https://github.com/LCAR979/thesilentage-2610-patch/releases/latest) 下载补丁 ZIP。
无需安装旧汉化。首次安装请下载完整发布包；已安装本项目 v1.0.0 的用户也可使用源码 ZIP 中的工具箱更新译文、安装加速或恢复结局存档。

1. 完全退出游戏，解压发布 ZIP。
2. 双击 `Tools.cmd` 打开中文工具箱。自动找到游戏目录后点击“安装 / 更新汉化”；找不到时点“浏览”选择包含 `thesilentage.exe` 的文件夹。
3. 路径可在 Steam 中右键游戏 → 管理 → 浏览本地文件找到。
4. 安装完成后从 Steam 启动，通过章节菜单左上角国旗切换中英文。中国国旗位于语言选择页第二行第四个位置。

适用于 **Steam Windows build 3358273 / Unity 2018.2.9f1**。
详细安装、回退与项目说明见 [使用说明](docs/使用说明-v1.1.0.txt)。旧命令行入口 `应用补丁.cmd` 仍可使用。

## v1.1.0 新功能

- 第一章烟灰缸的“骨灰”按维护者要求改为“烟灰”；[修订记录](extras/translation-fix.json)保留完整前后句和资源位置。
- 可选加速：行走约 2 倍，剧情/对白约 3 倍；每次启动默认开启，**F6** 切换正常/加速。语音音调会提高，背景音乐保持原速。
- 工具箱可安装和卸载加速；文件校验不符时拒绝覆盖，卸载保留汉化及存档。
- 第10章医生房间点击无反应时，可按需点击“修复结局”；先备份当前用户的完整存档，只修改三个关联字段。
- “撤销最近一次结局修复”仅在原场景且修复后字段没有变化时恢复三个字段，避免覆盖已继续的游戏进度。

结局恢复工具仅识别已验证的 `115_sanatorium_office` 点击阻挡状态，不是所有结局问题的通用修复。具体源码根因尚未证明，也没有证据认定汉化造成该问题。时序敏感场景建议按 F6 使用正常速度。

存档备份位于 `%LOCALAPPDATA%\TheSilentAge2610\Backups`；请用玩游戏的同一 Windows 账户运行，不需要管理员权限。

## 修改内容

- 结合英文和旧中文重译主线对白、场景独白与大量物品反馈，使用自然中文口语，统一名称并修正部分误译与漏句。
- 为中文使用独立字体、材质和图集，修复旧补丁导致的显示异常；增加中文换行、调整标题页“点击开始”居中。
- 启用隐藏的中国国旗并调整位置，修复语言选择返回错误场景，保留原版英文内容和显示逻辑。
- 补齐门牌、姓名标签等曾被文本处理程序跳过的条目。
- 差分安装校验四个源文件和生成结果；自动备份，支持恢复原版。

## 备份与卸载

备份保存在原文件旁：`resources-backup.assets`、`globalgamemanagers-backup`、`level3-backup`、`Managed/Assembly-CSharp-backup.dll`。
已有备份不会覆盖。建议先在游戏中切回英文，然后退出游戏，运行 `恢复备份.cmd` 并输入相同游戏目录。
恢复脚本校验全部备份后还原，保留备份文件。也可通过 Steam 验证游戏完整性恢复原版。

## 验证与限制

已用 Steam 客户端直接下载的官方 depot 验证差分安装，四个生成文件哈希均匹配。
最终脚本在 Windows PowerShell 5.1 下验证了重复安装、恢复、重复恢复、重新安装以及损坏备份拒绝。
已检查 25 个中文文本资源、12,120 个可翻译单元格、控制标记与字形覆盖；已实测 4K 标题、章节介绍换行和语言切换。

尚未完成十章逐场景通关；场景贴图里的英文招牌尚未重绘。未做全面杀毒扫描，不能保证所有安全软件放行。
v1.1.0 的差分重建、译文更新、重复操作、加速安装/恢复和备份损坏拒绝经过隔离文件测试；结局修复与撤销经过模拟存档测试，避免修改维护者已通关的实际存档。工具箱构造验证不代表所有 Windows 桌面环境均已实测。
安装脚本不联网、不添加开机启动项、不关闭安全软件；CMD 仅为当前 PowerShell 进程指定执行策略。

## 反馈

请在 [Issues](https://github.com/LCAR979/thesilentage-2610-patch/issues) 附上章节、场景、操作步骤、补丁版本与截图。
翻译反馈请附具体中文句子。

## 构建

`python tools/build_release.py` 从固定 SHA256 的 v1.0.0 发布包取用汉化差分，加入新版脚本及可选工具，输出 `dist/`。不会重新打包完整游戏 DLL。
加速补丁生成源码位于 `src/SpeedModBuilder`（.NET 8、Mono.Cecil 0.11.6）；输入为合法安装的本项目汉化 DLL，Unity 依赖需要位于相同目录：

```powershell
dotnet run --project src/SpeedModBuilder -- "游戏目录\thesilentage_Data\Managed\Assembly-CSharp.dll" "输出目录\Assembly-CSharp.dll"
python tools/make_speed_delta.py "原汉化DLL" "加速DLL" extras/speedmod.delta.gz
```

文件操作与存档保护测试：`powershell -NoProfile -ExecutionPolicy Bypass -File tests/Test-Extras.ps1 -GamePath "游戏目录"`。测试仅复制文件到临时目录、使用模拟注册表，不写入实际游戏或存档。

## 署名与许可

自有脚本、修复代码及原创文档采用 [MIT License](LICENSE)，使用或再发布时保留 **LCAR979** 的版权声明和许可证。
游戏资源、旧译文及字体不受本项目 MIT 授权覆盖，详见 [第三方内容说明](THIRD_PARTY_NOTICES.md)。
感谢 Steam 评论区 **@dofurzy** 提供的旧补丁参考；旧补丁的显示兼容问题促成了本项目。
