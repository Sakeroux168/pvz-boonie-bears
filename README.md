# P2 正式骨架与 Playable Prototype

状态：P2 阶段（H0–H3）实现分支。

技术栈（已批准，D028/D029）：Godot 4.7.2 + GDScript + GUT 9.7.1。

## Windows 启动

```bat
scripts\start-prototype.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"
```

或设置环境变量：

```bat
set "GODOT_BIN=C:\Tools\Godot_v4.7.2-stable_win64.exe"
scripts\start-prototype.cmd
```

操作方式：
- 从底部卡组拖 `unit_a1` / `unit_b1` 到空格部署。
- 把一个已部署单位拖到另一个单位上执行固定升级/融合（显示合法/非法预览光标）。
- 敌人从右向左推进；单位只攻击本路敌人；每路左侧黄色小格是一次性滚石保险。
- 紫色 `enemy_tree_targeter` 优先攻击同路受保护树木；树全灭或敌人越线即失败。

列数参数化：修改 `src/data/level_proto_01.json` 的 `columns`（8/9/10 均可），核心逻辑不写死 9。

## 自动测试（GUT 9.7.1，headless，失败返回非 0）

```bat
scripts\run-tests.cmd -GodotBin "C:\Tools\Godot_v4.7.2-stable_win64.exe"
```

首次运行会下载 GUT v9.7.1 官方源码包、校验 SHA-256 并解压到忽略的 `addons/gut/`。JUnit 报告输出到 `reports/gut/results.xml`。

## 目录职责

见任务书 H1。核心规则在 `src/battle/battle_core.gd` + `src/grid/` + `src/units/` + `src/fusion/` + `src/enemies/`，全部可 headless 测试；`src/battle/battle_scene.gd` 只做绘制与输入转发，不计算规则。角色/敌人/配方/关卡数据全部来自 `src/data/*.json`，没有硬编码常量表或 if/else 角色 ID 链。

## 素材

全部为 Godot `draw_*` 几何占位物与功能代号，无任何《熊出没》/PVZ 或未知授权素材。
