# pvz-boonie-bears

《植物大战僵尸》式路线塔防 × 《熊出没》多世界剧情同人项目。

## 当前定位

核心方向：

- PVZ 式路线塔防
- 《熊出没》动画世界/时期推进
- 角色同类合成升级
- 指定跨角色融合
- 人物关系与羁绊解锁
- 每个世界独有玩法机制
- Q 版夸张搞笑演出

当前阶段：**产品定义 + 研究 + 技术 PoC 准备**。

暂不进行大规模正式开发。

## 文档

- `AGENTS.md`：Agent 分工与工作规则
- `docs/product.md`：产品定义与核心玩法
- `docs/architecture.md`：初始架构边界
- `docs/decisions.md`：已接受决定
- `docs/project-plan.md`：项目计划与任务分配
- `docs/research/`：研究资料与独立报告

## 第一阶段目标

完成一个可完整游玩的 World 01 Vertical Slice：

- 10 关
- 8 名可用角色
- 6 种敌人
- 1 Boss
- 同角色升级
- 少量跨角色融合
- 1 种以上世界机制
- 基础剧情与完整 UI 流程

> 当前仓库为 Private。第三方代码、素材、字体、音乐和音效在进入正式项目之前必须单独核验来源与授权。

## P1 灰盒 PoC

`project.godot` 是一次性技术/玩法验证，不代表 Godot 已成为正式技术栈。它只包含几何占位物、功能代号、5 路参数化棋盘、部署/升级/融合、基础敌人、路线保险与保护目标。

Windows：安装 Godot 4.7.2 后运行 `scripts\start-graybox.cmd -GodotBin "C:\path\to\Godot_v4.7.2-stable_win64.exe"`。

自动测试：运行 `scripts\run-tests.cmd -GodotBin "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"`。

完整说明、实测证据、GUT/GdUnit4 对照、建议与已知问题见 `docs/poc/p1-graybox-results.md`；第三方清单见 `THIRD_PARTY_NOTICES.md`。
