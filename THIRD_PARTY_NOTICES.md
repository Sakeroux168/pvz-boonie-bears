# P1 灰盒 PoC 第三方依赖与 License

本清单只覆盖 P1 灰盒 PoC。项目代码、测试规格与几何表现均为本仓库新写内容；没有复制 PVZ clone、塔防模板或《熊出没》/PVZ 原作素材。

| 依赖 | 固定版本 / commit | 用途与是否入库 | License | 来源与通知位置 |
|---|---|---|---|---|
| Godot Engine | 4.7.2-stable / `ed1daf0bf001b61586d9930840f2f1394092c079` | 试验运行时；不提交引擎二进制 | MIT；引擎还汇总其第三方组件许可证 | [官方 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)、[COPYRIGHT.txt](https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt) |
| GUT | 9.7.1 / `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` | 测试候选；首次测试下载到忽略的 `addons/gut/` | MIT，Tom “Butch” Wesley | 安装后 `addons/gut/LICENSE.md`、[固定 commit](https://github.com/bitwes/Gut/commit/aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605) |
| GdUnit4 | 6.2.0 / `d18770221c2df4a3c991a42fdce7907df40eea75` | 测试候选；首次测试下载到忽略的 `addons/gdUnit4/` | MIT，Mike Schulze 等 | 安装后 `addons/gdUnit4/LICENSE`、[固定 commit](https://github.com/godot-gdunit-labs/gdUnit4/commit/d18770221c2df4a3c991a42fdce7907df40eea75) |
| Anonymous Pro | GUT 9.7.1 内含 | 仅测试工具 UI 字体，不用于灰盒画面 | SIL Open Font License 1.1；Copyright 2009 Mark Simonson；Reserved Font Name “Anonymous Pro” | `addons/gut/fonts/OFL.txt`、[上游许可](https://github.com/google/fonts/blob/main/ofl/anonymouspro/OFL.txt) |
| Courier Prime | GUT 9.7.1 内含 | 仅测试工具 UI 字体，不用于灰盒画面 | SIL Open Font License 1.1；Copyright 2015 Courier Prime Project Authors | 完整 OFL 文本见 `addons/gut/fonts/OFL.txt`；[上游许可与通知](https://github.com/google/fonts/blob/main/ofl/courierprime/OFL.txt) |
| Lobster Two | GUT 9.7.1 内含 | 仅测试工具 UI 字体，不用于灰盒画面 | SIL Open Font License 1.1；Copyright 2011 Pablo Impallari、Igino Marini；Reserved Font Names “Lobster”/“Lobster Two” | 完整 OFL 文本见 `addons/gut/fonts/OFL.txt`；[上游许可与通知](https://github.com/google/fonts/blob/main/ofl/lobstertwo/OFL.txt) |
| Source Code Pro（嵌入式 bitmap font） | GUT 9.7.1 内含 | 仅测试工具 UI 字体，不用于灰盒画面 | SIL Open Font License 1.1；© Adobe；Reserved Font Name “Source” | 完整 OFL 文本见 `addons/gut/fonts/OFL.txt`；[上游许可与通知](https://github.com/adobe-fonts/source-code-pro/blob/main/LICENSE.md) |

## 素材

- 位图、矢量图、字体文件、音频、视频：无。
- 画面只使用 Godot `draw_*` API、默认字体、纯色几何图形和功能代号。
- 未引入《熊出没》、PVZ 或未知授权素材。
- GUT/GdUnit4 自带的图标和报告 UI 图像属于锁定插件分发内容，随各插件 MIT 通知保留；不用于游戏画面。

## 下载包校验（本次 Windows 实测）

| 包 | SHA-256 |
|---|---|
| `Godot_v4.7.2-stable_win64.exe.zip` | `731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953` |
| `Gut v9.7.1 source zip` | `14969AA46ADC84AA08CDD21B9F6D1A64ADDD92AE60B36F02D0521ED305AA4086` |
| `gdUnit4 v6.2.0 source zip` | `99E86A1C0C91DEEF9AB88C4A0BFEA8802BF2D6FFB8167634C16CA12FEE16338B` |

## 删除成本

- 删除 `addons/gut/` 只会移除 GUT 测试入口；共享规格和运行灰盒不受影响。
- 删除 `addons/gdUnit4/` 只会移除 GdUnit4 测试入口；共享规格和运行灰盒不受影响。
- 核心状态没有存储在任一测试插件的私有格式中。
