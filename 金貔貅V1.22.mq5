#property copyright "Golden Pixiu EA"
#property version   "1.22"
#property strict

#include <Trade/Trade.mqh>

#resource "LOGO.bmp" as uchar g_logoRawData[]
#resource "背景.bmp" as uchar g_bgRawData[]

enum ENUM_MART_DIRECTION
  {
   MART_DIR_NONE  = 0,
   MART_DIR_BUY   = 1,
   MART_DIR_SELL  = 2
  };

// --- 历史交易明细 ---
struct DailyTradeRecord {
   string date;        // MM-DD格式
   double totalLots;   // 当日总手数
   double maxLot;      // 当日最大单笔手数
   int    tradeCount;  // 当日平仓次数
   double pnl;         // 当日盈亏(美分)
   double pnlRatio;    // 盈亏比(%)
   double balance;     // 当日收盘余额
   double maxDrawdown; // 当日最大浮亏(绝对值)
   double maxDDPct;    // 最大浮亏比(%)
};

enum ENUM_ENTRY_MODE
  {
   ENTRY_EMA_ONLY  = 0,   // 仅EMA
   ENTRY_SMC_ONLY  = 1,   // 仅SMC
   ENTRY_COMBINED  = 2    // 综合评分
  };

enum ENUM_H4_FILTER_MODE
  {
   H4_FILTER_OFF = 0,   // 关闭H4趋势过滤
   H4_FILTER_1K  = 1,   // 1K确认(仅上一根H4)
   H4_FILTER_2K  = 2    // 2K确认(连续两根H4,默认)
  };

enum HEDGE_TRIGGER_MODE
  {
   HEDGE_BY_EQUITY_PCT = 0,  // 权益百分比
   HEDGE_BY_ABSOLUTE   = 1   // 绝对金额(美分)
  };

enum HEDGE_MODE
  {
   HEDGE_MODE_OFF    = 0,    // 关闭
   HEDGE_MODE_FIXED  = 1,    // 固定比例(传统二选一触发)
   HEDGE_MODE_LADDER = 2     // 浮亏阶梯对冲(推荐)
  };

#ifndef DEF_PRESET_NAME
#define DEF_PRESET_NAME "金貔貅"
#endif
#ifndef DEF_MAGIC_NUMBER
#define DEF_MAGIC_NUMBER 26042702
#endif
#ifndef DEF_CN_OFFSET
#define DEF_CN_OFFSET 8
#endif
#ifndef DEF_AUTO_SERVER_OFFSET
#define DEF_AUTO_SERVER_OFFSET true
#endif
#ifndef DEF_SERVER_OFFSET
#define DEF_SERVER_OFFSET 2
#endif
#ifndef DEF_USE_NEWS_BLOCK
#define DEF_USE_NEWS_BLOCK false
#endif
#ifndef DEF_ENABLE_NEWS_FILTER
#define DEF_ENABLE_NEWS_FILTER true
#endif
#ifndef DEF_NEWS_BLOCK_START
#define DEF_NEWS_BLOCK_START 20
#endif
#ifndef DEF_NEWS_BLOCK_END
#define DEF_NEWS_BLOCK_END 23
#endif
#ifndef DEF_MAX_DAILY_LOSS
#define DEF_MAX_DAILY_LOSS 8.0
#endif
#ifndef DEF_MAX_SPREAD_POINTS
#define DEF_MAX_SPREAD_POINTS 450
#endif
#ifndef DEF_USE_FIXED_LOT
#define DEF_USE_FIXED_LOT false
#endif
#ifndef DEF_FIXED_LOT
#define DEF_FIXED_LOT 0.01
#endif
#ifndef DEF_MART_BASE_LOT
#define DEF_MART_BASE_LOT 0.01
#endif
#ifndef DEF_MART_LOT_MULTIPLIER
#define DEF_MART_LOT_MULTIPLIER 1.20
#endif
#ifndef DEF_MART_MAX_LAYER_LOT
#define DEF_MART_MAX_LAYER_LOT 1.50
#endif
#ifndef DEF_MART_MAX_LAYERS
#define DEF_MART_MAX_LAYERS 50
#endif
#ifndef DEF_MART_BASE_SPACING
#define DEF_MART_BASE_SPACING 100
#endif
#ifndef DEF_MART_INC_SPACING
#define DEF_MART_INC_SPACING 20
#endif
#ifndef DEF_MART_ATR_SPACING_COEFF
#define DEF_MART_ATR_SPACING_COEFF 0.05
#endif
#ifndef DEF_MART_ATR_SPACING_PERIOD
#define DEF_MART_ATR_SPACING_PERIOD 3
#endif
#ifndef DEF_MART_ATR_SPACING_LONG_PERIOD
#define DEF_MART_ATR_SPACING_LONG_PERIOD 6
#endif
#ifndef DEF_MART_MAX_TOTAL_LOTS
#define DEF_MART_MAX_TOTAL_LOTS 2.0
#endif
#ifndef DEF_MART_BASKET_TP
#define DEF_MART_BASKET_TP 8.0  // 基础止盈(美分), 动态TP=基础+(层数-1)×每层增量
#endif
#ifndef DEF_MART_BASKET_TP_PER_LAYER
#define DEF_MART_BASKET_TP_PER_LAYER 8.0  // 每增加一层的TP增量(美分)
#endif
#ifndef DEF_MART_HARD_SL
#define DEF_MART_HARD_SL 0.0
#endif
#ifndef DEF_MART_TRAIL_PCT
#define DEF_MART_TRAIL_PCT 50.0
#endif
#ifndef DEF_MART_TRAIL_MIN_PROFIT_PER_LAYER
#define DEF_MART_TRAIL_MIN_PROFIT_PER_LAYER 60.0  // 追踪启动门槛=当前TP×此%，如60=浮盈达TP的60%时启动
#endif
#ifndef DEF_MART_COOLDOWN_SEC
#define DEF_MART_COOLDOWN_SEC 45
#endif
#ifndef DEF_MART_ENTRY_TF
#define DEF_MART_ENTRY_TF PERIOD_M5
#endif
#ifndef DEF_MART_EMA_FAST
#define DEF_MART_EMA_FAST 13
#endif
#ifndef DEF_HISTORY_DAYS
#define DEF_HISTORY_DAYS 15
#endif
#define HISTORY_FILE_NAME "XAU_TrendGrid_History.csv"
#ifndef DEF_MART_EMA_SLOW
#define DEF_MART_EMA_SLOW 34
#endif
#ifndef DEF_MART_H4_FILTER_MODE
#define DEF_MART_H4_FILTER_MODE H4_FILTER_2K
#endif
#ifndef DEF_MART_START_HOUR
#define DEF_MART_START_HOUR 0
#endif
#ifndef DEF_MART_END_HOUR
#define DEF_MART_END_HOUR 0
#endif
#ifndef DEF_ENABLE_FAST_LOSS
#define DEF_ENABLE_FAST_LOSS false
#endif
#ifndef DEF_FAST_LOSS_DISTANCE
#define DEF_FAST_LOSS_DISTANCE 800
#endif
#ifndef DEF_FAST_LOSS_TIME
#define DEF_FAST_LOSS_TIME 300
#endif
#ifndef DEF_ENABLE_HEDGE
#define DEF_ENABLE_HEDGE false
#endif
#ifndef DEF_HEDGE_LOSS_PCT
#define DEF_HEDGE_LOSS_PCT 40.0
#endif
#ifndef DEF_HEDGE_TRIGGER_MODE
#define DEF_HEDGE_TRIGGER_MODE HEDGE_BY_EQUITY_PCT
#endif
#ifndef DEF_HEDGE_ABSOLUTE_USD
#define DEF_HEDGE_ABSOLUTE_USD 10000.0  // 绝对金额触发(美分)
#endif
#ifndef DEF_SHOW_PANEL
#define DEF_SHOW_PANEL true
#endif
#ifndef DEF_PANEL_X
#define DEF_PANEL_X 5
#endif
#ifndef DEF_PANEL_Y
#define DEF_PANEL_Y 5
#endif
#ifndef DEF_PANEL_WIDTH
#define DEF_PANEL_WIDTH 680
#endif
#ifndef DEF_PANEL_HEIGHT
#define DEF_PANEL_HEIGHT 380
#endif
#ifndef DEF_PANEL_REFRESH_SEC
#define DEF_PANEL_REFRESH_SEC 2
#endif
#ifndef DEF_ENTRY_MODE
#define DEF_ENTRY_MODE ENTRY_COMBINED
#endif
#ifndef DEF_SMC_SCORE_THRESHOLD
#define DEF_SMC_SCORE_THRESHOLD 35
#endif
#ifndef DEF_SMC_IMBALANCE
#define DEF_SMC_IMBALANCE true
#endif
#ifndef DEF_SMC_IMBALANCE_LOOKBACK
#define DEF_SMC_IMBALANCE_LOOKBACK 8
#endif
#ifndef DEF_SMC_IMBALANCE_RATIO
#define DEF_SMC_IMBALANCE_RATIO 1.2
#endif
#ifndef DEF_SMC_SUPPLY_DEMAND
#define DEF_SMC_SUPPLY_DEMAND true
#endif
#ifndef DEF_SMC_SD_LOOKBACK
#define DEF_SMC_SD_LOOKBACK 15
#endif
#ifndef DEF_SMC_SD_IMPULSE_ATR
#define DEF_SMC_SD_IMPULSE_ATR 1.5
#endif
#ifndef DEF_SMC_ORDER_BLOCK
#define DEF_SMC_ORDER_BLOCK true
#endif
#ifndef DEF_SMC_OB_LOOKBACK
#define DEF_SMC_OB_LOOKBACK 10
#endif
#ifndef DEF_SMC_OB_IMPULSE_ATR
#define DEF_SMC_OB_IMPULSE_ATR 1.2
#endif
#ifndef DEF_SMC_FVG
#define DEF_SMC_FVG true
#endif
#ifndef DEF_SMC_FVG_LOOKBACK
#define DEF_SMC_FVG_LOOKBACK 8
#endif
#ifndef DEF_SMC_LIQ_VOID
#define DEF_SMC_LIQ_VOID true
#endif
#ifndef DEF_SMC_LV_LOOKBACK
#define DEF_SMC_LV_LOOKBACK 10
#endif
#ifndef DEF_SMC_LV_MIN_BODY_ATR
#define DEF_SMC_LV_MIN_BODY_ATR 1.5
#endif
#ifndef DEF_SMC_BREAKER
#define DEF_SMC_BREAKER true
#endif
#ifndef DEF_SMC_BREAKER_LOOKBACK
#define DEF_SMC_BREAKER_LOOKBACK 12
#endif
#ifndef DEF_SMC_USE_CCI
#define DEF_SMC_USE_CCI true
#endif
#ifndef DEF_SMC_CCI_PERIOD
#define DEF_SMC_CCI_PERIOD 14
#endif
#ifndef DEF_SMC_CCI_TF
#define DEF_SMC_CCI_TF PERIOD_H1
#endif
#ifndef DEF_SMC_CCI_EXTREME
#define DEF_SMC_CCI_EXTREME 150
#endif

// === H4 EMA 过滤周期 ===
#ifndef DEF_MART_H4_EMA_PERIOD
#define DEF_MART_H4_EMA_PERIOD  3
#endif

// === 综合评分权重 ===
#ifndef DEF_SMC_WEIGHT_IMBALANCE
#define DEF_SMC_WEIGHT_IMBALANCE  15
#endif
#ifndef DEF_SMC_WEIGHT_SD
#define DEF_SMC_WEIGHT_SD  15
#endif
#ifndef DEF_SMC_WEIGHT_OB
#define DEF_SMC_WEIGHT_OB  13
#endif
#ifndef DEF_SMC_WEIGHT_FVG
#define DEF_SMC_WEIGHT_FVG  12
#endif
#ifndef DEF_SMC_WEIGHT_LV
#define DEF_SMC_WEIGHT_LV  8
#endif
#ifndef DEF_SMC_WEIGHT_BREAKER
#define DEF_SMC_WEIGHT_BREAKER  7
#endif
#ifndef DEF_SMC_WEIGHT_EMA
#define DEF_SMC_WEIGHT_EMA  30
#endif

input group "=== 基础设置 ==="
input string           InpPresetName             = DEF_PRESET_NAME;           // ▶ 策略预设名称
input long             InpMagicNumber            = DEF_MAGIC_NUMBER;          // ▶ EA唯一标识号(Magic)
input string           InpLicenseKey             = "";                        // ▶ 授权码(联系管理员获取)

input group "=== 时间与交易时段（北京时间） ==="
input int              InpChinaUtcOffsetHours    = DEF_CN_OFFSET;             // ▶ 北京时区=UTC+8
input bool             InpAutoServerUtcOffset    = DEF_AUTO_SERVER_OFFSET;    // ▶ 自动检测服务器时区
input int              InpServerUtcOffsetHours   = DEF_SERVER_OFFSET;         // ▶ 服务器UTC偏移(手动)
input bool             InpEnableNewsFilter       = DEF_ENABLE_NEWS_FILTER;    // ▶ 启用新闻过滤(仅禁开仓/加层,不强平)
input bool             InpNewsBlockThu2030       = true;                      // ▶ 周四20:30数据窗口(初请等)
input bool             InpNewsBlockFirstFri2030  = true;                      // ▶ 每月第一个周五20:30非农窗口
input bool             InpAutoUsDstNewsTime      = true;                      // ▶ 自动按美国夏/冬令时换算08:30数据
input int              InpNewsDataHour           = 20;                        // ▶ 手动模式:美国08:30数据对应北京时间小时
input int              InpNewsDataMinute         = 30;                        // ▶ 手动模式:美国08:30数据对应北京时间分钟
input int              InpNewsBlockPreMinutes    = 10;                        // ▶ 新闻前禁开分钟
input int              InpNewsBlockPostMinutes   = 40;                        // ▶ 新闻后禁开分钟
input bool             InpUseManualNewsBlock     = DEF_USE_NEWS_BLOCK;        // ▶ 启用自定义新闻窗口
input int              InpNewsBlockStartHour     = DEF_NEWS_BLOCK_START;      // ▶ 自定义窗口开始(北京时间小时)
input int              InpNewsBlockStartMinute   = 20;                        // ▶ 自定义窗口开始(分钟)
input int              InpNewsBlockEndHour       = DEF_NEWS_BLOCK_END;        // ▶ 自定义窗口结束(北京时间小时)
input int              InpNewsBlockEndMinute     = 10;                        // ▶ 自定义窗口结束(分钟)

input group "=== 全局风控 ==="
input double           InpMaxDailyLossPercent    = DEF_MAX_DAILY_LOSS;        // ▶ 日最大亏损占权益百分比
input int              InpMaxSpreadPoints        = DEF_MAX_SPREAD_POINTS;     // ▶ 允许最大点差(超过则不开单)
input bool             InpUseFixedLot            = DEF_USE_FIXED_LOT;         // ▶ 使用固定手数(否则按基础手数)
input double           InpFixedLot               = DEF_FIXED_LOT;             // ▶ 固定手数大小

input group "=== 马丁加仓 ==="
input double           InpMartBaseLot            = DEF_MART_BASE_LOT;         // ▶ 首单手数
input double           InpMartLotMultiplier      = DEF_MART_LOT_MULTIPLIER;   // ▶ 每层手数乘数(如1.20)
input double           InpMartMaxLayerLot        = DEF_MART_MAX_LAYER_LOT;    // ▶ 单层最大手数（每层开仓上限）
input int              InpMartMaxLayers          = DEF_MART_MAX_LAYERS;       // ▶ 最多加仓几层
input int              InpMartBaseSpacingPts     = DEF_MART_BASE_SPACING;     // ▶ 第1层加仓间距(点)
input int              InpMartIncSpacingPts      = DEF_MART_INC_SPACING;      // ▶ 每层多加几点间距
input double           InpMartATRSpacingCoeff    = DEF_MART_ATR_SPACING_COEFF; // ▶ ATR动态间距系数(0=关闭)
input int              InpMartATRSpacingPeriod   = DEF_MART_ATR_SPACING_PERIOD; // ▶ ATR短周期(默认3)
input int              InpMartATRSpacingLongPeriod = DEF_MART_ATR_SPACING_LONG_PERIOD; // ▶ ATR长周期(默认6)
input bool             InpUseATRAddPause         = true;                       // ▶ ATR扩张暂停加仓
input double           InpATRAddPauseRatio       = 1.60;                       // ▶ ATR短/长超过则暂停加仓
input double           InpATRAddResumeRatio      = 1.30;                       // ▶ ATR短/长回落则恢复加仓
input double           InpMartMaxTotalLots       = DEF_MART_MAX_TOTAL_LOTS;   // ▶ 所有层加起来最大手数

input group "=== 止盈止损 ==="
input double           InpMartBasketTP_USD       = DEF_MART_BASKET_TP;        // ▶ 篮子止盈基础(美分,0=关闭)
input double           InpMartBasketTPPerLayer   = DEF_MART_BASKET_TP_PER_LAYER; // ▶ 每层TP增量(美分)
input bool             InpEnableDeepProtectTP    = true;                      // ▶ 启用深层守护TP(深层降低目标优先脱身)
input int              InpDeepTPLevel1Start      = 6;                         // ▶ 轻度守护起始层(1-5层正常)
input double           InpDeepTPLevel1Factor     = 0.85;                      // ▶ 轻度守护TP系数
input int              InpDeepTPLevel2Start      = 10;                        // ▶ 中度守护起始层
input double           InpDeepTPLevel2Factor     = 0.70;                      // ▶ 中度守护TP系数
input int              InpDeepTPLevel3Start      = 16;                        // ▶ 重度守护起始层
input double           InpDeepTPLevel3Factor     = 0.55;                      // ▶ 重度守护TP系数
input double           InpDeepTPMinProfit        = 30.0;                      // ▶ 守护TP最低目标(美分)
input double           InpMartHardSL_USD         = DEF_MART_HARD_SL;          // ▶ 整篮子亏损多少强平(美分)
input double           InpMartTrailPct           = DEF_MART_TRAIL_PCT;        // ▶ 浮盈保留峰值%平仓(70=回撤到峰值70%平仓,0=关闭)
input double           InpMartTrailMinProfitPerLayer = DEF_MART_TRAIL_MIN_PROFIT_PER_LAYER; // ▶ 追踪启动门槛(占TP的%,60=浮盈达60%TP启动)
input int              InpMartCooldownSec        = DEF_MART_COOLDOWN_SEC;     // ▶ 平仓后等几秒再开新单

input group "=== 入场信号 ==="
input ENUM_TIMEFRAMES  InpMartEntryTF            = DEF_MART_ENTRY_TF;         // ▶ 入场信号的K线周期
input int              InpMartEmaFastPeriod      = DEF_MART_EMA_FAST;         // ▶ 快速EMA均线周期
input int              InpMartEmaSlowPeriod      = DEF_MART_EMA_SLOW;         // ▶ 慢速EMA均线周期
input ENUM_H4_FILTER_MODE InpMartH4FilterMode  = DEF_MART_H4_FILTER_MODE;   // ▶ H4趋势过滤模式(关闭/1K/2K,默认2K)
input int              InpMartStartHour          = DEF_MART_START_HOUR;       // ▶ 每天几点开始交易(0=全天)
input int              InpMartEndHour            = DEF_MART_END_HOUR;         // ▶ 每天几点停止交易(0=全天)
input bool             InpUseEntryChaseFilter    = true;                      // ▶ 首单防追高追低
input double           InpEntryMaxDistSlowEMA_ATR = 2.0;                      // ▶ 距慢EMA超过N倍ATR不追
input double           InpEntryMaxPrevBody_ATR   = 2.2;                       // ▶ 上根K实体超过N倍ATR不追

input group "=== SMC智能资金入场 ==="
input ENUM_ENTRY_MODE InpEntryMode              = DEF_ENTRY_MODE;            // ▶ 入场模式(仅EMA/仅SMC/综合评分)
input int             InpSMCScoreThreshold      = DEF_SMC_SCORE_THRESHOLD;   // ▶ 综合评分入场阈值(0-100)
input group "--- 大周期方向(4H) ---"
input bool            InpSMC_Imbalance          = DEF_SMC_IMBALANCE;         // ▶ 启用 Imbalance 失衡检测
input int             InpSMC_ImbalanceLookback  = DEF_SMC_IMBALANCE_LOOKBACK;// ▶ Imbalance 回溯K线数
input double          InpSMC_ImbalanceRatio     = DEF_SMC_IMBALANCE_RATIO;   // ▶ 失衡倍数(实体/前K振幅)
input bool            InpSMC_SupplyDemand       = DEF_SMC_SUPPLY_DEMAND;     // ▶ 启用 Supply/Demand 供需区
input int             InpSMC_SDZoneLookback     = DEF_SMC_SD_LOOKBACK;       // ▶ S/D Zone 回溯K线数
input double          InpSMC_SDImpulseATR       = DEF_SMC_SD_IMPULSE_ATR;    // ▶ 脉冲判定(N倍ATR)
input group "--- 中周期入场(1H) ---"
input bool            InpSMC_OrderBlock         = DEF_SMC_ORDER_BLOCK;       // ▶ 启用 Order Block 订单块
input int             InpSMC_OBLookback         = DEF_SMC_OB_LOOKBACK;       // ▶ OB 回溯K线数
input double          InpSMC_OBImpulseATR       = DEF_SMC_OB_IMPULSE_ATR;    // ▶ OB脉冲判定(N倍ATR)
input bool            InpSMC_FVG                = DEF_SMC_FVG;               // ▶ 启用 FVG 公允价值缺口
input int             InpSMC_FVGLookback        = DEF_SMC_FVG_LOOKBACK;      // ▶ FVG 回溯K线数
input group "--- 小周期精确(15M) ---"
input bool            InpSMC_LiquidityVoid      = DEF_SMC_LIQ_VOID;         // ▶ 启用 Liquidity Void 流动性空白
input int             InpSMC_LVLookback         = DEF_SMC_LV_LOOKBACK;       // ▶ LV 回溯K线数
input double          InpSMC_LVMinBodyATR       = DEF_SMC_LV_MIN_BODY_ATR;   // ▶ LV最小实体(N倍ATR)
input bool            InpSMC_Breaker            = DEF_SMC_BREAKER;           // ▶ 启用 Breaker 破坏块
input int             InpSMC_BreakerLookback    = DEF_SMC_BREAKER_LOOKBACK;  // ▶ Breaker 回溯K线数
input group "--- CCI 动量过滤(可选) ---"
input bool            InpSMC_UseCCI             = DEF_SMC_USE_CCI;           // ▶ 启用 CCI 极端过滤(默认关)
input ENUM_TIMEFRAMES InpSMC_CCI_TF            = DEF_SMC_CCI_TF;            // ▶ CCI 计算周期
input int             InpSMC_CCIPeriod          = DEF_SMC_CCI_PERIOD;        // ▶ CCI 参数周期
input int             InpSMC_CCIExtreme         = DEF_SMC_CCI_EXTREME;       // ▶ CCI 极端阈值(超过则否决)

input group "--- H4 EMA周期 ---"
input int             InpMartH4EmaPeriod        = DEF_MART_H4_EMA_PERIOD;    // ▶ H4 EMA过滤周期

input group "--- 综合评分权重 ---"
input int             InpSMCWeightImbalance     = DEF_SMC_WEIGHT_IMBALANCE;  // ▶ 权重-失衡(大周期)
input int             InpSMCWeightSD            = DEF_SMC_WEIGHT_SD;          // ▶ 权重-供需区(大周期)
input int             InpSMCWeightOB            = DEF_SMC_WEIGHT_OB;          // ▶ 权重-订单块(中周期)
input int             InpSMCWeightFVG           = DEF_SMC_WEIGHT_FVG;         // ▶ 权重-公允缺口(中周期)
input int             InpSMCWeightLV            = DEF_SMC_WEIGHT_LV;          // ▶ 权重-流动空白(小周期)
input int             InpSMCWeightBreaker       = DEF_SMC_WEIGHT_BREAKER;     // ▶ 权重-破坏块(小周期)
input int             InpSMCWeightEMA           = DEF_SMC_WEIGHT_EMA;         // ▶ 权重-EMA信号

input group "=== 高级风控（默认关闭） ==="
input bool             InpEnableFastLoss        = DEF_ENABLE_FAST_LOSS;      // ▶ 启用快速亏损紧急停止
input int              InpFastLossDistance      = DEF_FAST_LOSS_DISTANCE;    // ▶ 反向价格变动触发(美分,800=8美元)
input int              InpFastLossTime          = DEF_FAST_LOSS_TIME;        // ▶ 在几秒内发生算快速亏损
input HEDGE_MODE       InpHedgeMode             = HEDGE_MODE_OFF;             // ▶ 对冲模式(关闭/固定比例/浮亏阶梯)
input HEDGE_TRIGGER_MODE InpHedgeTriggerMode    = DEF_HEDGE_TRIGGER_MODE;     // ▶ [固定模式]触发方式
input double           InpHedgeLossPercent      = DEF_HEDGE_LOSS_PCT;        // ▶ [固定-权益%]亏损占权益多少%触发
input double           InpHedgeAbsoluteUSD      = DEF_HEDGE_ABSOLUTE_USD;    // ▶ [固定-绝对金额]亏损多少美分触发
input double           InpHedgeRatio            = 0.5;                       // ▶ [固定模式]对冲手数比例(0.5=50%)
input double           InpHedgeLadderLoss1      = 1800.0;                    // ▶ 阶梯1浮亏(美分)
input double           InpHedgeLadderRatio1     = 0.60;                      // ▶ 阶梯1目标对冲比例
input double           InpHedgeLadderLoss2      = 2600.0;                    // ▶ 阶梯2浮亏(美分)
input double           InpHedgeLadderRatio2     = 0.70;                      // ▶ 阶梯2目标对冲比例
input double           InpHedgeLadderLoss3      = 3800.0;                    // ▶ 阶梯3浮亏(美分)
input double           InpHedgeLadderRatio3     = 0.80;                      // ▶ 阶梯3目标对冲比例

enum ENUM_HEDGE_RELEASE_MODE
{
   HEDGE_RELEASE_FIXED,    // 固定阈值(总浮盈达标全平)
   HEDGE_RELEASE_DYNAMIC   // 动态(按层数)
};
input ENUM_HEDGE_RELEASE_MODE InpHedgeReleaseMode = HEDGE_RELEASE_FIXED; // ▶ 对冲止盈模式(总浮盈达标全平)
input double           InpHedgeReleaseFixed     = 200.0;                     // ▶ 固定止盈阈值(美分)
input double           InpHedgeReleaseDynPerLayer = 5.0;                    // ▶ 动态止盈每层加(美分)

input group "=== 状态面板 ==="
input bool             InpShowStatusPanel        = DEF_SHOW_PANEL;            // ▶ 显示状态信息面板
input int              InpPanelX                 = DEF_PANEL_X;               // ▶ 面板左边距(像素)
input int              InpPanelY                 = DEF_PANEL_Y;               // ▶ 面板上边距(像素)
input int              InpPanelWidth             = DEF_PANEL_WIDTH;           // ▶ 面板宽度(像素)
input int              InpPanelHeight            = DEF_PANEL_HEIGHT;          // ▶ 面板高度(像素)
input int              InpPanelRefreshSec        = DEF_PANEL_REFRESH_SEC;     // ▶ 面板数据刷新间隔(秒)

input group "=== 历史交易明细 ==="
input int              InpHistoryDays            = DEF_HISTORY_DAYS;           // ▶ 显示最近N天交易记录

CTrade g_trade;
int    g_hEmaFastM1   = INVALID_HANDLE;
int    g_hEmaSlowM1   = INVALID_HANDLE;
int    g_hEmaH4       = INVALID_HANDLE;

double     g_dayStartEquity = 0.0;
double     g_dayStartModulePnl = 0.0;
double     g_dayRealizedPnl = 0.0;
bool       g_dayHasModuleActivity = false;
int        g_dayKey         = -1;
bool       g_dailyLocked    = false;

// Martingale state
ENUM_MART_DIRECTION g_martDirection = MART_DIR_NONE;  // current basket direction
int    g_martLayerCount   = 0;      // current layer count (open positions)
int    g_martMaxLayerSeq  = 0;      // max layer sequence number (from comment _Lxx)
double g_martBasketPeakPnL = 0.0;   // highest basket floating profit (for trailing)
double g_martHighestPrice  = 0.0;   // furthest entry price (for spacing calc)
double g_martLowestPrice   = 0.0;   // furthest entry price (for spacing calc)
double g_martTotalLots     = 0.0;   // total lots in basket
double g_cachedMartPnl     = 0.0;   // cached CalcMartFloatingPnl per tick
bool   g_martHardSLLocked  = false; // hard stop loss triggered (lock until next day)
datetime g_martLastCloseTime = 0;     // last basket close time (for cooldown)
datetime g_martLastLayerTime = 0;     // last individual layer addition time

// Account-based offset (de-correlation across accounts on same symbol)
double g_effATRCoeff    = 0.0;   // Effective ATR spacing coefficient
double g_effBasketTP    = 0.0;   // Effective basket base TP (cents)
double g_effBaseSpacing = 0.0;   // Effective base spacing (points)
int    g_effEmaFast     = 0;     // Effective EMA fast period (偏移后)
int    g_effEmaSlow     = 0;     // Effective EMA slow period (偏移后)

// 每层TP累计目标（启动时按账号种子生成稳定序列，每层增量在 InpMartBasketTPPerLayer × (1 ± 25%) 范围）
// 防止多EA单边大趋势下同时触发TP共振，索引=层序号-1，0=首层
#define MAX_TP_LAYERS 40
double g_tpCumulative[MAX_TP_LAYERS];

// 速度模式（运行时按钮动态切换 ATR 系数）：0=稳(0.20) 1=中(0.15) 2=快(0.10)
int    g_speedMode      = 1;     // 默认中速

// Fast loss breaker state（V1.14: 基于价格振幅判断，与仓位规模解耦）
datetime   g_fastLossStartTime   = 0;    // 当前窗口起始时间
bool       g_fastLossLocked      = false;
double     g_fastLossPeakPrice   = 0.0;  // 窗口内对己最有利的极值价（多头记最高,空头记最低）
double     g_fastLossLockPrice   = 0.0;  // 触发锁定时记录的Bid价，用作回调解锁基准
int        g_fastLossLockDir     = 0;    // 锁定时的马丁方向（1=BUY,2=SELL）

bool       g_closedPnlDirty = true;        // 标记需要重新计算

string MART_COMMENT = "XAU_MART";
#define HEDGE_COMMENT "XAU_HEDGE"   // 对冲单专用注释（不含MART_COMMENT前缀）

// Hedge state
bool   g_hedgeActive = false;      // 是否有活跃对冲单
int    g_hedgeCount = 0;           // 对冲单数量
double g_hedgeLots = 0.0;          // 对冲单总手数
double g_hedgePnl = 0.0;           // 对冲单浮盈

bool   g_addAtrPaused = false;     // ATR扩张暂停加仓状态
double g_addAtrRatio  = 0.0;       // 当前ATR短/长比值

bool g_manualPaused = false;
bool g_panelVisible = true;  // 面板可见状态
bool g_panelCreated = false; // 面板是否已创建（替代原 static s_created）
bool g_isTester = false;     // 是否在策略测试器中运行
string g_noEntryReason = "";   // 不建仓原因

// --- 历史交易明细全局变量 ---
DailyTradeRecord g_historyRecords[];
int              g_historyCount = 0;
bool             g_historyPanelVisible = false;
double           g_todayMaxDrawdown = 0.0;    // 当日最大浮亏追踪
double           g_todayMaxDDPct = 0.0;       // 当日最大浮亏比追踪

string           g_licenseExpiry = "";        // 授权到期日期

// Panel object names
string PNL_PREFIX       = "HYB_";
string OBJ_BG           = "HYB_BG";
string OBJ_TOPBAR       = "HYB_TOPBAR";
string OBJ_HEADER       = "HYB_HEADER";
string OBJ_SUBHDR       = "HYB_SUBHDR";
string OBJ_LOGO         = "HYB_LOGO";
string OBJ_CARD1_BG     = "HYB_CARD1_BG";
string OBJ_CARD1_T      = "HYB_CARD1_T";
string OBJ_CARD1_V      = "HYB_CARD1_V";
string OBJ_CARD1_S      = "HYB_CARD1_S";
string OBJ_CARD2_BG     = "HYB_CARD2_BG";
string OBJ_CARD2_T      = "HYB_CARD2_T";
string OBJ_CARD2_V      = "HYB_CARD2_V";
string OBJ_CARD2_S      = "HYB_CARD2_S";
string OBJ_CARD3_BG     = "HYB_CARD3_BG";
string OBJ_CARD3_T      = "HYB_CARD3_T";
string OBJ_CARD3_V      = "HYB_CARD3_V";
string OBJ_CARD3_S      = "HYB_CARD3_S";
string OBJ_LINE0        = "HYB_LINE0";
string OBJ_LINE1        = "HYB_LINE1";
string OBJ_LINE2        = "HYB_LINE2";
string OBJ_LINE3        = "HYB_LINE3";
string OBJ_LINE4        = "HYB_LINE4";
string OBJ_LINE5        = "HYB_LINE5";
string OBJ_SMC_BG1    = "HYB_SMC_BG1";    // 大周期卡片背景
string OBJ_SMC_BG2    = "HYB_SMC_BG2";    // 中周期卡片背景
string OBJ_SMC_BG3    = "HYB_SMC_BG3";    // 小周期卡片背景
string OBJ_SMC_T1     = "HYB_SMC_T1";     // 大周期标题
string OBJ_SMC_T2     = "HYB_SMC_T2";     // 中周期标题
string OBJ_SMC_T3     = "HYB_SMC_T3";     // 小周期标题
string OBJ_SMC_D1A    = "HYB_SMC_D1A";    // Imbalance
string OBJ_SMC_D1B    = "HYB_SMC_D1B";    // S/D Zone
string OBJ_SMC_D1S    = "HYB_SMC_D1S";    // 大周期小计
string OBJ_SMC_D2A    = "HYB_SMC_D2A";    // OrderBlock
string OBJ_SMC_D2B    = "HYB_SMC_D2B";    // FVG
string OBJ_SMC_D2S    = "HYB_SMC_D2S";    // 中周期小计
string OBJ_SMC_D3A    = "HYB_SMC_D3A";    // LiqVoid
string OBJ_SMC_D3B    = "HYB_SMC_D3B";    // Breaker
string OBJ_SMC_D3S    = "HYB_SMC_D3S";    // 小周期小计
string OBJ_SMC_TOTAL  = "HYB_SMC_TOTAL";  // 综合得分行
string OBJ_SMC_OFFSET = "HYB_SMC_OFFSET"; // 账户偏移参数（综合行右侧独立Label，避开63字符上限）
string OBJ_BTN1         = "HYB_BTN_CLOSEBUY";
string OBJ_BTN2         = "HYB_BTN_CLOSESELL";
string OBJ_BTN3         = "HYB_BTN_CLOSEPROFIT";
string OBJ_BTN4         = "HYB_BTN_CLOSELOSS";
string OBJ_BTN5         = "HYB_BTN_CLOSEALL";
string OBJ_BTN6         = "HYB_BTN_PAUSE";
string OBJ_CHART_BG     = "HYB_CHART_BG";
string OBJ_LOGO_FRAME   = "HYB_LOGO_FRAME";
string OBJ_BTN_BG       = "HYB_BTN_BG";
string OBJ_BTN_TOGGLE   = "HYB_BTN_TOGGLE";
// 速度模式按钮（顶栏右上：稳/中/快）
string OBJ_BTN_SPEED_S  = "HYB_BTN_SPEED_S";  // 稳 = 0.20
string OBJ_BTN_SPEED_M  = "HYB_BTN_SPEED_M";  // 中 = 0.15
string OBJ_BTN_SPEED_F  = "HYB_BTN_SPEED_F";  // 快 = 0.10
string BG_RES           = "::HYB_BG_RES";
string LOGO_RES         = "::HYB_LOGO_RES";

int g_panelX = 10;
int g_panelY = 16;
int g_panelW = 580;
int g_panelH = 320;

// Background image source data (loaded once from BMP)
uint g_bgSrcPixels[];
int  g_bgSrcW = 0;
int  g_bgSrcH = 0;

// Logo image source data (loaded once from BMP)
uint g_logoSrcPixels[];
int  g_logoSrcW = 0;
int  g_logoSrcH = 0;

// Signal diagnostic cache (for panel display)
bool   g_sigMartEntryOk     = false;
int    g_sigMartEmaDir      = 0;       // 1=up, -1=down, 0=neutral
int    g_sigMartEmaScoreLong  = 0;     // EMA分级评分(多头) 0/弱/中/强
int    g_sigMartEmaScoreShort = 0;     // EMA分级评分(空头) 0/弱/中/强
double g_sigMartEmaFastVal  = 0.0;
double g_sigMartEmaSlowVal  = 0.0;
double g_sigMartClose1      = 0.0;
bool   g_sigH4Confirmed     = false;
double g_sigH4EmaVal        = 0.0;
int    g_sigMartDistToNext  = 0;       // points to next layer trigger
double g_sigMartBasketPnL   = 0.0;     // current basket floating PnL

// SMC signal cache
int    g_smcDirection       = 0;       // 1=看涨, -1=看跌, 0=中立
int    g_smcScore           = 0;       // SMC综合得分
int    g_smcImbalanceResult   = 0;   // 1=看涨, -1=看跌, 0=无
int    g_smcSDZoneResult      = 0;
int    g_smcOrderBlockResult  = 0;
int    g_smcFVGResult         = 0;
int    g_smcLiqVoidResult     = 0;
int    g_smcBreakerResult     = 0;
int    g_hATR_H4            = INVALID_HANDLE;   // H4 ATR句柄
int    g_hATR_H1            = INVALID_HANDLE;   // H1 ATR句柄
int    g_hATR_M15           = INVALID_HANDLE;   // M15 ATR句柄
int    g_hATR_Spacing       = INVALID_HANDLE;   // ATR动态间距-短(入场TF,3)
int    g_hATR_SpacingLong   = INVALID_HANDLE;   // ATR动态间距-长(入场TF,6)
int    g_hCCI              = INVALID_HANDLE;   // CCI句柄

void   ComputeSignalDiagnostics();
string GetBlockingReason();
double GetHedgeTargetRatio(const double floatingPnl);
double GetATRExpansionRatio();
bool   IsATRAddPaused();
bool   IsEntryChaseBlocked(const ENUM_POSITION_TYPE side);
double GetDeepProtectTPFactor(const int layers);
string GetNewsBlockReason();
int    GetUs0830DataMinuteBeijing(const MqlDateTime &chinaTime);

// ========== 离线授权码验证 ==========
#define LICENSE_XOR_KEY "JPX2025GoldEA!@#"   // XOR密钥，必须与Python生成工具一致

// Base64解码
int Base64Decode(string encoded, uchar &output[])
{
   // 标准Base64解码实现
   string base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
   int len = StringLen(encoded);
   // 去除末尾=
   int padding = 0;
   if(len > 0 && StringGetCharacter(encoded, len-1) == '=') padding++;
   if(len > 1 && StringGetCharacter(encoded, len-2) == '=') padding++;

   int outLen = len * 3 / 4 - padding;
   if(outLen <= 0) return 0;
   ArrayResize(output, outLen);

   int j = 0;
   for(int i = 0; i < len; i += 4)
   {
      int n = 0;
      for(int k = 0; k < 4; k++)
      {
         n <<= 6;
         if(i + k < len)
         {
            ushort ch = StringGetCharacter(encoded, i + k);
            if(ch == '=') continue;
            int idx = StringFind(base64chars, CharToString((uchar)ch));
            if(idx >= 0) n |= idx;
         }
      }
      if(j < outLen) output[j++] = (uchar)((n >> 16) & 0xFF);
      if(j < outLen) output[j++] = (uchar)((n >> 8) & 0xFF);
      if(j < outLen) output[j++] = (uchar)(n & 0xFF);
   }
   return outLen;
}

// XOR解密
string XorDecrypt(uchar &data[], string key)
{
   int keyLen = StringLen(key);
   if(keyLen == 0) return "";

   string result = "";
   for(int i = 0; i < ArraySize(data); i++)
   {
      ushort keyChar = StringGetCharacter(key, i % keyLen);
      uchar decrypted = (uchar)(data[i] ^ (uchar)keyChar);
      result += CharToString(decrypted);
   }
   return result;
}

// 验证授权码
bool ValidateLicense(string licenseKey, string &outAccount, string &outExpiry, string &outError)
{
   if(StringLen(licenseKey) == 0)
   {
      outError = "未输入授权码";
      return false;
   }

   // Base64解码
   uchar decoded[];
   int decLen = Base64Decode(licenseKey, decoded);
   if(decLen <= 0)
   {
      outError = "授权码格式错误";
      return false;
   }

   // XOR解密
   string plain = XorDecrypt(decoded, LICENSE_XOR_KEY);

   // 解析 "账号|YYYYMMDD"
   int sep = StringFind(plain, "|");
   if(sep < 0)
   {
      outError = "授权码无效";
      return false;
   }

   outAccount = StringSubstr(plain, 0, sep);
   outExpiry = StringSubstr(plain, sep + 1);

   // 校验账号
   long currentAccount = AccountInfoInteger(ACCOUNT_LOGIN);
   string currentAccountStr = IntegerToString(currentAccount);
   if(outAccount != currentAccountStr)
   {
      outError = StringFormat("授权账号不匹配(授权:%s 当前:%s)", outAccount, currentAccountStr);
      return false;
   }

   // 校验日期 YYYYMMDD
   if(StringLen(outExpiry) != 8)
   {
      outError = "授权码日期格式错误";
      return false;
   }

   int year = (int)StringToInteger(StringSubstr(outExpiry, 0, 4));
   int month = (int)StringToInteger(StringSubstr(outExpiry, 4, 2));
   int day = (int)StringToInteger(StringSubstr(outExpiry, 6, 2));

   MqlDateTime expDt;
   expDt.year = year;
   expDt.mon = month;
   expDt.day = day;
   expDt.hour = 23;
   expDt.min = 59;
   expDt.sec = 59;

   datetime expTime = StructToTime(expDt);
   datetime now = TimeCurrent();

   if(now > expTime)
   {
      outError = StringFormat("授权已过期(%04d-%02d-%02d)", year, month, day);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Account-based offset: deterministic hash to [-1, 1]               |
//| Uses MurmurHash3-style mixing so adjacent account numbers         |
//| produce well-separated offset values (avoids clustering).         |
//+------------------------------------------------------------------+
double GetAccountOffset(long salt)
{
   long acc = AccountInfoInteger(ACCOUNT_LOGIN);
   // Integer hash mixing (32-bit) — sufficient spread for de-correlation
   int h = (int)(acc ^ salt);
   h = (h ^ 61) ^ (h >> 16);
   h = h + (h << 3);
   h = h ^ (h >> 4);
   h = h * 0x27D4EB2D;
   h = h ^ (h >> 15);
   // 严格映射到 [-1.0, 1.0]（1/(2^31-1)*2 -1）
   return (double)(h & 0x7FFFFFFF) / 2147483647.0 * 2.0 - 1.0;
}

//+------------------------------------------------------------------+
//| Apply account offsets to selected parameters (called in OnInit)   |
//| Offset ranges: ATR coeff ±15%, Basket TP ±25%, Base spacing ±20% |
//| 回测/优化模式下使用原始参数，便于参数评估与结果复现           |
//+------------------------------------------------------------------+
void ApplyAccountOffsets()
{
   // 回测/优化模式下跳过随机偏移，避免结果不可复现
   if(g_isTester)
   {
      g_effATRCoeff    = InpMartATRSpacingCoeff;
      g_effBasketTP    = InpMartBasketTP_USD;
      g_effBaseSpacing = InpMartBaseSpacingPts;
      g_effEmaFast     = InpMartEmaFastPeriod;
      g_effEmaSlow     = InpMartEmaSlowPeriod;
      PrintFormat("[账户偏移] 回测/优化模式，使用原始参数 | ATR系数=%.4f TP基础=%.1f 基准间距=%d EMA=%d/%d",
                  g_effATRCoeff, g_effBasketTP, InpMartBaseSpacingPts, g_effEmaFast, g_effEmaSlow);
      return;
   }

   g_effATRCoeff    = InpMartATRSpacingCoeff * (1.0 + GetAccountOffset(1) * 0.15);
   g_effBasketTP    = InpMartBasketTP_USD   * (1.0 + GetAccountOffset(2) * 0.25);
   g_effBaseSpacing = InpMartBaseSpacingPts  * (1.0 + GetAccountOffset(3) * 0.20);

   // EMA 偏移: Fast ±15%, Slow ±10%（取整，保证 fast < slow）
   double emaFastOff = GetAccountOffset(4) * 0.15;  // [-0.15, +0.15]
   double emaSlowOff = GetAccountOffset(5) * 0.10;  // [-0.10, +0.10]
   g_effEmaFast = (int)MathRound(InpMartEmaFastPeriod * (1.0 + emaFastOff));
   g_effEmaSlow = (int)MathRound(InpMartEmaSlowPeriod * (1.0 + emaSlowOff));
   // 安全约束: Fast≥3, Slow≥Fast+3
   if(g_effEmaFast < 3) g_effEmaFast = 3;
   if(g_effEmaSlow <= g_effEmaFast + 2) g_effEmaSlow = g_effEmaFast + 3;

   // Floor: prevent parameters going too low (but respect 0=disabled)
   if(InpMartATRSpacingCoeff > 0.0 && g_effATRCoeff < 0.001)  g_effATRCoeff = 0.001;
   if(InpMartBasketTP_USD > 0.0   && g_effBasketTP < 1.0)    g_effBasketTP = 1.0;
   if(InpMartBaseSpacingPts > 0   && g_effBaseSpacing < 20.0) g_effBaseSpacing = 20.0;

   PrintFormat("[账户偏移] 账号=%lld | ATR系数=%.4f(原%.4f) TP基础=%.1f(原%.1f) 基准间距=%.0f(原%d) EMA=%d/%d(原%d/%d)",
               AccountInfoInteger(ACCOUNT_LOGIN), g_effATRCoeff, InpMartATRSpacingCoeff,
               g_effBasketTP, InpMartBasketTP_USD,
               g_effBaseSpacing, InpMartBaseSpacingPts,
               g_effEmaFast, g_effEmaSlow, InpMartEmaFastPeriod, InpMartEmaSlowPeriod);
}

//+------------------------------------------------------------------+
//| 生成每层TP累计目标序列（防多EA共振触发TP）                       |
//| 实盘：每层增量 = InpMartBasketTPPerLayer × (1 + offset(100+i)×0.25)|
//| 回测：每层固定 = InpMartBasketTPPerLayer（保证结果可复现）        |
//+------------------------------------------------------------------+
void BuildTpCumulative()
{
   g_tpCumulative[0] = g_effBasketTP;
   bool tester = g_isTester;
   double baseInc = InpMartBasketTPPerLayer;
   string sample = "";
   for(int i = 1; i < MAX_TP_LAYERS; i++)
   {
      double inc;
      if(tester || baseInc <= 0.0)
      {
         inc = baseInc;
      }
      else
      {
         // ±25% 偏移，每层独立种子(salt=100+i)
         inc = baseInc * (1.0 + GetAccountOffset((long)(100 + i)) * 0.25);
         // Floor: 防止增量过小
         if(inc < baseInc * 0.5) inc = baseInc * 0.5;
      }
      g_tpCumulative[i] = g_tpCumulative[i-1] + inc;
      if(i <= 5)
         sample += StringFormat(" L%d=%.1f", i+1, g_tpCumulative[i]);
   }
   PrintFormat("[TP序列] 基础=%.1f 每层基准增量=%.1f%s ... L%d=%.1f",
               g_tpCumulative[0], baseInc, sample,
               MAX_TP_LAYERS, g_tpCumulative[MAX_TP_LAYERS-1]);
}

//+------------------------------------------------------------------+
//| 查表获取当前层动态TP目标（统一入口，避免多处公式不一致）         |
//+------------------------------------------------------------------+
double GetDynamicTP(int layers)
{
   if(layers < 1) layers = 1;
   int idx = MathMin(layers - 1, MAX_TP_LAYERS - 1);
   double rawTP = g_tpCumulative[idx];
   if(!InpEnableDeepProtectTP)
      return rawTP;

   double factor = GetDeepProtectTPFactor(layers);
   double guardedTP = rawTP * factor;
   if(factor < 0.999 && InpDeepTPMinProfit > 0.0)
      guardedTP = MathMax(guardedTP, InpDeepTPMinProfit);
   return guardedTP;
}

double GetDeepProtectTPFactor(const int layers)
{
   if(!InpEnableDeepProtectTP)
      return 1.0;

   double factor = 1.0;
   if(InpDeepTPLevel1Start > 0 && layers >= InpDeepTPLevel1Start)
      factor = InpDeepTPLevel1Factor;
   if(InpDeepTPLevel2Start > 0 && layers >= InpDeepTPLevel2Start)
      factor = InpDeepTPLevel2Factor;
   if(InpDeepTPLevel3Start > 0 && layers >= InpDeepTPLevel3Start)
      factor = InpDeepTPLevel3Factor;

   if(factor <= 0.0) factor = 1.0;
   if(factor > 1.0) factor = 1.0;
   return factor;
}

//+------------------------------------------------------------------+
//| 速度模式切换：直接覆盖 g_effATRCoeff 与高亮按钮                   |
//| 0=稳(0.20) 1=中(0.15) 2=快(0.10)                                 |
//+------------------------------------------------------------------+
void RefreshSpeedButtons()
{
   if(g_isTester) return;
   string names[3] = {OBJ_BTN_SPEED_S, OBJ_BTN_SPEED_M, OBJ_BTN_SPEED_F};
   for(int i = 0; i < 3; i++)
   {
      if(ObjectFind(0, names[i]) < 0) continue;
      bool active = (i == g_speedMode);
      ObjectSetInteger(0, names[i], OBJPROP_BGCOLOR, active ? C'230,180,40' : C'80,90,110');
      ObjectSetInteger(0, names[i], OBJPROP_BORDER_COLOR, active ? clrWhite : C'150,160,180');
      ObjectSetInteger(0, names[i], OBJPROP_COLOR,  active ? C'30,30,30' : clrWhite);
      ObjectSetInteger(0, names[i], OBJPROP_STATE, false);
   }
}

void SetSpeedMode(int mode)
{
   if(mode < 0 || mode > 2) return;
   g_speedMode = mode;
   double values[3] = {0.20, 0.15, 0.10};
   double base = values[mode];
   // 在檔位基准值上应用账号偏移，避免多实例ATR系数完全相同
   if(!g_isTester)
      g_effATRCoeff = base * (1.0 + GetAccountOffset(1) * 0.15);
   else
      g_effATRCoeff = base;
   if(g_effATRCoeff < 0.01) g_effATRCoeff = 0.01;  // 地板保护
   RefreshSpeedButtons();
   string label = (mode == 0 ? "稳" : (mode == 1 ? "中" : "快"));
   PrintFormat("[速度切换] 模式=%s | ATR系数=%.4f(基准%.2f)", label, g_effATRCoeff, base);
}

int OnInit()
  {
   // 检测回测/优化模式
   g_isTester = (bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   // === 离线授权码验证 ===
   // 回测模式跳过授权验证
   if(!g_isTester)
   {
      string licAccount, licExpiry, licError;
      if(!ValidateLicense(InpLicenseKey, licAccount, licExpiry, licError))
      {
         Alert("授权验证失败: ", licError);
         PrintFormat("LICENSE FAILED: %s", licError);
         return INIT_FAILED;
      }
      PrintFormat("授权验证通过: 账号=%s 有效期至=%s", licAccount, licExpiry);
      g_licenseExpiry = licExpiry;
   }
   else
   {
      g_licenseExpiry = "回测模式";
      Print("Tester mode: license check skipped");
   }

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(50);

   ApplyAccountOffsets();  // Account-based parameter de-correlation (must before iMA creation)
   BuildTpCumulative();    // 生成每层TP累计目标序列（每层增量±25%偏移防共振）

   g_hEmaFastM1 = iMA(_Symbol, InpMartEntryTF, g_effEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlowM1 = iMA(_Symbol, InpMartEntryTF, g_effEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaH4     = iMA(_Symbol, PERIOD_H4, InpMartH4EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hEmaFastM1 == INVALID_HANDLE || g_hEmaSlowM1 == INVALID_HANDLE || g_hEmaH4 == INVALID_HANDLE)
     {
      Print("Indicator handle init failed");
      return(INIT_FAILED);
     }

   // SMC ATR indicators (always init for panel display)
   g_hATR_H4  = iATR(_Symbol, PERIOD_H4, 14);
   g_hATR_H1  = iATR(_Symbol, PERIOD_H1, 14);
   g_hATR_M15 = iATR(_Symbol, PERIOD_M15, 14);
   if(g_hATR_H4 == INVALID_HANDLE || g_hATR_H1 == INVALID_HANDLE || g_hATR_M15 == INVALID_HANDLE)
     {
      PrintFormat("[SMC] ATR init: H4=%d, H1=%d, M15=%d (some INVALID)", g_hATR_H4, g_hATR_H1, g_hATR_M15);
      if(InpEntryMode != ENTRY_EMA_ONLY)
        {
         Print("SMC ATR indicator init failed");
         return(INIT_FAILED);
        }
     }
   else
      PrintFormat("[SMC] ATR init OK: H4=%d, H1=%d, M15=%d", g_hATR_H4, g_hATR_H1, g_hATR_M15);

   // ATR spacing handles (entry TF, short+long periods for expansion detection)
   g_hATR_Spacing = iATR(_Symbol, InpMartEntryTF, InpMartATRSpacingPeriod);
   g_hATR_SpacingLong = iATR(_Symbol, InpMartEntryTF, InpMartATRSpacingLongPeriod);
   if(g_hATR_Spacing == INVALID_HANDLE || g_hATR_SpacingLong == INVALID_HANDLE)
      Print("[Mart] ATR spacing handle init failed, dynamic spacing disabled");
   else
      PrintFormat("[Mart] ATR spacing OK: TF=%d, short=%d, long=%d", InpMartEntryTF, InpMartATRSpacingPeriod, InpMartATRSpacingLongPeriod);

   // CCI indicator (optional)
   if(InpSMC_UseCCI)
     {
      g_hCCI = iCCI(_Symbol, InpSMC_CCI_TF, InpSMC_CCIPeriod, PRICE_TYPICAL);
      if(g_hCCI == INVALID_HANDLE)
        {
         Print("CCI indicator init failed");
         return(INIT_FAILED);
        }
     }

   if(!IsHedgingAccount())
      Print("Warning: non-hedging account detected. Martingale requires hedging.");

   // Cent account check
   string acctCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   bool isCent = (StringFind(acctCurrency, "USC") >= 0 || StringFind(acctCurrency, "CEN") >= 0);
   if(!isCent)
      Print("Warning: non-cent account (", acctCurrency, "). All PnL values are in account currency units. For cent accounts expect USC/CEN.");
   else
      Print("Cent account detected (", acctCurrency, "). PnL values in cents.");

   // 注意：不在 OnInit 调用 ResetDailyState(true)
   // 否则 EA 中途挂上已有大浮亏的篮子时，g_dayStartModulePnl 不含当前浮亏，
   // 首个 OnTick 会把历史浮亏当作"今日新增亏损"立即触发日亏锁定全平。
   // 改由首次 OnTick 中 ResetDailyState(false) 自动初始化（g_dayKey=-1 会自动进入分支）。
   int timerSec = 0;
   if(InpShowStatusPanel)
     {
      timerSec = MathMax(1, InpPanelRefreshSec);
      EventSetTimer(timerSec);
     }
   if(InpShowStatusPanel)
     {
      CreateStatusPanel();
      g_panelCreated = true;
      UpdateStatusPanel();
     }
   LoadHistoryFromFile();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   // 彻底清除所有面板对象（按前缀批量删除，比逐个删更可靠）
   ObjectsDeleteAll(0, "HYB_");
   ChartRedraw(0);
   if(g_hEmaFastM1 != INVALID_HANDLE) IndicatorRelease(g_hEmaFastM1);
   if(g_hEmaSlowM1 != INVALID_HANDLE) IndicatorRelease(g_hEmaSlowM1);
   if(g_hEmaH4     != INVALID_HANDLE) IndicatorRelease(g_hEmaH4);
   if(g_hATR_H4 != INVALID_HANDLE)  IndicatorRelease(g_hATR_H4);
   if(g_hATR_H1 != INVALID_HANDLE)  IndicatorRelease(g_hATR_H1);
   if(g_hATR_M15 != INVALID_HANDLE) IndicatorRelease(g_hATR_M15);
   if(g_hATR_Spacing != INVALID_HANDLE) IndicatorRelease(g_hATR_Spacing);
   if(g_hATR_SpacingLong != INVALID_HANDLE) IndicatorRelease(g_hATR_SpacingLong);
   if(g_hCCI != INVALID_HANDLE) IndicatorRelease(g_hCCI);
  }

void OnTimer()
  {
   ComputeSignalDiagnostics();
   if(InpShowStatusPanel)
      UpdateStatusPanel();
  }

void OnTick()
  {

   g_cachedMartPnl = CalcMartFloatingPnl();
   RefreshHedgeState();

   // 追踪当日最大回撤金额（北京时间，从日初模块盈亏峰值算起）
   {
      double modulePnlNow = g_dayRealizedPnl + GetEffectivePnL();
      double drawdownAmt = g_dayStartModulePnl - modulePnlNow;
      if(drawdownAmt > g_todayMaxDrawdown)
        {
         g_todayMaxDrawdown = drawdownAmt;
         double eqNow = AccountInfoDouble(ACCOUNT_EQUITY);
         if(eqNow > 0.0)
            g_todayMaxDDPct = drawdownAmt / eqNow * 100.0;
        }
   }

   ResetDailyState(false);

   // Daily loss lock check
   if(CheckDailyLossLock())
     {
      CloseAllMartPositions();
      g_dailyLocked = true;
      g_noEntryReason = "日亏损锁定(超" + DoubleToString(InpMaxDailyLossPercent,1) + "%)";
      return;
     }

   if(g_dailyLocked || g_martHardSLLocked)
     {
      if(g_dailyLocked)
         g_noEntryReason = "日亏损锁定(超" + DoubleToString(InpMaxDailyLossPercent,1) + "%)";
      else
         g_noEntryReason = "硬止损熔断(浮亏超$" + DoubleToString(InpMartHardSL_USD,0) + ")";
      return;
     }

   // Fast loss breaker
   CheckFastLossBreaker();
   if(g_fastLossLocked)
     {
      g_noEntryReason = "快速亏损熔断(锁开仓,等回调)";
      // 锁定期保留已有持仓等回调，仍跑止盈/硬止损/追踪/对冲管理
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();      // 对冲PnL必须每 tick 刷新，否则 GetEffectivePnL 失真
         ManageHedgeLock();        // 允许对冲保护在熔断期间仍能激活/追加
         ManageHedgeRelease();     // 对冲止盈仍需运行（追踪已被 hedgeActive 跳过）
         ManageMartBasketTP();
         CheckMartHardSL();
         ManageMartTrailing();
        }
      else
        {
         // 篮子已全平但本分支 return 跳过了主逻辑的 g_martDirection 重置点
         // 手动置 NONE，使下一 tick CheckFastLossBreaker 的 NONE 分支自动解除锁定
         g_martDirection = MART_DIR_NONE;
        }
      ComputeSignalDiagnostics();
      return;
     }

   if(IsSpreadTooHigh())
     {
      g_noEntryReason = "点差过大(" + DoubleToString(GetCurrentSpreadPoints(),0) + ">" + IntegerToString(InpMaxSpreadPoints) + ")";
      return;
     }

   // News filter: lock new entries/layers only; keep existing risk management running.
   if(IsManualNewsBlocked())
     {
      g_noEntryReason = GetNewsBlockReason();
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();
         ManageHedgeLock();
         ManageHedgeRelease();
         ManageMartBasketTP();
         CheckMartHardSL();
         ManageMartTrailing();
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   // Session check
   if(!IsInMartSession())
     {
      g_noEntryReason = "非交易时段";
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();
         ManageHedgeLock();
         ManageHedgeRelease();
         ManageMartBasketTP();
         CheckMartHardSL();
         ManageMartTrailing();
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   // Manual pause check
   if(g_manualPaused)
     {
      g_noEntryReason = "手动暂停交易中";
      // 暂停时仍执行止盈止损和风控（含对冲管理）
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();
         ManageHedgeLock();
         ManageHedgeRelease();
         ManageMartBasketTP();
         CheckMartHardSL();
         ManageMartTrailing();
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   // Hedge lock check (default off)
   ManageHedgeLock();
   ManageHedgeRelease();

   // === Core Martingale Logic ===
   int totalPos = CountMartPositions();

   if(totalPos == 0)
     {
      // Reset martingale state
      g_martDirection = MART_DIR_NONE;
      g_martLayerCount = 0;
      g_martMaxLayerSeq = 0;
      g_martBasketPeakPnL = 0.0;
      g_martHighestPrice = 0.0;
      g_martLowestPrice = 0.0;
      g_martTotalLots = 0.0;
      g_cachedMartPnl = 0.0;
      g_martLastLayerTime = 0;

      // Cooldown check: prevent immediate re-entry after basket close
      if(InpMartCooldownSec > 0 && g_martLastCloseTime > 0)
        {
         if(TimeCurrent() - g_martLastCloseTime < InpMartCooldownSec)
           {
            g_noEntryReason = "平仓冷却期(" + IntegerToString(InpMartCooldownSec) + "秒)";
            return;
           }
        }

      g_noEntryReason = "";  // 冷却期已过，清空旧原因，由TryMartEntry重新评估
      TryMartEntry();
     }
   else
     {
      g_noEntryReason = "";  // 已有持仓，不需要显示首单原因
      // Refresh basket state from open positions
      RefreshMartBasketState();
      RefreshHedgeState();

      ManageMartBasketTP();
      CheckMartHardSL();
      ManageMartTrailing();
      TryMartAddLayer();
     }

   ComputeSignalDiagnostics();
   if(InpShowStatusPanel)
      UpdateStatusPanel();
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(g_isTester) return;

   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      // 切换按钮必须最先检查，防止与其他按钮位置重叠时误触发
      if(sparam == OBJ_BTN_TOGGLE)
        {
         SetPanelVisibility(!g_panelVisible);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return;  // 直接返回，不再检查其他按钮
        }
      // 面板隐藏时不处理其他按钮点击
      if(!g_panelVisible) return;
      if(sparam == OBJ_BTN1) // 平多单仓
        {
         CloseMartByDirection(POSITION_TYPE_BUY);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == OBJ_BTN2) // 平空单仓
        {
         CloseMartByDirection(POSITION_TYPE_SELL);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == OBJ_BTN3) // 平盈利仓
        {
         CloseMartByProfit(true);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == OBJ_BTN4) // 平亏损仓
        {
         CloseMartByProfit(false);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == OBJ_BTN5) // 全部平仓
        {
         CloseAllMartPositions();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == OBJ_BTN6) // 暂停/恢复
        {
         g_manualPaused = !g_manualPaused;
         ObjectSetString(0, OBJ_BTN6, OBJPROP_TEXT, g_manualPaused ? "恢复交易" : "暂停交易");
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        }
      else if(sparam == "HYB_BTN_HIST") // 历史明细
        {
         g_historyPanelVisible = !g_historyPanelVisible;
         if(g_historyPanelVisible)
         {
            LoadHistoryFromFile();
            CreateHistoryPanel();
         }
         else
            DestroyHistoryPanel();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return;
        }
      else if(sparam == "HYB_HIST_CLOSE") // 关闭历史面板
        {
         g_historyPanelVisible = false;
         DestroyHistoryPanel();
         return;
        }
      else if(sparam == OBJ_BTN_SPEED_S) // 稳=0.20
        {
         SetSpeedMode(0);
        }
      else if(sparam == OBJ_BTN_SPEED_M) // 中=0.15
        {
         SetSpeedMode(1);
        }
      else if(sparam == OBJ_BTN_SPEED_F) // 快=0.10
        {
         SetSpeedMode(2);
        }
     }
  }

void OnTrade()
  {
   g_closedPnlDirty = true;
   double prev = g_dayRealizedPnl;
   if(g_closedPnlDirty)
   {
      g_dayRealizedPnl = CalcMartClosedPnlToday();
      g_closedPnlDirty = false;
   }
   if(MathAbs(g_dayRealizedPnl - prev) > 1e-8)
      g_dayHasModuleActivity = true;
  }

//=== Martingale Helper Functions ===

datetime GetChinaNow()
  {
   if(InpAutoServerUtcOffset)
      return TimeGMT() + InpChinaUtcOffsetHours * 3600;
   return TimeCurrent() - InpServerUtcOffsetHours * 3600 + InpChinaUtcOffsetHours * 3600;
  }

void CloseAllMartPositions()
  {
   bool hadPositions = false;
   double totalClosedLots = 0.0;
   double totalClosedPnl = 0.0;
   double closedPnlBefore = CalcMartClosedPnlToday();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL)))
         continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) < 0 && StringFind(cmt, HEDGE_COMMENT) < 0)
         continue;
      double posLots = PositionGetDouble(POSITION_VOLUME);
      if(ClosePositionChecked(ticket))
        {
         totalClosedLots += posLots;
         hadPositions = true;
        }
     }
   CancelMartOrders();
   if(hadPositions)
     {
      totalClosedPnl = CalcMartClosedPnlToday() - closedPnlBefore;
      g_martLastCloseTime = TimeCurrent();
      g_hedgeActive = false;
      g_cachedMartPnl = 0.0;
      RecordTradeToHistory(totalClosedLots, totalClosedPnl);
     }
  }

void CancelMartOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, MART_COMMENT) >= 0)
         g_trade.OrderDelete(ticket);
     }
  }

void CloseMartByDirection(ENUM_POSITION_TYPE dir)
  {
   bool closedAny = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt_d = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt_d, MART_COMMENT) < 0 && StringFind(cmt_d, HEDGE_COMMENT) < 0) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != dir) continue;
      if(ClosePositionChecked(ticket)) closedAny = true;
     }
   if(closedAny) g_martLastCloseTime = TimeCurrent();
  }

void CloseMartByProfit(bool profitableOnly)
  {
   bool closedAny = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt_p = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt_p, MART_COMMENT) < 0 && StringFind(cmt_p, HEDGE_COMMENT) < 0) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profitableOnly && profit <= 0.0) continue;
      if(!profitableOnly && profit >= 0.0) continue;
      if(ClosePositionChecked(ticket)) closedAny = true;
     }
   if(closedAny) g_martLastCloseTime = TimeCurrent();
  }

int CountMartPositions()
  {
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL)))
         continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) >= 0 && StringFind(cmt, HEDGE_COMMENT) < 0)
         cnt++;
     }
   return cnt;
  }

double CalcMartFloatingPnl()
  {
   double pnl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL)))
         continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) >= 0 && StringFind(cmt, HEDGE_COMMENT) < 0)
         pnl += PositionGetDouble(POSITION_PROFIT);
     }
   return pnl;
  }

double GetEffectivePnL()
  {
   double total = g_cachedMartPnl;
   if(g_hedgeActive)
      total += g_hedgePnl;
   return total;
  }

double CalcMartClosedPnlToday()
  {
   datetime chinaNow = GetChinaNow();
   MqlDateTime t;
   TimeToStruct(chinaNow, t);
   t.hour = 0;
   t.min = 0;
   t.sec = 0;
   datetime dayStartBeijing = StructToTime(t);

   // 将北京时间转换为服务器时间，HistorySelect 使用服务器时间
   long tzDiff = (long)(chinaNow - TimeCurrent());
   datetime dayStartServer = (datetime)((long)dayStartBeijing - tzDiff);
   datetime nowServer = TimeCurrent();

   if(!HistorySelect(dayStartServer, nowServer))
      return 0.0;

   double pnl = 0.0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; ++i)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(HistoryDealGetString(deal, DEAL_SYMBOL))) continue;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;
      // 不检查注释：平仓成交的DEAL_COMMENT可能被服务器覆盖为空或"[tp]/[sl]"等，
      // 仅依靠 MagicNumber + Symbol + DEAL_ENTRY_OUT 过滤即可
      pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
     }
   return pnl;
  }

void RefreshMartBasketState()
  {
   g_martLayerCount = 0;
   g_martTotalLots = 0.0;
   g_martHighestPrice = 0.0;
   g_martLowestPrice = DBL_MAX;
   int buys = 0, sells = 0;
   double floatingPnl = 0.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) < 0) continue;
      if(StringFind(cmt, HEDGE_COMMENT) >= 0) continue;  // 跳过对冲单

      g_martLayerCount++;
      g_martTotalLots += PositionGetDouble(POSITION_VOLUME);
      floatingPnl += PositionGetDouble(POSITION_PROFIT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      long type = PositionGetInteger(POSITION_TYPE);

      // 从comment解析层序号取最大值
      int posL = StringFind(cmt, "_L");
      if(posL >= 0)
        {
         string seqStr = StringSubstr(cmt, posL + 2);
         int layerSeq = (int)StringToInteger(seqStr);
         // 验证解析结果合理性（0-999范围）
         if(layerSeq >= 0 && layerSeq < 1000)
           {
            if(layerSeq + 1 > g_martMaxLayerSeq) g_martMaxLayerSeq = layerSeq + 1;
           }
         else
           {
            PrintFormat("[V1.09] 警告: 订单#%d 注释层序号异常: %s", ticket, seqStr);
           }
        }
      else if(StringFind(cmt, MART_COMMENT) >= 0)
        {
         // 马丁单但缺少_L标记，记录警告
         PrintFormat("[V1.09] 警告: 马丁订单#%d 缺少_L层序号标记, comment=%s", ticket, cmt);
        }

      if(type == POSITION_TYPE_BUY)
        {
         buys++;
         if(openPrice > g_martHighestPrice) g_martHighestPrice = openPrice;
         if(openPrice < g_martLowestPrice) g_martLowestPrice = openPrice;
        }
      else
        {
         sells++;
         if(openPrice > g_martHighestPrice) g_martHighestPrice = openPrice;
         if(openPrice < g_martLowestPrice) g_martLowestPrice = openPrice;
        }
     }

   if(g_martLowestPrice == DBL_MAX) g_martLowestPrice = 0.0;

   if(buys > 0 && sells == 0) g_martDirection = MART_DIR_BUY;
   else if(sells > 0 && buys == 0) g_martDirection = MART_DIR_SELL;
   else g_martDirection = MART_DIR_NONE;

   // 回退逻辑：若注释解析失败但有持仓，用持仓数推算层序号
   if(g_martMaxLayerSeq == 0 && g_martLayerCount > 1)
     {
      g_martMaxLayerSeq = g_martLayerCount;
      PrintFormat("[V1.09] 层序号回退: 使用持仓数 %d 作为 g_martMaxLayerSeq", g_martLayerCount);
     }

   g_martBasketPeakPnL = MathMax(g_martBasketPeakPnL, floatingPnl + (g_hedgeActive ? g_hedgePnl : 0.0));
   g_cachedMartPnl = floatingPnl;
  }

void RefreshHedgeState()
  {
   g_hedgeActive = false;
   g_hedgeCount = 0;
   g_hedgeLots = 0.0;
   g_hedgePnl = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGE_COMMENT) < 0) continue;

      g_hedgeActive = true;
      g_hedgeCount++;
      g_hedgeLots += PositionGetDouble(POSITION_VOLUME);
      g_hedgePnl += PositionGetDouble(POSITION_PROFIT);
     }
  }

bool IsInMartSession()
  {
   if(InpMartStartHour == 0 && InpMartEndHour == 0)
      return true;
   datetime chinaNow = GetChinaNow();
   MqlDateTime t;
   TimeToStruct(chinaNow, t);
   int hour = t.hour;
   if(InpMartStartHour <= InpMartEndHour)
      return (hour >= InpMartStartHour && hour < InpMartEndHour);
   return (hour >= InpMartStartHour || hour < InpMartEndHour);
  }

//=== Martingale Entry & Management Functions ===

//+------------------------------------------------------------------+
//| EMA分级评分: 根据快/慢线相对位置 + 收盘价位置 + 距慢线的ATR距离  |
//| 满分 = InpSMCWeightEMA(默认30); 强=满分, 中=2/3满分, 弱=1/3满分 |
//|   强(30): 趋势侧 + 收盘价突破快线 + |收盘-慢线|≥0.5×ATR         |
//|   中(20): 趋势侧 + 收盘价突破快线 + 距慢线 < 0.5×ATR             |
//|   弱(10): 趋势侧 + 收盘价位于快慢线之间(回踩中)                  |
//|   0     : 反向 / 快慢线交叉混乱                                  |
//+------------------------------------------------------------------+
void CalcEmaScores(double fast1, double slow1, double close1, int &outLong, int &outShort)
{
   outLong = 0; outShort = 0;
   if(fast1 <= 0.0 || slow1 <= 0.0 || close1 <= 0.0) return;

   bool fastAbove = (fast1 > slow1);
   bool fastBelow = (fast1 < slow1);

   // 收盘价距慢线的距离(用入场TF的ATR做阈值,与动态间距同一根ATR)
   double dist = MathAbs(close1 - slow1);
   double atr  = (g_hATR_Spacing != INVALID_HANDLE) ? GetATRValue(g_hATR_Spacing) : 0.0;
   bool farFromSlow = (atr > 0.0 && dist >= atr * 0.5);

   int strongScore = InpSMCWeightEMA;                                // 满分
   int midScore    = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);    // 2/3
   int weakScore   = (int)MathRound(InpSMCWeightEMA * 1.0 / 3.0);    // 1/3

   // 多头分级: fast > slow
   if(fastAbove)
   {
      if(close1 > fast1)                                  // 收盘在快线上方
         outLong = farFromSlow ? strongScore : midScore;
      else if(close1 >= slow1 && close1 <= fast1)         // 在快慢线之间(回踩)
         outLong = weakScore;
   }

   // 空头分级: fast < slow
   if(fastBelow)
   {
      if(close1 < fast1)                                  // 收盘在快线下方
         outShort = farFromSlow ? strongScore : midScore;
      else if(close1 <= slow1 && close1 >= fast1)         // 在快慢线之间(反弹)
         outShort = weakScore;
   }
}

// Check if we have a valid entry signal on the configured timeframe
bool GetMartSignal(bool &longSignal, bool &shortSignal)
  {
   longSignal = false;
   shortSignal = false;

   // --- EMA signal computation (existing logic) ---
   bool emaLong = false, emaShort = false;

   double emaFast[3], emaSlow[3], close1;
   if(CopyBuffer(g_hEmaFastM1, 0, 0, 3, emaFast) < 3) { g_noEntryReason = "指标数据读取失败"; return false; }
   if(CopyBuffer(g_hEmaSlowM1, 0, 0, 3, emaSlow) < 3) { g_noEntryReason = "指标数据读取失败"; return false; }
   close1 = iClose(_Symbol, InpMartEntryTF, 1);
   if(close1 <= 0.0) { g_noEntryReason = "指标数据读取失败"; return false; }

   // NaN检查
   for(int i = 0; i < 3; i++)
     {
      if(emaFast[i] != emaFast[i] || emaSlow[i] != emaSlow[i])
        {
         g_noEntryReason = "指标数据异常(NaN)";
         return false;
        }
     }

   bool fastAbove = emaFast[1] > emaSlow[1];
   bool fastBelow = emaFast[1] < emaSlow[1];
   bool closeAboveFast = close1 > emaFast[1];
   bool closeBelowFast = close1 < emaFast[1];

   // ---- EMA 分级评分（0/弱/中/强 → 0/10/20/30）----
   int emaScoreLong = 0, emaScoreShort = 0;
   CalcEmaScores(emaFast[1], emaSlow[1], close1, emaScoreLong, emaScoreShort);

   // 暴露给诊断面板
   g_sigMartEmaScoreLong  = emaScoreLong;
   g_sigMartEmaScoreShort = emaScoreShort;

   // 兼容旧布尔判定: ≥2/3满分(默认20) 才视为"成立"，用于EMA_ONLY模式
   int emaPassThreshold = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
   emaLong  = (emaScoreLong  > 0 && emaScoreLong  >= emaPassThreshold);
   emaShort = (emaScoreShort > 0 && emaScoreShort >= emaPassThreshold);

   // H4方向判断（对所有模式生效）
   bool h4Bullish = false;
   bool h4Bearish = false;
   if(InpMartH4FilterMode != H4_FILTER_OFF)
     {
      int needBars = (InpMartH4FilterMode == H4_FILTER_2K) ? 3 : 2;
      double emaH4[];
      ArraySetAsSeries(emaH4, true);
      if(CopyBuffer(g_hEmaH4, 0, 0, needBars, emaH4) >= needBars)
        {
         double closeH4_1 = iClose(_Symbol, PERIOD_H4, 1);
         if(closeH4_1 > 0.0)
           {
            if(InpMartH4FilterMode == H4_FILTER_2K)
              {
               double closeH4_2 = iClose(_Symbol, PERIOD_H4, 2);
               if(closeH4_2 > 0.0)
                 {
                  // 双K确认：上一根和上上一根都在均线同一侧
                  h4Bullish = (closeH4_1 > emaH4[1] && closeH4_2 > emaH4[2]);
                  h4Bearish = (closeH4_1 < emaH4[1] && closeH4_2 < emaH4[2]);
                 }
              }
            else  // H4_FILTER_1K
              {
               h4Bullish = (closeH4_1 > emaH4[1]);
               h4Bearish = (closeH4_1 < emaH4[1]);
              }
            // EMA信号的H4过滤
            if(emaLong && !h4Bullish)
              {
               emaLong = false;
               emaScoreLong = 0;       // 同步清零分级评分
               g_sigMartEmaScoreLong = 0;
               g_noEntryReason = "H4趋势不支持做多";
              }
            if(emaShort && !h4Bearish)
              {
               emaShort = false;
               emaScoreShort = 0;
               g_sigMartEmaScoreShort = 0;
               g_noEntryReason = "H4趋势不支持做空";
              }
           }
        }
      else
        {
         Print("[V1.09] H4 EMA CopyBuffer失败, 跳过H4滤波");
        }
     }

   // --- Mode-based signal merge ---
   switch(InpEntryMode)
     {
      case ENTRY_EMA_ONLY:
         longSignal = emaLong;
         shortSignal = emaShort;
         if(!longSignal && !shortSignal && g_noEntryReason == "")
            g_noEntryReason = "EMA无方向信号";
         break;

      case ENTRY_SMC_ONLY:
        {
         int smcDir = 0, smcScore = 0;
         ComputeSMCScore(smcDir, smcScore);
         longSignal  = (smcDir == 1 && smcScore >= InpSMCScoreThreshold);
         shortSignal = (smcDir == -1 && smcScore >= InpSMCScoreThreshold);

         // H4过滤也应用于SMC信号
         if(InpMartH4FilterMode != H4_FILTER_OFF)
           {
            if(longSignal && !h4Bullish)  { longSignal = false; g_noEntryReason = "H4趋势不支持SMC做多"; }
            if(shortSignal && !h4Bearish) { shortSignal = false; g_noEntryReason = "H4趋势不支持SMC做空"; }
           }

         if(!longSignal && !shortSignal && StringLen(g_noEntryReason) == 0)
            g_noEntryReason = "SMC评分不足(" + IntegerToString(smcScore) + "<" + IntegerToString(InpSMCScoreThreshold) + ")";
        }
         break;

      case ENTRY_COMBINED:
        {
         int smcDir = 0, smcScore = 0;
         ComputeSMCScore(smcDir, smcScore);
         // 将SMC得分归一化到0-InpSMCWeightEMA范围（与EMA权重对等）
         int smcMaxTotal = InpSMCWeightImbalance + InpSMCWeightSD + InpSMCWeightOB + InpSMCWeightFVG + InpSMCWeightLV + InpSMCWeightBreaker;
         int normalizedSMC = (smcMaxTotal > 0) ? (int)MathRound((double)smcScore / smcMaxTotal * InpSMCWeightEMA) : 0;
         // EMA 使用分级评分(0/弱/中/强)，与SMC归一化值同维度相加
         int totalBull = emaScoreLong  + (smcDir == 1  ? normalizedSMC : 0);
         int totalBear = emaScoreShort + (smcDir == -1 ? normalizedSMC : 0);
         // 净分入场：要求强方扣减弱方后仍≥阈值，避免 EMA 与 SMC 反向时弱信号入场
         int netScore = MathAbs(totalBull - totalBear);
         longSignal  = (totalBull > totalBear && netScore >= InpSMCScoreThreshold);
         shortSignal = (totalBear > totalBull && netScore >= InpSMCScoreThreshold);

         // H4过滤也应用于综合信号
         if(InpMartH4FilterMode != H4_FILTER_OFF)
           {
            if(longSignal && !h4Bullish)  { longSignal = false; g_noEntryReason = "H4趋势不支持综合做多"; }
            if(shortSignal && !h4Bearish) { shortSignal = false; g_noEntryReason = "H4趋势不支持综合做空"; }
           }

         if(!longSignal && !shortSignal && StringLen(g_noEntryReason) == 0)
            g_noEntryReason = "综合净分不足(多:" + IntegerToString(totalBull) + " 空:" + IntegerToString(totalBear) + " 净:" + IntegerToString(netScore) + " 需≥" + IntegerToString(InpSMCScoreThreshold) + ")";
        }
         break;
     }

   // --- CCI extreme filter (veto) ---
   if(InpSMC_UseCCI && g_hCCI != INVALID_HANDLE && (longSignal || shortSignal))
     {
      double cci[1];
      if(CopyBuffer(g_hCCI, 0, 1, 1, cci) >= 1)
        {
         if(longSignal && cci[0] > InpSMC_CCIExtreme)
           {
            longSignal = false;    // CCI overbought, veto long
            g_noEntryReason = "CCI极端过滤(CCI超" + IntegerToString(InpSMC_CCIExtreme) + ")";
           }
         if(shortSignal && cci[0] < -InpSMC_CCIExtreme)
           {
            shortSignal = false;   // CCI oversold, veto short
            g_noEntryReason = "CCI极端过滤(CCI超-" + IntegerToString(InpSMC_CCIExtreme) + ")";
           }
        }
      else
        {
         Print("[V1.09] CCI CopyBuffer失败, 跳过CCI极端过滤");
        }
     }

   return true;
  }

//=== Martingale Core Trading Functions ===

void TryMartEntry()
  {
   // 同秒防重复开仓保护
   static datetime s_lastEntryTime = 0;
   static uint s_lastEntryTick = 0;
   uint currentTick = GetTickCount();
   if(TimeCurrent() == s_lastEntryTime && currentTick - s_lastEntryTick < 1000)
     {
      if(g_noEntryReason == "") g_noEntryReason = "同秒防重复等待中";
      return;
     }

   bool longSig = false, shortSig = false;
   if(!GetMartSignal(longSig, shortSig)) return;
   if(!longSig && !shortSig)
     {
      if(g_noEntryReason == "")
         g_noEntryReason = "无有效入场信号";
      return;
     }

   ENUM_POSITION_TYPE side;
   double price;
   if(longSig)
     {
      side = POSITION_TYPE_BUY;
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else
     {
      side = POSITION_TYPE_SELL;
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }

   double lot = InpUseFixedLot ? InpFixedLot : InpMartBaseLot;
   lot = NormalizeVolume(lot);
   if(lot <= 0.0)
     {
      g_noEntryReason = "手数规范化失败";
      return;
     }

   if(IsEntryChaseBlocked(side))
      return;

   string cmt = MART_COMMENT + "_L0";
   if(PlaceMarketOrder(side, lot, 0, 0, cmt))
     {
      s_lastEntryTime = TimeCurrent();
      s_lastEntryTick = GetTickCount();
      g_noEntryReason = "";  // 建仓成功，清空原因
      g_martDirection = longSig ? MART_DIR_BUY : MART_DIR_SELL;
      g_martLayerCount = 1;
      g_martTotalLots = lot;
      g_martBasketPeakPnL = 0.0;
      g_martLastLayerTime = TimeCurrent();
      double entryPrice = price;
      g_martHighestPrice = entryPrice;
      g_martLowestPrice = entryPrice;
     }
  }

void TryMartAddLayer()
  {
   if(g_martDirection == MART_DIR_NONE) return;
   if(g_hedgeActive) return;  // 对冲激活=锁仓状态，停止加层防止敞口继续放大
   if(g_martMaxLayerSeq >= InpMartMaxLayers) return;
   if(g_martTotalLots >= InpMartMaxTotalLots) return;

   // Layer cooldown: prevent rapid-fire layer additions
   if(g_martLastLayerTime > 0 && TimeCurrent() - g_martLastLayerTime < InpMartCooldownSec)
      return;

   if(IsATRAddPaused())
     {
      g_noEntryReason = StringFormat("ATR扩张暂停加仓 %.2f>%.2f", g_addAtrRatio, InpATRAddPauseRatio);
      return;
     }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Calculate spacing for next layer (use max layer sequence, not position count)
   double spacingPts = GetMartSpacingPts();
   double spacingPrice = spacingPts * _Point;

   // Check if price has moved against us enough
   bool triggerAdd = false;
   double price;
   if(g_martDirection == MART_DIR_BUY)
     {
      triggerAdd = (g_martLowestPrice - ask >= spacingPrice);  // ASK vs ASK, exclude spread
      price = ask;
     }
   else
     {
      triggerAdd = (bid - g_martHighestPrice >= spacingPrice);  // BID vs BID, exclude spread
      price = bid;
     }
   if(!triggerAdd) return;

   // Martingale lot size (use max layer sequence for correct multiplier)
   double nextLot = InpUseFixedLot
      ? InpFixedLot * MathPow(InpMartLotMultiplier, g_martMaxLayerSeq)
      : InpMartBaseLot * MathPow(InpMartLotMultiplier, g_martMaxLayerSeq);
   nextLot = NormalizeVolume(nextLot);
   if(nextLot > InpMartMaxLayerLot)   // 单层最大手数限制
      nextLot = NormalizeVolume(InpMartMaxLayerLot);
   if(nextLot <= 0.0) return;
   if(g_martTotalLots + nextLot > InpMartMaxTotalLots) return;

   // Open layer (use max sequence for correct layer numbering)
   string cmt = MART_COMMENT + "_L" + IntegerToString(g_martMaxLayerSeq);
   if(PlaceMarketOrder((g_martDirection == MART_DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL,
                        nextLot, 0, 0, cmt))
     {
      g_martLayerCount++;
      g_martMaxLayerSeq++;
      g_martTotalLots += nextLot;
      g_martLastLayerTime = TimeCurrent();
      // Use actual fill price from position for accurate tracking
      ulong ticket = g_trade.ResultOrder();
      double fillPrice = price;
      if(ticket > 0 && PositionSelectByTicket(ticket))
         fillPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      if(fillPrice > g_martHighestPrice) g_martHighestPrice = fillPrice;
      if(fillPrice < g_martLowestPrice)  g_martLowestPrice = fillPrice;
     }
  }

void ManageMartBasketTP()
  {
   if(InpMartBasketTP_USD <= 0.0) return;
   // 动态TP = 查表(每层独立随机增量序列，启动时生成)
   int layers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTP = GetDynamicTP(layers);
   double pnl = GetEffectivePnL();
   if(pnl >= dynamicTP)
     {
      CloseAllMartPositions();
      PrintFormat("篮子动态TP触发: 浮盈=%.2f >= 目标=%.2f (层%d 守护系数=%.0f%%)",
                  pnl, dynamicTP, layers, GetDeepProtectTPFactor(layers) * 100.0);
     }
  }

void CheckMartHardSL()
  {
   if(InpMartHardSL_USD <= 0.0) return;
   double pnl = GetEffectivePnL();
   if(pnl <= -InpMartHardSL_USD)
     {
      CloseAllMartPositions();
      g_martHardSLLocked = true;
      Print("Mart hard SL hit: ", pnl);
     }
  }

void ManageMartTrailing()
  {
   if(InpMartTrailPct <= 0.0) return;
   if(g_hedgeActive) return;  // 对冲时由总止盈(HedgeRelease)接管，不启用追踪
   if(g_martBasketPeakPnL <= 0.0) return;

   // ---- 追踪门槛 = 当前动态TP × 启动比例% ----
   int layers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTP = GetDynamicTP(layers);
   double minProfit = dynamicTP * InpMartTrailMinProfitPerLayer / 100.0;

   // 峰值未达到门槛时，不启用追踪
   if(g_martBasketPeakPnL < minProfit) return;

   double pnl = GetEffectivePnL();
   double retraceThreshold = g_martBasketPeakPnL * InpMartTrailPct / 100.0;
   if(pnl < retraceThreshold)
     {
      PrintFormat("追踪止损触发: 峰值=%.2f 门槛=%.2f(TP%.0f×%.0f%%) 当前=%.2f 回撤阈值=%.2f",
                  g_martBasketPeakPnL, minProfit, dynamicTP, InpMartTrailMinProfitPerLayer, pnl, retraceThreshold);
      CloseAllMartPositions();
     }
  }
bool CheckDailyLossLock()
  {
   if(InpMaxDailyLossPercent <= 0.0)
      return false;

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0)
      return false;

   double modulePnlNow = g_dayRealizedPnl + GetEffectivePnL();
   if(MathAbs(modulePnlNow - g_dayStartModulePnl) < 0.01)
      return false;

   double deltaPnl = modulePnlNow - g_dayStartModulePnl;
   double dd = (-deltaPnl) / eq * 100.0;
   return (dd >= InpMaxDailyLossPercent);
  }

void ResetDailyState(const bool force)
  {
   datetime chinaNow = GetChinaNow();
   MqlDateTime t;
   TimeToStruct(chinaNow, t);
    int key = t.year * 10000 + t.day_of_year;

   if(force || key != g_dayKey)
     {
      g_dayKey = key;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_dayRealizedPnl = CalcMartClosedPnlToday();
      g_closedPnlDirty = false;
      g_dayStartModulePnl = g_dayRealizedPnl + GetEffectivePnL();
      g_dayHasModuleActivity = false;
      g_dailyLocked = false;
      g_martHardSLLocked = false;
      // 注意：g_fastLossLocked 等快速熔断状态【跨日不清】
      // 否则跨日时若仍处锁定中，会让 EA 立即恢复开仓而错过价格回调判定，存在风险。
      // 快速熔断只在'价格回到 lockPrice'时自然解锁，或重启 EA 时初始化。
      g_todayMaxDrawdown = 0.0;
      g_todayMaxDDPct = 0.0;
     }
  }


int NormalizeDayMinute(const int minute)
  {
   int m = minute % 1440;
   if(m < 0) m += 1440;
   return m;
  }

bool IsMinuteInWindow(const int nowMinute, const int startMinute, const int endMinute)
  {
   int nowM = NormalizeDayMinute(nowMinute);
   int startM = NormalizeDayMinute(startMinute);
   int endM = NormalizeDayMinute(endMinute);
   if(startM == endM)
      return false;
   if(startM < endM)
      return (nowM >= startM && nowM < endM);
   return (nowM >= startM || nowM < endM);
  }

int WeekdayOfDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = 12;
   dt.min = 0;
   dt.sec = 0;
   datetime ts = StructToTime(dt);
   MqlDateTime out;
   TimeToStruct(ts, out);
   return out.day_of_week;
  }

int NthSundayOfMonth(const int year, const int month, const int nth)
  {
   int firstDow = WeekdayOfDate(year, month, 1);
   int firstSunday = 1 + ((7 - firstDow) % 7);
   return firstSunday + (nth - 1) * 7;
  }

int GetUs0830DataMinuteBeijing(const MqlDateTime &chinaTime)
  {
   if(!InpAutoUsDstNewsTime)
      return InpNewsDataHour * 60 + InpNewsDataMinute;

   int y = chinaTime.year;
   int m = chinaTime.mon;
   int d = chinaTime.day;
   int secondSundayMarch = NthSundayOfMonth(y, 3, 2);
   int firstSundayNovember = NthSundayOfMonth(y, 11, 1);
   bool usDst = false;

   if(m > 3 && m < 11)
      usDst = true;
   else if(m == 3 && d > secondSundayMarch)
      usDst = true;
   else if(m == 3 && d == secondSundayMarch)
      usDst = true;   // 08:30 ET is after the 02:00 local DST switch.
   else if(m == 11 && d < firstSundayNovember)
      usDst = true;

   return (usDst ? 20 : 21) * 60 + 30;
  }

string GetNewsBlockReason()
  {
   datetime chinaNow = GetChinaNow();
   MqlDateTime t;
   TimeToStruct(chinaNow, t);
   int nowMinute = t.hour * 60 + t.min;

   int preMin = MathMax(0, InpNewsBlockPreMinutes);
   int postMin = MathMax(0, InpNewsBlockPostMinutes);
   int us0830 = GetUs0830DataMinuteBeijing(t);

   if(InpEnableNewsFilter)
     {
      if(InpNewsBlockThu2030 && t.day_of_week == 4 &&
         IsMinuteInWindow(nowMinute, us0830 - preMin, us0830 + postMin))
         return "新闻过滤:周四20:30数据";

      if(InpNewsBlockFirstFri2030 && t.day_of_week == 5 && t.day <= 7 &&
         IsMinuteInWindow(nowMinute, us0830 - preMin, us0830 + postMin))
         return "新闻过滤:非农20:30";

     }

   if(InpUseManualNewsBlock)
     {
      int startM = InpNewsBlockStartHour * 60 + InpNewsBlockStartMinute;
      int endM = InpNewsBlockEndHour * 60 + InpNewsBlockEndMinute;
      if(IsMinuteInWindow(nowMinute, startM, endM))
         return "新闻过滤:自定义窗口";
     }

   return "";
  }

bool IsManualNewsBlocked()
  {
   return (GetNewsBlockReason() != "");
  }

bool IsSpreadTooHigh()
  {
   if(InpMaxSpreadPoints <= 0)
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   double spreadPoints = (ask - bid) / _Point;
   return (spreadPoints > InpMaxSpreadPoints);
  }

bool IsHedgingAccount()
  {
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (mode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

string GetBaseSymbol(const string sym)
  {
   string s = sym;
   // 移除 .xxx 后缀 (如 .raw, .std, .ecn)
   int dotPos = StringFind(s, ".");
   if(dotPos > 0) s = StringSubstr(s, 0, dotPos);
   // 移除尾部小写字母后缀 (如 c, m, micro)
   int len = StringLen(s);
   while(len > 0)
     {
      ushort ch = StringGetCharacter(s, len - 1);
      if(ch >= 'a' && ch <= 'z')
         len--;
      else
         break;
     }
   if(len > 0)
      s = StringSubstr(s, 0, len);
   return s;
  }

bool IsManagedSymbol(const string symbolName)
  {
   if(symbolName == _Symbol)
      return true;
   // 自动匹配同基础品种名(XAUUSD = XAUUSDc = XAUUSDm = XAUUSDmicro)
   string base1 = GetBaseSymbol(_Symbol);
   string base2 = GetBaseSymbol(symbolName);
   return (base1 == base2 && StringLen(base1) >= 6);
  }

double NormalizeVolume(const double lots)
  {
   double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(vMin <= 0.0 || vMax <= 0.0 || vStep <= 0.0)
      return 0.0;

   double clamped = MathMax(vMin, MathMin(vMax, lots));
   double steps   = MathFloor(clamped / vStep + 1e-8);
   double result  = steps * vStep;

   int volDigits = 2;
   if(vStep < 0.1)  volDigits = 3;
   if(vStep < 0.01) volDigits = 4;

   return NormalizeDouble(result, volDigits);
  }


bool IsStopRetcode(const uint rc)
  {
   return (rc == TRADE_RETCODE_INVALID_STOPS || rc == TRADE_RETCODE_INVALID_PRICE || rc == TRADE_RETCODE_FROZEN);
  }

void PrintTradeResult(const string action, const bool ok)
  {
   uint rc = g_trade.ResultRetcode();
   string desc = g_trade.ResultRetcodeDescription();
   if(!ok || rc != TRADE_RETCODE_DONE)
      Print(action, " failed. retcode=", (int)rc, " ", desc, " err=", GetLastError());
  }

void EnsureStopsForMarketOrder(const ENUM_POSITION_TYPE side, double &sl, double &tp)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLevelDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freezeLevelDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   double minDist = MathMax(stopLevelDist, freezeLevelDist);
   if(minDist < _Point)
      minDist = _Point;

   if(side == POSITION_TYPE_BUY)
     {
      if(sl > 0.0 && (bid - sl) < minDist) sl = NormalizeDouble(bid - minDist, _Digits);
      if(tp > 0.0 && (tp - ask) < minDist) tp = NormalizeDouble(ask + minDist, _Digits);
      if(sl > 0.0 && sl >= bid) sl = NormalizeDouble(bid - minDist, _Digits);
      if(tp > 0.0 && tp <= ask) tp = NormalizeDouble(ask + minDist, _Digits);
     }
   else
     {
      if(sl > 0.0 && (sl - ask) < minDist) sl = NormalizeDouble(ask + minDist, _Digits);
      if(tp > 0.0 && (bid - tp) < minDist) tp = NormalizeDouble(bid - minDist, _Digits);
      if(sl > 0.0 && sl <= ask) sl = NormalizeDouble(ask + minDist, _Digits);
      if(tp > 0.0 && tp >= bid) tp = NormalizeDouble(bid - minDist, _Digits);
     }
  }

bool PlaceMarketOrder(const ENUM_POSITION_TYPE side, const double vol, double sl, double tp, const string comment)
  {
   EnsureStopsForMarketOrder(side, sl, tp);
   bool ok = false;
   if(side == POSITION_TYPE_BUY)
      ok = g_trade.Buy(vol, _Symbol, 0.0, sl, tp, comment);
   else
      ok = g_trade.Sell(vol, _Symbol, 0.0, sl, tp, comment);

   uint rc = g_trade.ResultRetcode();
   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
      return true;

   if(IsStopRetcode(rc))
     {
      bool retry = (side == POSITION_TYPE_BUY) ? g_trade.Buy(vol, _Symbol, 0.0, 0.0, 0.0, comment)
                                               : g_trade.Sell(vol, _Symbol, 0.0, 0.0, 0.0, comment);
      uint rcRetry = g_trade.ResultRetcode();
      if(retry && (rcRetry == TRADE_RETCODE_DONE || rcRetry == TRADE_RETCODE_DONE_PARTIAL))
        {
         ulong ticket = g_trade.ResultOrder();
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            ticket = FindLatestModulePosition(comment);
         if(ticket > 0 && PositionSelectByTicket(ticket))
           {
            double newSl = sl;
            double newTp = tp;
            EnsureStopsForMarketOrder(side, newSl, newTp);
            bool modOk = false;
            for(int modAttempt = 0; modAttempt < 3; modAttempt++)
            {
               if(ModifyPositionChecked(ticket, newSl, newTp))
               { modOk = true; break; }
               Sleep(500);
            }
            if(!modOk)
            {
               Alert("WARNING: 订单#", ticket, " SL/TP设置失败! 请手动检查");
               PrintFormat("CRITICAL: Position %d opened WITHOUT SL/TP after 3 retry attempts", ticket);
            }
           }
         return true;
        }
     }

   PrintTradeResult("PlaceMarketOrder(" + comment + ")", false);
   return false;
  }

ulong FindLatestModulePosition(const string comment)
  {
   ulong bestTicket = 0;
   long bestTimeMs = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL)))
         continue;
      if(PositionGetString(POSITION_COMMENT) != comment)
         continue;

      long tms = (long)PositionGetInteger(POSITION_TIME_MSC);
      if(tms > bestTimeMs)
        {
         bestTimeMs = tms;
         bestTicket = ticket;
        }
     }
   return bestTicket;
  }

bool ModifyPositionChecked(const ulong ticket, const double sl, const double tp)
  {
   if(!PositionSelectByTicket(ticket))
      return false;

   ENUM_POSITION_TYPE side = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double adjSl = sl;
   double adjTp = tp;
   EnsureStopsForMarketOrder(side, adjSl, adjTp);

   bool ok = g_trade.PositionModify(ticket, adjSl, adjTp);
   uint rc = g_trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL))
     {
      PrintTradeResult("PositionModify(" + (string)ticket + ")", false);
      return false;
     }
   return true;
  }

bool ClosePositionChecked(const ulong ticket)
  {
   for(int attempt=0; attempt<3; ++attempt)
     {
      bool ok = g_trade.PositionClose(ticket);
      uint rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
         return true;
     }
   PrintTradeResult("PositionClose(" + (string)ticket + ")", false);
   return false;
  }

double GetHedgeTargetRatio(const double floatingPnl)
  {
   if(InpHedgeMode == HEDGE_MODE_OFF)
      return 0.0;
   if(floatingPnl >= 0.0)
      return 0.0;

   if(InpHedgeMode == HEDGE_MODE_FIXED)
     {
      if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
        {
         if(InpHedgeLossPercent <= 0.0) return 0.0;
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         if(eq <= 0.0) return 0.0;
         double absEquity = eq - floatingPnl;
         if(absEquity <= 0.0) return 0.0;
         double lossPct = (-floatingPnl) / absEquity * 100.0;
         return (lossPct >= InpHedgeLossPercent) ? InpHedgeRatio : 0.0;
        }
      if(InpHedgeAbsoluteUSD <= 0.0) return 0.0;
      return ((-floatingPnl) >= InpHedgeAbsoluteUSD) ? InpHedgeRatio : 0.0;
     }

   double loss = -floatingPnl;
   double ratio = 0.0;
   if(InpHedgeLadderLoss1 > 0.0 && loss >= InpHedgeLadderLoss1)
      ratio = MathMax(ratio, InpHedgeLadderRatio1);
   if(InpHedgeLadderLoss2 > 0.0 && loss >= InpHedgeLadderLoss2)
      ratio = MathMax(ratio, InpHedgeLadderRatio2);
   if(InpHedgeLadderLoss3 > 0.0 && loss >= InpHedgeLadderLoss3)
      ratio = MathMax(ratio, InpHedgeLadderRatio3);
   return MathMax(0.0, ratio);
  }

double GetATRExpansionRatio()
  {
   g_addAtrRatio = 0.0;
   if(g_hATR_Spacing == INVALID_HANDLE || g_hATR_SpacingLong == INVALID_HANDLE)
      return 0.0;
   double atrShort = GetATRValue(g_hATR_Spacing);
   double atrLong  = GetATRValue(g_hATR_SpacingLong);
   if(atrShort <= 0.0 || atrLong <= 0.0)
      return 0.0;
   g_addAtrRatio = atrShort / atrLong;
   return g_addAtrRatio;
  }

bool IsATRAddPaused()
  {
   if(!InpUseATRAddPause)
     {
      g_addAtrPaused = false;
      g_addAtrRatio = 0.0;
      return false;
     }
   if(InpATRAddPauseRatio <= 0.0 || InpATRAddResumeRatio <= 0.0)
      return false;

   double ratio = GetATRExpansionRatio();
   if(ratio <= 0.0)
      return false;

   if(g_addAtrPaused)
     {
      if(ratio <= InpATRAddResumeRatio)
         g_addAtrPaused = false;
     }
   else if(ratio >= InpATRAddPauseRatio)
      g_addAtrPaused = true;

   return g_addAtrPaused;
  }

bool IsEntryChaseBlocked(const ENUM_POSITION_TYPE side)
  {
   if(!InpUseEntryChaseFilter)
      return false;

   double atr = GetATRValue(g_hATR_Spacing);
   if(atr <= 0.0)
      return false;

   double slow[1];
   if(CopyBuffer(g_hEmaSlowM1, 0, 1, 1, slow) < 1)
      return false;

   double close1 = iClose(_Symbol, InpMartEntryTF, 1);
   double open1  = iOpen(_Symbol, InpMartEntryTF, 1);
   if(close1 <= 0.0 || open1 <= 0.0 || slow[0] <= 0.0)
      return false;

   if(InpEntryMaxDistSlowEMA_ATR > 0.0)
     {
      double distAtr = MathAbs(close1 - slow[0]) / atr;
      bool chaseLong  = (side == POSITION_TYPE_BUY  && close1 > slow[0]);
      bool chaseShort = (side == POSITION_TYPE_SELL && close1 < slow[0]);
      if((chaseLong || chaseShort) && distAtr > InpEntryMaxDistSlowEMA_ATR)
        {
         g_noEntryReason = StringFormat("防追单: 距慢EMA %.1fATR>%.1f", distAtr, InpEntryMaxDistSlowEMA_ATR);
         return true;
        }
     }

   if(InpEntryMaxPrevBody_ATR > 0.0)
     {
      double bodyAtr = MathAbs(close1 - open1) / atr;
      if(bodyAtr > InpEntryMaxPrevBody_ATR)
        {
         g_noEntryReason = StringFormat("防追单: 上根实体 %.1fATR>%.1f", bodyAtr, InpEntryMaxPrevBody_ATR);
         return true;
        }
     }

   return false;
  }

//=== Risk Management Modules ===

void CheckFastLossBreaker()
  {
   if(!InpEnableFastLoss) return;

   // 无马丁方向时：
   //  - 未锁定 → 不评估也不维护窗口（没持仓，价格波动与本 EA 无关）
   //  - 已锁定 → 篮子已被止盈/手动全平，锁开仓失去意义 → 自动解除
   if(g_martDirection == MART_DIR_NONE)
     {
      if(g_fastLossLocked)
        {
         PrintFormat("快速熔断解除: 篮子已全部平仓, 锁开仓失去意义, 自动恢复");
         g_fastLossLocked    = false;
         g_fastLossLockPrice = 0.0;
         g_fastLossLockDir   = 0;
        }
      g_fastLossStartTime = 0;
      g_fastLossPeakPrice = 0.0;
      return;
     }

   double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(curBid <= 0.0) return;

   if(!g_fastLossLocked)
     {
      // 初始化窗口：以当前价为起点
      if(g_fastLossStartTime == 0)
        {
         g_fastLossStartTime = TimeCurrent();
         g_fastLossPeakPrice = curBid;
         return;
        }

      // 持续追踪窗口内"对己最有利"的极值价（峰值）
      // 多头篮子：跌为不利，峰值=最高价；空头篮子：涨为不利，峰值=最低价
      if(g_martDirection == MART_DIR_BUY)
        {
         if(curBid > g_fastLossPeakPrice) g_fastLossPeakPrice = curBid;
        }
      else // MART_DIR_SELL
        {
         if(curBid < g_fastLossPeakPrice) g_fastLossPeakPrice = curBid;
        }

      // 计算反向变动幅度（美元）：多头看 peak→cur 跌幅，空头看 cur→peak 涨幅
      double adverseDollar = (g_martDirection == MART_DIR_BUY)
                              ? (g_fastLossPeakPrice - curBid)
                              : (curBid - g_fastLossPeakPrice);
      // 触发判定：反向变动美元 ×100 ≥ 阈值（参数单位"美分价格",800=8美元）
      if(adverseDollar * 100.0 >= (double)InpFastLossDistance)
        {
         g_fastLossLocked    = true;
         // V1.15: 锁定价 = 最后一层加仓价（与篮子持仓挑关）
         //   - 多头篮子: g_martLowestPrice（最深加仓价，逆势加仓 → 最低价即最后一层）
         //   - 空头篮子: g_martHighestPrice（同理）
         //   - 含义: 价格回到最后一层加仓价 → 那笔最危险的加仓浮亏归零 → 风险消化 → 可重新评估加层
         //   - Fallback: 篮子数据异常时退回到 peak（防出错）
         RefreshMartBasketState();
         double lastLayerPrice = 0.0;
         if(g_martDirection == MART_DIR_BUY && g_martLowestPrice < DBL_MAX && g_martLowestPrice > 0.0)
            lastLayerPrice = g_martLowestPrice;
         else if(g_martDirection == MART_DIR_SELL && g_martHighestPrice > 0.0)
            lastLayerPrice = g_martHighestPrice;

         g_fastLossLockPrice = (lastLayerPrice > 0.0) ? lastLayerPrice : g_fastLossPeakPrice;
         g_fastLossLockDir   = (int)g_martDirection;
         PrintFormat("快速熔断触发: 方向=%s 窗口峰价=%.3f→当前=%.3f 反向%.2f美元≥%.2f美元 | 锁定开仓,等价回至最后层加仓价%.3f",
                     (g_martDirection==MART_DIR_BUY?"BUY":"SELL"),
                     g_fastLossPeakPrice, curBid, adverseDollar,
                     InpFastLossDistance/100.0, g_fastLossLockPrice);
         return;
        }

      // 窗口超时：滑动到新窗口（以当前价为新峰）
      if(TimeCurrent() - g_fastLossStartTime > InpFastLossTime)
        {
         g_fastLossStartTime = TimeCurrent();
         g_fastLossPeakPrice = curBid;
        }
     }
   else
     {
      // Locked: 等价格回调至锁定价（多头：curBid≥lockPrice；空头：curBid≤lockPrice）
      bool recovered = false;
      if(g_fastLossLockDir == (int)MART_DIR_BUY)
         recovered = (curBid >= g_fastLossLockPrice);
      else if(g_fastLossLockDir == (int)MART_DIR_SELL)
         recovered = (curBid <= g_fastLossLockPrice);

      if(recovered)
        {
         PrintFormat("快速熔断解除: 价回调至%.3f(锁定价=最后层加仓价%.3f), 恢复开仓",
                     curBid, g_fastLossLockPrice);
         g_fastLossLocked    = false;
         g_fastLossStartTime = 0;
         g_fastLossPeakPrice = 0.0;
         g_fastLossLockPrice = 0.0;
         g_fastLossLockDir   = 0;
        }
     }
  }

void ManageHedgeLock()
  {
   if(InpHedgeMode == HEDGE_MODE_OFF) return;
   if(InpHedgeMode == HEDGE_MODE_FIXED)
     {
      if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT && InpHedgeLossPercent <= 0.0) return;
      if(InpHedgeTriggerMode == HEDGE_BY_ABSOLUTE && InpHedgeAbsoluteUSD <= 0.0) return;
     }

   // 先计算马丁持仓信息（对冲追加逻辑需要）
   double floatingPnl = 0.0;
   double totalVolume = 0.0;
   ENUM_POSITION_TYPE existingSide = POSITION_TYPE_BUY;
   bool hasPosition = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) < 0) continue;
      if(StringFind(cmt, HEDGE_COMMENT) >= 0) continue;  // 排除对冲单

      floatingPnl += PositionGetDouble(POSITION_PROFIT);
      totalVolume += PositionGetDouble(POSITION_VOLUME);
      existingSide = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      hasPosition = true;
     }

   if(!hasPosition)
      return;

   // 检查是否已有对冲单
   bool hedgeExists = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGE_COMMENT) >= 0)
        {
         hedgeExists = true;
         break;
        }
     }
   if(hedgeExists)
     {
      // 检查是否需要追加对冲（马丁加仓后对冲比例下降）
      double targetRatio = GetHedgeTargetRatio(floatingPnl);
      if(targetRatio <= 0.0)
         return;
      double targetHedgeVol = NormalizeVolume(totalVolume * targetRatio);
      double currentHedgeVol = g_hedgeLots;
      double deficit = targetHedgeVol - currentHedgeVol;
      if(deficit >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
         deficit = NormalizeVolume(deficit);
         if(existingSide == POSITION_TYPE_BUY)
            PlaceMarketOrder(POSITION_TYPE_SELL, deficit, 0.0, 0.0, HEDGE_COMMENT);
         else
            PlaceMarketOrder(POSITION_TYPE_BUY, deficit, 0.0, 0.0, HEDGE_COMMENT);
         PrintFormat("对冲追加: 当前%.2f手 → 目标%.2f手, 追加%.2f手", currentHedgeVol, targetHedgeVol, deficit);
        }
      return;
     }

   // 根据当前对冲模式计算目标比例，固定/阶梯模式互斥由 GetHedgeTargetRatio 统一处理。
   double targetRatio = GetHedgeTargetRatio(floatingPnl);
   if(floatingPnl >= 0.0) return;  // 没有浮亏不触发

   if(targetRatio > 0.0)
     {
      double hedgeVol = NormalizeVolume(totalVolume * targetRatio);
      if(hedgeVol <= 0.0) return;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask <= 0.0 || bid <= 0.0) return;

      if(existingSide == POSITION_TYPE_BUY)
        {
         PlaceMarketOrder(POSITION_TYPE_SELL, hedgeVol, 0.0, 0.0, HEDGE_COMMENT);
         Print("Hedge lock: opened SELL hedge ", hedgeVol, " lots against BUY positions, floatingPnl=", -floatingPnl);
        }
      else
        {
         PlaceMarketOrder(POSITION_TYPE_BUY, hedgeVol, 0.0, 0.0, HEDGE_COMMENT);
         Print("Hedge lock: opened BUY hedge ", hedgeVol, " lots against SELL positions, floatingPnl=", -floatingPnl);
        }
     }
  }

void ManageHedgeRelease()
  {
   if(InpHedgeMode == HEDGE_MODE_OFF) return;
   if(!g_hedgeActive) return;

   // 计算马丁+对冲的总浮盈
   double totalPnl = g_cachedMartPnl + g_hedgePnl;

   // 计算止盈阈值
   double releaseThreshold = 0.0;
   if(InpHedgeReleaseMode == HEDGE_RELEASE_FIXED)
      releaseThreshold = InpHedgeReleaseFixed;
   else
     {
      // 仅剩对冲单（马丁已被手动平掉）时 g_martLayerCount=0，
      // 若直接相乘会得到阈值 0 → 对冲微浮盈即立即全平。
      // 此时按 1 层兜底，等同于"单层动态止盈"，避免误平对冲。
      int effLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
      releaseThreshold = effLayers * InpHedgeReleaseDynPerLayer;
     }

   // 止盈条件：总浮盈达标 → 全平马丁+对冲
   if(totalPnl >= releaseThreshold)
     {
      PrintFormat("对冲止盈: 总浮盈=%.2f≥%.2f(Mart=%.2f,Hedge=%.2f), 全平",
         totalPnl, releaseThreshold, g_cachedMartPnl, g_hedgePnl);
      CloseAllMartPositions();
     }
  }


void ComputeSignalDiagnostics()
  {
   // Reset martingale diagnostics
   g_sigMartEntryOk    = false;
   g_sigMartEmaDir     = 0;
   g_sigMartEmaScoreLong  = 0;
   g_sigMartEmaScoreShort = 0;
   g_sigMartEmaFastVal = 0.0;
   g_sigMartEmaSlowVal = 0.0;
   g_sigMartClose1     = 0.0;
   g_sigH4Confirmed    = false;
   g_sigH4EmaVal       = 0.0;
   g_sigMartDistToNext = 0;
   g_sigMartBasketPnL  = g_cachedMartPnl;

   // Read EMA values and compute signal inline (avoids duplicate GetMartSignal call)
   double emaFast[3], emaSlow[3];
   if(CopyBuffer(g_hEmaFastM1, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(g_hEmaSlowM1, 0, 0, 3, emaSlow) < 3)
     {
     }
   else
     {
      g_sigMartEmaFastVal = emaFast[1];
      g_sigMartEmaSlowVal = emaSlow[1];
      if(emaFast[1] > emaSlow[1])      g_sigMartEmaDir = 1;
      else if(emaFast[1] < emaSlow[1]) g_sigMartEmaDir = -1;

      double close1 = iClose(_Symbol, InpMartEntryTF, 1);
      if(close1 > 0.0)
        {
         g_sigMartClose1 = close1;
         // 分级评分(与GetMartSignal保持一致)
         CalcEmaScores(emaFast[1], emaSlow[1], close1, g_sigMartEmaScoreLong, g_sigMartEmaScoreShort);
         int passTh = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
         g_sigMartEntryOk = ((g_sigMartEmaScoreLong  > 0 && g_sigMartEmaScoreLong  >= passTh) ||
                             (g_sigMartEmaScoreShort > 0 && g_sigMartEmaScoreShort >= passTh));
        }
     }

   // H4 EMA diagnostics
   {
      int needBars = (InpMartH4FilterMode == H4_FILTER_2K) ? 3 : 2;
      double emaH4[];
      ArraySetAsSeries(emaH4, true);
      if(CopyBuffer(g_hEmaH4, 0, 0, needBars, emaH4) >= needBars)
        {
         g_sigH4EmaVal = emaH4[1];
         double closeH4_1 = iClose(_Symbol, PERIOD_H4, 1);
         if(closeH4_1 > 0.0)
           {
            if(InpMartH4FilterMode == H4_FILTER_OFF)
               g_sigH4Confirmed = true;
            else if(InpMartH4FilterMode == H4_FILTER_2K)
              {
               double closeH4_2 = iClose(_Symbol, PERIOD_H4, 2);
               if(closeH4_2 > 0.0)
                 {
                  bool h4Bull = (closeH4_1 > emaH4[1] && closeH4_2 > emaH4[2]);
                  bool h4Bear = (closeH4_1 < emaH4[1] && closeH4_2 < emaH4[2]);
                  g_sigH4Confirmed = ((g_sigMartEmaDir == 1 && h4Bull) ||
                                      (g_sigMartEmaDir == -1 && h4Bear));
                 }
              }
            else  // H4_FILTER_1K
              {
               g_sigH4Confirmed = ((g_sigMartEmaDir == 1 && closeH4_1 > emaH4[1]) ||
                                   (g_sigMartEmaDir == -1 && closeH4_1 < emaH4[1]));
              }
           }
        }
     }

   // Distance to next layer trigger (use max layer sequence for correct spacing)
   g_sigMartDistToNext = 0;
   if(g_martDirection != MART_DIR_NONE && g_martLayerCount > 0 && g_martMaxLayerSeq < InpMartMaxLayers)
     {
      double spacingPts = GetMartSpacingPts();
      double spacingPrice = spacingPts * _Point;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_martDirection == MART_DIR_BUY && g_martLowestPrice > 0.0)
        {
         // 做多时，下一层触发价 = lowestPrice - spacing，距离 = ask - 触发价
         double triggerPrice = g_martLowestPrice - spacingPrice;
         g_sigMartDistToNext = (int)MathRound((ask - triggerPrice) / _Point);
        }
      else if(g_martDirection == MART_DIR_SELL && g_martHighestPrice > 0.0)
        {
         // 做空时，下一层触发价 = highestPrice + spacing，距离 = 触发价 - bid
         double triggerPrice = g_martHighestPrice + spacingPrice;
         g_sigMartDistToNext = (int)MathRound((triggerPrice - bid) / _Point);
        }
     }

   // SMC diagnostics update (always compute for panel display)
   if(g_hATR_H4 != INVALID_HANDLE && g_hATR_H1 != INVALID_HANDLE && g_hATR_M15 != INVALID_HANDLE)
     {
      int dir = 0, sc = 0;
      ComputeSMCScore(dir, sc);
      // g_smcDirection and g_smcScore are already updated inside ComputeSMCScore
     }
  }

string GetBlockingReason()
  {
   if(g_dailyLocked)
      return "日亏损锁定";
   if(g_martHardSLLocked)
      return "马丁硬止损熔断";
   if(IsSpreadTooHigh())
      return "点差过大";
   if(IsManualNewsBlocked())
      return GetNewsBlockReason();
   if(g_fastLossLocked)
      return "快速亏损熔断";
   return "";
  }


double GetTodayMaxDrawdown()
  {
   if(g_dayStartEquity <= 0.0)
      return 0.0;
   return g_todayMaxDrawdown;
  }

double GetCurrentSpreadPoints()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || _Point <= 0.0)
      return 0.0;
   return (ask - bid) / _Point;
  }

void ResolvePanelLayout()
  {
   long chartW = 0, chartH = 0;
   ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chartW);
   ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartH);

   int desiredW = MathMax(400, InpPanelWidth);
   int desiredH = MathMax(360, InpPanelHeight);
   g_panelW = desiredW;
   g_panelH = desiredH;

   if(chartW > 0)
     {
      int maxW = (int)MathMax(400, chartW - 8);
      g_panelW = (int)MathMin(g_panelW, maxW);
     }
   if(chartH > 0)
     {
      int maxH = (int)MathMax(360, chartH - 8);
      g_panelH = (int)MathMin(g_panelH, maxH);
     }

   g_panelX = MathMax(4, InpPanelX);
   g_panelY = MathMax(4, InpPanelY);
   if(chartW > 0 && g_panelX + g_panelW + 4 > chartW)
      g_panelX = (int)MathMax(4, chartW - g_panelW - 4);
   if(chartH > 0 && g_panelY + g_panelH + 4 > chartH)
      g_panelY = (int)MathMax(4, chartH - g_panelH - 4);
  }

//--- Load BMP data into g_bgSrcPixels[] (24/32-bit uncompressed, from embedded resource)
bool LoadBgBmpFile(const uchar &buf[], int bufSize)
  {
   if(bufSize < 54) { PrintFormat("[BG] BMP buf too small: %d", bufSize); return false; }
   if(buf[0] != 'B' || buf[1] != 'M') { Print("[BG] Invalid BMP header"); return false; }
   int dataOff = buf[10] | (buf[11]<<8) | (buf[12]<<16) | (buf[13]<<24);
   g_bgSrcW = buf[18] | (buf[19]<<8) | (buf[20]<<16) | (buf[21]<<24);
   g_bgSrcH = buf[22] | (buf[23]<<8) | (buf[24]<<16) | (buf[25]<<24);
   int bpp = buf[28] | (buf[29]<<8);
   PrintFormat("[BG] BMP: %dx%d, bpp=%d, dataOff=%d, bufSize=%d", g_bgSrcW, g_bgSrcH, bpp, dataOff, bufSize);
   if(bpp != 24 && bpp != 32) { PrintFormat("[BG] Unsupported bpp: %d", bpp); return false; }
   if(g_bgSrcW <= 0 || g_bgSrcH <= 0) { Print("[BG] Invalid dimensions"); return false; }
   int rowBytes = ((bpp * g_bgSrcW + 31) / 32) * 4;
   int pxSize = bpp / 8;
   ArrayResize(g_bgSrcPixels, g_bgSrcW * g_bgSrcH);
   for(int y = 0; y < g_bgSrcH; y++)
     {
      int dstY = g_bgSrcH - 1 - y;
      int rowBase = dataOff + y * rowBytes;
      for(int x = 0; x < g_bgSrcW; x++)
        {
         int p = rowBase + x * pxSize;
         if(p + 2 >= bufSize) break;
         uchar b2 = buf[p], g2 = buf[p+1], r2 = buf[p+2];
         g_bgSrcPixels[dstY * g_bgSrcW + x] = (uint)(0xFF000000 | (r2<<16) | (g2<<8) | b2);
        }
     }
   return true;
  }

//--- Load BMP data into g_logoSrcPixels[] (24/32-bit uncompressed, from embedded resource)
bool LoadLogoBmpFile(const uchar &buf[], int bufSize)
  {
   if(bufSize < 54) { PrintFormat("[LOGO] BMP buf too small: %d", bufSize); return false; }
   if(buf[0] != 'B' || buf[1] != 'M') { Print("[LOGO] Invalid BMP header"); return false; }
   int dataOff = buf[10] | (buf[11]<<8) | (buf[12]<<16) | (buf[13]<<24);
   g_logoSrcW = buf[18] | (buf[19]<<8) | (buf[20]<<16) | (buf[21]<<24);
   g_logoSrcH = buf[22] | (buf[23]<<8) | (buf[24]<<16) | (buf[25]<<24);
   int bpp = buf[28] | (buf[29]<<8);
   PrintFormat("[LOGO] BMP: %dx%d, bpp=%d, dataOff=%d, bufSize=%d", g_logoSrcW, g_logoSrcH, bpp, dataOff, bufSize);
   if(bpp != 24 && bpp != 32) { PrintFormat("[LOGO] Unsupported bpp: %d", bpp); return false; }
   if(g_logoSrcW <= 0 || g_logoSrcH <= 0) { Print("[LOGO] Invalid dimensions"); return false; }
   int rowBytes = ((bpp * g_logoSrcW + 31) / 32) * 4;
   int pxSize = bpp / 8;
   ArrayResize(g_logoSrcPixels, g_logoSrcW * g_logoSrcH);
   for(int y = 0; y < g_logoSrcH; y++)
     {
      int dstY = g_logoSrcH - 1 - y;
      int rowBase = dataOff + y * rowBytes;
      for(int x = 0; x < g_logoSrcW; x++)
        {
         int p = rowBase + x * pxSize;
         if(p + 2 >= bufSize) break;
         uchar b2 = buf[p], g2 = buf[p+1], r2 = buf[p+2];
         g_logoSrcPixels[dstY * g_logoSrcW + x] = (uint)(0xFF000000 | (r2<<16) | (g2<<8) | b2);
        }
     }
   return true;
  }

//--- Scale logo pixels to targetW x targetH (fit-inside, keep aspect ratio)
bool UpdateLogoResource(int targetW, int targetH)
  {
   if(g_logoSrcW == 0 || g_logoSrcH == 0) return false;

   uint scaled[];
   ArrayResize(scaled, targetW * targetH);

   // fit-inside: scale to fit within target, keep aspect ratio
   double scaleX = (double)targetW / g_logoSrcW;
   double scaleY = (double)targetH / g_logoSrcH;
   double scale  = MathMin(scaleX, scaleY);
   int drawW = (int)(g_logoSrcW * scale);
   int drawH = (int)(g_logoSrcH * scale);
   int offsetX = (targetW - drawW) / 2;
   int offsetY = (targetH - drawH) / 2;

   // Fill with panel background color (深蓝黑，衬托金色Logo)
   uint bgColor = 0xFF141A25;  // C'20,26,37' 面板背景色
   ArrayInitialize(scaled, bgColor);

   // Bilinear interpolation
   for(int y = 0; y < drawH; y++)
     {
      double srcYf = y * ((double)g_logoSrcH / drawH);
      int srcY0 = (int)MathFloor(srcYf);
      int srcY1 = MathMin(srcY0 + 1, g_logoSrcH - 1);
      double fy = srcYf - srcY0;
      for(int x = 0; x < drawW; x++)
        {
         double srcXf = x * ((double)g_logoSrcW / drawW);
         int srcX0 = (int)MathFloor(srcXf);
         int srcX1 = MathMin(srcX0 + 1, g_logoSrcW - 1);
         double fx = srcXf - srcX0;
         uint c00 = g_logoSrcPixels[srcY0 * g_logoSrcW + srcX0];
         uint c10 = g_logoSrcPixels[srcY0 * g_logoSrcW + srcX1];
         uint c01 = g_logoSrcPixels[srcY1 * g_logoSrcW + srcX0];
         uint c11 = g_logoSrcPixels[srcY1 * g_logoSrcW + srcX1];
         uchar rr = (uchar)(((c00>>16&0xFF)*(1-fx)+(c10>>16&0xFF)*fx)*(1-fy)+((c01>>16&0xFF)*(1-fx)+(c11>>16&0xFF)*fx)*fy);
         uchar gg = (uchar)(((c00>>8&0xFF)*(1-fx)+(c10>>8&0xFF)*fx)*(1-fy)+((c01>>8&0xFF)*(1-fx)+(c11>>8&0xFF)*fx)*fy);
         uchar bb = (uchar)(((c00&0xFF)*(1-fx)+(c10&0xFF)*fx)*(1-fy)+((c01&0xFF)*(1-fx)+(c11&0xFF)*fx)*fy);
         scaled[(y + offsetY) * targetW + (x + offsetX)] = (uint)(0xFF000000 | (rr << 16) | (gg << 8) | bb);
        }
     }

   if(!ResourceCreate(LOGO_RES, scaled, (uint)targetW, (uint)targetH,
                      0, 0, (uint)targetW, COLOR_FORMAT_XRGB_NOALPHA))
     {
      PrintFormat("[LOGO] ResourceCreate FAILED: %dx%d, err=%d", targetW, targetH, GetLastError());
      return false;
     }
   PrintFormat("[LOGO] ResourceCreate OK: %dx%d", targetW, targetH);
   return true;
  }

//--- Scale BG pixels to targetW x targetH using cover mode (keep ratio, crop)
bool UpdateBgResource(int targetW, int targetH)
  {
   if(g_bgSrcW == 0 || g_bgSrcH == 0) return false;
   if(targetW <= 0 || targetH <= 0)   return false;

   uint scaled[];
   ArrayResize(scaled, targetW * targetH);

   // Cover mode: scale to cover entire target, center crop
   double scaleX = (double)targetW / g_bgSrcW;
   double scaleY = (double)targetH / g_bgSrcH;
   double scale  = MathMax(scaleX, scaleY);

   int srcDrawW = (int)(targetW / scale);
   int srcDrawH = (int)(targetH / scale);
   int srcOffX  = (g_bgSrcW - srcDrawW) / 2;
   int srcOffY  = (g_bgSrcH - srcDrawH) / 2;

   // Bilinear interpolation
   for(int y = 0; y < targetH; y++)
     {
      double srcYf = srcOffY + y * ((double)srcDrawH / targetH);
      int srcY0 = (int)MathFloor(srcYf);
      srcY0 = MathMax(0, MathMin(srcY0, g_bgSrcH - 1));
      int srcY1 = MathMin(srcY0 + 1, g_bgSrcH - 1);
      double fy = srcYf - (int)MathFloor(srcYf);
      for(int x = 0; x < targetW; x++)
        {
         double srcXf = srcOffX + x * ((double)srcDrawW / targetW);
         int srcX0 = (int)MathFloor(srcXf);
         srcX0 = MathMax(0, MathMin(srcX0, g_bgSrcW - 1));
         int srcX1 = MathMin(srcX0 + 1, g_bgSrcW - 1);
         double fx = srcXf - (int)MathFloor(srcXf);

         uint c00 = g_bgSrcPixels[srcY0 * g_bgSrcW + srcX0];
         uint c10 = g_bgSrcPixels[srcY0 * g_bgSrcW + srcX1];
         uint c01 = g_bgSrcPixels[srcY1 * g_bgSrcW + srcX0];
         uint c11 = g_bgSrcPixels[srcY1 * g_bgSrcW + srcX1];
         uchar rr = (uchar)(((c00>>16&0xFF)*(1-fx)+(c10>>16&0xFF)*fx)*(1-fy)+((c01>>16&0xFF)*(1-fx)+(c11>>16&0xFF)*fx)*fy);
         uchar gg = (uchar)(((c00>>8&0xFF)*(1-fx)+(c10>>8&0xFF)*fx)*(1-fy)+((c01>>8&0xFF)*(1-fx)+(c11>>8&0xFF)*fx)*fy);
         uchar bb = (uchar)(((c00&0xFF)*(1-fx)+(c10&0xFF)*fx)*(1-fy)+((c01&0xFF)*(1-fx)+(c11&0xFF)*fx)*fy);
         scaled[y * targetW + x] = (uint)(0xFF000000 | (rr << 16) | (gg << 8) | bb);
        }
     }

   if(!ResourceCreate(BG_RES, scaled, (uint)targetW, (uint)targetH,
                      0, 0, (uint)targetW, COLOR_FORMAT_XRGB_NOALPHA))
     {
      PrintFormat("[BG] ResourceCreate FAILED: %dx%d, err=%d", targetW, targetH, GetLastError());
      return false;
     }
   PrintFormat("[BG] ResourceCreate OK: %dx%d", targetW, targetH);
   return true;
  }

void CreateStatusPanel()
  {
   if(g_isTester) return;  // 回测模式不创建面板
   if(!InpShowStatusPanel)
      return;

   // --- 方案A：清理所有可能残留的LINE对象（LINE5~LINE9 不应存在） ---
   for(int i = 5; i < 10; i++)
     {
      string oldLine = "HYB_LINE" + IntegerToString(i);
      if(ObjectFind(0, oldLine) >= 0)
         ObjectDelete(0, oldLine);
     }

   ResolvePanelLayout();

   // --- Chart background (背景图 cover mode, behind candles) ---
   if(g_bgSrcW == 0)
      LoadBgBmpFile(g_bgRawData, ArraySize(g_bgRawData));
   long chartW = 0, chartH = 0;
   ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0, chartW);
   ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0, chartH);
   if(g_bgSrcW > 0 && UpdateBgResource((int)chartW, (int)chartH))
     {
      if(ObjectFind(0, OBJ_CHART_BG) < 0)
         ObjectCreate(0, OBJ_CHART_BG, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_XDISTANCE, 0);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_YDISTANCE, 0);
      ObjectSetString(0, OBJ_CHART_BG, OBJPROP_BMPFILE, 0, BG_RES);
      ObjectSetString(0, OBJ_CHART_BG, OBJPROP_BMPFILE, 1, BG_RES);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_STATE, false);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_BACK, true);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, OBJ_CHART_BG, OBJPROP_HIDDEN, true);
     }

   // --- Panel background (solid color rectangle) ---
   if(ObjectFind(0, OBJ_BG) >= 0 && ObjectGetInteger(0, OBJ_BG, OBJPROP_TYPE) != OBJ_RECTANGLE_LABEL)
      ObjectDelete(0, OBJ_BG);
   if(ObjectFind(0, OBJ_BG) < 0)
      ObjectCreate(0, OBJ_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_XDISTANCE, g_panelX);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_YDISTANCE, g_panelY);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_XSIZE, g_panelW);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_YSIZE, g_panelH);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_COLOR, C'73,80,101');
   ObjectSetInteger(0, OBJ_BG, OBJPROP_BGCOLOR, C'20,26,37');
   ObjectSetInteger(0, OBJ_BG, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_BG, OBJPROP_HIDDEN, true);

   // --- Top bar (create BEFORE logo so logo Z-order is higher) ---
   int contentW = g_panelW - 120;
   if(ObjectFind(0, OBJ_TOPBAR) < 0)
      ObjectCreate(0, OBJ_TOPBAR, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_XDISTANCE, g_panelX + 8);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_YDISTANCE, g_panelY + 1);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_XSIZE, contentW - 16);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_YSIZE, 82);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_COLOR, C'45,55,75');
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BGCOLOR, C'45,55,75');
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_HIDDEN, true);

   // --- Logo Frame (black background) ---
   if(ObjectFind(0, OBJ_LOGO_FRAME) < 0)
      ObjectCreate(0, OBJ_LOGO_FRAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_XDISTANCE, g_panelX + 16);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_YDISTANCE, g_panelY + 10);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_XSIZE, 64);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_YSIZE, 64);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_COLOR, C'80,90,110');
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_ZORDER, 1);

   // --- Logo (60x60, keep aspect ratio — created AFTER topbar for Z-order) ---
   if(g_logoSrcW == 0)
      LoadLogoBmpFile(g_logoRawData, ArraySize(g_logoRawData));
   bool logoBmpOk = (g_logoSrcW > 0 && UpdateLogoResource(60, 60));
   PrintFormat("[LOGO] srcW=%d srcH=%d bmpOk=%d", g_logoSrcW, g_logoSrcH, (int)logoBmpOk);
   if(logoBmpOk)
     {
      if(ObjectFind(0, OBJ_LOGO) < 0)
         ObjectCreate(0, OBJ_LOGO, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_XDISTANCE, g_panelX + 18);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_YDISTANCE, g_panelY + 12);
      ObjectSetString(0, OBJ_LOGO, OBJPROP_BMPFILE, 0, LOGO_RES);
      ObjectSetString(0, OBJ_LOGO, OBJPROP_BMPFILE, 1, LOGO_RES);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_STATE, false);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_ZORDER, 2);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_BACK, false);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, OBJ_LOGO, OBJPROP_HIDDEN, true);
     }

   // --- Header text ---
   if(ObjectFind(0, OBJ_HEADER) < 0)
      ObjectCreate(0, OBJ_HEADER, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_XDISTANCE, g_panelX + 88);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_YDISTANCE, g_panelY + 18);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_FONTSIZE, 15);
   ObjectSetString(0, OBJ_HEADER, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_ZORDER, 3);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_HEADER, OBJPROP_HIDDEN, true);
   ObjectSetString(0, OBJ_HEADER, OBJPROP_TEXT, "金貔貅 v1.22");

   // --- Sub-header ---
   if(ObjectFind(0, OBJ_SUBHDR) < 0)
      ObjectCreate(0, OBJ_SUBHDR, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_XDISTANCE, g_panelX + 88);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_YDISTANCE, g_panelY + 48);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_COLOR, C'224,231,255');
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_ZORDER, 3);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_HIDDEN, true);
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_TEXT, "");

   // --- 3 Stat Cards ---
   int cardY = g_panelY + 90;
   int cardH = 60;
   int cardGap = 6;
   int cardW = (contentW - 16 - cardGap * 2) / 3;  // 16=左右各8px边距
   int cardX1 = g_panelX + 8;
   int cardX2 = cardX1 + cardW + cardGap;
   int cardX3 = cardX2 + cardW + cardGap;

   // Card 1
   CreateCardObj(OBJ_CARD1_BG, OBJ_CARD1_T, OBJ_CARD1_V, OBJ_CARD1_S, cardX1, cardY, cardW, cardH);
   // Card 2
   CreateCardObj(OBJ_CARD2_BG, OBJ_CARD2_T, OBJ_CARD2_V, OBJ_CARD2_S, cardX2, cardY, cardW, cardH);
   // Card 3
   CreateCardObj(OBJ_CARD3_BG, OBJ_CARD3_T, OBJ_CARD3_V, OBJ_CARD3_S, cardX3, cardY, cardW, cardH);

   // --- SMC Score Detail Area ---
   int smcY = g_panelY + 158;
   int smcCardH = 65;
   int smcX1 = cardX1;
   int smcX2 = cardX2;
   int smcX3 = cardX3;

   CreateSmcCard(OBJ_SMC_BG1, OBJ_SMC_T1, OBJ_SMC_D1A, OBJ_SMC_D1B, OBJ_SMC_D1S, smcX1, smcY, cardW, smcCardH);
   CreateSmcCard(OBJ_SMC_BG2, OBJ_SMC_T2, OBJ_SMC_D2A, OBJ_SMC_D2B, OBJ_SMC_D2S, smcX2, smcY, cardW, smcCardH);
   CreateSmcCard(OBJ_SMC_BG3, OBJ_SMC_T3, OBJ_SMC_D3A, OBJ_SMC_D3B, OBJ_SMC_D3S, smcX3, smcY, cardW, smcCardH);

   // 综合得分行
   int totalY = smcY + smcCardH + 3;
   if(ObjectFind(0, OBJ_SMC_TOTAL) < 0)
      ObjectCreate(0, OBJ_SMC_TOTAL, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_YDISTANCE, totalY);
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_COLOR, C'140,155,180');
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, OBJ_SMC_TOTAL, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_HIDDEN, true);
   ObjectSetString(0, OBJ_SMC_TOTAL, OBJPROP_TEXT, "");

   // 综合行右侧 - 账户偏移参数独立 Label（绕开 OBJPROP_TEXT 63字符上限）
   if(ObjectFind(0, OBJ_SMC_OFFSET) < 0)
      ObjectCreate(0, OBJ_SMC_OFFSET, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_XDISTANCE, g_panelX + 380);
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_YDISTANCE, totalY);
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_COLOR, C'180,200,140');
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, OBJ_SMC_OFFSET, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_SMC_OFFSET, OBJPROP_HIDDEN, true);
   ObjectSetString(0, OBJ_SMC_OFFSET, OBJPROP_TEXT, "");

   // --- Info Lines (all 6 active) ---
   int lineY = g_panelY + 250;
   int lineGap = 20;
   string lineObjs[] = {OBJ_LINE0, OBJ_LINE1, OBJ_LINE2};
   for(int i = 0; i < 3; ++i)
     {
      if(ObjectFind(0, lineObjs[i]) < 0)
         ObjectCreate(0, lineObjs[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_XDISTANCE, g_panelX + 10);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_YDISTANCE, lineY + i * lineGap);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_COLOR, C'224,231,255');
      ObjectSetInteger(0, lineObjs[i], OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, lineObjs[i], OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetString(0, lineObjs[i], OBJPROP_TEXT, "");
      ObjectSetInteger(0, lineObjs[i], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_HIDDEN, true);
     }

   // LINE4 — 止盈止损参数行（风控行下方）
   if(ObjectFind(0, OBJ_LINE4) < 0)
      ObjectCreate(0, OBJ_LINE4, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_YDISTANCE, lineY + 3 * lineGap);
   ObjectSetString(0, OBJ_LINE4, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_COLOR, C'140,155,180');
   ObjectSetString(0, OBJ_LINE4, OBJPROP_TEXT, "");
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_HIDDEN, true);

   // LINE5 — 对冲信息行（止盈止损行下方）
   if(ObjectFind(0, OBJ_LINE5) < 0)
      ObjectCreate(0, OBJ_LINE5, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_YDISTANCE, lineY + 4 * lineGap);
   ObjectSetString(0, OBJ_LINE5, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_COLOR, C'140,155,180');
   ObjectSetString(0, OBJ_LINE5, OBJPROP_TEXT, "");
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_HIDDEN, true);

   // LINE3 — 不建仓原因行（对冲行下方，初始移至屏幕外，由UpdateStatusPanel按需显示）
   if(ObjectFind(0, OBJ_LINE3) < 0)
      ObjectCreate(0, OBJ_LINE3, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, -9999); // 初始移至屏幕外，避免空文本时MT5显示默认"Label"
   ObjectSetString(0, OBJ_LINE3, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_COLOR, C'255,200,60');
   ObjectSetString(0, OBJ_LINE3, OBJPROP_TEXT, "");
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_HIDDEN, true);

   // --- Button area background ---
   int btnAreaX = g_panelX + g_panelW - 116;
   if(ObjectFind(0, OBJ_BTN_BG) < 0)
      ObjectCreate(0, OBJ_BTN_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_XDISTANCE, btnAreaX);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_YDISTANCE, g_panelY + 1);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_XSIZE, 115);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_YSIZE, g_panelH - 2);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_COLOR, C'40,48,65');
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_BGCOLOR, C'28,34,48');
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_HIDDEN, true);

   // --- 6 Buttons ---
   int btnW = 100;
   int btnH = 42;
   int btnGap = 4;
   int btnX = g_panelX + g_panelW - 108;
   string btnNames[] = {OBJ_BTN1, OBJ_BTN2, OBJ_BTN3, OBJ_BTN4, OBJ_BTN5, OBJ_BTN6};
   string btnTexts[] = {"平多单", "平空单", "平盈利", "平亏损", "全平仓", "暂停交易"};
   color btnColors[] = {C'40,120,180', C'180,100,40', C'50,150,80', C'180,60,60', C'160,50,50', C'100,110,130'};
   for(int i = 0; i < 6; ++i)
     {
      int btnY = g_panelY + 4 + i * (btnH + btnGap);
      if(ObjectFind(0, btnNames[i]) < 0)
         ObjectCreate(0, btnNames[i], OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnNames[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, btnNames[i], OBJPROP_XDISTANCE, btnX);
      ObjectSetInteger(0, btnNames[i], OBJPROP_YDISTANCE, btnY);
      ObjectSetInteger(0, btnNames[i], OBJPROP_XSIZE, btnW);
      ObjectSetInteger(0, btnNames[i], OBJPROP_YSIZE, btnH);
      ObjectSetInteger(0, btnNames[i], OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btnNames[i], OBJPROP_BGCOLOR, btnColors[i]);
      ObjectSetInteger(0, btnNames[i], OBJPROP_BORDER_COLOR, C'200,210,230');
      ObjectSetInteger(0, btnNames[i], OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, btnNames[i], OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetString(0, btnNames[i], OBJPROP_TEXT, btnTexts[i]);
      ObjectSetInteger(0, btnNames[i], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, btnNames[i], OBJPROP_HIDDEN, true);
     }
   // If already paused, show correct text
   if(g_manualPaused)
      ObjectSetString(0, OBJ_BTN6, OBJPROP_TEXT, "恢复交易");

   // --- 历史明细按钮 (在6个操作按钮与隐藏面板按钮之间) ---
   int histBtnY = g_panelY + 4 + 6 * (btnH + btnGap);
   if(ObjectFind(0, "HYB_BTN_HIST") < 0)
      ObjectCreate(0, "HYB_BTN_HIST", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_XDISTANCE, btnX);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_YDISTANCE, histBtnY);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_XSIZE, btnW);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_YSIZE, btnH);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_BGCOLOR, C'60,90,130');
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_BORDER_COLOR, C'200,210,230');
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, "HYB_BTN_HIST", OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetString(0, "HYB_BTN_HIST", OBJPROP_TEXT, "历史明细");
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "HYB_BTN_HIST", OBJPROP_HIDDEN, true);

   // --- Toggle Button (第8个按钮，在历史明细按钮下面) ---
   int toggleBtnY = g_panelY + 4 + 7 * (btnH + btnGap);
   if(ObjectFind(0, OBJ_BTN_TOGGLE) < 0)
      ObjectCreate(0, OBJ_BTN_TOGGLE, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_XDISTANCE, btnX);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_YDISTANCE, toggleBtnY);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_XSIZE, btnW);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_YSIZE, btnH);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_BGCOLOR, C'70,80,100');
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_BORDER_COLOR, C'200,210,230');
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, OBJ_BTN_TOGGLE, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetString(0, OBJ_BTN_TOGGLE, OBJPROP_TEXT, "隐藏面板");
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_HIDDEN, true);

   // --- 速度模式按钮组（顶栏右上：稳/中/快，运行时动态调整 ATR 系数） ---
   int speedBtnW = 42;
   int speedBtnH = 24;
   int speedGap  = 4;
   // 顶栏内右端 = g_panelX + g_panelW - 128（contentW=g_panelW-120，内边距8）
   int speedX0   = g_panelX + g_panelW - 128 - 8 - (speedBtnW * 3 + speedGap * 2);
   int speedY    = g_panelY + 10;
   string speedNames[3] = {OBJ_BTN_SPEED_S, OBJ_BTN_SPEED_M, OBJ_BTN_SPEED_F};
   string speedTexts[3] = {"稳", "中", "快"};
   for(int s = 0; s < 3; s++)
   {
      int sx = speedX0 + s * (speedBtnW + speedGap);
      if(ObjectFind(0, speedNames[s]) < 0)
         ObjectCreate(0, speedNames[s], OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, speedNames[s], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, speedNames[s], OBJPROP_XDISTANCE, sx);
      ObjectSetInteger(0, speedNames[s], OBJPROP_YDISTANCE, speedY);
      ObjectSetInteger(0, speedNames[s], OBJPROP_XSIZE, speedBtnW);
      ObjectSetInteger(0, speedNames[s], OBJPROP_YSIZE, speedBtnH);
      ObjectSetInteger(0, speedNames[s], OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, speedNames[s], OBJPROP_BGCOLOR, C'80,90,110');
      ObjectSetInteger(0, speedNames[s], OBJPROP_BORDER_COLOR, C'150,160,180');
      ObjectSetInteger(0, speedNames[s], OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, speedNames[s], OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetString(0, speedNames[s], OBJPROP_TEXT, speedTexts[s]);
      ObjectSetInteger(0, speedNames[s], OBJPROP_ZORDER, 11);
      ObjectSetInteger(0, speedNames[s], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, speedNames[s], OBJPROP_HIDDEN, true);
   }
   // 应用默认（或用户上次选择的）速度模式
   SetSpeedMode(g_speedMode);
  }

void CreateCardObj(string bgName, string titleName, string valueName, string subName,
                   int x, int y, int w, int h)
  {
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'55,65,85');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'35,43,60');
   ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   if(ObjectFind(0, titleName) < 0)
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, x + 8);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, y + 4);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, C'140,155,180');
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, titleName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "");

   if(ObjectFind(0, valueName) < 0)
      ObjectCreate(0, valueName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, valueName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, x + 8);
   ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, y + 20);
   ObjectSetInteger(0, valueName, OBJPROP_COLOR, C'224,231,255');
   ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 13);
   ObjectSetString(0, valueName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, valueName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, valueName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, valueName, OBJPROP_TEXT, "");

   if(ObjectFind(0, subName) < 0)
      ObjectCreate(0, subName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, subName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, subName, OBJPROP_XDISTANCE, x + 8);
   ObjectSetInteger(0, subName, OBJPROP_YDISTANCE, y + 42);
   ObjectSetInteger(0, subName, OBJPROP_COLOR, C'140,155,180');
   ObjectSetInteger(0, subName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, subName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, subName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, subName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, subName, OBJPROP_TEXT, "");
  }

void CreateSmcCard(string bgName, string titleName, string line1Name, string line2Name, string subName,
                   int x, int y, int w, int h)
  {
   // 背景框
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'55,65,85');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'35,43,60');
   ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);

   // 标题 (8pt)
   if(ObjectFind(0, titleName) < 0)
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, x + 6);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, y + 3);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, C'140,155,180');
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, titleName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "");

   // 第1行得分
   if(ObjectFind(0, line1Name) < 0)
      ObjectCreate(0, line1Name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, line1Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, line1Name, OBJPROP_XDISTANCE, x + 6);
   ObjectSetInteger(0, line1Name, OBJPROP_YDISTANCE, y + 18);
   ObjectSetInteger(0, line1Name, OBJPROP_COLOR, C'90,100,120');
   ObjectSetInteger(0, line1Name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, line1Name, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, line1Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, line1Name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, line1Name, OBJPROP_TEXT, "");

   // 第2行得分
   if(ObjectFind(0, line2Name) < 0)
      ObjectCreate(0, line2Name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, line2Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, line2Name, OBJPROP_XDISTANCE, x + 6);
   ObjectSetInteger(0, line2Name, OBJPROP_YDISTANCE, y + 33);
   ObjectSetInteger(0, line2Name, OBJPROP_COLOR, C'90,100,120');
   ObjectSetInteger(0, line2Name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, line2Name, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, line2Name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, line2Name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, line2Name, OBJPROP_TEXT, "");

   // 小计行
   if(ObjectFind(0, subName) < 0)
      ObjectCreate(0, subName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, subName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, subName, OBJPROP_XDISTANCE, x + 6);
   ObjectSetInteger(0, subName, OBJPROP_YDISTANCE, y + 48);
   ObjectSetInteger(0, subName, OBJPROP_COLOR, C'224,231,255');
   ObjectSetInteger(0, subName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, subName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, subName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, subName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, subName, OBJPROP_TEXT, "");
  }

void SetPanelVisibility(bool visible)
  {
   g_panelVisible = visible;

   if(!visible)
     {
      // 隐藏：销毁所有面板对象（DestroyStatusPanel 不会删除 OBJ_BTN_TOGGLE）
      DestroyStatusPanel();
      g_panelCreated = false;

      // 在左上角创建/保留"显示面板"按钮
      if(ObjectFind(0, OBJ_BTN_TOGGLE) < 0)
         ObjectCreate(0, OBJ_BTN_TOGGLE, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_XDISTANCE, 4);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_YDISTANCE, 4);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_XSIZE, 70);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_YSIZE, 28);
      ObjectSetString(0, OBJ_BTN_TOGGLE, OBJPROP_TEXT, "显示面板");
      ObjectSetString(0, OBJ_BTN_TOGGLE, OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_BGCOLOR, C'50,60,80');
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_BORDER_COLOR, C'80,90,110');
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_HIDDEN, true);
     }
   else
     {
      // 显示：删除左上角按钮（面板重建时 CreateStatusPanel 会创建新的）
      ObjectDelete(0, OBJ_BTN_TOGGLE);
      // g_panelCreated = false 确保下次 UpdateStatusPanel 自动重建整个面板
      g_panelCreated = false;
     }

   ChartRedraw(0);
  }

void DestroyStatusPanel()
  {
   // 注意：不删除 OBJ_BTN_TOGGLE 和 OBJ_CHART_BG，由 SetPanelVisibility / OnDeinit 单独管理
   ObjectDelete(0, OBJ_BTN_BG);
   ObjectDelete(0, OBJ_LOGO_FRAME);
   ObjectDelete(0, OBJ_LOGO);
   ObjectDelete(0, OBJ_BG);
   ObjectDelete(0, OBJ_TOPBAR);
   ObjectDelete(0, OBJ_HEADER);
   ObjectDelete(0, OBJ_SUBHDR);
   ObjectDelete(0, OBJ_CARD1_BG); ObjectDelete(0, OBJ_CARD1_T); ObjectDelete(0, OBJ_CARD1_V); ObjectDelete(0, OBJ_CARD1_S);
   ObjectDelete(0, OBJ_CARD2_BG); ObjectDelete(0, OBJ_CARD2_T); ObjectDelete(0, OBJ_CARD2_V); ObjectDelete(0, OBJ_CARD2_S);
   ObjectDelete(0, OBJ_CARD3_BG); ObjectDelete(0, OBJ_CARD3_T); ObjectDelete(0, OBJ_CARD3_V); ObjectDelete(0, OBJ_CARD3_S);
   ObjectDelete(0, OBJ_SMC_BG1); ObjectDelete(0, OBJ_SMC_BG2); ObjectDelete(0, OBJ_SMC_BG3);
   ObjectDelete(0, OBJ_SMC_T1);  ObjectDelete(0, OBJ_SMC_T2);  ObjectDelete(0, OBJ_SMC_T3);
   ObjectDelete(0, OBJ_SMC_D1A); ObjectDelete(0, OBJ_SMC_D1B); ObjectDelete(0, OBJ_SMC_D1S);
   ObjectDelete(0, OBJ_SMC_D2A); ObjectDelete(0, OBJ_SMC_D2B); ObjectDelete(0, OBJ_SMC_D2S);
   ObjectDelete(0, OBJ_SMC_D3A); ObjectDelete(0, OBJ_SMC_D3B); ObjectDelete(0, OBJ_SMC_D3S);
   ObjectDelete(0, OBJ_SMC_TOTAL);
   ObjectDelete(0, OBJ_SMC_OFFSET);
   // 删除所有可能的LINE对象 (0-9)，确保无残留
   for(int i = 0; i < 10; i++)
     {
      string lineName = "HYB_LINE" + IntegerToString(i);
      ObjectDelete(0, lineName);
     }
   ObjectDelete(0, OBJ_BTN1); ObjectDelete(0, OBJ_BTN2); ObjectDelete(0, OBJ_BTN3);
   ObjectDelete(0, OBJ_BTN4); ObjectDelete(0, OBJ_BTN5); ObjectDelete(0, OBJ_BTN6);
   ObjectDelete(0, "HYB_BTN_HIST");
   ObjectDelete(0, OBJ_BTN_SPEED_S);
   ObjectDelete(0, OBJ_BTN_SPEED_M);
   ObjectDelete(0, OBJ_BTN_SPEED_F);
   ResourceFree(LOGO_RES);
   ResourceFree(BG_RES);
  }

void UpdateStatusPanel()
  {
   if(g_isTester) return;  // 回测模式不渲染面板
   if(!InpShowStatusPanel)
      return;
   if(!g_panelVisible) return;

   if(!g_panelCreated)
     {
      CreateStatusPanel();
      g_panelCreated = true;
     }

   // 定期确保面板文字标签在前景层（矩形背景保持背景层，避免遮挡K线）
   static int s_frontCounter = 0;
   if(++s_frontCounter >= 10)
     {
      s_frontCounter = 0;
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, "HYB_") < 0) continue;
         ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
         // 矩形背景和位图保持背景层，文字标签拉到前景层
         if(objType == OBJ_LABEL || objType == OBJ_EDIT)
           {
            if((bool)ObjectGetInteger(0, name, OBJPROP_BACK))
               ObjectSetInteger(0, name, OBJPROP_BACK, false);
           }
        }
     }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double dayDd = GetTodayMaxDrawdown();
   double spread = GetCurrentSpreadPoints();
   double floatingPnl = GetEffectivePnL();

   // Account type detection
   string acctCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   bool isCent = (StringFind(acctCurrency, "USC") >= 0 || StringFind(acctCurrency, "CEN") >= 0);
   string acctType = isCent ? "美分账户" : "标准账户";

   // Direction text
   string dirText = "待机";
   if(g_martDirection == MART_DIR_BUY)      dirText = "做多";
   else if(g_martDirection == MART_DIR_SELL) dirText = "做空";

   // Sub-header with trend info
   string trendArrow = "";
   if(g_smcDirection == 1) trendArrow = "SMC趋势:涨";
   else if(g_smcDirection == -1) trendArrow = "SMC趋势:跌";
   else
     {
      // 多空打平时显示具体分数
      int bs = (g_smcImbalanceResult==1?InpSMCWeightImbalance:0) + (g_smcSDZoneResult==1?InpSMCWeightSD:0)
             + (g_smcOrderBlockResult==1?InpSMCWeightOB:0) + (g_smcFVGResult==1?InpSMCWeightFVG:0)
             + (g_smcLiqVoidResult==1?InpSMCWeightLV:0) + (g_smcBreakerResult==1?InpSMCWeightBreaker:0);
      int br = (g_smcImbalanceResult==-1?InpSMCWeightImbalance:0) + (g_smcSDZoneResult==-1?InpSMCWeightSD:0)
             + (g_smcOrderBlockResult==-1?InpSMCWeightOB:0) + (g_smcFVGResult==-1?InpSMCWeightFVG:0)
             + (g_smcLiqVoidResult==-1?InpSMCWeightLV:0) + (g_smcBreakerResult==-1?InpSMCWeightBreaker:0);
      trendArrow = StringFormat("SMC趋势:平(%d:%d)", bs, br);
     }

   string subHdr = StringFormat("%s | %s | %s  %s  授权至:%s-%s-%s", InpPresetName, _Symbol, acctType, trendArrow,
      StringSubstr(g_licenseExpiry, 0, 4), StringSubstr(g_licenseExpiry, 4, 2), StringSubstr(g_licenseExpiry, 6, 2));
   if(g_manualPaused)
      subHdr += " [暂停]";
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_TEXT, subHdr);

   // Top bar color — 仅风控锁定/暂停时变色，持仓方向不改变标题栏颜色
   color topColor = C'45,55,75';
   if(g_dailyLocked || g_martHardSLLocked || g_fastLossLocked)
      topColor = C'160,50,50';
   else if(g_manualPaused)
      topColor = C'140,110,40';
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_COLOR, topColor);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BGCOLOR, topColor);

   // --- Card 1: Basket PnL ---
   ObjectSetString(0, OBJ_CARD1_T, OBJPROP_TEXT, g_hedgeActive ? "总浮盈" : "篮子浮盈");
   string pnlText = StringFormat("%+.2f", floatingPnl);
   ObjectSetString(0, OBJ_CARD1_V, OBJPROP_TEXT, pnlText);
   ObjectSetInteger(0, OBJ_CARD1_V, OBJPROP_COLOR, floatingPnl >= 0 ? C'80,200,120' : C'255,80,80');
   color pnlColor = (g_dayRealizedPnl >= 0) ? C'0,200,120' : C'255,80,80';
   ObjectSetInteger(0, OBJ_CARD1_S, OBJPROP_COLOR, pnlColor);
   ObjectSetString(0, OBJ_CARD1_S, OBJPROP_TEXT, StringFormat("当日已平: %.2f", g_dayRealizedPnl));

   // --- Card 2: Position lots ---
   ObjectSetString(0, OBJ_CARD2_T, OBJPROP_TEXT, "持仓手数");
   ObjectSetString(0, OBJ_CARD2_V, OBJPROP_TEXT, StringFormat("%.2f手", g_martTotalLots));
   ObjectSetString(0, OBJ_CARD2_S, OBJPROP_TEXT, StringFormat("%d/%d层", g_martLayerCount, InpMartMaxLayers));

   // --- Card 3: TP progress ---
   double tpPct = 0.0;
   int tpLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTPPanel = GetDynamicTP(tpLayers);
   if(dynamicTPPanel > 0.0)
      tpPct = MathMin(100.0, MathMax(0.0, floatingPnl / dynamicTPPanel * 100.0));
   ObjectSetString(0, OBJ_CARD3_T, OBJPROP_TEXT, "TP进度");
   ObjectSetString(0, OBJ_CARD3_V, OBJPROP_TEXT, StringFormat("%.1f%%", tpPct));
   ObjectSetInteger(0, OBJ_CARD3_V, OBJPROP_COLOR, tpPct >= 75.0 ? C'80,200,120' : C'224,231,255');
   ObjectSetString(0, OBJ_CARD3_S, OBJPROP_TEXT, StringFormat("目标:%.0f", dynamicTPPanel));

   // === Panel Lines: 6行信息区 ===
   // 计算共用变量
   string sigText = "待机";
   if(g_sigMartEntryOk)
     {
      if(g_sigMartEmaDir == 1)      sigText = "做多";
      else if(g_sigMartEmaDir == -1) sigText = "做空";
     }
   string emaDirText = g_sigMartEmaDir == 1 ? "看多" : (g_sigMartEmaDir == -1 ? "看空" : "无方向");
   string modeLabel = (InpMartH4FilterMode == H4_FILTER_2K) ? "2K" : ((InpMartH4FilterMode == H4_FILTER_1K) ? "1K" : "");
   string h4Text = (InpMartH4FilterMode == H4_FILTER_OFF) ? "已关闭" : (g_sigH4Confirmed ? "已通过(" + modeLabel + ")" : "未通过");

   double curSpacing = GetMartSpacingPts();
   string distText;
   if(g_martLayerCount >= InpMartMaxLayers)
      distText = "-";
   else if(g_martLayerCount <= 0)
      distText = StringFormat("%.0f点", curSpacing);  // 无持仓时显示当前间距
   else if(g_sigMartDistToNext < 0)
     {
      double nextLot = InpMartBaseLot * MathPow(InpMartLotMultiplier, g_martMaxLayerSeq);
      if(nextLot > InpMartMaxLayerLot) nextLot = InpMartMaxLayerLot;
      if(g_martTotalLots + nextLot > InpMartMaxTotalLots)
         distText = "已触发[手数上限]";
      else
         distText = StringFormat("已触发[%.0f]", curSpacing);
     }
   else
      distText = StringFormat("%d|%.0f", g_sigMartDistToNext, curSpacing);  // 剩余距离/当前间距

   double modulePnlNow = g_dayRealizedPnl + floatingPnl;
   double deltaPnl = modulePnlNow - g_dayStartModulePnl;
   double dailyLossPct = 0.0;
   if(eq > 0.0 && deltaPnl < 0.0)
      dailyLossPct = (-deltaPnl) / eq * 100.0;

   double curLossPct = 0.0;
   if(eq > 0.0 && floatingPnl < 0.0)
     {
      double absEquity = eq - floatingPnl;
      if(absEquity > 0.0)
         curLossPct = (-floatingPnl) / absEquity * 100.0;
     }

   string riskDaily = g_dailyLocked ? "锁定" : "正常";
   string riskHardSL = g_martHardSLLocked ? "锁定" : "正常";
   string riskFast = g_fastLossLocked ? "锁定" : "正常";

   // Line 0: 综合评分明细 ─ 逐组件显示实际贡献分（可累加验证）
   {
      // 计算SMC归一化系数（COMBINED模式缩放到EMA范围，SMC_ONLY保持原值，EMA_ONLY不显示）
      int smcMaxRaw = InpSMCWeightImbalance+InpSMCWeightSD+InpSMCWeightOB+InpSMCWeightFVG+InpSMCWeightLV+InpSMCWeightBreaker;
      double smcScale = 1.0;
      if(InpEntryMode == ENTRY_COMBINED && smcMaxRaw > 0)
         smcScale = (double)InpSMCWeightEMA / smcMaxRaw;
      else if(InpEntryMode == ENTRY_EMA_ONLY)
         smcScale = 0.0;

      int imbVal = (int)MathRound(InpSMCWeightImbalance * smcScale);
      int sdVal  = (int)MathRound(InpSMCWeightSD * smcScale);
      int obVal  = (int)MathRound(InpSMCWeightOB * smcScale);
      int fvgVal = (int)MathRound(InpSMCWeightFVG * smcScale);
      int lvVal  = (int)MathRound(InpSMCWeightLV * smcScale);
      int brkVal = (int)MathRound(InpSMCWeightBreaker * smcScale);

      // 各组件得分文本（看多=+N, 看空=-N, 无=0）
      string imbT = (g_smcImbalanceResult==1) ? StringFormat("+%d",imbVal) : ((g_smcImbalanceResult==-1) ? StringFormat("-%d",imbVal) : "0");
      string sdT  = (g_smcSDZoneResult==1) ? StringFormat("+%d",sdVal) : ((g_smcSDZoneResult==-1) ? StringFormat("-%d",sdVal) : "0");
      string obT  = (g_smcOrderBlockResult==1) ? StringFormat("+%d",obVal) : ((g_smcOrderBlockResult==-1) ? StringFormat("-%d",obVal) : "0");
      string fvgT = (g_smcFVGResult==1) ? StringFormat("+%d",fvgVal) : ((g_smcFVGResult==-1) ? StringFormat("-%d",fvgVal) : "0");
      string lvT  = (g_smcLiqVoidResult==1) ? StringFormat("+%d",lvVal) : ((g_smcLiqVoidResult==-1) ? StringFormat("-%d",lvVal) : "0");
      string brkT = (g_smcBreakerResult==1) ? StringFormat("+%d",brkVal) : ((g_smcBreakerResult==-1) ? StringFormat("-%d",brkVal) : "0");

      // EMA有效性: 方向+收盘价突破快线(与入场逻辑一致)
      bool emaBullEff = (g_sigMartEmaDir==1 && g_sigMartClose1 > g_sigMartEmaFastVal);
      bool emaBearEff = (g_sigMartEmaDir==-1 && g_sigMartClose1 < g_sigMartEmaFastVal);

      // EMA组件文本(分级评分: 0=无 / 弱 / 中 / 强)
      string emaT;
      if(InpEntryMode == ENTRY_EMA_ONLY)
         emaT = (g_sigMartEmaScoreLong > 0) ? StringFormat("EMA多%d", g_sigMartEmaScoreLong)
              : ((g_sigMartEmaScoreShort > 0) ? StringFormat("EMA空%d", g_sigMartEmaScoreShort) : "EMA无0");
      else
         emaT = (g_sigMartEmaScoreLong > 0) ? StringFormat("EMA+%d", g_sigMartEmaScoreLong)
              : ((g_sigMartEmaScoreShort > 0) ? StringFormat("EMA-%d", g_sigMartEmaScoreShort) : "EMA0");

      // 计算综合总分（与入场逻辑一致）
      int totalBull, totalBear, bestScore, totalMax;
      string dirLabel;
      if(InpEntryMode == ENTRY_EMA_ONLY)
        {
         int passTh = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
         totalBull = (g_sigMartEmaScoreLong  > 0 && g_sigMartEmaScoreLong  >= passTh) ? g_sigMartEmaScoreLong  : 0;
         totalBear = (g_sigMartEmaScoreShort > 0 && g_sigMartEmaScoreShort >= passTh) ? g_sigMartEmaScoreShort : 0;
         totalMax = InpSMCWeightEMA;
        }
      else if(InpEntryMode == ENTRY_SMC_ONLY)
        {
         totalBull = (g_smcDirection==1) ? g_smcScore : 0;
         totalBear = (g_smcDirection==-1) ? g_smcScore : 0;
         totalMax = smcMaxRaw;
        }
      else // COMBINED
        {
         int normSMC = (smcMaxRaw>0) ? (int)MathRound((double)g_smcScore/smcMaxRaw*InpSMCWeightEMA) : 0;
         totalBull = g_sigMartEmaScoreLong  + ((g_smcDirection==1)  ? normSMC : 0);
         totalBear = g_sigMartEmaScoreShort + ((g_smcDirection==-1) ? normSMC : 0);
         totalMax = InpSMCWeightEMA * 2;
        }
      bestScore = MathAbs(totalBull - totalBear);   // 净分 = 强方-弱方，与入场判定一致
      dirLabel = (totalBull >= totalBear) ? "多" : "空";
      string passMark = (bestScore >= InpSMCScoreThreshold && totalBull != totalBear) ? "V" : "X";

      string scoreLine = StringFormat("%s 失:%s 供:%s 订:%s 缺:%s 空:%s 破:%s>%s 净%d/%d%s %d/%d 距:%s",
         emaT, imbT, sdT, obT, fvgT, lvT, brkT,
         dirLabel, bestScore, totalMax, passMark,
         g_martLayerCount, InpMartMaxLayers, distText);

      ObjectSetString(0, OBJ_LINE0, OBJPROP_TEXT, scoreLine);
      color sigColor = C'140,155,180';
      if(bestScore >= InpSMCScoreThreshold && totalBull != totalBear) sigColor = C'80,200,120';
      else if(totalBull > 0 || totalBear > 0) sigColor = C'255,200,60';
      ObjectSetInteger(0, OBJ_LINE0, OBJPROP_COLOR, sigColor);
   }

   // Line 1: 账户风控 ─ 权益/余额/日亏损/风控状态
   {
      string dailyLossInfo = "";
      if(InpMaxDailyLossPercent > 0.0)
         dailyLossInfo = StringFormat("  日亏:%.2f%%(>%.0f%%)", dailyLossPct, InpMaxDailyLossPercent);
      ObjectSetString(0, OBJ_LINE1, OBJPROP_TEXT,
         StringFormat("权益:%.0f  余额:%.0f%s  日锁:%s  SL:%s  熔:%s",
            eq, bal, dailyLossInfo, riskDaily, riskHardSL, riskFast));
      color riskColor = C'140,155,180';
      if(g_dailyLocked || g_martHardSLLocked || g_fastLossLocked) riskColor = C'255,80,80';
      ObjectSetInteger(0, OBJ_LINE1, OBJPROP_COLOR, riskColor);
   }

   // Line 2: 回撤浮亏 ─ 日最大回撤/浮亏/对冲触发距离
   {
      string line2Text = StringFormat("最大回撤:%.2f(%.2f%%)  当前浮亏:%.2f%%",
         dayDd, g_todayMaxDDPct, curLossPct);
      if(InpHedgeMode != HEDGE_MODE_OFF && !g_hedgeActive)
        {
         if(InpHedgeMode == HEDGE_MODE_LADDER)
            line2Text += StringFormat("  对冲阶梯:%.0f/%.0f/%.0f美分", InpHedgeLadderLoss1, InpHedgeLadderLoss2, InpHedgeLadderLoss3);
         else if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
            line2Text += StringFormat("  对冲需:%.1f%%", InpHedgeLossPercent);
         else
            line2Text += StringFormat("  对冲需:%.0f美分", InpHedgeAbsoluteUSD);
        }
      else if(g_hedgeActive)
         line2Text += StringFormat("  对冲:%d单/%.2f手", g_hedgeCount, g_hedgeLots);
      ObjectSetString(0, OBJ_LINE2, OBJPROP_TEXT, line2Text);
      ObjectSetInteger(0, OBJ_LINE2, OBJPROP_COLOR, C'140,155,180');
   }

   // Line 4: 止盈止损参数显示
   {
      // 篮子TP（动态：查表每层独立随机增量序列）
      int dispLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
      double dynamicTP = GetDynamicTP(dispLayers);
      double tpFactor = GetDeepProtectTPFactor(dispLayers);
      string tpText = (InpMartBasketTP_USD <= 0.0) ? "不限制" : StringFormat("%.0f美分", dynamicTP);
      if(InpMartBasketTP_USD > 0.0 && tpFactor < 0.999)
         tpText += StringFormat("/守护%.0f%%", tpFactor * 100.0);
      // 硬止损
      string slText = (InpMartHardSL_USD <= 0.0) ? "不限制" : StringFormat("%.0f美分", InpMartHardSL_USD);
      // 追踪门槛（动态：TP×百分比）
      double trailMinProfit = dynamicTP * InpMartTrailMinProfitPerLayer / 100.0;
      // 组合显示
      string trailText = "";
      if(InpMartTrailPct <= 0.0)
         trailText = "关闭";
      else
         trailText = StringFormat("%.0f%% 门:%.0f(TP×%.0f%%) 峰:%.1f", InpMartTrailPct, trailMinProfit, InpMartTrailMinProfitPerLayer, g_martBasketPeakPnL);
      string tpslLine = StringFormat("TP:%s(%d层)  SL:%s  追踪:%s", tpText, g_martLayerCount, slText, trailText);
      ObjectSetString(0, OBJ_LINE4, OBJPROP_TEXT, tpslLine);
      ObjectSetInteger(0, OBJ_LINE4, OBJPROP_COLOR, C'140,155,180');
   }

   // Line 5: 对冲信息行
   {
      string hedgeText = "";
      bool useLadder = (InpHedgeMode == HEDGE_MODE_LADDER);
      double panelHedgeRatio = useLadder ? GetHedgeTargetRatio(g_cachedMartPnl) : InpHedgeRatio;
      if(panelHedgeRatio <= 0.0)
         panelHedgeRatio = useLadder ? InpHedgeLadderRatio1 : InpHedgeRatio;
      double targetHedgeLot = NormalizeVolume(g_martTotalLots * panelHedgeRatio);
      if(InpHedgeMode == HEDGE_MODE_OFF)
         hedgeText = StringFormat("对冲: 已关闭  比例:%.0f%%(%.2f手)  [权益%%:%.1f%%  绝对:%.0f美分]", panelHedgeRatio*100, targetHedgeLot, InpHedgeLossPercent, InpHedgeAbsoluteUSD);
      else if(g_hedgeActive)
        {
         double totalPnl = floatingPnl + g_hedgePnl;
         int dispEffLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
         double releaseThreshold = (InpHedgeReleaseMode == HEDGE_RELEASE_FIXED) ? InpHedgeReleaseFixed : dispEffLayers * InpHedgeReleaseDynPerLayer;
         hedgeText = StringFormat("对冲: 激活中  总浮盈:%.1f(止盈>%.0f)  马丁:%.1f  对冲:%.1f  单数:%d  手数:%.2f",
            totalPnl, releaseThreshold, floatingPnl, g_hedgePnl, g_hedgeCount, g_hedgeLots);
        }
      else
        {
         if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
            hedgeText = useLadder
               ? StringFormat("对冲: 阶梯待命  %.0f/%.0f/%.0f美分 -> %.0f/%.0f/%.0f%%",
                  InpHedgeLadderLoss1, InpHedgeLadderLoss2, InpHedgeLadderLoss3,
                  InpHedgeLadderRatio1*100, InpHedgeLadderRatio2*100, InpHedgeLadderRatio3*100)
               : StringFormat("对冲: 待命  模式:权益%%  触发:浮亏超%.1f%%  比例:%.0f%%(%.2f手)  [绝对:%.0f美分]", InpHedgeLossPercent, panelHedgeRatio*100, targetHedgeLot, InpHedgeAbsoluteUSD);
         else
            hedgeText = useLadder
               ? StringFormat("对冲: 阶梯待命  %.0f/%.0f/%.0f美分 -> %.0f/%.0f/%.0f%%",
                  InpHedgeLadderLoss1, InpHedgeLadderLoss2, InpHedgeLadderLoss3,
                  InpHedgeLadderRatio1*100, InpHedgeLadderRatio2*100, InpHedgeLadderRatio3*100)
               : StringFormat("对冲: 待命  模式:绝对金额  触发:浮亏超%.0f美分  比例:%.0f%%(%.2f手)  [权益:%.1f%%]", InpHedgeAbsoluteUSD, panelHedgeRatio*100, targetHedgeLot, InpHedgeLossPercent);
        }
      ObjectSetString(0, OBJ_LINE5, OBJPROP_TEXT, hedgeText);
      ObjectSetInteger(0, OBJ_LINE5, OBJPROP_COLOR, g_hedgeActive ? C'255,200,60' : C'140,155,180');
   }

   // Line 3: 不建仓原因（有原因时移至可见位置，无原因时移至屏幕外）
   int line3Y = g_panelY + 250 + 5 * 20; // lineY + 5*lineGap（LINE5下方）
   if(g_noEntryReason != "")
     {
      ObjectSetString(0, OBJ_LINE3, OBJPROP_TEXT, "未建仓: " + g_noEntryReason);
      ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, line3Y);
      if(StringFind(g_noEntryReason, "锁定") >= 0 || StringFind(g_noEntryReason, "熔断") >= 0)
         ObjectSetInteger(0, OBJ_LINE3, OBJPROP_COLOR, C'255,80,80');
      else if(StringFind(g_noEntryReason, "暂停") >= 0 || StringFind(g_noEntryReason, "休市") >= 0)
         ObjectSetInteger(0, OBJ_LINE3, OBJPROP_COLOR, C'255,200,60');
      else
         ObjectSetInteger(0, OBJ_LINE3, OBJPROP_COLOR, C'180,190,210');
     }
   else
     {
      ObjectSetString(0, OBJ_LINE3, OBJPROP_TEXT, "");
      ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, -9999); // 移至屏幕外，彻底避免"Label"显示
     }

   // Line 3 & 4: no longer created, just safety clear

   // --- SMC Detail Update ---
   if(InpEntryMode == ENTRY_EMA_ONLY)
     {
      ObjectSetString(0, OBJ_SMC_T1, OBJPROP_TEXT, "大周期(4H)");
      ObjectSetString(0, OBJ_SMC_D1A, OBJPROP_TEXT, "已关闭");
      ObjectSetInteger(0, OBJ_SMC_D1A, OBJPROP_COLOR, C'90,100,120');
      ObjectSetString(0, OBJ_SMC_D1B, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_D1S, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_T2, OBJPROP_TEXT, "中周期(1H)");
      ObjectSetString(0, OBJ_SMC_D2A, OBJPROP_TEXT, "已关闭");
      ObjectSetInteger(0, OBJ_SMC_D2A, OBJPROP_COLOR, C'90,100,120');
      ObjectSetString(0, OBJ_SMC_D2B, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_D2S, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_T3, OBJPROP_TEXT, "小周期(15M)");
      ObjectSetString(0, OBJ_SMC_D3A, OBJPROP_TEXT, "已关闭");
      ObjectSetInteger(0, OBJ_SMC_D3A, OBJPROP_COLOR, C'90,100,120');
      ObjectSetString(0, OBJ_SMC_D3B, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_D3S, OBJPROP_TEXT, "");
      ObjectSetString(0, OBJ_SMC_TOTAL, OBJPROP_TEXT, "SMC: 已关闭 (入场模式: 仅EMA)");
      ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_COLOR, C'90,100,120');
     }
   else
     {
      // 大周期
      ObjectSetString(0, OBJ_SMC_T1, OBJPROP_TEXT, "大周期(4H)");
      string imbText = StringFormat("失衡       %s", g_smcImbalanceResult == 1 ? StringFormat("+%d", InpSMCWeightImbalance) : (g_smcImbalanceResult == -1 ? StringFormat("-%d", InpSMCWeightImbalance) : " 0"));
      ObjectSetString(0, OBJ_SMC_D1A, OBJPROP_TEXT, imbText);
      ObjectSetInteger(0, OBJ_SMC_D1A, OBJPROP_COLOR, g_smcImbalanceResult == 1 ? C'80,200,120' : (g_smcImbalanceResult == -1 ? C'255,120,80' : C'90,100,120'));
      string sdText = StringFormat("供需区     %s", g_smcSDZoneResult == 1 ? StringFormat("+%d", InpSMCWeightSD) : (g_smcSDZoneResult == -1 ? StringFormat("-%d", InpSMCWeightSD) : " 0"));
      ObjectSetString(0, OBJ_SMC_D1B, OBJPROP_TEXT, sdText);
      ObjectSetInteger(0, OBJ_SMC_D1B, OBJPROP_COLOR, g_smcSDZoneResult == 1 ? C'80,200,120' : (g_smcSDZoneResult == -1 ? C'255,120,80' : C'90,100,120'));
      int bigSum = 0;
      int bigMax = InpSMCWeightImbalance + InpSMCWeightSD;
      if(g_smcDirection == 1) { bigSum = (g_smcImbalanceResult==1?InpSMCWeightImbalance:0) + (g_smcSDZoneResult==1?InpSMCWeightSD:0); }
      else if(g_smcDirection == -1) { bigSum = (g_smcImbalanceResult==-1?InpSMCWeightImbalance:0) + (g_smcSDZoneResult==-1?InpSMCWeightSD:0); }
      ObjectSetString(0, OBJ_SMC_D1S, OBJPROP_TEXT, StringFormat("小计: %d/%d", bigSum, bigMax));
      ObjectSetInteger(0, OBJ_SMC_D1S, OBJPROP_COLOR, C'224,231,255');

      // 中周期
      ObjectSetString(0, OBJ_SMC_T2, OBJPROP_TEXT, "中周期(1H)");
      string obText = StringFormat("订单块     %s", g_smcOrderBlockResult == 1 ? StringFormat("+%d", InpSMCWeightOB) : (g_smcOrderBlockResult == -1 ? StringFormat("-%d", InpSMCWeightOB) : " 0"));
      ObjectSetString(0, OBJ_SMC_D2A, OBJPROP_TEXT, obText);
      ObjectSetInteger(0, OBJ_SMC_D2A, OBJPROP_COLOR, g_smcOrderBlockResult == 1 ? C'80,200,120' : (g_smcOrderBlockResult == -1 ? C'255,120,80' : C'90,100,120'));
      string fvgText = StringFormat("公允缺口   %s", g_smcFVGResult == 1 ? StringFormat("+%d", InpSMCWeightFVG) : (g_smcFVGResult == -1 ? StringFormat("-%d", InpSMCWeightFVG) : " 0"));
      ObjectSetString(0, OBJ_SMC_D2B, OBJPROP_TEXT, fvgText);
      ObjectSetInteger(0, OBJ_SMC_D2B, OBJPROP_COLOR, g_smcFVGResult == 1 ? C'80,200,120' : (g_smcFVGResult == -1 ? C'255,120,80' : C'90,100,120'));
      int midSum = 0;
      int midMax = InpSMCWeightOB + InpSMCWeightFVG;
      if(g_smcDirection == 1) { midSum = (g_smcOrderBlockResult==1?InpSMCWeightOB:0) + (g_smcFVGResult==1?InpSMCWeightFVG:0); }
      else if(g_smcDirection == -1) { midSum = (g_smcOrderBlockResult==-1?InpSMCWeightOB:0) + (g_smcFVGResult==-1?InpSMCWeightFVG:0); }
      ObjectSetString(0, OBJ_SMC_D2S, OBJPROP_TEXT, StringFormat("小计: %d/%d", midSum, midMax));
      ObjectSetInteger(0, OBJ_SMC_D2S, OBJPROP_COLOR, C'224,231,255');

      // 小周期
      ObjectSetString(0, OBJ_SMC_T3, OBJPROP_TEXT, "小周期(15M)");
      string lvText = StringFormat("流动空白   %s", g_smcLiqVoidResult == 1 ? StringFormat("+%d", InpSMCWeightLV) : (g_smcLiqVoidResult == -1 ? StringFormat("-%d", InpSMCWeightLV) : " 0"));
      ObjectSetString(0, OBJ_SMC_D3A, OBJPROP_TEXT, lvText);
      ObjectSetInteger(0, OBJ_SMC_D3A, OBJPROP_COLOR, g_smcLiqVoidResult == 1 ? C'80,200,120' : (g_smcLiqVoidResult == -1 ? C'255,120,80' : C'90,100,120'));
      string brkText = StringFormat("破坏块     %s", g_smcBreakerResult == 1 ? StringFormat("+%d", InpSMCWeightBreaker) : (g_smcBreakerResult == -1 ? StringFormat("-%d", InpSMCWeightBreaker) : " 0"));
      ObjectSetString(0, OBJ_SMC_D3B, OBJPROP_TEXT, brkText);
      ObjectSetInteger(0, OBJ_SMC_D3B, OBJPROP_COLOR, g_smcBreakerResult == 1 ? C'80,200,120' : (g_smcBreakerResult == -1 ? C'255,120,80' : C'90,100,120'));
      int smallSum = 0;
      int smallMax = InpSMCWeightLV + InpSMCWeightBreaker;
      if(g_smcDirection == 1) { smallSum = (g_smcLiqVoidResult==1?InpSMCWeightLV:0) + (g_smcBreakerResult==1?InpSMCWeightBreaker:0); }
      else if(g_smcDirection == -1) { smallSum = (g_smcLiqVoidResult==-1?InpSMCWeightLV:0) + (g_smcBreakerResult==-1?InpSMCWeightBreaker:0); }
      ObjectSetString(0, OBJ_SMC_D3S, OBJPROP_TEXT, StringFormat("小计: %d/%d", smallSum, smallMax));
      ObjectSetInteger(0, OBJ_SMC_D3S, OBJPROP_COLOR, C'224,231,255');

      // 综合得分行（考虑H4过滤后的真实得分）
      bool emaEffective = g_sigMartEntryOk && g_sigH4Confirmed;
      int smcMaxRaw = InpSMCWeightImbalance + InpSMCWeightSD + InpSMCWeightOB + InpSMCWeightFVG + InpSMCWeightLV + InpSMCWeightBreaker;
      int totalBull, totalBear, totalMaxScore;
      if(InpEntryMode == ENTRY_EMA_ONLY)
        {
         totalBull = (emaEffective && g_sigMartEmaDir == 1) ? InpSMCWeightEMA : 0;
         totalBear = (emaEffective && g_sigMartEmaDir == -1) ? InpSMCWeightEMA : 0;
         totalMaxScore = InpSMCWeightEMA;
        }
      else if(InpEntryMode == ENTRY_SMC_ONLY)
        {
         totalBull = (g_smcDirection == 1) ? g_smcScore : 0;
         totalBear = (g_smcDirection == -1) ? g_smcScore : 0;
         totalMaxScore = smcMaxRaw;
        }
      else // COMBINED: SMC归一化到EMA范围后相加
        {
         int normSMC = (smcMaxRaw > 0) ? (int)MathRound((double)g_smcScore / smcMaxRaw * InpSMCWeightEMA) : 0;
         totalBull = ((emaEffective && g_sigMartEmaDir == 1) ? InpSMCWeightEMA : 0) + ((g_smcDirection == 1) ? normSMC : 0);
         totalBear = ((emaEffective && g_sigMartEmaDir == -1) ? InpSMCWeightEMA : 0) + ((g_smcDirection == -1) ? normSMC : 0);
         totalMaxScore = InpSMCWeightEMA * 2;
        }
      int bestScore = MathAbs(totalBull - totalBear);   // 净分入场：强方-弱方
      string dirLabel = totalBull >= totalBear ? "多" : "空";
      string totalText = StringFormat("综合: 多:%d 空:%d [%s净%d/%d 阈值:%d]", totalBull, totalBear, dirLabel, bestScore, totalMaxScore, InpSMCScoreThreshold);
      // ATR扩张比
      double atrRatio = 1.0;
      if(g_hATR_Spacing != INVALID_HANDLE && g_hATR_SpacingLong != INVALID_HANDLE)
        {
         double atrS = GetATRValue(g_hATR_Spacing);
         double atrL = GetATRValue(g_hATR_SpacingLong);
         if(atrS > 0.0 && atrL > 0.0 && atrS/atrL > 1.0)
            atrRatio = atrS / atrL;
        }
      totalText += StringFormat("  ATR%.2f", atrRatio);
      if(InpSMC_UseCCI && g_hCCI != INVALID_HANDLE)
        {
         double cciVal[1];
         if(CopyBuffer(g_hCCI, 0, 1, 1, cciVal) >= 1)
            totalText += StringFormat(" CCI实时:%+d/±%d", (int)MathRound(cciVal[0]), InpSMC_CCIExtreme);
        }
      // 账户偏移后的实际生效参数(ATR系数/基准间距/篮子止盈) → 独立 Label，避开综合行 63字符上限
      string offsetText = StringFormat("[偏移%.3f 间距%.0f TP%.1f]", g_effATRCoeff, g_effBaseSpacing, g_effBasketTP);
      ObjectSetString(0, OBJ_SMC_OFFSET, OBJPROP_TEXT, offsetText);
      ObjectSetString(0, OBJ_SMC_TOTAL, OBJPROP_TEXT, totalText);
      ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_COLOR, bestScore >= InpSMCScoreThreshold ? C'80,200,120' : C'140,155,180');
     }
  }

//+------------------------------------------------------------------+
//| Get ATR value for a specific timeframe                            |
//+------------------------------------------------------------------+
double GetATRValue(int handle, int shift=1)
  {
   double buf[2];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
  }

//+------------------------------------------------------------------+
//| Calculate dynamic martingale spacing (points)                     |
//| First add layer uses base spacing; later layers add inc stepwise. |
//| ratio = ATR(short)/ATR(long), clamped to >=1.0                    |
//| Consolidation: ratio≈1, spacing = base+layer*inc + ATR*coeff      |
//| Strong trend: ratio>1, ATR contribution gets amplified            |
//+------------------------------------------------------------------+
double GetMartSpacingPts()
  {
   double baseSpacing = g_effBaseSpacing + MathMax(0, g_martMaxLayerSeq - 1) * InpMartIncSpacingPts;
   if(g_effATRCoeff <= 0.0 || g_hATR_Spacing == INVALID_HANDLE || g_hATR_SpacingLong == INVALID_HANDLE)
      return baseSpacing;
   double atrShort = GetATRValue(g_hATR_Spacing);
   double atrLong  = GetATRValue(g_hATR_SpacingLong);
   if(atrShort <= 0.0 || atrLong <= 0.0)
      return baseSpacing;
   double ratio = atrShort / atrLong;
   if(ratio < 1.0) ratio = 1.0;
   double expansion = MathPow(ratio, 1.5);
   return baseSpacing
          + atrShort / _Point * g_effATRCoeff * expansion;
  }

//+------------------------------------------------------------------+
//| Detect Imbalance candle on higher timeframe                       |
//| Returns: 1=bullish imbalance, -1=bearish, 0=none                 |
//+------------------------------------------------------------------+
int DetectImbalance(ENUM_TIMEFRAMES tf, int lookback, double ratio)
  {
   if(!InpSMC_Imbalance) return 0;
   for(int i = 1; i <= lookback; i++)
     {
      double open_i  = iOpen(_Symbol, tf, i);
      double close_i = iClose(_Symbol, tf, i);
      double high_i  = iHigh(_Symbol, tf, i);
      double low_i   = iLow(_Symbol, tf, i);
      double body_i  = MathAbs(close_i - open_i);

      // Previous candle range
      double high_prev = iHigh(_Symbol, tf, i + 1);
      double low_prev  = iLow(_Symbol, tf, i + 1);
      double range_prev = high_prev - low_prev;
      if(range_prev <= 0.0) continue;

      // Imbalance: body >= previous range * ratio
      if(body_i >= range_prev * ratio)
        {
         if(close_i > open_i) return 1;   // Bullish imbalance
         else                 return -1;  // Bearish imbalance
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Detect if price is near a Supply/Demand zone                      |
//| Returns: 1=near demand(bullish), -1=near supply(bearish), 0=none |
//+------------------------------------------------------------------+
int DetectSupplyDemandZone(ENUM_TIMEFRAMES tf, int lookback, double impulseMultiplier)
  {
   if(!InpSMC_SupplyDemand) return 0;
   int atrHandle = INVALID_HANDLE;
   if(tf == PERIOD_H4) atrHandle = g_hATR_H4;
   else if(tf == PERIOD_H1) atrHandle = g_hATR_H1;
   else if(tf == PERIOD_M15) atrHandle = g_hATR_M15;
   else atrHandle = g_hATR_H4;  // fallback
   double atr = GetATRValue(atrHandle);
   if(atr <= 0.0) return 0;
   double impulseThreshold = atr * impulseMultiplier;
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 1; i <= lookback - 3; i++)
     {
      double open_i  = iOpen(_Symbol, tf, i);
      double close_i = iClose(_Symbol, tf, i);
      double body_i  = MathAbs(close_i - open_i);

      // Is this an impulse candle?
      if(body_i < impulseThreshold) continue;

      // Zone = the 2-3 candles BEFORE the impulse (consolidation)
      double zoneHigh = 0.0, zoneLow = DBL_MAX;
      for(int j = i + 1; j <= MathMin(i + 3, lookback); j++)
        {
         double h = iHigh(_Symbol, tf, j);
         double l = iLow(_Symbol, tf, j);
         if(h > zoneHigh) zoneHigh = h;
         if(l < zoneLow)  zoneLow = l;
        }
      if(zoneHigh <= zoneLow) continue;

      // Expand zone slightly for tolerance
      double zoneWidth = zoneHigh - zoneLow;
      double tolerance = zoneWidth * 0.3;

      if(close_i > open_i)
        {
         // Bullish impulse -> demand zone below
         if(currentAsk >= zoneLow - tolerance && currentAsk <= zoneHigh + tolerance)
            return 1;  // Price at demand zone = bullish
        }
      else
        {
         // Bearish impulse -> supply zone above
         if(currentBid >= zoneLow - tolerance && currentBid <= zoneHigh + tolerance)
            return -1; // Price at supply zone = bearish
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Detect Order Block on medium timeframe                            |
//| Returns: 1=price at bullish OB, -1=bearish OB, 0=none           |
//+------------------------------------------------------------------+
int DetectOrderBlock(ENUM_TIMEFRAMES tf, int lookback, double impulseMultiplier)
  {
   if(!InpSMC_OrderBlock) return 0;
   double atr = GetATRValue(g_hATR_H1);
   if(atr <= 0.0) return 0;
   double impulseThreshold = atr * impulseMultiplier;
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 1; i <= lookback - 2; i++)
     {
      // Check for impulse: 2 consecutive candles in same direction > threshold
      double open1  = iOpen(_Symbol, tf, i);
      double close1 = iClose(_Symbol, tf, i);
      double open2  = iOpen(_Symbol, tf, i + 1);
      double close2 = iClose(_Symbol, tf, i + 1);
      double body1  = close1 - open1;  // signed
      double body2  = close2 - open2;  // signed

      bool bullishImpulse = (body1 > impulseThreshold && body2 > impulseThreshold);
      bool bearishImpulse = (body1 < -impulseThreshold && body2 < -impulseThreshold);

      if(!bullishImpulse && !bearishImpulse) continue;

      // Order Block = last opposite candle before impulse
      int obIdx = i + 2;
      if(obIdx > lookback) continue;
      double obOpen  = iOpen(_Symbol, tf, obIdx);
      double obClose = iClose(_Symbol, tf, obIdx);
      double obHigh  = iHigh(_Symbol, tf, obIdx);
      double obLow   = iLow(_Symbol, tf, obIdx);

      if(bullishImpulse && obClose < obOpen)
        {
         // Bullish OB: last bearish candle before bullish impulse
         double tolerance = (obHigh - obLow) * 0.2;
         if(currentBid >= obLow - tolerance && currentBid <= obHigh + tolerance)
            return 1;
        }
      else if(bearishImpulse && obClose > obOpen)
        {
         // Bearish OB: last bullish candle before bearish impulse
         double tolerance = (obHigh - obLow) * 0.2;
         if(currentBid >= obLow - tolerance && currentBid <= obHigh + tolerance)
            return -1;
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Detect Fair Value Gap                                              |
//| Returns: 1=bullish FVG(support), -1=bearish FVG(resistance), 0   |
//+------------------------------------------------------------------+
int DetectFVG(ENUM_TIMEFRAMES tf, int lookback)
  {
   if(!InpSMC_FVG) return 0;
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 1; i <= lookback - 2; i++)
     {
      double high0 = iHigh(_Symbol, tf, i);       // most recent of the 3
      double low0  = iLow(_Symbol, tf, i);
      double high2 = iHigh(_Symbol, tf, i + 2);   // oldest of the 3
      double low2  = iLow(_Symbol, tf, i + 2);

      // Bullish FVG: gap between candle[i+2].high and candle[i].low
      if(low0 > high2)
        {
         // FVG zone = [high2, low0]
         bool filled = (iLow(_Symbol, tf, 0) <= high2);
         if(!filled && currentBid >= high2 && currentBid <= low0)
            return 1;  // Price in bullish FVG = support
        }

      // Bearish FVG: gap between candle[i].high and candle[i+2].low
      if(high0 < low2)
        {
         // FVG zone = [high0, low2]
         bool filled = (iHigh(_Symbol, tf, 0) >= low2);
         if(!filled && currentBid >= high0 && currentBid <= low2)
            return -1; // Price in bearish FVG = resistance
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Detect Liquidity Void (large body, tiny wicks)                    |
//| Returns: 1=void below price(bullish), -1=above(bearish), 0=none |
//+------------------------------------------------------------------+
int DetectLiquidityVoid(ENUM_TIMEFRAMES tf, int lookback, double minBodyMultiplier)
  {
   if(!InpSMC_LiquidityVoid) return 0;
   double atr = GetATRValue(g_hATR_M15);
   if(atr <= 0.0) return 0;
   double minBody = atr * minBodyMultiplier;
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 1; i <= lookback; i++)
     {
      double open_i  = iOpen(_Symbol, tf, i);
      double close_i = iClose(_Symbol, tf, i);
      double high_i  = iHigh(_Symbol, tf, i);
      double low_i   = iLow(_Symbol, tf, i);
      double body    = MathAbs(close_i - open_i);
      double range   = high_i - low_i;
      if(range <= 0.0) continue;

      // Large body + tiny wicks (wick ratio < 20%)
      double wickRatio = (range - body) / range;
      if(body >= minBody && wickRatio < 0.20)
        {
         // This candle is a liquidity void
         double tolerance = body * 0.15;
         if(close_i > open_i)
           {
            // Bullish void: if current price is near the bottom of this void
            if(currentBid >= low_i - tolerance && currentBid <= open_i + tolerance)
               return 1;  // Price approaching void from below = bullish
           }
         else
           {
            // Bearish void: if current price is near the top of this void
            if(currentBid >= close_i - tolerance && currentBid <= high_i + tolerance)
               return -1; // Price approaching void from above = bearish
           }
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Detect Breaker (violated Order Block acting as opposite S/R)      |
//| Returns: 1=bullish breaker, -1=bearish breaker, 0=none           |
//+------------------------------------------------------------------+
int DetectBreaker(ENUM_TIMEFRAMES tf, int lookback)
  {
   if(!InpSMC_Breaker) return 0;
   double atr = GetATRValue(g_hATR_M15);
   if(atr <= 0.0) return 0;
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 3; i <= lookback - 2; i++)
     {
      // Find a potential Order Block (same logic as DetectOrderBlock but on M15)
      double open1  = iOpen(_Symbol, tf, i - 2);
      double close1 = iClose(_Symbol, tf, i - 2);
      double open2  = iOpen(_Symbol, tf, i - 1);
      double close2 = iClose(_Symbol, tf, i - 1);
      double body1  = close1 - open1;
      double body2  = close2 - open2;

      bool bullishImpulse = (body1 > atr && body2 > atr);
      bool bearishImpulse = (body1 < -atr && body2 < -atr);
      if(!bullishImpulse && !bearishImpulse) continue;

      // OB candle
      double obHigh = iHigh(_Symbol, tf, i);
      double obLow  = iLow(_Symbol, tf, i);
      double obOpen = iOpen(_Symbol, tf, i);
      double obClose = iClose(_Symbol, tf, i);

      if(bullishImpulse && obClose < obOpen)
        {
         // This was a bearish OB before bullish impulse
         // Check if it was VIOLATED later (price broke below obLow)
         bool violated = false;
         for(int k = i - 3; k >= 1; k--)
           {
            if(iLow(_Symbol, tf, k) < obLow)
              { violated = true; break; }
           }
         if(violated)
           {
            // Violated bearish OB becomes BULLISH breaker (support)
            double tolerance = (obHigh - obLow) * 0.3;
            if(currentBid >= obLow - tolerance && currentBid <= obHigh + tolerance)
               return 1;
           }
        }
      else if(bearishImpulse && obClose > obOpen)
        {
         // This was a bullish OB before bearish impulse
         // Check if it was VIOLATED (price broke above obHigh)
         bool violated = false;
         for(int k = i - 3; k >= 1; k--)
           {
            if(iHigh(_Symbol, tf, k) > obHigh)
              { violated = true; break; }
           }
         if(violated)
           {
            // Violated bullish OB becomes BEARISH breaker (resistance)
            double tolerance = (obHigh - obLow) * 0.3;
            if(currentBid >= obLow - tolerance && currentBid <= obHigh + tolerance)
               return -1;
           }
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Compute SMC composite score                                        |
//| direction: 1=bullish, -1=bearish, 0=neutral                       |
//| score: 0-70 (max without EMA component)                           |
//+------------------------------------------------------------------+
void ComputeSMCScore(int &direction, int &score)
  {
   direction = 0;
   score = 0;
   int bullScore = 0, bearScore = 0;

   // --- Large timeframe: direction (4H) ---
   int imb = DetectImbalance(PERIOD_H4, InpSMC_ImbalanceLookback, InpSMC_ImbalanceRatio);
   g_smcImbalanceResult = imb;
   if(imb == 1) bullScore += InpSMCWeightImbalance;
   else if(imb == -1) bearScore += InpSMCWeightImbalance;

   int sdz = DetectSupplyDemandZone(PERIOD_H4, InpSMC_SDZoneLookback, InpSMC_SDImpulseATR);
   g_smcSDZoneResult = sdz;
   if(sdz == 1) bullScore += InpSMCWeightSD;
   else if(sdz == -1) bearScore += InpSMCWeightSD;

   // --- Medium timeframe: entry confirmation (1H) ---
   int ob = DetectOrderBlock(PERIOD_H1, InpSMC_OBLookback, InpSMC_OBImpulseATR);
   g_smcOrderBlockResult = ob;
   if(ob == 1) bullScore += InpSMCWeightOB;
   else if(ob == -1) bearScore += InpSMCWeightOB;

   int fvg = DetectFVG(PERIOD_H1, InpSMC_FVGLookback);
   g_smcFVGResult = fvg;
   if(fvg == 1) bullScore += InpSMCWeightFVG;
   else if(fvg == -1) bearScore += InpSMCWeightFVG;

   // --- Small timeframe: precision (15M) ---
   int lv = DetectLiquidityVoid(PERIOD_M15, InpSMC_LVLookback, InpSMC_LVMinBodyATR);
   g_smcLiqVoidResult = lv;
   if(lv == 1) bullScore += InpSMCWeightLV;
   else if(lv == -1) bearScore += InpSMCWeightLV;

   int brk = DetectBreaker(PERIOD_M15, InpSMC_BreakerLookback);
   g_smcBreakerResult = brk;
   if(brk == 1) bullScore += InpSMCWeightBreaker;
   else if(brk == -1) bearScore += InpSMCWeightBreaker;

   // Determine direction by highest score
   if(bullScore > bearScore)
     { direction = 1; score = bullScore; }
   else if(bearScore > bullScore)
     { direction = -1; score = bearScore; }
   else
     { direction = 0; score = 0; }

   // Cache for panel display
   g_smcDirection = direction;
   g_smcScore = score;
  }

//=== 历史交易明细函数 ===

void RecordTradeToHistory(double closedLots, double closedPnl)
{
   if(g_isTester) return;  // 回测模式不写文件

   // 获取当前日期 MM-DD（北京时间，与 CalcMartClosedPnlToday/ResetDailyState 时区一致）
   MqlDateTime dt;
   TimeToStruct(GetChinaNow(), dt);
   string today = StringFormat("%02d-%02d", dt.mon, dt.day);
   
   // 读取现有文件数据
   LoadHistoryFromFile();
   
   // 查找今天是否已有记录
   int todayIdx = -1;
   for(int i = 0; i < g_historyCount; i++)
   {
      if(g_historyRecords[i].date == today)
      {
         todayIdx = i;
         break;
      }
   }
   
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(todayIdx < 0)
   {
      // 新增今天的记录
      g_historyCount++;
      ArrayResize(g_historyRecords, g_historyCount);
      todayIdx = g_historyCount - 1;
      g_historyRecords[todayIdx].date = today;
      g_historyRecords[todayIdx].totalLots = 0;
      g_historyRecords[todayIdx].maxLot = 0;
      g_historyRecords[todayIdx].tradeCount = 0;
      g_historyRecords[todayIdx].pnl = 0;
      g_historyRecords[todayIdx].maxDrawdown = 0;
      g_historyRecords[todayIdx].maxDDPct = 0;
   }
   
   // 更新当日统计
   g_historyRecords[todayIdx].totalLots += closedLots;
   if(closedLots > g_historyRecords[todayIdx].maxLot)
      g_historyRecords[todayIdx].maxLot = closedLots;
   g_historyRecords[todayIdx].tradeCount++;
   g_historyRecords[todayIdx].pnl += closedPnl;
   g_historyRecords[todayIdx].balance = bal;
   
   // 使用追踪的当日最大浮亏
   if(g_todayMaxDrawdown > g_historyRecords[todayIdx].maxDrawdown)
      g_historyRecords[todayIdx].maxDrawdown = g_todayMaxDrawdown;
   if(g_todayMaxDDPct > g_historyRecords[todayIdx].maxDDPct)
      g_historyRecords[todayIdx].maxDDPct = g_todayMaxDDPct;
   
   // 盈亏比 = 当日盈亏 / 余额 × 100
   if(bal > 0)
      g_historyRecords[todayIdx].pnlRatio = g_historyRecords[todayIdx].pnl / bal * 100.0;
   
   // 只保留最近N天
   while(g_historyCount > InpHistoryDays)
   {
      // 移除最旧的
      for(int i = 0; i < g_historyCount - 1; i++)
         g_historyRecords[i] = g_historyRecords[i+1];
      g_historyCount--;
      ArrayResize(g_historyRecords, g_historyCount);
   }
   
   // 写入文件
   SaveHistoryToFile();
}

void SaveHistoryToFile()
{
   int handle = FileOpen(HISTORY_FILE_NAME, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE) return;
   
   // 写入表头
   FileWrite(handle, "Date", "Lots", "MaxLot", "Count", "PnL", "PnLRatio", "Balance", "MaxDD", "MaxDDPct");
   
   for(int i = 0; i < g_historyCount; i++)
   {
      FileWrite(handle, 
         g_historyRecords[i].date,
         DoubleToString(g_historyRecords[i].totalLots, 2),
         DoubleToString(g_historyRecords[i].maxLot, 2),
         IntegerToString(g_historyRecords[i].tradeCount),
         DoubleToString(g_historyRecords[i].pnl, 2),
         DoubleToString(g_historyRecords[i].pnlRatio, 2),
         DoubleToString(g_historyRecords[i].balance, 2),
         DoubleToString(g_historyRecords[i].maxDrawdown, 2),
         DoubleToString(g_historyRecords[i].maxDDPct, 2));
   }
   FileClose(handle);
}

void LoadHistoryFromFile()
{
   if(g_isTester) return;  // 回测模式不读文件

   g_historyCount = 0;
   ArrayResize(g_historyRecords, 0);
   
   if(!FileIsExist(HISTORY_FILE_NAME)) return;
   
   int handle = FileOpen(HISTORY_FILE_NAME, FILE_READ|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE) return;
   
   // 跳过表头
   if(!FileIsEnding(handle))
   {
      FileReadString(handle); FileReadString(handle); FileReadString(handle);
      FileReadString(handle); FileReadString(handle); FileReadString(handle);
      FileReadString(handle); FileReadString(handle); FileReadString(handle);
   }
   
   while(!FileIsEnding(handle))
   {
      string dateStr = FileReadString(handle);
      if(dateStr == "") break;
      
      g_historyCount++;
      ArrayResize(g_historyRecords, g_historyCount);
      int idx = g_historyCount - 1;
      
      g_historyRecords[idx].date = dateStr;
      g_historyRecords[idx].totalLots = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxLot = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].tradeCount = (int)StringToInteger(FileReadString(handle));
      g_historyRecords[idx].pnl = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].pnlRatio = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].balance = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxDrawdown = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxDDPct = StringToDouble(FileReadString(handle));
   }
   FileClose(handle);
   
   // 只保留最近N天
   while(g_historyCount > InpHistoryDays)
   {
      for(int i = 0; i < g_historyCount - 1; i++)
         g_historyRecords[i] = g_historyRecords[i+1];
      g_historyCount--;
   }
   ArrayResize(g_historyRecords, g_historyCount);
}

void CreateHistLabel(string name, int x, int y, string text, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateHistoryPanel()
{
   if(g_isTester) return;
   if(!g_historyPanelVisible) return;
   
   // 先清除旧对象
   ObjectsDeleteAll(0, "HYB_HIST_");
   
   int panelWidth = 750;
   int rowHeight = 20;
   int headerHeight = 25;
   int rows = g_historyCount + 3; // 标题+表头+数据行+汇总
   int panelHeight = rows * rowHeight + 10;
   
   int margin = 10;  // 距右边界间距
   int startY = 10;
   // 使用LEFT_UPPER定位，计算绝对X坐标
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int startX = chartW - panelWidth - margin;
   if(startX < 0) startX = 0;
   
   // 背景矩形 - 与左侧面板风格一致
   string bgName = "HYB_HIST_BG";
   if(ObjectFind(0, bgName) >= 0)
      ObjectDelete(0, bgName);
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, startY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'73,80,101');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,26,37');
   ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   
   int y = startY + 5;
   
   // 标题
   CreateHistLabel("HYB_HIST_TITLE", panelWidth - 20, y, "历史交易明细", C'200,210,230', 10);
   // X关闭按钮
   CreateHistLabel("HYB_HIST_CLOSE", 25, y, "X", C'255,160,60', 10);
   y += headerHeight;
   
   // 表头 - 使用固定列宽
   string headers[] = {"日期", "手数", "最大手", "次数", "盈亏", "盈亏比", "余额", "最大浮亏", "最大浮亏比"};
   int colX[] = {panelWidth-20, panelWidth-80, panelWidth-140, panelWidth-200, panelWidth-255, panelWidth-330, panelWidth-410, panelWidth-490, panelWidth-580};
   
   for(int c = 0; c < 9; c++)
   {
      string name = "HYB_HIST_HDR_" + IntegerToString(c);
      CreateHistLabel(name, colX[c], y, headers[c], C'140,155,180', 9);
   }
   y += rowHeight;
   
   // 数据行（从最近的日期开始显示）
   for(int i = g_historyCount - 1; i >= 0; i--)
   {
      string rowPrefix = "HYB_HIST_R" + IntegerToString(g_historyCount - 1 - i) + "_";
      color pnlColor = (g_historyRecords[i].pnl >= 0) ? C'80,200,120' : C'255,80,80';
      color ddColor = C'255,80,80';
      
      CreateHistLabel(rowPrefix + "0", colX[0], y, g_historyRecords[i].date, C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "1", colX[1], y, DoubleToString(g_historyRecords[i].totalLots, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "2", colX[2], y, DoubleToString(g_historyRecords[i].maxLot, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "3", colX[3], y, IntegerToString(g_historyRecords[i].tradeCount), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "4", colX[4], y, StringFormat("%+.2f", g_historyRecords[i].pnl), pnlColor, 9);
      CreateHistLabel(rowPrefix + "5", colX[5], y, DoubleToString(g_historyRecords[i].pnlRatio, 2) + "%", pnlColor, 9);
      CreateHistLabel(rowPrefix + "6", colX[6], y, DoubleToString(g_historyRecords[i].balance, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "7", colX[7], y, StringFormat("-%.2f", g_historyRecords[i].maxDrawdown), ddColor, 9);
      CreateHistLabel(rowPrefix + "8", colX[8], y, DoubleToString(g_historyRecords[i].maxDDPct, 2) + "%", ddColor, 9);
      y += rowHeight;
   }
   
   // 汇总行
   double sumLots = 0, sumPnl = 0;
   int sumCount = 0;
   for(int i = 0; i < g_historyCount; i++)
   {
      sumLots += g_historyRecords[i].totalLots;
      sumCount += g_historyRecords[i].tradeCount;
      sumPnl += g_historyRecords[i].pnl;
   }
   double latestBal = (g_historyCount > 0) ? g_historyRecords[g_historyCount-1].balance : AccountInfoDouble(ACCOUNT_BALANCE);
   double sumRatio = (latestBal > 0) ? sumPnl / latestBal * 100.0 : 0.0;
   color sumPnlColor = (sumPnl >= 0) ? C'80,200,120' : C'255,80,80';
   
   CreateHistLabel("HYB_HIST_SUM_0", colX[0], y, "汇总", C'255,200,60', 9);
   CreateHistLabel("HYB_HIST_SUM_1", colX[1], y, DoubleToString(sumLots, 2), C'255,200,60', 9);
   CreateHistLabel("HYB_HIST_SUM_2", colX[2], y, "-", C'140,155,180', 9);
   CreateHistLabel("HYB_HIST_SUM_3", colX[3], y, IntegerToString(sumCount), C'255,200,60', 9);
   CreateHistLabel("HYB_HIST_SUM_4", colX[4], y, StringFormat("%+.2f", sumPnl), sumPnlColor, 9);
   CreateHistLabel("HYB_HIST_SUM_5", colX[5], y, DoubleToString(sumRatio, 2) + "%", sumPnlColor, 9);
   CreateHistLabel("HYB_HIST_SUM_6", colX[6], y, DoubleToString(latestBal, 2), C'255,200,60', 9);
   CreateHistLabel("HYB_HIST_SUM_7", colX[7], y, "-", C'140,155,180', 9);
   CreateHistLabel("HYB_HIST_SUM_8", colX[8], y, "-", C'140,155,180', 9);
   
   ChartRedraw(0);
}

void DestroyHistoryPanel()
{
   ObjectsDeleteAll(0, "HYB_HIST_");
   ChartRedraw(0);
}
