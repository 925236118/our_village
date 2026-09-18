# our_village

群友一起搭的一个小村子。每个人交一间屋子、一个角色、几句台词，
所有人做的场景拼在一起，就是一个能走进去逛的村庄。

- **想参加** → 读 [`SPEC.md`](SPEC.md)，那是唯一的规范
- **交之前自查** → 用 [`AI_CHECK.md`](AI_CHECK.md) 里的那段话让 AI 帮你查
- **想看范例** → [`entries/_example/`](entries/_example)

---

## 五分钟上手

**你需要**：Godot **4.7**（其它版本可能打不开）、Git、室内素材包（群文件里拿）。

```bash
git clone <仓库地址>
cd our_village
```

**先把素材包放好**：把室内素材包解压到仓库根目录的 `assets_indoor/`。
这个目录是 gitignore 掉的，不会进仓库 ——
素材的授权不允许再分发，所以每个人本地放一份就行。

```
our_village/
└── assets_indoor/          ← 你自己解压进来，不进 git
	└── (素材包的 png)
```

用 Godot 打开这个文件夹，然后按 <kbd>F5</kbd>。
你应该会看到一个房间里有个角色在走来走去 —— 那就是范例 `entries/_example/`。
（范例用的是纯色块，没有素材也能跑。）

### 开始做你自己的

1. **复制范例**：把 `entries/_example/` 整个复制一份，
   改名成你的目录名（只能用小写字母、数字、`_`、`-`，比如 `entries/alan/`）
2. **改 `meta.json`**：填上你的角色名和昵称
3. **换角色图集**：用角色生成器导出 `sheet.png`，
   尺寸必须正好 **2688×1920**，覆盖掉 `char/sheet.png`
   （生成器如果有「裁剪 / trim」选项，**关掉**）
4. **改台词**：编辑 `dialogue.json`，照着范例的格式加几句
   （注意引号要是英文的 `"`，从微信、Word 里复制来的弯引号 `“ ”` 会让文件读不了）
5. **搭场景**：打开你的 `entry.tscn`，用室内素材铺地面和家具
6. **铺导航**：在 `NavLayer` 上，把角色能走的地面刷满格子
7. **摆角色和出口**：把 `shared/npc/npc.tscn` 和
   `shared/scene_portal/exit_portal.tscn` 拖进场景，在检查器里填好
8. 按 <kbd>F5</kbd> 试跑，满意了就提 PR

> 每一步的硬性要求都在 [`SPEC.md`](SPEC.md) 里，条款编号 H-1 ~ H-18。
> 被退回时会直接告诉你违反了哪一条。

---

## 操作键位

| 按键 | 作用 |
| --- | --- |
| <kbd>W</kbd><kbd>A</kbd><kbd>S</kbd><kbd>D</kbd> / 方向键 | 走路 |
| <kbd>E</kbd> / <kbd>Enter</kbd> | 跟身边的角色说话；说着的时候再按一次收起 |

---

## 仓库里都有什么

```
entries/            每个人一个文件夹，你的作品放这儿
  _example/         范例，照着抄就行（别改它）
  your_name/        你的
shared/             共享代码，不要改
  character/        角色图集的规格和逐帧播放器
  npc/              角色壳子 npc.tscn —— 拖进场景填两个属性就能用
  player/           共享玩家，引擎自动生成，你不用管
  scene_portal/     出口 exit_portal.tscn —— 走进去就切场景
  dialogue/         对话表解析 + 对话框 UI
  tileset/          导航瓦片集 nav_tileset.tres
  autoload/         GameShell：生成玩家、转发对话
tools/              主办方的脚本，你一般用不到
```

**你只需要动 `entries/<你的目录>/`，别的都别碰。** 详见 SPEC.md 的 H-2。

---

## 几个概念

**角色是 NPC，不是你自己操作的。**
你摆几个 `Marker2D` 当巡逻点，它会自己寻路走过去、停一会儿、再走下一个。
玩家走近按 <kbd>E</kbd> 就能跟它说话。

**对话按游戏内时间切换。**
`dialogue.json` 的 `start`/`end` 是时段，到了那个点只会说那个点该说的话。
有多个候选时按 `weight` 随机抽。

录屏或评审时想固定时间，改 `shared/autoload/game_shell.gd` 上的
`time_override`（比如填 `"22:30"`），留空就是用系统真实时间。

**导航瓦片是半透明的青色格子。**
刷在 `NavLayer` 上，编辑器里看得见方便你对齐，
游戏里会被地板盖住 —— 只要把 `NavLayer` 排在场景树最前面。

---

## 遇到问题

**角色站着不动**
`NavLayer` 上没刷格子，或者刷的范围没盖住它和巡逻点。
按 <kbd>F5</kbd> 跑起来，在「调试 / Debug」菜单里打开
「可见导航 / Visible Navigation」，看绿色网格盖到哪了。

**玩家出现在 (0,0)，或者一进去就被弹走**
`EntryPoint` 忘了加 `entry_point` 节点组，或者出口摆在了出生点上。

**`dialogue.json` 读不了 / 角色不说话**
多半是 JSON 写坏了。看输出窗口里的 `[对话]` 报错，它会告诉你是第几行、第几条。
最常见的两个原因：引号是从别处复制来的弯引号 `“ ”`，或者最后一项后面多了一个逗号。

**地上露出一片青色的格子**
`NavLayer` 在场景树里排太靠后了，把它拖到所有地板节点的前面。

**图集报错说尺寸不对**
生成器导出时把透明边裁掉了。关掉裁剪选项重新导出，
尺寸必须正好 2688×1920。

自查时先跑一遍：

```bash
python tools/inspect_sheet.py entries/你的目录/char/sheet.png
```

---

## 素材出处

室内家具素材来自 **LimeZu**（<https://limezu.itch.io>），授权不允许再分发。

**本仓库是私有的，请不要把素材或仓库内容转发给参加者以外的人。**
