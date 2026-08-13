# 资源占位说明

本目录用来放游戏素材，目前都是占位文件，等拿到正式图标/元素后按下面方式替换即可。

## 目录结构

```
assets/
├── icons/          # 图标（节气图标、操作按钮图标等）
│   ├── season_placeholder.svg    # 顶部节气图标占位
│   └── action_placeholder.svg    # 操作图标占位（当前未接线）
├── ui/             # UI 背景、面板、按钮底图等（建议新增）
├── fonts/          # 字体（建议新增）
└── audio/          # 音频（建议新增）
```

## 替换方式

1. **直接覆盖**：把正式图标保存为同名文件覆盖即可（如 `season_placeholder.svg` 换成真图，PNG/SVG 均可）。
2. **换成新文件**：如果换了文件名，需要同步修改引用它的场景：
   - `res://scenes/HUD.tscn` 里的 `[ext_resource type="Texture2D" path="res://assets/icons/season_placeholder.svg"]`。
3. 改完后在 Godot 编辑器里重新打开项目，会自动重新导入资源。

## 字体注意

当前 UI 中的中文文本依赖 Godot 4 默认字体的系统回退显示。若在目标机器上中文显示为方框/问号，
请在 `assets/fonts/` 放置一个支持中文的字体（如 Noto Sans CJK、思源黑体），然后：
`项目设置 → GUI → 主题 → 自定义字体` 设置为该字体，或在场景根节点挂一个 Theme 覆盖默认字体。

## 已占位的功能点

- 主菜单：开始 / 设置 / 退出（设置仅打印日志）
- HUD：节气名、日期、资源计数（`scripts/hud.gd` 提供 `advance_season()` / `add_resource()` 接口）
- 游戏主区域：纯占位文字
- 底部操作栏：播种 / 收获 / 建造 / 图鉴（点击仅打印日志 + 演示刷新 HUD）
