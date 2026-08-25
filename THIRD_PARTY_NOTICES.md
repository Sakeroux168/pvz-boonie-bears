# 第三方依赖与 License

本清单覆盖当前正式 P2 原型。P1 曾对比 GUT 与 GdUnit4；正式 P2 只保留 GUT 作为测试依赖。

| 依赖 | 固定版本 / commit | 用途 | License |
|---|---|---|---|
| Godot Engine | 4.7.2-stable / `ed1daf0bf001b61586d9930840f2f1394092c079` | 正式运行时/编辑器，不提交二进制 | MIT；引擎另汇总第三方组件许可证 |
| GUT | 9.7.1 / `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` | 默认自动测试框架；下载到忽略的 `addons/gut/` | MIT；插件随附字体遵循各自 OFL |

固定下载校验：Godot Windows zip `731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953`；GUT source zip `14969AA46ADC84AA08CDD21B9F6D1A64ADDD92AE60B36F02D0521ED305AA4086`。

P2 游戏画面不提交位图、矢量图、音频、视频或外部字体，不使用《熊出没》、PVZ 或未知授权素材。删除 `addons/gut/` 只会移除测试框架；核心游戏运行与数据不依赖 GUT 私有格式。
