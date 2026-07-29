# AGENTS.md — 金貔貅 EA 项目上下文

> 本文件供 Codex / Claude / Qoder 等 AI 编程助手快速理解项目背景。
> 最后更新：2026-07-29，对应版本 青鸾 V1.58（EA 主程序）/ jpx_auth_pay_dashboard（PHP 后台 + 盈亏大屏）。

---

## 1. 项目定位

**青鸾 EA**（原金貔貅）是一个运行在 MetaTrader 5 平台、基于 MQL5 开发的自动交易程序。

- **专属交易品种**：`XAUUSDc`（黄金美分账户），不再支持 EURUSD/EURUSDc 等外汇品种
- **策略类型**：马丁格尔 + 网格 + 对冲 + 多重风控（日亏锁定 / 对冲止盈 / 快速熔断）
- **目标账户**：杠杆 2000 倍的小额美分账户
- **多实例并行**：支持单机同时挂载 20 个 MT5 客户端运行同一 EA，需通过参数随机偏移避免共振爆仓

**配套系统：**
1. **MT5 EA 主程序**（MQL5）：青鸾V1.58.mq5
2. **授权工具**（Python + Tkinter，PyInstaller 打包为 EXE）：金貔貅授权工具.exe
3. **PHP 后台**（PHP + MySQL）：授权码生成、管理后台

**独立实验版：**
- `稳貔貅-EUR_V1.00.mq5`：用户指定新增的 EURUSDc 轻网格 EA，不属于金貔貅黄金主线；采用 H1 趋势过滤 + M15 回撤入场 + ATR 动态间距 + ADX 过热过滤 + 严格限层/硬止损。

---

## 2. 项目目录结构

```
c:\Users\Administrator\Desktop\源码\           # 项目根目录
├── 金貔貅V{版本号}.mq5                        # EA 主源码（如 金貔貅V1.19.mq5）
├── 稳貔貅-EUR_V{版本号}.mq5                    # EURUSDc 独立实验版
├── 金貔貅V{版本号}.ex5                        # 编译产物
├── 金貔貅V{版本号}.log                        # 编译日志
├── 金貔貅授权工具.py                           # 授权工具源码
├── 金貔貅授权工具.exe                          # 授权工具打包产物
├── 金貔貅参数.set                              # MT5 策略测试器参数文件
├── LOGO.bmp / 背景.bmp                         # EA 面板资源（编译时必须在同目录）
├── LOGO.ico                                    # 授权工具图标
├── 参数说明.txt / 金貔貅EA介绍.txt              # 文档
├── 程序界面.jpg / 背景.bmp                     # 资源图
└── build/                                      # PHP 后台
    ├── install.php                            # 数据库初始化
    ├── login.php / admin.php                  # 后台管理
    ├── schema.sql                             # 数据库脚本
    ├── includes/{config,db,auth}.php          # 通用模块
    └── api/{generate,list,delete,change_password}.php
```

**命名规范：**
- 本地授权标准版：`金貔貅V{版本号}.mq5`（如 `金貔貅V1.25.mq5`），继续使用本地授权码，不改远程授权
- 远程授权版：`金貔貅V{版本号}-远程授权.mq5`（如 `金貔貅V1.25-远程授权.mq5`），通过 HTTP API 到后台验证交易账号授权状态
- V1.25 起保留两个并行版本；今后策略逻辑、风控逻辑、面板逻辑升级时，必须同步到两个版本，授权层差异单独维护
- 历史品种适配版（已废弃）：`金貔貅V{版本号}-{品种}.mq5`

---

## 3. 技术栈

| 模块 | 技术 |
|------|------|
| EA 主程序 | MQL5 / MetaTrader 5 |
| 授权工具 | Python 3 + Tkinter，PyInstaller `--onefile` 打包 |
| 后台 | PHP + MySQL（早期 Python 版已弃用）|
| 版本控制 | Git，远程：https://github.com/guanzhiyuan80-cpu/ea.git |

---

## 4. EA 核心机制

### 4.1 入场评分系统

EA 综合评分由 **EMA 评分 + SMC 评分** 构成，阈值默认 30 分：

- **EMA 评分（四档分级，0/10/20/30）**：
  - 🟢 **强（30）**：收盘 > 快线 且 |收盘−慢线| ≥ 0.5×ATR
  - 🟡 **中（20）**：收盘 > 快线 但距慢线 < 0.5×ATR
  - 🔵 **弱（10）**：收盘在快慢线之间
  - ⚪ **无（0）**：反向或交叉混乱
- **SMC 评分**：6 项原始分加总后归一化至 [0,30]
- **综合策略**：净分入场（强方 - 弱方 ≥ 阈值且强方严格大于弱方）

### 4.2 马丁格尔加仓

- **加仓间距**：基于 ATR 动态计算，由 `InpMartATRSpacingCoeff` 控制
  - V1.45 默认：基础间距 200 点、每层递增 30 点、ATR 系数 0.03
  - 阶梯倍率：1~5 层 1.0，6~10 层 1.1，11~15 层 1.3，16 层以上 1.6
  - 最大层数默认 25；受 `InpMartMaxTotalLots=10.0` 总手数上限共同约束
- **顶栏按钮**：稳/中/快三档支持运行时动态切换
- **TP 计算（线性公式）**：
  ```
  动态TP = g_effBasketTP + (层数-1) × InpMartBasketTPPerLayer
  ```
  - `g_effBasketTP` 受账户偏移因子影响（±25%）
  - `InpMartBasketTPPerLayer`（默认 8 美分）**不受偏移影响**
  - 多账号 TP 曲线为同斜率不同截距的平行线
- **每层 TP 增量随机化**：±25%，下限保护 50%（避免增量趋零）
- **V1.44 固定 TP 参数**：`InpMartBasketTP_USD=3.0`、`InpMartBasketTPPerLayer=8.0` 改为源码内部固定值，不再作为 MT5 输入参数暴露，避免旧 `.set` 覆盖浅层 TP。
- **V1.49 固定止盈止损细节**：深层守护 TP、硬止损恢复、追踪止损、平仓后新篮子冷却均改为源码内部固定值，不再作为 MT5 输入参数暴露；平仓后新篮子冷却固定为 60 秒。
- **深层守护 TP（V1.22）**：在动态 TP 计算出口统一乘守护系数，不做部分平仓：
  - 1~5 层：100%
  - 6~9 层：85%
  - 10~15 层：70%
  - 16 层以上：55%
  - 最低目标 `InpDeepTPMinProfit` 默认 30 美分，仅在 6 层以上进入守护系数后生效，1~5 层不抬高 TP

### 4.3 对冲机制

**V1.22 重构**：原 `InpEnableHedge`(总开关) + `InpUseHedgeLadder`(算法选择) 两个 bool 合并为单一枚举 `InpHedgeMode`：
- `HEDGE_MODE_OFF`：完全关闭对冲（默认值，保持兼容）
- `HEDGE_MODE_FIXED`：固定比例（仅按绝对浮亏美分触发）
- `HEDGE_MODE_LADDER`：浮亏阶梯对冲（推荐）

**固定模式触发方式（HEDGE_MODE_FIXED 时生效）：**
- V1.47 起删除权益百分比触发方式，只保留绝对浮亏美分触发。
- `InpHedgeAbsoluteUSD` 默认 10000 美分（$100）触发固定比例对冲。
- 注意：变量名 `InpHedgeAbsoluteUSD` 但单位实际是账户本币（美分账户即美分）

**浮亏阶梯对冲（HEDGE_MODE_LADDER 时生效）：**
- 浮亏 2000 美分：目标对冲比例 0.55
- 浮亏 3000 美分：目标对冲比例 0.65
- 浮亏 4500 美分：目标对冲比例 0.75
- 阶梯比例为目标总对冲比例，只补足差额，不重复叠加。
- V1.43 新增对冲恢复机制：从对冲激活后的最大马丁浮亏回收 30% 时，自动减掉当前对冲手数的 30%，但减仓后至少保留 0.35 对冲比例。
- V1.43 新增小仓修复：对冲激活后，若浮亏已回收 20% 且 ATR 短/长恢复到 `InpATRAddResumeRatio` 以下，允许最多 2 次 0.01 手同向修复单；修复单不是马丁倍数加仓。

**对冲比例风险分级：**
| 比例 | 性质 | 推荐 |
|------|------|------|
| 0.6 | 最保守，保护弱但 V 反收益高 | 可用 |
| **0.7** | 均衡甜点 | ✅ 默认 |
| 0.8 | 偏锁仓 | 中等趋势可用 |
| 1.0 | 完全锁死 → 死锁陷阱 | ❌ 不推荐 |
| 1.2 | 反向追势赌博 | ❌ 严禁 |

**对冲激活后**：
- 停止普通马丁加层（防止敞口放大），仅允许 V1.43 的受限小仓修复单
- 追踪止损被禁用（由 HedgeRelease 接管）
- 解锁阈值 `InpHedgeReleaseFixed` 默认 200 美分（建议黄金调到 300~500）

**跨日行为**：
- ResetDailyState 仅重置日级统计，不平对冲单
- 若新日亏损达到 `InpMaxDailyLossPercent`（默认 40%），CloseAllMartPositions 一并平掉对冲单

**面板盈亏口径（V1.23）**：
- `总浮盈` / TP进度 / 当前浮亏 / 日回撤：使用马丁+对冲的有效浮盈（`GetEffectivePnL` 口径）
- `马丁`：仅统计马丁篮子浮盈（`g_cachedMartPnl`）
- `对冲`：仅统计对冲单浮盈（`g_hedgePnl`），禁止在总浮盈中重复相加

**轮转锁仓篮子（V1.42 已删除）**：
- 2026-07-28 按实盘反馈删除整套轮转功能，不再暴露 `InpEnableBasketRotation` / `InpRotate*` 参数，不再切换多 Magic 篮子，也不再显示轮转面板。
- 原因：20 多个实盘账号一个月内长期保持 8 个以上轮转篮子，资金效率低、旧篮子长期占用保证金，并且容易被隔夜费/成本拖累。
- V1.42 起主保护改为单 Magic 单篮子：阶梯对冲 + ATR 扩张暂停加仓 + 快速熔断小亏脱身。遇到强单边时优先停止扩大敞口，而不是继续换篮子。

**价格距离阶梯对冲设计（已暂缓）**：
- 曾讨论按价格距离触发 0.9/1.1/1.3/1.5 倍对冲，但因高比例容易锁死并拖慢解套，V1.43 暂不实现。
- 当前采用浮亏阶梯 0.55/0.65/0.75 + 部分减对冲 + 小仓修复的恢复型方案。

### 4.4 快速熔断（Fast Loss Breaker）

**默认状态**：V1.47 起 `InpEnableFastLoss=true` 默认开启。

**触发条件**：单位时间内价格向不利方向变动达阈值
- `InpFastLossDistance`：单位**美分**，800 = $8 反向价幅
- `InpFastLossTime`：300 秒（5 分钟）窗口
- `InpFastLossRecoveryDistance`：500 美分，熔断后从极端点反弹/回落达到该距离即可解锁

**触发后行为**：
- **仅锁定新开仓与加层**，保留已有仓位等回调（不全平）
- 锁定期间继续运行：止盈、追踪、硬止损、对冲管理
- 解锁条件：价格回到最后一层加仓价，或熔断后从最不利极值点回撤达到 `InpFastLossRecoveryDistance`
- 小亏脱身：若通过极值回撤解锁且总浮亏不超过 `InpFastLossExitMaxLoss`（默认 300 美分），则直接全平篮子并解除熔断
- 守卫逻辑：篮子全平时（`g_martDirection == NONE`）自动解锁

**与对冲机制独立**：两者触发条件不同，可叠加发生

### 4.5 ATR扩张暂停加仓（V1.21）

- 复用马丁加仓间距 ATR 句柄：短 ATR=3，长 ATR=6
- `ATR短 / ATR长 >= 1.5`：暂停加仓
- `ATR短 / ATR长 <= 1.25`：恢复加仓
- 只影响 `TryMartAddLayer()`，不影响熔断、止盈、止损、追踪、对冲。

### 4.6 新闻过滤（V1.22）

- `InpEnableNewsFilter=true` 默认启用自动新闻过滤。
- 自动窗口：
  - 周四 20:30 数据窗口（默认 20:20~21:10）
  - 每月第一个周五 20:30 非农窗口（默认 20:20~21:10）
- `InpAutoUsDstNewsTime=true` 自动按美国夏/冬令时换算美国 08:30 数据：夏令时北京时间 20:30，冬令时北京时间 21:30；关闭后用 `InpNewsDataHour/InpNewsDataMinute` 手动覆盖。
- `InpUseManualNewsBlock` 保留为自定义新闻窗口，支持小时+分钟；FOMC 等非固定日期事件用自定义窗口处理。
- 新闻过滤触发后**只锁新开仓和马丁加层，不强平**；已有持仓继续执行 TP、硬止损、追踪、对冲管理。

### 4.7 风控分支统一性（重要！）

OnTick 中以下三个提前 return 分支**必须**完整调用对冲管理三件套：
1. 快速熔断锁定分支
2. 非交易时段分支
3. 手动暂停分支

```cpp
RefreshHedgeState();      // 刷新对冲 PnL（否则 GetEffectivePnL 失真）
ManageHedgeLock();        // 允许对冲激活/追加
ManageHedgeRelease();     // 对冲止盈
```

### 4.8 日截止时间（V1.20 已统一）

**统一为北京时间 00:00**：
- 日盈亏统计区间：北京 00:00:00 ~ 当前
- 日状态重置（ResetDailyState）：按北京时间日键
- 历史明细 CSV 日期归属：按北京时间（V1.19 修复）

实现方式：通过 `GetChinaNow()` 函数（自动模式基于 `TimeGMT() + InpChinaUtcOffsetHours*3600`；手动模式为 `TimeCurrent() - InpServerUtcOffsetHours*3600 + InpChinaUtcOffsetHours*3600`）

### 4.9 首单防追 / 精确过滤

- `InpUseEntryChaseFilter=true` 默认启用，仅影响首单，不影响已有篮子加层。
- `InpEntryMaxDistSlowEMA_ATR=3.0`：上一根入场周期 K 线收盘价距离慢 EMA 超过 3 倍 ATR 时不追。
- `InpEntryMaxPrevBody_ATR=3.0`：上一根入场周期 K 线实体超过 3 倍 ATR 时不追。
- V1.41 固定为单一入场模式：EMA 分级 + H4 方向 + 首单精确过滤。SMC 不再作为参数、面板或入场计算的一部分。
- V1.49 起入场信号整组写死并从 MT5 参数页隐藏：`InpMartEntryTF=PERIOD_M5`、EMA `13/34`、`InpMartH4FilterMode=H4_FILTER_2K`、全天交易、首单防追开启、精确过滤 RSI 周期 `PERIOD_M5/14`、RSI 买入上限 52 / 卖出下限 48、距慢 EMA `0.20~1.80 ATR`、实体下限 `0.30 ATR` 且要求实体同向。
- V1.40 新增 `InpUseEntryPrecisionFilter=true`：首单下单前叠加 RSI / 回撤位置 / K 线实体确认。
- 默认精确过滤：
  - `InpEntryPrecisionRSITF=PERIOD_M5`，`InpEntryPrecisionRSIPeriod=14`
  - 做多要求 `RSI < 52`，做空要求 `RSI > 48`，避免追高追低。
  - 距慢 EMA 需在 `0.20~1.80 ATR` 之间：太贴近视为动能不足，太远视为位置过热。
  - 上根 K 线实体至少 `0.30 ATR`，且默认要求实体方向与开仓方向一致。
- V1.46 面板改为紧凑诊断：摘要行显示 `入场:等待/通过 | EMA多/空 当前分/达标分 | H4 | 层数/距离`；新增条件行显示 `未建仓原因 + EMA/H4 达标情况`，新增精确过滤行显示 `RSI 当前值/买卖阈值、距慢EMA当前值/上下限、实体当前值/下限`。
- 对冲关闭时面板只显示 `对冲: 已关闭（不会自动开对冲）`，不再显示固定比例、权益百分比、绝对金额等未生效参数。

### 4.10 多账户参数随机偏移（防共振）

`ApplyAccountOffsets()` 对以下参数注入稳定随机偏移。V1.25 已升级为 64 位混合种子，混合账户、Magic、ChartID、品种和 salt，避免相邻账号偏移聚集：
- `g_effATRCoeff`：±30%
- `g_effBasketTP`：±25%
- `g_effBaseSpacing`：±45%
- `g_effIncSpacing`：每层递增加仓间距 ±35%
- `EMA Fast` 周期：黄金场景 ±28%
- `EMA Slow` 周期：黄金场景 ±22%
- `g_effEmaStrongAtrMult`：EMA 强信号距离慢线阈值约 0.30~0.70 ATR
- `InpSMCScoreThreshold`：不做账号偏移，保持 10/20/30 EMA 分档的阈值稳定性

---

## 5. 关键参数（XAUUSDc 推荐值）

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `InpMartATRSpacingCoeff` | 0.15~0.20 | 5位精度推荐 0.20，6位精度 0.30 |
| `InpMartBasketTPPerLayer` | 8 美分 | 每层 TP 增量基础值 |
| `InpEnableNewsFilter` | true | 新闻过滤：锁新开仓/加层，不强平 |
| `InpAutoUsDstNewsTime` | true | 自动按美国夏/冬令时换算 08:30 数据 |
| `InpNewsDataHour/Minute` | 20 / 30 | 手动模式下美国 08:30 数据对应北京时间 |
| `InpNewsBlockPreMinutes/PostMinutes` | 10 / 40 | 新闻前后禁开分钟 |
| `InpEnableDeepProtectTP` | true | 深层守护 TP |
| `InpDeepTPLevel1/2/3Start` | 6 / 10 / 16 | 守护 TP 起始层 |
| `InpDeepTPLevel1/2/3Factor` | 0.85 / 0.70 / 0.55 | 守护 TP 系数 |
| `InpDeepTPMinProfit` | 30 美分 | 守护 TP 最低目标 |
| `InpHedgeMode` | HEDGE_MODE_OFF | 对冲模式（OFF/FIXED/LADDER），V1.22 新增 |
| `InpHedgeRatio` | 0.5 | [固定模式]对冲手数比例 |
| `InpHedgeLadderLoss1/2/3` | 2000 / 3000 / 4500 | 阶梯对冲浮亏阈值（美分） |
| `InpHedgeLadderRatio1/2/3` | 0.55 / 0.65 / 0.75 | 阶梯目标对冲比例 |
| `InpHedgeAbsoluteUSD` | 10000 美分 | 对冲触发浮亏（黄金建议 5000）|
| `InpHedgeReleaseFixed` | 200 美分 | 对冲解锁阈值（黄金建议 300~500）|
| `InpEnableFastLoss` | true | 启用快速亏损紧急停止 |
| `InpFastLossDistance` | 800 美分 | 5min 内反向 $8 |
| `InpFastLossTime` | 300 秒 | 熔断窗口 |
| `InpFastLossRecoveryDistance` | 500 美分 | 熔断后极值回撤解锁 |
| `InpFastLossExitMaxLoss` | 300 美分 | 回撤解锁时小亏以内全平，0=关闭 |
| `InpMaxDailyLossPercent` | 40.0 | 日亏锁定阈值 |
| `InpChinaUtcOffsetHours` | 8 | 北京时区 |
| `InpAutoServerUtcOffset` | true | 自动检测服务器时区 |

**美分账户单位约定**：所有以"美元"命名的金额参数（如 `*_USD`）实际单位为账户本币，美分账户下即美分（1 美元 = 100 美分）。

---

## 6. 编译流程

**MetaEditor 命令行编译**（PowerShell）：
```powershell
& "C:\Program Files\MetaTrader 5\MetaEditor64.exe" `
  /compile:"c:\Users\Administrator\Desktop\源码\金貔貅V1.25.mq5" `
  /log:"c:\Users\Administrator\Desktop\源码\金貔貅V1.25.log"
```

**远程授权版编译**：
```powershell
& "C:\Program Files\MetaTrader 5\MetaEditor64.exe" `
  /compile:"c:\Users\Administrator\Desktop\源码\金貔貅V1.25-远程授权.mq5" `
  /log:"c:\Users\Administrator\Desktop\源码\金貔貅V1.25-远程授权.log"
```

**注意事项**：
- ❌ 不要使用 `/portable` 参数（会禁用 AppData Include 查找）
- ❌ 不要使用 `/include` 参数（需精确匹配终端 ID 目录）
- ✅ 让 MetaEditor 自动识别默认终端的 `MQL5\Include`
- ✅ 编译前确保 `LOGO.bmp` 和 `背景.bmp` 与 `.mq5` 同目录
- ✅ 命令完成后需 `Start-Sleep 3` 等待 ex5 异步生成
- ✅ 远程授权版需要在 MT5 的“工具 → 选项 → EA交易”中允许 `InpRemoteAuthUrl` 所在域名，否则 `WebRequest` 会失败

---

## 7. Git 工作流

**用户行为规范**：每次代码修改后自动提交，无需询问确认。

```powershell
cd "c:\Users\Administrator\Desktop\源码"
git add "金貔貅V{版本号}.mq5" "金貔貅V{版本号}.ex5" "金貔貅V{版本号}.log"
git commit -m "release: V{版本号} {描述}"
git push
```

**Commit 信息约定**：
- `release: V{版本号} {核心改动}` — 版本发布
- `fix(EA): {模块} {问题}` — Bug 修复
- `feat(EA): {功能}` — 新功能

**已知 Git 陷阱**：
- Windows 凭据缓存：切换仓库时需 `cmdkey /delete:git:https://github.com` 清除
- 远程地址变更：`guanzhiyuan4986-star` 已废弃 → `guanzhiyuan80-cpu`
- 网络超时：直连 GitHub 失败时考虑代理 / SSH / Gitee 镜像

---

## 8. 版本发布流程（标准化技能）

1. **复制源码**：`Copy-Item 金貔貅V{old}.mq5 金貔貅V{new}.mq5`
2. **修改版本号**：
   - `#property version "{new}"`
   - 面板标题 `ObjectSetString(0, OBJ_HEADER, OBJPROP_TEXT, "金貔貅 v{new}");`
3. **同步远程授权版**：同步策略逻辑到 `金貔貅V{new}-远程授权.mq5`，仅保留授权层差异
4. **编译验证**：本地授权版和远程授权版都用 MetaEditor 命令行编译，确保 0 errors
5. **Git 提交**：add + commit + push 三件套

---

## 9. 已知陷阱（Pitfalls）

| 问题 | 解决方案 |
|------|----------|
| MT5 OBJ_LABEL 文本超 63 字符被静默截断 | 拆分多个 Label 显示 |
| XAUUSDc 5位/6位报价精度差 10 倍 | spacing 参数需按 _Point 校准 |
| 多实例 EMA 不偏移 → 同向爆仓 | 必须启用 ApplyAccountOffsets |
| 对冲激活后追踪止损未禁用 → 与 HedgeRelease 冲突 | 已修复：`if(g_hedgeActive) return;` |
| 锁定分支提前 return → 状态变量陈旧 | 必须在分支内显式重置 g_martDirection |
| 美分/美元单位混淆 | 以 UI 标签为准（如"亏损多少美分触发"）|
| Tkinter `state=tk.READONLY` 在部分版本未定义 | 改用字符串 `"readonly"` |
| 后台报错 `Table 'ea.admins' doesn't exist` | 必须先访问 install.php 或修改 schema.sql 库名 |

---

## 10. 编程规范

### MQL5 代码规范
- 枚举显示名使用中文注释定义：`enum X { A,/*固定阈值*/ B,/*动态(按层数)*/ };`
- 全局变量命名前缀 `g_`，输入参数前缀 `Inp`
- 美分账户下 TP/SL 参数单位统一为美分

### 业务规范
- **非交易时段**：禁开新仓，但必须执行止盈/止损/追踪等持仓风控
- **供需区检测**：需求区用 Ask 判定，供给区用 Bid 判定
- **对冲激活**：必须停止马丁加层
- **跨日**：快速熔断状态不清，对冲不强平

---

## 11. 已废弃的内容（不要再实现）

- ❌ EURUSD / EURUSDc 等外汇品种适配
- 例外：`稳貔貅-EUR_V1.00.mq5` 是用户明确要求的新独立 EA，不是金貔貅黄金主线适配版
- ❌ 金貔貅-EUR_V1.00.mq5、金貔貅-EURUSD参数.set、金貔貅V1.01-EURUSD.mq5 等历史文件
- ❌ Python 版后台（已迁移到 PHP+MySQL）
- ❌ 1.0 完全锁仓对冲比例（死锁陷阱）
- ❌ 1.2 反向追势对冲比例（双向亏损）

---

## 12. 待办与未来方向

1. **阶梯对冲落地**（按价格距离触发，方案已设计未实现）
2. **反趋势网格策略分支**（独立 EA，等手数加仓 + 严格止损）
3. **入场过滤增强**：ADX > 25 禁开、Volume Profile POC 距离过滤
4. **Python 回测脚本**：跨黄金 6 个月历史数据验证策略期望值

---

## 13. 重要决策记录

| 决策 | 内容 |
|------|------|
| 品种聚焦 | 仅 XAUUSDc，放弃外汇 |
| 阶梯对冲触发依据 | 价格距离 > 浮亏美分（避免对冲压缩浮亏增长） |
| 对冲激活后加仓 | 完全停止（A 方案，推荐） |
| 多因子评分主导 | EMA 分级（0/10/20/30），SMC 仅做过滤 |
| 信号融合 | 净分入场（强 - 弱 ≥ 阈值） |
| 快速熔断 | 锁开仓不平仓（保留持仓等回调） |
| 解锁基准 | 最后一层加仓价（不是窗口峰价） |
| 美分账户 TP 单位 | 美分（不要按美元放大） |

---

## 14. PHP 后台 / Web 大屏（jpx_auth_pay_dashboard）

> EA 主程序之外的另一条主线：管理后台、盈亏大屏、续费支付。
> 与 `build/` 下的早期最简后台**不是同一套**，请勿混淆。

### 14.1 项目位置与部署

| 项目 | 值 |
|------|----|
| 本地源码 | `c:\Users\Administrator\Desktop\源码\jpx_auth_pay_dashboard\` |
| 生产域名 | `https://ea.newqidian365.com` |
| 生产服务器 | `root@121.41.12.87` |
| 生产部署目录 | `/www/wwwroot/ea.newqidian365.com/` |
| 数据库 | **`jpqea`**（不是 `schema.sql` 字面值 `jpx_auth_pay_dashboard`）|
| DB 账号 | `jpqea` / `k8fATCMWYHLzCADS` |
| MySQL 时区 | `+08:00`（北京时间，`CURDATE()` 即北京今天）|

**部署方式**：scp 推送修改后的文件到对应目录（无 CI），如：

```powershell
scp jpx_auth_pay_dashboard\admin\xxx.php `
    root@121.41.12.87:/www/wwwroot/ea.newqidian365.com/admin/
```

AI 助手不掌握服务器密码，scp 由用户在本机交互式输入。

### 14.2 关键文件清单

```
jpx_auth_pay_dashboard/
├── index.php                      # 游客续费页（微信浏览器有特殊兜底逻辑）
├── admin/
│   ├── accounts.php               # 账号管理（8列表格，账号字段只读）
│   ├── dashboard.php              # 盈亏大屏（60s自动刷新 + 多图表）
│   ├── orders.php                 # 续费支付记录列表（2026-05-24 新增）
│   ├── login.php / logout.php
├── api/
│   ├── admin_update_account.php   # 账号编辑接口（仅允许改 customer_name + admin_note）
│   ├── wxpay_notify.php           # 微信支付回调
│   └── ...
├── includes/
│   ├── business.php / db.php / auth.php / config.php
├── assets/css/app.css             # 全局样式（带版本号 ?v=YYYYMMDD-N）
└── schema.sql                     # 仅作参考，实际库名 jpqea
```

### 14.3 关键数据表（库 jpqea）

| 表 | 用途 | 关键字段 |
|----|------|----------|
| `accounts` | MT5 账号档案 | `id, account_login, customer_name, admin_note, expires_at, last_heartbeat_at` |
| `trade_reports` | EA 实时上报快照 | `account_login, report_time, realized_profit, floating_profit, equity, balance` |
| `renew_orders` | 续费订单 | `id, account_id, order_no, amount_yuan, months, status, code_url, wx_transaction_id, created_at, paid_at, notify_raw` |

`renew_orders.status` 枚举：`pending` / `paid` / `failed` / `closed`。

### 14.4 大屏（admin/dashboard.php）

- **自动刷新**：`<meta http-equiv="refresh" content="60">`，右上角脉冲徽标 `.refresh-badge` 显示 60s 倒计时
- **时间口径**：北京时间，`CURDATE()` = 北京今天（不要在 PHP 端再转一遍）
- **账户最新快照表**：8 列，含"今日已实现"列（取每账号当日最后一条快照的 `realized_profit`）
- **快照排序**：`usort` 三级 — 当日有上报优先、`today_realized` 降序、`account_login` 次级
- **日期筛选默认值**：`dateFrom = dateTo = 今天`（不要再改回 -30 days，会破坏单日视图）
- **每日趋势图（dailyTrend）**：固定取最近 30 天，**不受筛选 date_from/date_to 影响**
  - PHP 端必须**补全 30 天日期序列**（缺失日补 0），否则单日数据会让 ECharts X 轴退化为单点
- **三个图表**：
  - `#dailyChart` 每日已实现盈亏（柱状）
  - `#floatingChart` 每日浮动盈亏（柱状）
  - `#combinedChart` 每日盈亏曲线（双线对比，已实现绿 + 浮动蓝，带面积填充）
- **CSS 关键修复**：`.dashboard-chart-grid .chart-panel.chart { height: 340px; }`
  - ⚠️ 改回 `auto` 会让容器高度坍缩为 0 → ECharts 不渲染
- **缓存版本号**：每次改 css 同步升 `?v=YYYYMMDD-N`

### 14.5 账号管理（admin/accounts.php + api/admin_update_account.php）

- 账号字段（`account_login`）**双层只读**：
  - 前端：`<input class="edit-account readonly-input" readonly>`，金色 monospace 视觉
  - 后端：`admin_update_account.php` SQL **不更新** `account_login`，仅 `customer_name` + `admin_note`
- 备注：`<input type="text" class="edit-note">`（不再是 textarea，避免行高错乱）
- 操作按钮独立列 `.cell-action`，避免心跳时间和保存按钮挤两行

### 14.6 续费支付记录（admin/orders.php，2026-05-24 新增）

- 4 KPI 卡片：订单总数 / 已支付 / 待支付 / 已收款合计 ¥
- 筛选：关键词（订单号 / 账号 / 用户 / 微信交易号）+ 状态 + 日期范围（默认近 30 天）
- 列表：最多 500 条，按 `created_at DESC`
- 状态徽标颜色：`paid → active 绿`、`pending → warning 金`、其余红
- 中文映射函数 `order_status_label()`：pending→待支付 / paid→已支付 / failed→失败 / closed→已关闭

### 14.7 微信支付现状（重要）

- 当前实现：**NATIVE 扫码**（`trade_type=NATIVE`，返回 `code_url` 生成二维码）
- **微信内置浏览器无法自跳** `weixin://wxpay/bizpayurl` 协议（被微信主动拒绝）
- 兜底方案（`index.php` 已实现）：检测到 UA 含 MicroMessenger 时，显示遮罩 `#wechatGuide`，引导用户右上角 → 在浏览器中打开
- **JSAPI 改造未做**，原因：`wx41723d8ed6ae9877` 是开放平台/小程序 appid，**不能做 JSAPI**
  - JSAPI 硬性前提：①公众号 appid ②JSAPI 支付权限 ③网页授权域名 ④支付授权目录 ⑤公众号 access_token 体系
  - 待用户申请到服务号后再改造

### 14.8 已知坑（Web 后台部分）

| 问题 | 解决方案 |
|------|----------|
| `nslookup` 显示 198.18.0.x 劫持 IP | nslookup 不读 hosts；用 `ping` / `curl.exe` 验证真实 IP |
| PowerShell `curl` 被 `Invoke-WebRequest` 别名劫持 | 显式调用 `curl.exe`，否则 `-sS` `-w '%{http_code}'` 报参数错误 |
| ECharts 容器高度为 0 → 图表空白 | `.chart-panel.chart` 必须显式 `height: 340px` |
| 单日数据让 X 轴退化为 1 个点（柱被边距吃掉） | PHP 端补全完整日期序列，缺失补 0 |
| 微信内 weixin:// 协议无法自跳 | 走"在浏览器中打开"兜底引导 |
| `schema.sql` 库名 `jpx_auth_pay_dashboard` 与生产 `jpqea` 不一致 | 以生产 `jpqea` 为准，不要按 schema.sql 字面执行 |

---

## 15. 变更日志

### 2026-07-29（Web 后台品牌）

**修改**
- EA 授权续费后台和盈亏大屏可见品牌统一从“金貔貅”改为“青鸾”。
- 后台网页 Logo / favicon 改用源码目录 `LOGO.jpg` 同步到 `jpx_auth_pay_dashboard/assets/img/logo.jpg` 与 `favicon.jpg`。
- 后台全局与大屏主色从金色调调整为青鸾青色系，保留盈亏红绿功能色。

### 2026-07-29（EA V1.59）

**修改**
- 收紧快速熔断后的“小亏脱身”：账户浮亏上限从 300 美分降为 150 美分。
- 新增内部固定保护：至少 5 层才允许小亏脱身；若当前价格距离马丁加权均价不超过 200 价格美分（约 $2），不再亏损全平，继续等 TP/追踪。
- 小亏脱身未执行时输出 `FastLoss exit skipped` 日志，便于从 MT5 专家日志判断被哪条保护拦截。

### 2026-06-22（EA V1.37）

**修复**
- 修复篮子风控触发平仓后，同一 tick 继续执行后续加层逻辑的问题。
- `ManageMartBasketTP` / `CheckMartHardSL` / `ManageMartTrailing` / `ManageHedgeRelease` 改为返回是否已触发平仓。
- `OnTick` 在 TP、硬止损、追踪止损、对冲止盈触发平仓后立即返回，避免异步批量平仓期间又开新层。
- 本地授权版与远程授权版同步更新，版本号升至 V1.37 / V1.37R。

### 2026-06-23（EA V1.38）

**新增**
- 轮转首单同向风险限制：`InpRotateMaxSameDirection` 默认 5，同方向仍持有马丁仓位的轮转篮子达到上限时，禁止新篮子继续开同方向首单。
- 轮转同价区间限制：`InpRotateSameDirMinGap` 默认 1500 美分，若已有同方向轮转篮子的马丁加权均价距离当前价格不足阈值，禁止新篮子在同价区继续开同方向首单。

**说明**
- 该限制只作用于轮转新篮子首单，不影响已有篮子加层、平仓、锁仓和风控退出。
- 触发限制时，面板未建仓原因显示`轮转同向限制`或`轮转同价限制`。

### 2026-07-27（EA V1.40）

**新增**
- 首单精确过滤：借鉴恒鑫 v18 的 RSI 过热拦截，并结合金貔貅已有 EMA/ATR 体系，新增 RSI、回撤距离、K 线实体强度、K 线方向四项首单确认。
- 轮转新篮子冷却结束后，同样复核首单精确过滤，避免冷却一结束就追入。

**修改**
- 默认入场模式从 `ENTRY_COMBINED` 调整为 `ENTRY_EMA_ONLY`，SMC 保留为可选辅助和面板展示，不再作为默认核心入场依据。
- 本地授权版与远程授权版同步更新到 V1.40 / V1.40R，远程上报版本号同步为 `1.40R`。

### 2026-07-27（EA V1.41）

**修改**
- 按用户要求移除 SMC 作为可选入场模式，参数页不再展示 `InpEntryMode` 和 SMC 相关参数。
- `GetMartSignal()` 固定为唯一入场路径：EMA 分级信号 + H4 趋势过滤；SMC 评分不再参与入场。
- 面板移除 SMC 三周期卡片和综合评分行，改为显示 `入场: EMA/H4/精确过滤` 诊断。
- 远程授权版同步为 V1.41R，远程上报版本号同步为 `1.41R`。

### 2026-07-28（EA V1.42）

**删除**
- 删除轮转锁仓篮子功能：移除 `InpEnableBasketRotation` / `InpRotate*` 参数、轮转多 Magic 切换、旧篮子冻结管理、轮转冷却、轮转面板和单篮子平仓按钮。
- 远程授权版同步删除轮转上报字段 `frozen_basket_profit` / `active_basket`，远程上报版本号同步为 `1.42R`。

**修改**
- 风控主链路回到单 Magic 单篮子，主保护为阶梯对冲 + ATR 扩张暂停加仓 + 快速熔断小亏脱身。
- `GetActiveMagicNumber()` / 历史统计过滤退化为单一 `InpMagicNumber`，避免旧轮转 Magic 继续参与当前 EA 统计。
- 本地授权版与远程授权版均编译通过，0 errors / 0 warnings。

### 2026-07-28（EA V1.43）

**新增**
- 对冲后部分减仓：记录对冲激活后的最大马丁浮亏，浮亏回收 30% 时减掉当前对冲手数的 30%，减仓后至少保留 0.35 对冲比例。
- 对冲后小仓修复：浮亏回收 20% 且 ATR 短/长恢复到 `InpATRAddResumeRatio` 以下时，允许最多 2 次 0.01 手同向修复单。

**修改**
- 阶梯对冲默认从 `1800/2600/3800 -> 0.60/0.70/0.80` 调整为 `2000/3000/4500 -> 0.55/0.65/0.75`，减少锁死概率。
- 对冲激活后仍禁止普通马丁加层，但允许受限修复单；面板对冲行显示浮亏回收百分比和修复次数。
- 本地授权版与远程授权版同步更新到 V1.43 / V1.43R，远程上报版本号同步为 `1.43R`，均编译通过 0 errors / 0 warnings。

### 2026-07-28（EA V1.44）

**修改**
- 按用户要求将篮子 TP 写死：基础 TP 固定 3 美分，每层 TP 增量固定 8 美分，不再作为输入参数显示。
- `金貔貅参数.set` 移除 `InpMartBasketTP_USD` / `InpMartBasketTPPerLayer`，避免加载旧参数覆盖源码固定值。
- 本地授权版与远程授权版同步更新到 V1.44 / V1.44R，远程上报版本号同步为 `1.44R`。

### 2026-07-28（EA V1.45）

**修改**
- 最大加仓层数默认从 35/50 口径统一收敛到 25 层；实际仍受 `InpMartMaxTotalLots=10.0` 总手数上限约束。
- 加仓间距默认调整为基础 200 点、每层递增 30 点、ATR 系数 0.03。
- 阶梯间距倍率调整为 1.0 / 1.1 / 1.3 / 1.6，取消前 5 层 0.5 倍密集加仓。
- ATR 扩张暂停从 1.6/1.3 调整为 1.5/1.25，更早暂停、稍早恢复。

- 本地授权版与远程授权版同步更新到 V1.45 / V1.45R，远程上报版本号同步为 `1.45R`。

### 2026-07-28（EA V1.46）

**修改**
- 面板默认高度从 440/380 压缩为 374，并允许布局最小高度降到 360，减少底部空白。
- 面板子标题移除旧 SMC 趋势文案，改为显示当前单一入场路径 `EMA+H4+精确过滤`。
- 入场信息拆分为摘要、未建仓原因、精确过滤阈值三部分，明确显示 EMA 多空当前分/达标分、H4 是否顺向、RSI/距慢EMA/实体强度的当前值和阈值。
- 对冲关闭时不再显示比例、权益百分比、绝对金额等未生效参数，避免误解为轮转或对冲残留。
- 本地授权版与远程授权版同步更新到 V1.46 / V1.46R，远程上报版本号同步为 `1.46R`。

### 2026-07-28（EA V1.47）

**修改**
- 删除固定对冲的权益百分比触发方式，移除 `InpHedgeTriggerMode` / `InpHedgeLossPercent` 参数；固定对冲现在只按 `InpHedgeAbsoluteUSD` 绝对浮亏美分触发。
- 快速亏损紧急停止默认开启：`DEF_ENABLE_FAST_LOSS=true`，参数文件同步 `InpEnableFastLoss=true`。
- 点差默认从 450 点统一为 350 点，和实盘 `.set` 参数保持一致。
- `DEF_MART_MAX_TOTAL_LOTS` 从 2.0 同步为 10.0，避免未加载 `.set` 时总手数默认值过低。
- 本地授权版与远程授权版同步更新到 V1.47 / V1.47R，远程上报版本号同步为 `1.47R`。

### 2026-07-28（青鸾 V1.48）

**修改**
- 按用户要求将 EA 对外显示品牌从 `金貔貅` 改为 `青鸾`，生成 `青鸾V1.48.mq5` / `青鸾V1.48-远程授权.mq5`。
- 面板标题改为 `青鸾 v1.48` / `青鸾 v1.48R`，默认预设名 `DEF_PRESET_NAME` 和参数文件 `InpPresetName` 同步改为 `青鸾`。
- 使用源码目录下用户新替换的 `LOGO.bmp` 和 `背景.bmp` 重新嵌入编译。
- 远程授权版上报版本号同步为 `1.48R`；授权密钥、Magic、远程 product 字段保持兼容，不改后台授权体系。

### 2026-07-28（青鸾 V1.49）

**修改**
- 将 `止盈止损` 参数组写死并从 MT5 参数页隐藏：深层守护 TP、硬止损恢复、追踪止损、平仓后新篮子冷却均使用源码固定值。
- 平仓后新篮子冷却从 45 秒固定为 60 秒，避免刚平仓后在点差/跳价噪音中立刻重开。
- 将 `入场信号` 参数组写死并从 MT5 参数页隐藏：入场 K 线固定 M5、EMA 13/34、H4 连续两根确认、全天交易、首单防追和 M5 RSI 精确过滤固定开启。
- `金貔貅参数.set` 删除上述已固定参数，避免加载旧 `.set` 时出现无效/误导项。
- 本地授权版与远程授权版同步更新到 青鸾 V1.49 / V1.49R，远程上报版本号同步为 `1.49R`。

### 2026-07-28（青鸾 V1.50）

**新增**
- 首单入场复用 ATR 扩张暂停阈值：当 `ATR短/ATR长 >= InpATRAddPauseRatio` 时禁止开启新篮子，恢复条件沿用 `ATR短/ATR长 <= InpATRAddResumeRatio`。
- 面板未建仓原因新增 `ATR扩张禁首单 x.xx>阈值`，用于提示当前不是方向问题，而是波动扩张/大单边风险。

**修改**
- 面板 `H4顺/逆` 改为直接显示 H4 背景方向：`多`、`空`、`震荡`、`逆多`、`逆空`、`关`。
- 面板背景、卡片和按钮从灰色系调整为青色系，匹配青鸾背景图主色调。
- 面板下半部分字号和行距加大，入场条件状态拆成独立彩色标签，满足显示绿色、不满足显示红色。
- 远程授权版同步更新到 青鸾 V1.50R，远程上报版本号同步为 `1.50R`。

**策略判断**
- 马丁策略不应只追求入场方向精准，核心是避开大单边和波动突然扩张；EMA/H4 保留为粗方向过滤，ATR 扩张负责拦截不适合开新篮子的行情。

### 2026-07-28（青鸾 V1.51）

**修改**
- 未建仓原因行改为纯文字说明，不再重复显示 `EMA多/空`、`H4` 等数值。
- 未建仓原因支持同时汇总多个未通过条件，例如 `H4趋势不支持做多；RSI偏高，不适合做多`。
- 条件状态改为两行三列：上排 `EMA/H4/ATR`，下排 `RSI/距EMA/实体`，减少不等距和拥挤感。
- 本地授权版与远程授权版同步更新到 青鸾 V1.51 / V1.51R，远程上报版本号同步为 `1.51R`。

### 2026-07-28（青鸾 V1.52）

**修改**
- 未建仓原因支持自动拆成两行显示，优先按中文分号断行，避免长原因超出面板宽度。
- 条件状态整体下移，为两行未建仓原因预留空间。
- 本地授权版与远程授权版同步更新到 青鸾 V1.52 / V1.52R，远程上报版本号同步为 `1.52R`。

### 2026-07-28（青鸾 V1.53）

**修复**
- 修复未建仓文字原因与条件状态红绿数量不一致的问题。
- `实体` 条件状态现在同时判断实体大小和实体方向，并显示 `阳/阴/平`，例如 `实体:阴0.42`。
- 本地授权版与远程授权版同步更新到 青鸾 V1.53 / V1.53R，远程上报版本号同步为 `1.53R`。

### 2026-07-29（青鸾 V1.54）

**修改**
- 取消 H4 趋势对首单的一票否决，避免 `H4逆多/逆空` 导致整晚不开单。
- 首单大方向保护改为最近 3 根已收盘 H1 的强单边风险过滤：仅当 3 小时净位移 >= 1.20 倍 H1 ATR、至少 2 根同向实体、且收盘价连续推进时，判定为 `H1强多/强空`。
- 只有 `H1强多` 时禁止逆势做空、`H1强空` 时禁止逆势做多；H1 震荡或弱趋势不拦截首单。
- 面板显示从 `H4` 改为 `H1`，条件状态显示 `H1:震荡/强多/强空/强多逆空/强空逆多`。
- 本地授权版与远程授权版同步更新到 青鸾 V1.54 / V1.54R，远程上报版本号同步为 `1.54R`。

### 2026-07-29（青鸾 V1.55）

**修改**
- `距EMA` 不再以 `1.80 ATR` 作为硬拦截；`1.80` 以上仅黄色提示偏远，超过 `3.00 ATR` 才作为防追高/追低硬拦截。
- `实体大小` 不再以 `0.30 ATR` 作为硬拦截；实体偏小仅黄色提示，实体方向反向仍红色硬拦截。
- 条件状态显示新增 `距EMA:偏远`、`实体:阳/阴/平 + 偏小`，让提示/拦截口径更清楚。
- 本地授权版与远程授权版同步更新到 青鸾 V1.55 / V1.55R，远程上报版本号同步为 `1.55R`。

### 2026-07-29（青鸾 V1.56）

**修改**
- 为避免利润过碎，追踪止盈默认从 `保留峰值50%` 调整为 `保留峰值60%`。
- 追踪启动门槛从 `动态TP×60%` 调整为 `动态TP×80%`，减少 1-3 层小浮盈过早被追踪扫掉。
- 本地授权版与远程授权版同步更新到 青鸾 V1.56 / V1.56R，远程上报版本号同步为 `1.56R`。

### 2026-07-29（青鸾 V1.57）

**修改**
- RSI 继续作为短线过热过滤，不改为方向信号。
- RSI 阈值从做多 `<=52` / 做空 `>=48` 放宽为做多 `<=55` / 做空 `>=45`，减少普通波动被误拦截。
- 本地授权版与远程授权版同步更新到 青鸾 V1.57 / V1.57R，远程上报版本号同步为 `1.57R`。

### 2026-07-29（青鸾 V1.58）

**修改**
- M5 实体方向不再作为首单硬拦截条件，仅作为面板黄色提示。
- `实体` 条件状态显示 `反向` 时为黄色提示，不计入未建仓原因；实体大小偏小仍为黄色提示。
- 本地授权版与远程授权版同步更新到 青鸾 V1.58 / V1.58R，远程上报版本号同步为 `1.58R`。

### 2026-05-24（Web 大屏 + 续费记录页）

**新增**
- `admin/orders.php`（116 行）：续费支付记录页，含 KPI、关键词/状态/日期筛选、订单列表（最多 500 条）
- `admin/dashboard.php`：每日盈亏曲线大图 `#combinedChart`（双线对比）
- `admin/dashboard.php`：账户最新快照表新增"今日已实现"列
- `admin/dashboard.php`：60s 自动刷新 + `.refresh-badge` 倒计时徽标
- `index.php`：微信浏览器内点续费时显示 `#wechatGuide` 遮罩，引导跳外部浏览器
- `app.css`：账号表格样式集合（`.readonly-input` / `.edit-note` / `.cell-time` / `.cell-heartbeat` / `.cell-action` / `.btn-sm`）
- `app.css`：`.wechat-guide` 系列遮罩样式 + `@keyframes wxArrowBounce`
- `app.css`：`.refresh-badge` + `@keyframes refreshPulse`

**修改**
- `admin/accounts.php`：表格扩为 8 列，账号字段 readonly + 金色 monospace，备注改单行 input，操作按钮独立列
- `admin/dashboard.php`：`dateFrom` 默认值从 `-30 days` 改为今天
- `admin/dashboard.php`：新增 `dailyTrend` 查询（固定 30 天）+ PHP 端补全日期序列（缺失补 0）
- `admin/dashboard.php`：`usort` 按 `today_realized` 降序排序快照列表
- `admin/accounts.php` / `admin/dashboard.php` / `admin/orders.php` 导航栏统一加入「续费记录」入口
- `api/admin_update_account.php`：SQL 移除 `account_login` 字段更新（账号双层只读保险）
- `app.css`：`.dashboard-chart-grid .chart-panel.chart` 高度 `auto` → `340px`（修复图表空白）
- CSS 缓存版本号升至 `?v=20260524-5`

**修复**
- hosts 文件 fake-IP 劫持（部分线路 `198.18.0.x`）→ ping/curl.exe 已确认真实 IP `121.41.12.87`
- 大屏"每日已实现 / 每日浮动"两个小图空白：双重根因（CSS 容器高度 0 + 数据库仅 1 天数据）

**部署文件清单**（需 scp 推送至 `/www/wwwroot/ea.newqidian365.com/`）
```
admin/orders.php             （新增）
admin/accounts.php           （nav + 表格）
admin/dashboard.php          （nav + 多处）
index.php                    （微信引导）
api/admin_update_account.php （后端加固）
assets/css/app.css           （样式集合）
```

**未完成 / 后续**
- JSAPI 微信支付改造：等待用户申请到**公众号** appid 后再做
- 续费记录页可考虑加导出 CSV 功能
- 大屏数据当前只有 1 天历史，30 天趋势图待数据积累后才有意义

---

> 任何修改 EA 行为前，必须先阅读此文件相关章节。
> 修改后请同步更新本文件相应小节。
