# AGENTS.md — 金貔貅 EA 项目上下文

> 本文件供 Codex / Claude / Qoder 等 AI 编程助手快速理解项目背景。
> 最后更新：2026-05-30，对应版本 V1.22。

---

## 1. 项目定位

**金貔貅 EA** 是一个运行在 MetaTrader 5 平台、基于 MQL5 开发的自动交易程序。

- **专属交易品种**：`XAUUSDc`（黄金美分账户），不再支持 EURUSD/EURUSDc 等外汇品种
- **策略类型**：马丁格尔 + 网格 + 对冲 + 多重风控（日亏锁定 / 对冲止盈 / 快速熔断）
- **目标账户**：杠杆 2000 倍的小额美分账户
- **多实例并行**：支持单机同时挂载 20 个 MT5 客户端运行同一 EA，需通过参数随机偏移避免共振爆仓

**配套系统：**
1. **MT5 EA 主程序**（MQL5）：金貔貅V1.22.mq5
2. **授权工具**（Python + Tkinter，PyInstaller 打包为 EXE）：金貔貅授权工具.exe
3. **PHP 后台**（PHP + MySQL）：授权码生成、管理后台

---

## 2. 项目目录结构

```
c:\Users\Administrator\Desktop\源码\           # 项目根目录
├── 金貔貅V{版本号}.mq5                        # EA 主源码（如 金貔貅V1.19.mq5）
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
- 标准版：`金貔貅V{版本号}.mq5`（如 `金貔貅V1.19.mq5`）
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
  - 系数 0.20 = 单层约 $3.5（"稳"档）
  - 系数 0.15 = 单层约 $2.5（"中"档，默认）
  - 系数 0.10 = 单层约 $1.7（"快"档）
- **顶栏按钮**：稳/中/快三档支持运行时动态切换
- **TP 计算（线性公式）**：
  ```
  动态TP = g_effBasketTP + (层数-1) × InpMartBasketTPPerLayer
  ```
  - `g_effBasketTP` 受账户偏移因子影响（±25%）
  - `InpMartBasketTPPerLayer`（默认 8 美分）**不受偏移影响**
  - 多账号 TP 曲线为同斜率不同截距的平行线
- **每层 TP 增量随机化**：±25%，下限保护 50%（避免增量趋零）
- **深层守护 TP（V1.22）**：在动态 TP 计算出口统一乘守护系数，不做部分平仓：
  - 1~5 层：100%
  - 6~9 层：85%
  - 10~15 层：70%
  - 16 层以上：55%
  - 最低目标 `InpDeepTPMinProfit` 默认 30 美分

### 4.3 对冲机制

**V1.22 重构**：原 `InpEnableHedge`(总开关) + `InpUseHedgeLadder`(算法选择) 两个 bool 合并为单一枚举 `InpHedgeMode`：
- `HEDGE_MODE_OFF`：完全关闭对冲（默认值，保持兼容）
- `HEDGE_MODE_FIXED`：固定比例（走传统二选一触发：权益% 或 绝对金额）
- `HEDGE_MODE_LADDER`：浮亏阶梯对冲（推荐）

**固定模式触发方式（HEDGE_MODE_FIXED 时生效）：**
- 权益百分比：浮亏达权益的 40% 触发
- 绝对金额：浮亏达 10000 美分（$100）触发
- 注意：变量名 `InpHedgeAbsoluteUSD` 但单位实际是账户本币（美分账户即美分）

**浮亏阶梯对冲（HEDGE_MODE_LADDER 时生效）：**
- 浮亏 1800 美分：目标对冲比例 0.6
- 浮亏 2600 美分：目标对冲比例 0.7
- 浮亏 3800 美分：目标对冲比例 0.8
- 阶梯比例为目标总对冲比例，只补足差额，不重复叠加。

**对冲比例风险分级：**
| 比例 | 性质 | 推荐 |
|------|------|------|
| 0.6 | 最保守，保护弱但 V 反收益高 | 可用 |
| **0.7** | 均衡甜点 | ✅ 默认 |
| 0.8 | 偏锁仓 | 中等趋势可用 |
| 1.0 | 完全锁死 → 死锁陷阱 | ❌ 不推荐 |
| 1.2 | 反向追势赌博 | ❌ 严禁 |

**对冲激活后**：
- 停止马丁加层（防止敞口放大）
- 追踪止损被禁用（由 HedgeRelease 接管）
- 解锁阈值 `InpHedgeReleaseFixed` 默认 200 美分（建议黄金调到 300~500）

**跨日行为**：
- ResetDailyState 仅重置日级统计，不平对冲单
- 若新日亏损达到 `InpMaxDailyLossPercent`（默认 40%），CloseAllMartPositions 一并平掉对冲单

**阶梯对冲设计（待实现）**：
- 触发依据：**价格距离主仓均价**（不是浮亏美分数，因为浮亏增长会被首档对冲压缩）
- 1档：价格偏离 ≥ $20 → 对冲 0.9 倍
- 2档：偏离 ≥ $35 → 累计 1.1 倍
- 3档：偏离 ≥ $55 → 累计 1.3 倍
- 4档：偏离 ≥ $80 → 累计 1.5 倍

### 4.4 快速熔断（Fast Loss Breaker）

**触发条件**：单位时间内价格向不利方向变动达阈值
- `InpFastLossDistance`：单位**美分**，800 = $8 反向价幅
- `InpFastLossTime`：300 秒（5 分钟）窗口
- `InpFastLossRecoveryDistance`：400 美分回调解锁

**触发后行为**：
- **仅锁定新开仓与加层**，保留已有仓位等回调（不全平）
- 锁定期间继续运行：止盈、追踪、硬止损、对冲管理
- 解锁条件：价格回到最后一层加仓价（多头取 `g_martLowestPrice`，空头取 `g_martHighestPrice`）
- 守卫逻辑：篮子全平时（`g_martDirection == NONE`）自动解锁

**与对冲机制独立**：两者触发条件不同，可叠加发生

### 4.5 ATR扩张暂停加仓（V1.21）

- 复用马丁加仓间距 ATR 句柄：短 ATR=3，长 ATR=6
- `ATR短 / ATR长 >= 1.6`：暂停加仓
- `ATR短 / ATR长 <= 1.3`：恢复加仓
- 只影响 `TryMartAddLayer()`，不影响熔断、止盈、止损、追踪、对冲。

### 4.6 新闻过滤（V1.22）

- `InpEnableNewsFilter=true` 默认启用自动新闻过滤。
- 自动窗口：
  - 周四 20:30 数据窗口（默认 20:20~21:10）
  - 每月第一个周五 20:30 非农窗口（默认 20:20~21:10）
- `InpNewsDataHour/InpNewsDataMinute` 控制美国 08:30 数据对应的北京时间；夏令时默认 20:30，冬令时可改 21:30。
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

### 4.9 多账户参数随机偏移（防共振）

`ApplyAccountOffsets()` 对以下参数注入基于账户ID的偏移：
- `g_effATRCoeff`：±15%
- `g_effBasketTP`：±25%
- `g_effBaseSpacing`：±20%
- `EMA Fast` 周期：黄金场景 ±15%（原13→11~15）
- `EMA Slow` 周期：黄金场景 ±10%（原34→31~37）

---

## 5. 关键参数（XAUUSDc 推荐值）

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `InpMartATRSpacingCoeff` | 0.15~0.20 | 5位精度推荐 0.20，6位精度 0.30 |
| `InpMartBasketTPPerLayer` | 8 美分 | 每层 TP 增量基础值 |
| `InpEnableNewsFilter` | true | 新闻过滤：锁新开仓/加层，不强平 |
| `InpNewsDataHour/Minute` | 20 / 30 | 美国 08:30 数据对应北京时间（冬令时可改 21/30） |
| `InpNewsBlockPreMinutes/PostMinutes` | 10 / 40 | 新闻前后禁开分钟 |
| `InpEnableDeepProtectTP` | true | 深层守护 TP |
| `InpDeepTPLevel1/2/3Start` | 6 / 10 / 16 | 守护 TP 起始层 |
| `InpDeepTPLevel1/2/3Factor` | 0.85 / 0.70 / 0.55 | 守护 TP 系数 |
| `InpDeepTPMinProfit` | 30 美分 | 守护 TP 最低目标 |
| `InpHedgeMode` | HEDGE_MODE_OFF | 对冲模式（OFF/FIXED/LADDER），V1.22 新增 |
| `InpHedgeRatio` | 0.5 | [固定模式]对冲手数比例 |
| `InpHedgeLadderLoss1/2/3` | 1800 / 2600 / 3800 | 阶梯对冲浮亏阈值（美分） |
| `InpHedgeLadderRatio1/2/3` | 0.6 / 0.7 / 0.8 | 阶梯目标对冲比例 |
| `InpHedgeAbsoluteUSD` | 10000 美分 | 对冲触发浮亏（黄金建议 5000）|
| `InpHedgeReleaseFixed` | 200 美分 | 对冲解锁阈值（黄金建议 300~500）|
| `InpFastLossDistance` | 800 美分 | 5min 内反向 $8 |
| `InpFastLossTime` | 300 秒 | 熔断窗口 |
| `InpFastLossRecoveryDistance` | 400 美分 | 熔断解锁 |
| `InpMaxDailyLossPercent` | 40.0 | 日亏锁定阈值 |
| `InpChinaUtcOffsetHours` | 8 | 北京时区 |
| `InpAutoServerUtcOffset` | true | 自动检测服务器时区 |

**美分账户单位约定**：所有以"美元"命名的金额参数（如 `*_USD`）实际单位为账户本币，美分账户下即美分（1 美元 = 100 美分）。

---

## 6. 编译流程

**MetaEditor 命令行编译**（PowerShell）：
```powershell
& "C:\Program Files\MetaTrader 5\MetaEditor64.exe" `
  /compile:"c:\Users\Administrator\Desktop\源码\金貔貅V1.22.mq5" `
  /log:"c:\Users\Administrator\Desktop\源码\金貔貅V1.22.log"
```

**注意事项**：
- ❌ 不要使用 `/portable` 参数（会禁用 AppData Include 查找）
- ❌ 不要使用 `/include` 参数（需精确匹配终端 ID 目录）
- ✅ 让 MetaEditor 自动识别默认终端的 `MQL5\Include`
- ✅ 编译前确保 `LOGO.bmp` 和 `背景.bmp` 与 `.mq5` 同目录
- ✅ 命令完成后需 `Start-Sleep 3` 等待 ex5 异步生成

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
3. **编译验证**：MetaEditor 命令行编译，确保 0 errors
4. **Git 提交**：add + commit + push 三件套

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

> 任何修改 EA 行为前，必须先阅读此文件相关章节。
> 修改后请同步更新本文件相应小节。
