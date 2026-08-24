# P2｜Playable Prototype 实施记录

日期：2026-08-24

状态：等待 GitHub PR / Windows CI 最终验收。

正式 P2 将 P1 临时 `src/core` 拆分为 data / grid / units / enemies / fusion / resources / world_rules / battle / ui 等职责。单位、敌人、配方和关卡分别由 JSON 提供，战斗核心不直接依赖正式美术或剧情。

P2 暂用 JSON：文本可 diff、AI/人工易审查；缺点是缺少 Godot Resource 编辑器类型提示。数据入口集中在 `GameDataRepository`，以后迁移 Resource 不需要重写 Battle Core；这不是存档格式决定。

`PointerRouter` 把鼠标与触屏统一成 down/move/up 事件，Battle Core 不读取输入设备。当前 UI 以 1280×720 横屏为验证基准。

H1 已建立职责目录、数据加载、正式主场景和脚本入口。H2 实现 5 路/可变列数、2 友方、2 敌人、单资源、拖拽、攻击/承伤、波次、路线保险、胜负与保护目标。H3 实现三级同角色升级和一组固定跨角色融合；合成继承较差生命比例与较长冷却，不免费刷新；结果可预览。H0 Windows/GUT 结果由 PR 的 `P2 Windows Godot + GUT` workflow 记录。

已知问题：仍是几何占位原型；触屏只验证输入路由代码/测试，尚未做 Android 真机导出；波次/数值不是最终平衡；撤销只保留收据/窗口字段，未实现恢复；JSON 不代表正式存档格式；UI 仍为开发型横屏界面。
