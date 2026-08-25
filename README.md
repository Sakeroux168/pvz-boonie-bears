# PVZ Boonie Bears

私人同人学习项目：以 5 路路线塔防为基础，围绕《熊出没》角色关系、同角色升级、固定跨角色融合和不同世界规则设计原创玩法。

## P2 Playable Prototype

正式技术栈：Godot 4.7.2 + GDScript + GUT 9.7.1。

当前 P2 原型包含 5 路可变列数棋盘、2 个友方功能角色、2 类敌人、单资源、最小波次、路线保险、胜负闭环、三级同角色升级、固定跨角色融合、保护目标，以及鼠标/触屏统一指针路由。

Windows 启动：`scripts\start-game.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"`

Windows 测试：`scripts\run-tests.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64_console.exe"`

P2 画面只用 Godot 代码绘制的几何图形和功能代号，不包含《熊出没》、PVZ 原作图片、音频、字体或其他未知授权素材。第三方依赖见 `THIRD_PARTY_NOTICES.md`。
