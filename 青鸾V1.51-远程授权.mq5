#property copyright "Qingluan EA"
#property version   "1.51"
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

enum HEDGE_MODE
  {
   HEDGE_MODE_OFF    = 0,    // 关闭
   HEDGE_MODE_FIXED  = 1,    // 固定比例(传统二选一触发)
   HEDGE_MODE_LADDER = 2     // 浮亏阶梯对冲(推荐)
  };

#ifndef DEF_PRESET_NAME
#define DEF_PRESET_NAME "青鸾"
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
#define DEF_MAX_SPREAD_POINTS 350
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
#define DEF_MART_MAX_LAYERS 25
#endif
#ifndef DEF_MART_BASE_SPACING
#define DEF_MART_BASE_SPACING 200
#endif
#ifndef DEF_MART_INC_SPACING
#define DEF_MART_INC_SPACING 30
#endif
#ifndef DEF_MART_ATR_SPACING_COEFF
#define DEF_MART_ATR_SPACING_COEFF 0.03
#endif
#ifndef DEF_MART_ATR_SPACING_PERIOD
#define DEF_MART_ATR_SPACING_PERIOD 3
#endif
#ifndef DEF_MART_ATR_SPACING_LONG_PERIOD
#define DEF_MART_ATR_SPACING_LONG_PERIOD 6
#endif
#ifndef DEF_MART_MAX_TOTAL_LOTS
#define DEF_MART_MAX_TOTAL_LOTS 10.0
#endif
#ifndef DEF_MART_BASKET_TP
#define DEF_MART_BASKET_TP 3.0  // 基础止盈(美分), 动态TP=基础+(层数-1)×每层增量
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
#define DEF_MART_COOLDOWN_SEC 60
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
#define DEF_ENABLE_FAST_LOSS true
#endif
#ifndef DEF_FAST_LOSS_DISTANCE
#define DEF_FAST_LOSS_DISTANCE 800
#endif
#ifndef DEF_FAST_LOSS_TIME
#define DEF_FAST_LOSS_TIME 300
#endif
#ifndef DEF_FAST_LOSS_RECOVERY_DISTANCE
#define DEF_FAST_LOSS_RECOVERY_DISTANCE 500
#endif
#ifndef DEF_FAST_LOSS_EXIT_MAX_LOSS
#define DEF_FAST_LOSS_EXIT_MAX_LOSS 300.0
#endif
#ifndef DEF_ENABLE_HEDGE
#define DEF_ENABLE_HEDGE false
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
#define DEF_PANEL_HEIGHT 374
#endif
#ifndef DEF_PANEL_REFRESH_SEC
#define DEF_PANEL_REFRESH_SEC 2
#endif
#ifndef DEF_ENTRY_MODE
#define DEF_ENTRY_MODE ENTRY_EMA_ONLY
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

// === EMA评分兼容常量 ===
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

#define REMOTE_AUTH_URL             "https://ea.newqidian365.com/api/verify.php"
#define REMOTE_AUTH_TIMEOUT_MS      5000
#define REMOTE_AUTH_CHECK_MINUTES   60
#define REMOTE_REPORT_URL           "https://ea.newqidian365.com/api/trade_report.php"
#define REMOTE_REPORT_MINUTES       3
#define REMOTE_REPORT_TIMEOUT_MS    3000
#define REMOTE_REPORT_HISTORY       true

input group "=== 基础设置 ==="
input string           InpPresetName             = DEF_PRESET_NAME;           // ▶ 策略预设名称
input long             InpMagicNumber            = DEF_MAGIC_NUMBER;          // ▶ EA唯一标识号(Magic)

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
input int              InpMartSpacingStage1MaxLayer = 5;                       // ▶ 阶梯间距1结束层
input double           InpMartSpacingStage1Factor   = 1.00;                    // ▶ 阶梯间距1倍率(1-5层)
input int              InpMartSpacingStage2MaxLayer = 10;                      // ▶ 阶梯间距2结束层
input double           InpMartSpacingStage2Factor   = 1.10;                    // ▶ 阶梯间距2倍率(6-10层)
input int              InpMartSpacingStage3MaxLayer = 15;                      // ▶ 阶梯间距3结束层
input double           InpMartSpacingStage3Factor   = 1.30;                    // ▶ 阶梯间距3倍率(11-15层)
input double           InpMartSpacingStage4Factor   = 1.60;                    // ▶ 阶梯间距4倍率(16层以上)
input bool             InpUseATRAddPause         = true;                       // ▶ ATR扩张暂停加仓
input double           InpATRAddPauseRatio       = 1.50;                       // ▶ ATR短/长超过则暂停加仓
input double           InpATRAddResumeRatio      = 1.25;                       // ▶ ATR短/长回落则恢复加仓
input double           InpMartMaxTotalLots       = DEF_MART_MAX_TOTAL_LOTS;   // ▶ 所有层加起来最大手数

// V1.49: 止盈止损细节固定，避免实盘误调。
double                 InpMartBasketTP_USD       = DEF_MART_BASKET_TP;        // V1.44 固定: 篮子止盈基础=3美分
double                 InpMartBasketTPPerLayer   = DEF_MART_BASKET_TP_PER_LAYER; // V1.44 固定: 每层TP增量=8美分
bool             InpEnableDeepProtectTP    = true;                      // 固定: 启用深层守护TP
int              InpDeepTPLevel1Start      = 6;                         // 固定: 轻度守护起始层
double           InpDeepTPLevel1Factor     = 0.85;                      // 固定: 轻度守护TP系数
int              InpDeepTPLevel2Start      = 10;                        // 固定: 中度守护起始层
double           InpDeepTPLevel2Factor     = 0.70;                      // 固定: 中度守护TP系数
int              InpDeepTPLevel3Start      = 16;                        // 固定: 重度守护起始层
double           InpDeepTPLevel3Factor     = 0.55;                      // 固定: 重度守护TP系数
double           InpDeepTPMinProfit        = 30.0;                      // 固定: 守护TP最低目标(美分)
double           InpMartHardSL_USD         = DEF_MART_HARD_SL;          // 固定: 整篮子硬止损(美分,0=关闭)
bool             InpHardSLAllowResume      = false;                     // 固定: 硬止损后当天不自动恢复
int              InpHardSLResumeMinutes    = 20;                        // 固定: 保留内部兼容
double           InpMartTrailPct           = DEF_MART_TRAIL_PCT;        // 固定: 浮盈保留峰值%平仓
double           InpMartTrailMinProfitPerLayer = DEF_MART_TRAIL_MIN_PROFIT_PER_LAYER; // 固定: 追踪启动门槛
int              InpMartCooldownSec        = DEF_MART_COOLDOWN_SEC;     // 固定: 平仓后60秒再开新篮子

// V1.49: 入场信号固定为 M5 + EMA13/34 + H4 2K + M5 RSI 精确过滤。
ENUM_TIMEFRAMES  InpMartEntryTF            = PERIOD_M5;                 // 固定: 入场信号M5
int              InpMartEmaFastPeriod      = 13;                        // 固定: 快速EMA
int              InpMartEmaSlowPeriod      = 34;                        // 固定: 慢速EMA
ENUM_H4_FILTER_MODE InpMartH4FilterMode  = H4_FILTER_2K;               // 固定: H4连续两根确认
int              InpMartStartHour          = 0;                         // 固定: 全天交易
int              InpMartEndHour            = 0;                         // 固定: 全天交易
bool             InpUseEntryChaseFilter    = true;                      // 固定: 首单防追高追低
double           InpEntryMaxDistSlowEMA_ATR = 3.0;                      // 固定: 距慢EMA超过N倍ATR不追
double           InpEntryMaxPrevBody_ATR   = 3.0;                       // 固定: 上根K实体超过N倍ATR不追
bool             InpUseEntryPrecisionFilter = true;                     // 固定: 启用首单精确过滤
ENUM_TIMEFRAMES  InpEntryPrecisionRSITF    = PERIOD_M5;                 // 固定: 精确过滤RSI用M5
int              InpEntryPrecisionRSIPeriod = 14;                       // 固定: RSI参数
double           InpEntryBuyRsiMax         = 52.0;                      // 固定: 做多RSI需低于
double           InpEntrySellRsiMin        = 48.0;                      // 固定: 做空RSI需高于
double           InpEntryMinDistSlowEMA_ATR = 0.20;                    // 固定: 距慢EMA低于N倍ATR不进
double           InpEntryMaxPullbackEMA_ATR = 1.80;                    // 固定: 距慢EMA高于N倍ATR不进
double           InpEntryMinBody_ATR       = 0.30;                      // 固定: 上根实体至少N倍ATR
bool             InpEntryRequireBodyDirection = true;                   // 固定: 上根K实体方向必须同向

int             InpMartH4EmaPeriod        = DEF_MART_H4_EMA_PERIOD;    // 固定: H4 EMA过滤周期

// V1.41: single entry mode. SMC inputs are hidden and disabled; legacy variables
// remain only so old helper code compiles without exposing extra modes.
ENUM_ENTRY_MODE InpEntryMode              = ENTRY_EMA_ONLY;
int             InpSMCScoreThreshold      = DEF_SMC_SCORE_THRESHOLD;
bool            InpSMC_Imbalance          = false;
int             InpSMC_ImbalanceLookback  = DEF_SMC_IMBALANCE_LOOKBACK;
double          InpSMC_ImbalanceRatio     = DEF_SMC_IMBALANCE_RATIO;
bool            InpSMC_SupplyDemand       = false;
int             InpSMC_SDZoneLookback     = DEF_SMC_SD_LOOKBACK;
double          InpSMC_SDImpulseATR       = DEF_SMC_SD_IMPULSE_ATR;
bool            InpSMC_OrderBlock         = false;
int             InpSMC_OBLookback         = DEF_SMC_OB_LOOKBACK;
double          InpSMC_OBImpulseATR       = DEF_SMC_OB_IMPULSE_ATR;
bool            InpSMC_FVG                = false;
int             InpSMC_FVGLookback        = DEF_SMC_FVG_LOOKBACK;
bool            InpSMC_LiquidityVoid      = false;
int             InpSMC_LVLookback         = DEF_SMC_LV_LOOKBACK;
double          InpSMC_LVMinBodyATR       = DEF_SMC_LV_MIN_BODY_ATR;
bool            InpSMC_Breaker            = false;
int             InpSMC_BreakerLookback    = DEF_SMC_BREAKER_LOOKBACK;
bool            InpSMC_UseCCI             = false;
ENUM_TIMEFRAMES InpSMC_CCI_TF             = DEF_SMC_CCI_TF;
int             InpSMC_CCIPeriod          = DEF_SMC_CCI_PERIOD;
int             InpSMC_CCIExtreme         = DEF_SMC_CCI_EXTREME;
int             InpSMCWeightImbalance     = DEF_SMC_WEIGHT_IMBALANCE;
int             InpSMCWeightSD            = DEF_SMC_WEIGHT_SD;
int             InpSMCWeightOB            = DEF_SMC_WEIGHT_OB;
int             InpSMCWeightFVG           = DEF_SMC_WEIGHT_FVG;
int             InpSMCWeightLV            = DEF_SMC_WEIGHT_LV;
int             InpSMCWeightBreaker       = DEF_SMC_WEIGHT_BREAKER;
int             InpSMCWeightEMA           = DEF_SMC_WEIGHT_EMA;

input group "=== 高级风控（默认关闭） ==="
input bool             InpEnableFastLoss        = DEF_ENABLE_FAST_LOSS;      // ▶ 启用快速亏损紧急停止
input int              InpFastLossDistance      = DEF_FAST_LOSS_DISTANCE;    // ▶ 反向价格变动触发(美分,800=8美元)
input int              InpFastLossTime          = DEF_FAST_LOSS_TIME;        // ▶ 在几秒内发生算快速亏损
input int              InpFastLossRecoveryDistance = DEF_FAST_LOSS_RECOVERY_DISTANCE; // ▶ 熔断后从极端点回撤多少美分解锁
input double           InpFastLossExitMaxLoss   = DEF_FAST_LOSS_EXIT_MAX_LOSS; // ▶ 回撤解锁时浮亏小于多少美分直接全平(0=关闭)
input HEDGE_MODE       InpHedgeMode             = HEDGE_MODE_LADDER;          // ▶ 对冲模式(关闭/固定比例/浮亏阶梯)
input double           InpHedgeAbsoluteUSD      = DEF_HEDGE_ABSOLUTE_USD;    // ▶ [固定模式]浮亏多少美分触发
input double           InpHedgeRatio            = 0.5;                       // ▶ [固定模式]对冲手数比例(0.5=50%)
input double           InpHedgeLadderLoss1      = 2000.0;                    // ▶ 阶梯1浮亏(美分)
input double           InpHedgeLadderRatio1     = 0.55;                      // ▶ 阶梯1目标对冲比例
input double           InpHedgeLadderLoss2      = 3000.0;                    // ▶ 阶梯2浮亏(美分)
input double           InpHedgeLadderRatio2     = 0.65;                      // ▶ 阶梯2目标对冲比例
input double           InpHedgeLadderLoss3      = 4500.0;                    // ▶ 阶梯3浮亏(美分)
input double           InpHedgeLadderRatio3     = 0.75;                      // ▶ 阶梯3目标对冲比例
input bool             InpEnableHedgePartialRelease = true;                 // ▶ 对冲后回收浮亏自动减对冲
input double           InpHedgePartialRecoverPct = 30.0;                    // ▶ 从最大马丁浮亏回收多少%触发减对冲
input double           InpHedgePartialClosePct  = 30.0;                     // ▶ 每次减掉当前对冲手数百分比
input double           InpHedgeMinRatioAfterPartial = 0.35;                 // ▶ 减对冲后至少保留的对冲比例
input int              InpHedgePartialMinIntervalSec = 600;                 // ▶ 两次减对冲最小间隔秒
input bool             InpEnableHedgeRepairAdd  = true;                     // ▶ 对冲后允许小仓修复
input int              InpHedgeRepairMaxAdds    = 2;                        // ▶ 单个篮子最多修复几次
input double           InpHedgeRepairLot        = 0.01;                     // ▶ 每次修复手数
input double           InpHedgeRepairMinRecoverPct = 20.0;                  // ▶ 从最大马丁浮亏回收多少%允许修复
input int              InpHedgeRepairMinIntervalSec = 900;                  // ▶ 两次修复最小间隔秒

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
datetime g_martHardSLResumeTime = 0; // optional same-day resume time after hard SL
datetime g_martLastCloseTime = 0;     // last basket close time (for cooldown)
datetime g_martLastLayerTime = 0;     // last individual layer addition time

// Account-based offset (de-correlation across accounts on same symbol)
double g_effATRCoeff    = 0.0;   // Effective ATR spacing coefficient
double g_effBasketTP    = 0.0;   // Effective basket base TP (cents)
double g_effBaseSpacing = 0.0;   // Effective base spacing (points)
double g_effIncSpacing  = 0.0;   // Effective per-layer spacing increment (points)
int    g_effEmaFast     = 0;     // Effective EMA fast period (偏移后)
int    g_effEmaSlow     = 0;     // Effective EMA slow period (偏移后)
double g_effEmaStrongAtrMult = 0.5; // EMA强信号: 距慢线ATR倍数

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
double     g_fastLossExtremePrice = 0.0; // 熔断锁定后最不利极值价（多头最低,空头最高）
int        g_fastLossLockDir     = 0;    // 锁定时的马丁方向（1=BUY,2=SELL）

bool       g_closedPnlDirty = true;        // 标记需要重新计算

string MART_COMMENT = "XAU_MART";
#define HEDGE_COMMENT "XAU_HEDGE"   // 对冲单专用注释（不含MART_COMMENT前缀）
#define FAST_CLOSING_SLOTS 1

// Hedge state
bool   g_hedgeActive = false;      // 是否有活跃对冲单
int    g_hedgeCount = 0;           // 对冲单数量
double g_hedgeLots = 0.0;          // 对冲单总手数
double g_hedgePnl = 0.0;           // 对冲单浮盈
double g_hedgeMaxMartLoss = 0.0;   // 对冲激活后的最大马丁浮亏(正数)
datetime g_hedgeLastPartialTime = 0; // 最近一次减对冲时间
datetime g_hedgeLastRepairTime = 0;  // 最近一次修复单时间
int    g_hedgeRepairAdds = 0;      // 当前篮子已开修复单次数

long     g_fastClosingMagic[FAST_CLOSING_SLOTS];   // 异步批量平仓中的Magic
datetime g_fastClosingUntil[FAST_CLOSING_SLOTS];   // 防重复发送截止时间

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
bool             g_remoteAuthorized = false;  // 远程授权状态
bool             g_remoteRenewWarning = false;// 远程授权续费提醒
string           g_remoteAuthStatus = "";     // 远程授权状态文本
string           g_remoteAuthError = "";      // 远程授权错误
datetime         g_lastRemoteAuthCheck = 0;   // 上次远程授权检查时间
bool             g_remoteAuthAlerted = false; // 授权失效报警去重
datetime         g_lastRemoteReport = 0;      // 上次盈亏状态上报时间
string           g_remoteReportError = "";    // 上报错误
int              g_remoteReportFailCount = 0; // 连续上报失败次数
datetime         g_lastRemoteAlert = 0;        // 运行中远程异常报警节流
bool             g_remoteRuntimeWarning = false; // 运行中远程异常醒目提示
string           g_remoteRuntimeWarningText = "";
long             g_lastHistoryDealMsc = 0;    // 已同步历史成交游标
long             g_lastFundDealMsc = 0;       // 已同步入金/出金游标

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
string OBJ_LINE6        = "HYB_LINE6";
string OBJ_LINE7        = "HYB_LINE7";
string OBJ_ENTRY_C0     = "HYB_ENTRY_C0";
string OBJ_ENTRY_C1     = "HYB_ENTRY_C1";
string OBJ_ENTRY_C2     = "HYB_ENTRY_C2";
string OBJ_ENTRY_C3     = "HYB_ENTRY_C3";
string OBJ_ENTRY_C4     = "HYB_ENTRY_C4";
string OBJ_ENTRY_C5     = "HYB_ENTRY_C5";
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
string OBJ_REMOTE_WARN_BG = "HYB_REMOTE_WARN_BG";
string OBJ_REMOTE_WARN_TXT = "HYB_REMOTE_WARN_TXT";
// 速度模式按钮（顶栏右上：稳/中/快）
string OBJ_BTN_SPEED_S  = "HYB_BTN_SPEED_S";  // 稳 = 0.20
string OBJ_BTN_SPEED_M  = "HYB_BTN_SPEED_M";  // 中 = 0.15
string OBJ_BTN_SPEED_F  = "HYB_BTN_SPEED_F";  // 快 = 0.10
string BG_RES           = "::HYB_BG_RES";
string LOGO_RES         = "::HYB_LOGO_RES";

int g_panelX = 10;
int g_panelY = 16;
int g_panelW = 580;
int g_panelH = 374;

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
int    g_sigH4TrendDir      = 0;       // 1=H4 bullish, -1=H4 bearish, 0=neutral/unknown
int    g_sigMartDistToNext  = 0;       // points to next layer trigger
double g_sigMartBasketPnL   = 0.0;     // current basket floating PnL
double g_sigEntryDistSlowAtr = 0.0;     // 首单防追: 收盘价距慢EMA的ATR倍数
double g_sigEntryBodyAtr     = 0.0;     // 首单防追: 上根K实体ATR倍数
int    g_sigEntryBodyDir     = 0;       // 首单精确过滤: 上根K实体方向(1阳线/-1阴线)
double g_sigEntryPrecisionRsi = 0.0;    // 首单精确过滤: RSI

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
int    g_hEntryPrecisionRSI = INVALID_HANDLE;  // 首单精确过滤RSI句柄

void   ComputeSignalDiagnostics();
string GetBlockingReason();
string GetEntryReasonLine();
string GetEntryThresholdLine();
string GetH4PanelText();
double GetHedgeTargetRatio(const double floatingPnl);
double GetHedgeRecoveryPct();
bool   CloseHedgeVolume(double volumeToClose);
bool   ManageHedgePartialRelease();
bool   TryHedgeRepairAdd();
double GetATRExpansionRatio();
bool   IsATRAddPaused();
bool   IsEntryChaseBlocked(const ENUM_POSITION_TYPE side);
bool   IsEntryPrecisionBlocked(const ENUM_POSITION_TYPE side);
double GetDeepProtectTPFactor(const int layers);
string GetNewsBlockReason();
int    GetUs0830DataMinuteBeijing(const MqlDateTime &chinaTime);
bool   CheckRemoteAuthorization(const bool showAlert);
void   MaybeRefreshRemoteAuthorization();
void   MaybeReportRemoteTradeState();
bool   ReportRemoteTradeSnapshot();
void   ReportRemoteTradeHistory();
void   ReportRemoteFundHistory(const string historyUrl);
bool   SendRemoteJson(const string url, const string json, string &body, int &httpCode, int &lastError);
string JsonEscape(const string value);
string FormatServerTime(const datetime value);
string DealTypeToText(const long type);
bool   IsFundDealType(const long type);
string DealEntryToText(const long entry);
void   SetRemoteRuntimeWarning(const string text, const bool alertNow);
void   ClearRemoteRuntimeWarning();
void   RenderRemoteWarning();
string JsonGetString(const string json, const string key, const string fallback="");
bool   JsonGetBool(const string json, const string key, const bool fallback=false);
string NormalizeRemoteExpiry(const string expiresAt);

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
//| Account-based offset: deterministic 64-bit mix to [-1, 1]          |
//| Mixes account, magic, chart id and symbol to avoid clustering.     |
//+------------------------------------------------------------------+
double GetAccountOffset(long salt)
{
   ulong h = (ulong)AccountInfoInteger(ACCOUNT_LOGIN);
   h ^= (ulong)InpMagicNumber + 0x9E3779B97F4A7C15;
   h ^= (ulong)ChartID() + 0xBF58476D1CE4E5B9;
   h ^= (ulong)(salt * 0x94D049BB133111EB);
   for(int i = 0; i < StringLen(_Symbol); ++i)
      h ^= ((ulong)StringGetCharacter(_Symbol, i) + 0x9E3779B97F4A7C15 + (h << 6) + (h >> 2));

   h ^= (h >> 30);
   h *= 0xBF58476D1CE4E5B9;
   h ^= (h >> 27);
   h *= 0x94D049BB133111EB;
   h ^= (h >> 31);

   double u = (double)(h & 0x7FFFFFFFFFFFFFFF) / 9223372036854775807.0;
   return u * 2.0 - 1.0;
}

//+------------------------------------------------------------------+
//| Apply account offsets to selected parameters (called in OnInit)   |
//| Offset ranges: ATR coeff ±30%, Basket TP ±25%, Base spacing ±45% |
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
      g_effIncSpacing  = InpMartIncSpacingPts;
      g_effEmaFast     = InpMartEmaFastPeriod;
      g_effEmaSlow     = InpMartEmaSlowPeriod;
      g_effEmaStrongAtrMult = 0.5;
      PrintFormat("[账户偏移] 回测/优化模式，使用原始参数 | ATR系数=%.4f TP基础=%.1f 基准间距=%d EMA=%d/%d",
                  g_effATRCoeff, g_effBasketTP, InpMartBaseSpacingPts, g_effEmaFast, g_effEmaSlow);
      return;
   }

   g_effATRCoeff    = InpMartATRSpacingCoeff * (1.0 + GetAccountOffset(11) * 0.30);
   g_effBasketTP    = InpMartBasketTP_USD   * (1.0 + GetAccountOffset(2) * 0.25);
   g_effBaseSpacing = InpMartBaseSpacingPts  * (1.0 + GetAccountOffset(31) * 0.45);
   g_effIncSpacing  = InpMartIncSpacingPts   * (1.0 + GetAccountOffset(32) * 0.35);
   g_effEmaStrongAtrMult = 0.5 * (1.0 + GetAccountOffset(41) * 0.40); // 0.30~0.70

   // EMA 偏移: Fast ±28%, Slow ±22%（取整，保证 fast < slow）
   double emaFastOff = GetAccountOffset(51) * 0.28;
   double emaSlowOff = GetAccountOffset(52) * 0.22;
   g_effEmaFast = (int)MathRound(InpMartEmaFastPeriod * (1.0 + emaFastOff));
   g_effEmaSlow = (int)MathRound(InpMartEmaSlowPeriod * (1.0 + emaSlowOff));
   // 安全约束: Fast≥3, Slow≥Fast+3
   if(g_effEmaFast < 3) g_effEmaFast = 3;
   if(g_effEmaSlow <= g_effEmaFast + 2) g_effEmaSlow = g_effEmaFast + 3;

   // Floor: prevent parameters going too low (but respect 0=disabled)
   if(InpMartATRSpacingCoeff > 0.0 && g_effATRCoeff < 0.001)  g_effATRCoeff = 0.001;
   if(InpMartBasketTP_USD > 0.0   && g_effBasketTP < 1.0)    g_effBasketTP = 1.0;
   if(InpMartBaseSpacingPts > 0   && g_effBaseSpacing < 20.0) g_effBaseSpacing = 20.0;
   if(InpMartIncSpacingPts > 0    && g_effIncSpacing < 0.0)   g_effIncSpacing = 0.0;
   if(g_effEmaStrongAtrMult < 0.25) g_effEmaStrongAtrMult = 0.25;
   if(g_effEmaStrongAtrMult > 0.80) g_effEmaStrongAtrMult = 0.80;

   PrintFormat("[账户偏移] 账号=%lld | ATR系数=%.4f(原%.4f) TP基础=%.1f(原%.1f) 间距=%.0f+%.0f(原%d+%d) EMA=%d/%d(原%d/%d) 强EMA=%.2fATR",
               AccountInfoInteger(ACCOUNT_LOGIN), g_effATRCoeff, InpMartATRSpacingCoeff,
               g_effBasketTP, InpMartBasketTP_USD,
               g_effBaseSpacing, g_effIncSpacing, InpMartBaseSpacingPts, InpMartIncSpacingPts,
               g_effEmaFast, g_effEmaSlow, InpMartEmaFastPeriod, InpMartEmaSlowPeriod, g_effEmaStrongAtrMult);
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
      ObjectSetInteger(0, names[i], OBJPROP_BGCOLOR, active ? C'230,180,40' : C'11,88,84');
      ObjectSetInteger(0, names[i], OBJPROP_BORDER_COLOR, active ? clrWhite : C'72,220,205');
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
      g_effATRCoeff = base * (1.0 + GetAccountOffset(11) * 0.30);
   else
      g_effATRCoeff = base;
   if(g_effATRCoeff < 0.01) g_effATRCoeff = 0.01;  // 地板保护
   RefreshSpeedButtons();
   string label = (mode == 0 ? "稳" : (mode == 1 ? "中" : "快"));
   PrintFormat("[速度切换] 模式=%s | ATR系数=%.4f(基准%.2f)", label, g_effATRCoeff, base);
}

string JsonGetString(const string json, const string key, const string fallback="")
{
   string pattern = "\"" + key + "\"";
   int p = StringFind(json, pattern);
   if(p < 0) return fallback;
   p = StringFind(json, ":", p + StringLen(pattern));
   if(p < 0) return fallback;
   p++;
   while(p < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, p);
      if(ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n') break;
      p++;
   }
   if(p >= StringLen(json) || StringGetCharacter(json, p) != '"') return fallback;
   p++;
   string out = "";
   while(p < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, p);
      if(ch == '"') break;
      if(ch == '\\' && p + 1 < StringLen(json))
      {
         p++;
         ch = StringGetCharacter(json, p);
      }
      out += CharToString((uchar)ch);
      p++;
   }
   return out;
}

bool JsonGetBool(const string json, const string key, const bool fallback=false)
{
   string pattern = "\"" + key + "\"";
   int p = StringFind(json, pattern);
   if(p < 0) return fallback;
   p = StringFind(json, ":", p + StringLen(pattern));
   if(p < 0) return fallback;
   p++;
   while(p < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, p);
      if(ch != ' ' && ch != '\t' && ch != '\r' && ch != '\n') break;
      p++;
   }
   string tail = StringSubstr(json, p, 5);
   if(StringFind(tail, "true") == 0) return true;
   if(StringFind(tail, "false") == 0) return false;
   return fallback;
}

string NormalizeRemoteExpiry(const string expiresAt)
{
   if(StringLen(expiresAt) >= 10)
   {
      string y = StringSubstr(expiresAt, 0, 4);
      string m = StringSubstr(expiresAt, 5, 2);
      string d = StringSubstr(expiresAt, 8, 2);
      if(StringToInteger(y) > 0 && StringToInteger(m) > 0 && StringToInteger(d) > 0)
         return y + m + d;
   }
   return expiresAt;
}

string JsonEscape(const string value)
{
   string out = "";
   for(int i = 0; i < StringLen(value); ++i)
   {
      ushort ch = StringGetCharacter(value, i);
      if(ch == '"') out += "\\\"";
      else if(ch == '\\') out += "\\\\";
      else if(ch == '\n') out += "\\n";
      else if(ch == '\r') out += "\\r";
      else if(ch == '\t') out += "\\t";
      else out += ShortToString(ch);
   }
   return out;
}

string FormatServerTime(const datetime value)
{
   string text = TimeToString(value, TIME_DATE | TIME_SECONDS);
   StringReplace(text, ".", "-");
   return text;
}

string DealTypeToText(const long type)
{
   if(type == DEAL_TYPE_BUY) return "buy";
   if(type == DEAL_TYPE_SELL) return "sell";
   if(type == DEAL_TYPE_BALANCE) return "balance";
   if(type == DEAL_TYPE_CREDIT) return "credit";
   if(type == DEAL_TYPE_CHARGE) return "charge";
   if(type == DEAL_TYPE_CORRECTION) return "correction";
   if(type == DEAL_TYPE_BONUS) return "bonus";
   if(type == DEAL_TYPE_COMMISSION) return "commission";
   return IntegerToString((int)type);
}

bool IsFundDealType(const long type)
{
   return (type == DEAL_TYPE_BALANCE
      || type == DEAL_TYPE_CREDIT
      || type == DEAL_TYPE_CHARGE
      || type == DEAL_TYPE_CORRECTION
      || type == DEAL_TYPE_BONUS);
}

string DealEntryToText(const long entry)
{
   if(entry == DEAL_ENTRY_IN) return "in";
   if(entry == DEAL_ENTRY_OUT) return "out";
   if(entry == DEAL_ENTRY_INOUT) return "inout";
   if(entry == DEAL_ENTRY_OUT_BY) return "out_by";
   return IntegerToString((int)entry);
}

bool SendRemoteJson(const string url, const string json, string &body, int &httpCode, int &lastError)
{
   body = "";
   httpCode = 0;
   lastError = 0;
   if(url == "") return false;

   char data[];
   char result[];
   string resultHeaders = "";
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json, data, 0, StringLen(json), CP_UTF8);
   ResetLastError();
   int timeoutMs = MathMax(500, REMOTE_REPORT_TIMEOUT_MS);
   httpCode = WebRequest("POST", url, headers, timeoutMs, data, result, resultHeaders);
   if(httpCode == -1)
   {
      lastError = GetLastError();
      body = "";
      return false;
   }
   body = CharArrayToString(result, 0, -1, CP_UTF8);
   return (httpCode >= 200 && httpCode < 300);
}

void SetRemoteRuntimeWarning(const string text, const bool alertNow)
{
   g_remoteRuntimeWarning = true;
   g_remoteRuntimeWarningText = text;
   Print(text);
   datetime now = TimeCurrent();
   if(alertNow && (g_lastRemoteAlert == 0 || now - g_lastRemoteAlert >= 300))
   {
      Alert(text);
      g_lastRemoteAlert = now;
   }
   RenderRemoteWarning();
}

void ClearRemoteRuntimeWarning()
{
   g_remoteRuntimeWarning = false;
   g_remoteRuntimeWarningText = "";
   ObjectDelete(0, OBJ_REMOTE_WARN_BG);
   ObjectDelete(0, OBJ_REMOTE_WARN_TXT);
}

void RenderRemoteWarning()
{
   if(g_isTester) return;

   string text = "";
   color bg = C'170,45,45';
   if(g_remoteRuntimeWarning)
      text = g_remoteRuntimeWarningText;
   else if(g_remoteRenewWarning)
   {
      text = "授权剩余不足3天，请及时续费";
      bg = C'180,120,20';
   }

   if(text == "")
   {
      ObjectDelete(0, OBJ_REMOTE_WARN_BG);
      ObjectDelete(0, OBJ_REMOTE_WARN_TXT);
      return;
   }

   int x = 12;
   int y = 4;
   int w = 520;
   int h = 26;
   if(ObjectFind(0, OBJ_REMOTE_WARN_BG) < 0)
      ObjectCreate(0, OBJ_REMOTE_WARN_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_COLOR, bg);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_ZORDER, 50);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_BG, OBJPROP_HIDDEN, true);

   if(ObjectFind(0, OBJ_REMOTE_WARN_TXT) < 0)
      ObjectCreate(0, OBJ_REMOTE_WARN_TXT, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_XDISTANCE, x + 10);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_YDISTANCE, y + 5);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, OBJ_REMOTE_WARN_TXT, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_ZORDER, 51);
   ObjectSetInteger(0, OBJ_REMOTE_WARN_TXT, OBJPROP_HIDDEN, true);
   ObjectSetString(0, OBJ_REMOTE_WARN_TXT, OBJPROP_TEXT, text);
}

bool ReportRemoteTradeSnapshot()
{
   if(g_isTester || REMOTE_REPORT_URL == "") return false;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double accountFloating = eq - bal;
   int openPositions = PositionsTotal();
   double totalExposure = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      totalExposure += PositionGetDouble(POSITION_VOLUME);
   }

   RefreshMartBasketState();
   RefreshHedgeState();
   double moduleFloating = g_cachedMartPnl + (g_hedgeActive ? g_hedgePnl : 0.0);

   string json = "{";
   json += "\"account_login\":\"" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "\",";
   json += "\"timestamp\":\"" + FormatServerTime(TimeCurrent()) + "\",";
   json += "\"symbol\":\"" + JsonEscape(_Symbol) + "\",";
   json += "\"version\":\"1.51R\",";
   json += "\"balance\":" + DoubleToString(bal, 2) + ",";
   json += "\"equity\":" + DoubleToString(eq, 2) + ",";
   json += "\"floating_profit\":" + DoubleToString(accountFloating, 2) + ",";
   json += "\"realized_profit\":" + DoubleToString(g_dayRealizedPnl, 2) + ",";
   json += "\"open_positions\":" + IntegerToString(openPositions) + ",";
   json += "\"total_exposure\":" + DoubleToString(totalExposure, 2) + ",";
   json += "\"margin\":" + DoubleToString(margin, 2) + ",";
   json += "\"free_margin\":" + DoubleToString(freeMargin, 2) + ",";
   json += "\"module_floating_profit\":" + DoubleToString(moduleFloating, 2) + ",";
   json += "\"mart_floating_profit\":" + DoubleToString(g_cachedMartPnl, 2) + ",";
   json += "\"hedge_floating_profit\":" + DoubleToString(g_hedgePnl, 2) + ",";
   json += "\"mart_lots\":" + DoubleToString(g_martTotalLots, 2) + ",";
   json += "\"hedge_lots\":" + DoubleToString(g_hedgeLots, 2) + ",";
   json += "\"mart_layers\":" + IntegerToString(g_martLayerCount) + ",";
   json += "\"auth_status\":\"" + JsonEscape(g_remoteAuthStatus) + "\",";
   json += "\"auth_expires\":\"" + JsonEscape(g_licenseExpiry) + "\"";
   json += "}";

   string body;
   int httpCode = 0;
   int lastError = 0;
   bool ok = SendRemoteJson(REMOTE_REPORT_URL, json, body, httpCode, lastError);
   if(!ok)
   {
      g_remoteReportFailCount++;
      if(httpCode == -1)
         g_remoteReportError = StringFormat("交易状态上报失败: WebRequest错误=%d 连续%d次", lastError, g_remoteReportFailCount);
      else
         g_remoteReportError = StringFormat("交易状态上报失败: HTTP=%d %s 连续%d次", httpCode, body, g_remoteReportFailCount);

      Print(g_remoteReportError);
      if(g_remoteReportFailCount >= 3)
         SetRemoteRuntimeWarning(g_remoteReportError, true);
      return false;
   }

   g_remoteReportError = "";
   g_remoteReportFailCount = 0;
   if(!g_remoteRuntimeWarning || StringFind(g_remoteRuntimeWarningText, "上报") >= 0)
      ClearRemoteRuntimeWarning();
   return true;
}

void ReportRemoteTradeHistory()
{
   if(g_isTester || !REMOTE_REPORT_HISTORY) return;
   string historyUrl = REMOTE_REPORT_URL;
   int p = StringFind(historyUrl, "trade_report.php");
   if(p >= 0)
      historyUrl = StringSubstr(historyUrl, 0, p) + "trade_history.php";
   if(historyUrl == REMOTE_REPORT_URL) return;

   string gvName = "JPX_LAST_DEAL_MSC_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + IntegerToString((int)InpMagicNumber);
   if(g_lastHistoryDealMsc <= 0 && GlobalVariableCheck(gvName))
      g_lastHistoryDealMsc = (long)GlobalVariableGet(gvName);

   datetime fromTime = TimeCurrent() - 86400 * 14;
   if(!HistorySelect(fromTime, TimeCurrent())) return;

   long maxSent = g_lastHistoryDealMsc;
   int sent = 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals && sent < 50; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      long dealMsc = (long)HistoryDealGetInteger(deal, DEAL_TIME_MSC);
      if(dealMsc <= g_lastHistoryDealMsc) continue;
      long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
      bool isFundDeal = IsFundDealType(dealType);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(!isFundDeal)
      {
         if(!IsManagedMagic((long)HistoryDealGetInteger(deal, DEAL_MAGIC))) continue;
         if(!IsManagedSymbol(HistoryDealGetString(deal, DEAL_SYMBOL))) continue;
         if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;
      }
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      string dealSymbol = HistoryDealGetString(deal, DEAL_SYMBOL);
      if(dealSymbol == "") dealSymbol = "ACCOUNT";

      string json = "{";
      json += "\"account_login\":\"" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "\",";
      json += "\"deal_ticket\":\"" + IntegerToString((long)deal) + "\",";
      json += "\"symbol\":\"" + JsonEscape(dealSymbol) + "\",";
      json += "\"deal_type\":\"" + DealTypeToText(dealType) + "\",";
      json += "\"entry_type\":\"" + DealEntryToText(entry) + "\",";
      json += "\"volume\":" + DoubleToString(HistoryDealGetDouble(deal, DEAL_VOLUME), 2) + ",";
      json += "\"price\":" + DoubleToString(HistoryDealGetDouble(deal, DEAL_PRICE), _Digits) + ",";
      json += "\"profit\":" + DoubleToString(profit, 2) + ",";
      json += "\"commission\":" + DoubleToString(commission, 2) + ",";
      json += "\"swap\":" + DoubleToString(swap, 2) + ",";
      json += "\"total_pnl\":" + DoubleToString(profit + commission + swap, 2) + ",";
      json += "\"deal_time\":\"" + FormatServerTime((datetime)HistoryDealGetInteger(deal, DEAL_TIME)) + "\",";
      json += "\"magic_number\":" + IntegerToString((long)HistoryDealGetInteger(deal, DEAL_MAGIC));
      json += "}";

      string body;
      int httpCode = 0;
      int lastError = 0;
      bool ok = SendRemoteJson(historyUrl, json, body, httpCode, lastError);
      if(!ok)
      {
         if(httpCode == -1)
            PrintFormat("历史成交上报失败: WebRequest错误=%d", lastError);
         else
            PrintFormat("历史成交上报失败: HTTP=%d %s", httpCode, body);
         break;
      }
      if(dealMsc > maxSent) maxSent = dealMsc;
      sent++;
   }

   if(maxSent > g_lastHistoryDealMsc)
   {
      g_lastHistoryDealMsc = maxSent;
      GlobalVariableSet(gvName, (double)g_lastHistoryDealMsc);
   }

   ReportRemoteFundHistory(historyUrl);
}

void ReportRemoteFundHistory(const string historyUrl)
{
   string gvName = "JPX_LAST_FUND_DEAL_MSC_" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   if(g_lastFundDealMsc <= 0 && GlobalVariableCheck(gvName))
      g_lastFundDealMsc = (long)GlobalVariableGet(gvName);

   datetime fromTime = TimeCurrent() - 86400 * 3650;
   if(!HistorySelect(fromTime, TimeCurrent())) return;

   long maxSent = g_lastFundDealMsc;
   int sent = 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals && sent < 20; ++i)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      long dealMsc = (long)HistoryDealGetInteger(deal, DEAL_TIME_MSC);
      if(dealMsc <= g_lastFundDealMsc) continue;
      long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
      if(!IsFundDealType(dealType)) continue;

      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(deal, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);

      string json = "{";
      json += "\"account_login\":\"" + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "\",";
      json += "\"deal_ticket\":\"" + IntegerToString((long)deal) + "\",";
      json += "\"symbol\":\"ACCOUNT\",";
      json += "\"deal_type\":\"" + DealTypeToText(dealType) + "\",";
      json += "\"entry_type\":\"" + DealEntryToText(entry) + "\",";
      json += "\"volume\":0.00,";
      json += "\"price\":0.00,";
      json += "\"profit\":" + DoubleToString(profit, 2) + ",";
      json += "\"commission\":" + DoubleToString(commission, 2) + ",";
      json += "\"swap\":" + DoubleToString(swap, 2) + ",";
      json += "\"total_pnl\":" + DoubleToString(profit + commission + swap, 2) + ",";
      json += "\"deal_time\":\"" + FormatServerTime((datetime)HistoryDealGetInteger(deal, DEAL_TIME)) + "\",";
      json += "\"magic_number\":0";
      json += "}";

      string body;
      int httpCode = 0;
      int lastError = 0;
      bool ok = SendRemoteJson(historyUrl, json, body, httpCode, lastError);
      if(!ok)
      {
         if(httpCode == -1)
            PrintFormat("资金流水上报失败: WebRequest错误=%d", lastError);
         else
            PrintFormat("资金流水上报失败: HTTP=%d %s", httpCode, body);
         break;
      }
      if(dealMsc > maxSent) maxSent = dealMsc;
      sent++;
   }

   if(maxSent > g_lastFundDealMsc)
   {
      g_lastFundDealMsc = maxSent;
      GlobalVariableSet(gvName, (double)g_lastFundDealMsc);
   }
}

void MaybeReportRemoteTradeState()
{
   if(g_isTester) return;
   if(REMOTE_REPORT_MINUTES <= 0) return;
   if(g_lastRemoteReport > 0 && TimeCurrent() - g_lastRemoteReport < REMOTE_REPORT_MINUTES * 60)
      return;
   g_lastRemoteReport = TimeCurrent();
   if(ReportRemoteTradeSnapshot())
      ReportRemoteTradeHistory();
}

bool CheckRemoteAuthorization(const bool showAlert)
{
   g_lastRemoteAuthCheck = TimeCurrent();
   g_remoteAuthError = "";

   string account = IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN));
   string url = REMOTE_AUTH_URL;
   string sep = (StringFind(url, "?") >= 0) ? "&" : "?";
   url += sep + "account_login=" + account + "&version=1.51R&product=XAUUSD";

   char data[];
   char result[];
   string resultHeaders = "";
   ResetLastError();
   int httpCode = WebRequest("GET", url, "", REMOTE_AUTH_TIMEOUT_MS, data, result, resultHeaders);
   if(httpCode == -1)
   {
      int err = GetLastError();
      g_remoteAuthStatus = "request_failed";
      g_remoteAuthError = StringFormat("远程授权请求失败，错误%d。请在MT5 工具-选项-EA交易 中允许URL: %s", err, REMOTE_AUTH_URL);
      if(g_remoteAuthorized)
      {
         SetRemoteRuntimeWarning(g_remoteAuthError + "；EA继续按上次授权状态运行", true);
         return true;
      }
      if(showAlert) Alert(g_remoteAuthError);
      Print(g_remoteAuthError);
      return false;
   }

   string body = CharArrayToString(result, 0, -1, CP_UTF8);
   if(httpCode < 200 || httpCode >= 300)
   {
      g_remoteAuthStatus = "http_error";
      g_remoteAuthError = StringFormat("远程授权服务器异常: HTTP=%d", httpCode);
      if(g_remoteAuthorized)
      {
         SetRemoteRuntimeWarning(g_remoteAuthError + "；EA继续按上次授权状态运行", true);
         return true;
      }
      if(showAlert) Alert(g_remoteAuthError);
      Print(g_remoteAuthError, " body=", body);
      return false;
   }

   bool authorized = JsonGetBool(body, "authorized", false);
   string status = JsonGetString(body, "status", "unknown");
   string expiresAt = JsonGetString(body, "expires_at", "");
   bool renewWarning = JsonGetBool(body, "renew_warning", false);

   g_remoteAuthorized = authorized;
   g_remoteAuthStatus = status;
   g_remoteRenewWarning = renewWarning;
   if(expiresAt != "")
      g_licenseExpiry = NormalizeRemoteExpiry(expiresAt);

   if(!authorized)
   {
      g_remoteAuthError = StringFormat("远程授权失败: HTTP=%d status=%s account=%s", httpCode, status, account);
      if(showAlert) Alert(g_remoteAuthError);
      Print(g_remoteAuthError, " body=", body);
      return false;
   }

   g_remoteAuthAlerted = false;
   if(g_remoteRuntimeWarning && StringFind(g_remoteRuntimeWarningText, "远程授权") >= 0)
      ClearRemoteRuntimeWarning();
   RenderRemoteWarning();
   PrintFormat("远程授权通过: 账号=%s 状态=%s 有效期=%s 续费提醒=%s",
               account, status, expiresAt, renewWarning ? "true" : "false");
   return true;
}

void MaybeRefreshRemoteAuthorization()
{
   if(g_isTester) return;
   if(REMOTE_AUTH_CHECK_MINUTES <= 0) return;
   if(g_lastRemoteAuthCheck > 0 && TimeCurrent() - g_lastRemoteAuthCheck < REMOTE_AUTH_CHECK_MINUTES * 60)
      return;

   bool ok = CheckRemoteAuthorization(false);
   if(!ok && !g_remoteAuthAlerted)
   {
      Alert(g_remoteAuthError);
      g_remoteAuthAlerted = true;
   }
}

int OnInit()
  {
   // 检测回测/优化模式
   g_isTester = (bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   // === 远程授权验证 ===
   // 回测模式跳过授权验证
   if(!g_isTester)
   {
      if(!CheckRemoteAuthorization(true))
      {
         PrintFormat("REMOTE LICENSE FAILED: %s", g_remoteAuthError);
         return INIT_FAILED;
      }
   }
   else
   {
      g_licenseExpiry = "回测模式";
      g_remoteAuthorized = true;
      Print("Tester mode: remote license check skipped");
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

   if(InpUseEntryPrecisionFilter)
     {
      g_hEntryPrecisionRSI = iRSI(_Symbol, InpEntryPrecisionRSITF, InpEntryPrecisionRSIPeriod, PRICE_CLOSE);
      if(g_hEntryPrecisionRSI == INVALID_HANDLE)
         Print("[首单精确过滤] RSI句柄初始化失败，将跳过RSI过滤");
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
      timerSec = MathMax(1, InpPanelRefreshSec);
   if(!g_isTester && REMOTE_AUTH_CHECK_MINUTES > 0)
   {
      int authTimer = MathMax(30, MathMin(300, REMOTE_AUTH_CHECK_MINUTES * 60));
      timerSec = (timerSec > 0) ? MathMin(timerSec, authTimer) : authTimer;
   }
   if(!g_isTester && REMOTE_REPORT_MINUTES > 0)
   {
      int reportTimer = MathMax(30, MathMin(300, REMOTE_REPORT_MINUTES * 60));
      timerSec = (timerSec > 0) ? MathMin(timerSec, reportTimer) : reportTimer;
   }
   if(timerSec > 0)
      EventSetTimer(timerSec);
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
   if(g_hEntryPrecisionRSI != INVALID_HANDLE) IndicatorRelease(g_hEntryPrecisionRSI);
  }

void OnTimer()
  {
   MaybeRefreshRemoteAuthorization();
   MaybeReportRemoteTradeState();
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

   if(!g_isTester && !g_remoteAuthorized)
     {
      g_noEntryReason = "远程授权失效/过期";
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();
         ManageHedgeLock();
         if(ManageHedgeRelease() || ManageHedgePartialRelease() || TryHedgeRepairAdd() || ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
           {
            ComputeSignalDiagnostics();
            if(InpShowStatusPanel) UpdateStatusPanel();
            return;
           }
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   // Daily loss lock check
   if(CheckDailyLossLock())
     {
      CloseAllMartPositions();
      g_dailyLocked = true;
      g_noEntryReason = "日亏损锁定(超" + DoubleToString(InpMaxDailyLossPercent,1) + "%)";
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   if(g_martHardSLLocked && InpHardSLAllowResume && g_martHardSLResumeTime > 0 && TimeCurrent() >= g_martHardSLResumeTime)
     {
      g_martHardSLLocked = false;
      g_martHardSLResumeTime = 0;
      g_noEntryReason = "";
      Print("[硬止损恢复] 等待时间已到，允许重新开新篮子");
     }

   if(g_dailyLocked || g_martHardSLLocked)
     {
      if(g_dailyLocked)
         g_noEntryReason = "日亏损锁定(超" + DoubleToString(InpMaxDailyLossPercent,1) + "%)";
      else
        {
         if(InpHardSLAllowResume && g_martHardSLResumeTime > TimeCurrent())
           {
            int remainMin = (int)MathCeil((double)(g_martHardSLResumeTime - TimeCurrent()) / 60.0);
            g_noEntryReason = StringFormat("硬止损熔断(%d分钟后恢复)", remainMin);
           }
         else
            g_noEntryReason = "硬止损熔断(浮亏超$" + DoubleToString(InpMartHardSL_USD,0) + ")";
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
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
         if(ManageHedgeRelease() || ManageHedgePartialRelease() || TryHedgeRepairAdd() || ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
           {
            ComputeSignalDiagnostics();
            if(InpShowStatusPanel) UpdateStatusPanel();
            return;
           }
        }
      else
        {
         // 篮子已全平但本分支 return 跳过了主逻辑的 g_martDirection 重置点
         // 手动置 NONE，使下一 tick CheckFastLossBreaker 的 NONE 分支自动解除锁定
         g_martDirection = MART_DIR_NONE;
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
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
         if(ManageHedgeRelease() || ManageHedgePartialRelease() || TryHedgeRepairAdd() || ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
           {
            ComputeSignalDiagnostics();
            if(InpShowStatusPanel) UpdateStatusPanel();
            return;
           }
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
         if(ManageHedgeRelease() || ManageHedgePartialRelease() || TryHedgeRepairAdd() || ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
           {
            ComputeSignalDiagnostics();
            if(InpShowStatusPanel) UpdateStatusPanel();
            return;
           }
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
         if(ManageHedgeRelease() || ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
           {
            ComputeSignalDiagnostics();
            if(InpShowStatusPanel) UpdateStatusPanel();
            return;
           }
        }
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

   // Hedge lock check (default off)
   ManageHedgeLock();
   if(ManageHedgeRelease() || ManageHedgePartialRelease() || TryHedgeRepairAdd())
     {
      ComputeSignalDiagnostics();
      if(InpShowStatusPanel) UpdateStatusPanel();
      return;
     }

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

      if(ManageMartBasketTP() || CheckMartHardSL() || ManageMartTrailing())
        {
         ComputeSignalDiagnostics();
         if(InpShowStatusPanel) UpdateStatusPanel();
         return;
        }
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
   bool hadPositions = CloseBasketByMagic(GetActiveMagicNumber());
   CancelMartOrders();
   if(hadPositions)
     {
      g_martLastCloseTime = TimeCurrent();
      g_hedgeActive = false;
      g_hedgeMaxMartLoss = 0.0;
      g_hedgeLastPartialTime = 0;
      g_hedgeLastRepairTime = 0;
      g_hedgeRepairAdds = 0;
      g_cachedMartPnl = 0.0;
      g_closedPnlDirty = true;
     }
  }

void CancelMartOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != GetActiveMagicNumber())
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber())
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber())
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

void GetBasketStatsByMagic(const long magic, int &martCount, double &martLots, double &martPnl,
                           int &hedgeCount, double &hedgeLots, double &hedgePnl,
                           ENUM_MART_DIRECTION &dir)
  {
   martCount = 0;
   martLots = 0.0;
   martPnl = 0.0;
   hedgeCount = 0;
   hedgeLots = 0.0;
   hedgePnl = 0.0;
   int buys = 0;
   int sells = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      bool isHedge = (StringFind(cmt, HEDGE_COMMENT) >= 0);
      bool isMart = (StringFind(cmt, MART_COMMENT) >= 0 && !isHedge);
      if(!isMart && !isHedge) continue;

      double lots = PositionGetDouble(POSITION_VOLUME);
      double pnl = PositionGetDouble(POSITION_PROFIT);
      if(isHedge)
        {
         hedgeCount++;
         hedgeLots += lots;
         hedgePnl += pnl;
        }
      else
        {
         martCount++;
         martLots += lots;
         martPnl += pnl;
         long type = PositionGetInteger(POSITION_TYPE);
         if(type == POSITION_TYPE_BUY) buys++;
         else if(type == POSITION_TYPE_SELL) sells++;
        }
     }

   if(buys > 0 && sells == 0) dir = MART_DIR_BUY;
   else if(sells > 0 && buys == 0) dir = MART_DIR_SELL;
   else dir = MART_DIR_NONE;
  }

bool BasketHasAnyPosition(const int index)
  {
   int mc, hc;
   double ml, mp, hl, hp;
   ENUM_MART_DIRECTION d;
   GetBasketStatsByMagic(GetBasketMagicByIndex(index), mc, ml, mp, hc, hl, hp, d);
   return (mc > 0 || hc > 0);
  }

double GetBasketMartAvgPriceByMagic(const long magic, const ENUM_MART_DIRECTION dir, double &lots)
  {
   lots = 0.0;
   double weighted = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) < 0 || StringFind(cmt, HEDGE_COMMENT) >= 0) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == MART_DIR_BUY && type != POSITION_TYPE_BUY) continue;
      if(dir == MART_DIR_SELL && type != POSITION_TYPE_SELL) continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      weighted += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
      lots += vol;
     }
   return (lots > 0.0) ? (weighted / lots) : 0.0;
  }

void SortCloseTicketsByLotsDesc(ulong &tickets[], double &lots[])
  {
   int n = ArraySize(tickets);
   for(int i = 0; i < n - 1; ++i)
     {
      int maxIdx = i;
      for(int j = i + 1; j < n; ++j)
        {
         if(lots[j] > lots[maxIdx])
            maxIdx = j;
        }
      if(maxIdx == i) continue;
      ulong t = tickets[i];
      tickets[i] = tickets[maxIdx];
      tickets[maxIdx] = t;
      double l = lots[i];
      lots[i] = lots[maxIdx];
      lots[maxIdx] = l;
     }
  }

int CollectBasketCloseTickets(const long magic, ulong &tickets[], double &lots[], double &totalLots, double &floatingPnl)
  {
   ArrayResize(tickets, 0);
   ArrayResize(lots, 0);
   totalLots = 0.0;
   floatingPnl = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, MART_COMMENT) < 0 && StringFind(cmt, HEDGE_COMMENT) < 0) continue;

      int n = ArraySize(tickets);
      ArrayResize(tickets, n + 1);
      ArrayResize(lots, n + 1);
      tickets[n] = ticket;
      lots[n] = PositionGetDouble(POSITION_VOLUME);
      totalLots += lots[n];
      floatingPnl += PositionGetDouble(POSITION_PROFIT);
     }

   SortCloseTicketsByLotsDesc(tickets, lots);
   return ArraySize(tickets);
  }

void ResetActiveBasketAfterClose(const long magic)
  {
   if(magic != GetActiveMagicNumber())
      return;

   g_martDirection = MART_DIR_NONE;
   g_martLayerCount = 0;
   g_martMaxLayerSeq = 0;
   g_martBasketPeakPnL = 0.0;
   g_martHighestPrice = 0.0;
   g_martLowestPrice = 0.0;
   g_martTotalLots = 0.0;
   g_cachedMartPnl = 0.0;
   g_hedgeActive = false;
   g_hedgeCount = 0;
   g_hedgeLots = 0.0;
   g_hedgePnl = 0.0;
   g_hedgeMaxMartLoss = 0.0;
   g_hedgeLastPartialTime = 0;
   g_hedgeLastRepairTime = 0;
   g_hedgeRepairAdds = 0;
  }

bool IsMagicFastClosing(const long magic)
  {
   datetime now = TimeCurrent();
   for(int i = 0; i < FAST_CLOSING_SLOTS; ++i)
     {
      if(g_fastClosingMagic[i] == magic && g_fastClosingUntil[i] > now)
         return true;
     }
   return false;
  }

void MarkMagicFastClosing(const long magic, const int seconds)
  {
   int slot = -1;
   datetime now = TimeCurrent();
   for(int i = 0; i < FAST_CLOSING_SLOTS; ++i)
     {
      if(g_fastClosingMagic[i] == magic)
        {
         slot = i;
         break;
        }
      if(slot < 0 && g_fastClosingUntil[i] <= now)
         slot = i;
     }
   if(slot < 0) slot = 0;
   g_fastClosingMagic[slot] = magic;
   g_fastClosingUntil[slot] = now + seconds;
  }

bool CloseBasketByMagic(const long magic)
  {
   if(IsMagicFastClosing(magic))
      return true;

   ulong tickets[];
   double lots[];
   double totalLots = 0.0;
   double floatingPnl = 0.0;
   int total = CollectBasketCloseTickets(magic, tickets, lots, totalLots, floatingPnl);
   if(total <= 0)
      return false;

   bool sentAny = false;
   int sent = 0;
   g_trade.SetAsyncMode(true);
   for(int i = 0; i < total; ++i)
     {
      if(!PositionSelectByTicket(tickets[i]))
         continue;
      bool ok = g_trade.PositionClose(tickets[i]);
      if(ok)
        {
         sent++;
         sentAny = true;
        }
      else
        {
         PrintTradeResult("FastPositionClose(" + (string)tickets[i] + ")", false);
        }
     }
   g_trade.SetAsyncMode(false);

   if(sentAny)
     {
      MarkMagicFastClosing(magic, 5);
      g_martLastCloseTime = TimeCurrent();
      g_closedPnlDirty = true;
      ResetActiveBasketAfterClose(magic);
      PrintFormat("[快速篮子平仓] Magic=%I64d 已发送%d/%d张平仓请求 手数=%.2f 当前浮盈=%.2f",
                  magic, sent, total, totalLots, floatingPnl);
     }
   return sentAny;
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
      if(!IsManagedMagic((long)HistoryDealGetInteger(deal, DEAL_MAGIC))) continue;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGE_COMMENT) < 0) continue;

      g_hedgeActive = true;
      g_hedgeCount++;
      g_hedgeLots += PositionGetDouble(POSITION_VOLUME);
      g_hedgePnl += PositionGetDouble(POSITION_PROFIT);
     }
   if(g_hedgeActive)
     {
      double martLoss = MathMax(0.0, -g_cachedMartPnl);
      if(martLoss > g_hedgeMaxMartLoss)
         g_hedgeMaxMartLoss = martLoss;
     }
   else
     {
      g_hedgeMaxMartLoss = 0.0;
      g_hedgeLastPartialTime = 0;
      g_hedgeLastRepairTime = 0;
      g_hedgeRepairAdds = 0;
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
   bool farFromSlow = (atr > 0.0 && dist >= atr * g_effEmaStrongAtrMult);

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

   // V1.41 single entry path: EMA score + H4 trend. Precision filters run before order placement.
   longSignal = emaLong;
   shortSignal = emaShort;
   if(!longSignal && !shortSignal && g_noEntryReason == "")
      g_noEntryReason = "EMA无方向信号";

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

   if(IsATRAddPaused())
     {
      g_noEntryReason = StringFormat("ATR扩张禁首单 %.2f>%.2f", g_addAtrRatio, InpATRAddPauseRatio);
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

   if(IsEntryPrecisionBlocked(side))
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

bool ManageMartBasketTP()
  {
   if(InpMartBasketTP_USD <= 0.0) return false;
   // 动态TP = 查表(每层独立随机增量序列，启动时生成)
   int layers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTP = GetDynamicTP(layers);
   double pnl = GetEffectivePnL();
   if(pnl >= dynamicTP)
     {
      CloseAllMartPositions();
      PrintFormat("篮子动态TP触发: 浮盈=%.2f >= 目标=%.2f (层%d 守护系数=%.0f%%)",
                  pnl, dynamicTP, layers, GetDeepProtectTPFactor(layers) * 100.0);
      return true;
     }
   return false;
  }

bool CheckMartHardSL()
  {
   if(InpMartHardSL_USD <= 0.0) return false;
   double pnl = GetEffectivePnL();
   if(pnl <= -InpMartHardSL_USD)
     {
      CloseAllMartPositions();
      g_martHardSLLocked = true;
      if(InpHardSLAllowResume && InpHardSLResumeMinutes > 0)
         g_martHardSLResumeTime = TimeCurrent() + InpHardSLResumeMinutes * 60;
      else
         g_martHardSLResumeTime = 0;
      Print("Mart hard SL hit: ", pnl);
      return true;
     }
   return false;
  }

bool ManageMartTrailing()
  {
   if(InpMartTrailPct <= 0.0) return false;
   if(g_hedgeActive) return false;  // 对冲时由总止盈(HedgeRelease)接管，不启用追踪
   if(g_martBasketPeakPnL <= 0.0) return false;

   // ---- 追踪门槛 = 当前动态TP × 启动比例% ----
   int layers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTP = GetDynamicTP(layers);
   double minProfit = dynamicTP * InpMartTrailMinProfitPerLayer / 100.0;

   // 峰值未达到门槛时，不启用追踪
   if(g_martBasketPeakPnL < minProfit) return false;

   double pnl = GetEffectivePnL();
   double retraceThreshold = g_martBasketPeakPnL * InpMartTrailPct / 100.0;
   if(pnl < retraceThreshold)
     {
      PrintFormat("追踪止损触发: 峰值=%.2f 门槛=%.2f(TP%.0f×%.0f%%) 当前=%.2f 回撤阈值=%.2f",
                  g_martBasketPeakPnL, minProfit, dynamicTP, InpMartTrailMinProfitPerLayer, pnl, retraceThreshold);
      CloseAllMartPositions();
      return true;
     }
   return false;
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
      g_martHardSLResumeTime = 0;
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

long GetBasketMagicByIndex(const int index)
  {
   return InpMagicNumber;
  }

long GetActiveMagicNumber()
  {
   return InpMagicNumber;
  }

bool IsManagedMagic(const long magic)
  {
   return (magic == InpMagicNumber);
  }

bool IsActiveMagic(const long magic)
  {
   return (magic == GetActiveMagicNumber());
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
   g_trade.SetExpertMagicNumber(GetActiveMagicNumber());
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber())
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

double GetHedgeRecoveryPct()
  {
   if(g_hedgeMaxMartLoss <= 0.0)
      return 0.0;
   double currentLoss = MathMax(0.0, -g_cachedMartPnl);
   double recovered = g_hedgeMaxMartLoss - currentLoss;
   if(recovered <= 0.0)
      return 0.0;
   return recovered / g_hedgeMaxMartLoss * 100.0;
  }

bool CloseHedgeVolume(double volumeToClose)
  {
   if(volumeToClose <= 0.0)
      return false;

   double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vMin <= 0.0 || vStep <= 0.0)
      return false;

   bool closedAny = false;
   double remaining = volumeToClose;
   for(int i = PositionsTotal() - 1; i >= 0 && remaining >= vMin; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, HEDGE_COMMENT) < 0) continue;

      double posVol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = MathMin(posVol, remaining);
      closeVol = MathFloor(closeVol / vStep + 1e-8) * vStep;
      closeVol = NormalizeDouble(closeVol, 4);
      if(closeVol < vMin)
         continue;

      bool ok = false;
      if(posVol - closeVol < vMin)
         ok = ClosePositionChecked(ticket);
      else
        {
         for(int attempt = 0; attempt < 3; ++attempt)
           {
            bool partialOk = g_trade.PositionClosePartial(ticket, closeVol);
            uint rc = g_trade.ResultRetcode();
            if(partialOk && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL))
              {
               ok = true;
               break;
              }
           }
         if(!ok)
            PrintTradeResult("PositionClosePartial(" + (string)ticket + ")", false);
        }

      if(ok)
        {
         closedAny = true;
         remaining -= closeVol;
        }
     }
   if(closedAny)
     {
      g_closedPnlDirty = true;
      RefreshHedgeState();
     }
   return closedAny;
  }

double GetHedgeTargetRatio(const double floatingPnl)
  {
   if(InpHedgeMode == HEDGE_MODE_OFF)
      return 0.0;
   if(floatingPnl >= 0.0)
      return 0.0;

   if(InpHedgeMode == HEDGE_MODE_FIXED)
     {
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

   g_sigEntryDistSlowAtr = MathAbs(close1 - slow[0]) / atr;
   g_sigEntryBodyAtr = MathAbs(close1 - open1) / atr;

   if(InpEntryMaxDistSlowEMA_ATR > 0.0)
     {
      bool chaseLong  = (side == POSITION_TYPE_BUY  && close1 > slow[0]);
      bool chaseShort = (side == POSITION_TYPE_SELL && close1 < slow[0]);
      if((chaseLong || chaseShort) && g_sigEntryDistSlowAtr > InpEntryMaxDistSlowEMA_ATR)
        {
         g_noEntryReason = StringFormat("防追单: 距慢EMA %.1fATR>%.1f", g_sigEntryDistSlowAtr, InpEntryMaxDistSlowEMA_ATR);
         return true;
        }
     }

   if(InpEntryMaxPrevBody_ATR > 0.0)
     {
      if(g_sigEntryBodyAtr > InpEntryMaxPrevBody_ATR)
        {
         g_noEntryReason = StringFormat("防追单: 上根实体 %.1fATR>%.1f", g_sigEntryBodyAtr, InpEntryMaxPrevBody_ATR);
         return true;
        }
     }

   return false;
  }

bool IsEntryPrecisionBlocked(const ENUM_POSITION_TYPE side)
  {
   if(!InpUseEntryPrecisionFilter)
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

   double body = close1 - open1;
   g_sigEntryDistSlowAtr = MathAbs(close1 - slow[0]) / atr;
   g_sigEntryBodyAtr = MathAbs(body) / atr;
   g_sigEntryBodyDir = (body > 0.0) ? 1 : ((body < 0.0) ? -1 : 0);

   if(InpEntryMinDistSlowEMA_ATR > 0.0 && g_sigEntryDistSlowAtr < InpEntryMinDistSlowEMA_ATR)
     {
      g_noEntryReason = StringFormat("精确过滤: 距EMA %.2fATR<%.2f", g_sigEntryDistSlowAtr, InpEntryMinDistSlowEMA_ATR);
      return true;
     }

   if(InpEntryMaxPullbackEMA_ATR > 0.0 && g_sigEntryDistSlowAtr > InpEntryMaxPullbackEMA_ATR)
     {
      g_noEntryReason = StringFormat("精确过滤: 距EMA %.2fATR>%.2f", g_sigEntryDistSlowAtr, InpEntryMaxPullbackEMA_ATR);
      return true;
     }

   if(InpEntryMinBody_ATR > 0.0 && g_sigEntryBodyAtr < InpEntryMinBody_ATR)
     {
      g_noEntryReason = StringFormat("精确过滤: 实体 %.2fATR<%.2f", g_sigEntryBodyAtr, InpEntryMinBody_ATR);
      return true;
     }

   if(InpEntryRequireBodyDirection)
     {
      if(side == POSITION_TYPE_BUY && body <= 0.0)
        {
         g_noEntryReason = "精确过滤: 上根K线未同向做多";
         return true;
        }
      if(side == POSITION_TYPE_SELL && body >= 0.0)
        {
         g_noEntryReason = "精确过滤: 上根K线未同向做空";
         return true;
        }
     }

   if(g_hEntryPrecisionRSI != INVALID_HANDLE)
     {
      double rsi[1];
      if(CopyBuffer(g_hEntryPrecisionRSI, 0, 1, 1, rsi) >= 1)
        {
         g_sigEntryPrecisionRsi = rsi[0];
         if(side == POSITION_TYPE_BUY && InpEntryBuyRsiMax > 0.0 && rsi[0] >= InpEntryBuyRsiMax)
           {
            g_noEntryReason = StringFormat("精确过滤: RSI %.1f>=%.1f 不追多", rsi[0], InpEntryBuyRsiMax);
            return true;
           }
         if(side == POSITION_TYPE_SELL && InpEntrySellRsiMin > 0.0 && rsi[0] <= InpEntrySellRsiMin)
           {
            g_noEntryReason = StringFormat("精确过滤: RSI %.1f<=%.1f 不追空", rsi[0], InpEntrySellRsiMin);
            return true;
           }
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
         g_fastLossExtremePrice = 0.0;
         g_fastLossLockDir   = 0;
        }
      g_fastLossStartTime = 0;
      g_fastLossPeakPrice = 0.0;
      g_fastLossExtremePrice = 0.0;
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
         g_fastLossExtremePrice = curBid;
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
      // Locked: either return to the last layer price, or rebound enough from the post-lock extreme.
      bool recoveredByLastLayer = false;
      bool recoveredByBounce = false;
      double recoveryCents = 0.0;

      if(g_fastLossLockDir == (int)MART_DIR_BUY)
        {
         if(g_fastLossExtremePrice <= 0.0 || curBid < g_fastLossExtremePrice)
            g_fastLossExtremePrice = curBid;
         recoveredByLastLayer = (curBid >= g_fastLossLockPrice);
         recoveryCents = (curBid - g_fastLossExtremePrice) * 100.0;
        }
      else if(g_fastLossLockDir == (int)MART_DIR_SELL)
        {
         if(g_fastLossExtremePrice <= 0.0 || curBid > g_fastLossExtremePrice)
            g_fastLossExtremePrice = curBid;
         recoveredByLastLayer = (curBid <= g_fastLossLockPrice);
         recoveryCents = (g_fastLossExtremePrice - curBid) * 100.0;
        }

      if(InpFastLossRecoveryDistance > 0 && recoveryCents >= (double)InpFastLossRecoveryDistance)
         recoveredByBounce = true;

      if(recoveredByBounce && InpFastLossExitMaxLoss > 0.0)
        {
         RefreshMartBasketState();
         RefreshHedgeState();
         double pnl = GetEffectivePnL();
         if(pnl >= -InpFastLossExitMaxLoss)
           {
            PrintFormat("FastLoss exit flat: recovery=%.0f/%.0f cents pnl=%.2f >= -%.2f, close all",
                        recoveryCents, (double)InpFastLossRecoveryDistance, pnl, InpFastLossExitMaxLoss);
            CloseAllMartPositions();
            g_martDirection = MART_DIR_NONE;
            g_fastLossLocked = false;
            g_fastLossStartTime = 0;
            g_fastLossPeakPrice = 0.0;
            g_fastLossLockPrice = 0.0;
            g_fastLossExtremePrice = 0.0;
            g_fastLossLockDir = 0;
            return;
           }
        }

      if(recoveredByLastLayer || recoveredByBounce)
        {
         PrintFormat("快速熔断解除: 当前=%.3f 锁定价=%.3f 回撤=%.0f/%.0f美分 原因=%s",
                     curBid, g_fastLossLockPrice, recoveryCents, (double)InpFastLossRecoveryDistance,
                     recoveredByLastLayer ? "last-layer" : "bounce");
         g_fastLossLocked = false;
         g_fastLossStartTime = 0;
         g_fastLossPeakPrice = 0.0;
         g_fastLossLockPrice = 0.0;
         g_fastLossExtremePrice = 0.0;
         g_fastLossLockDir = 0;
        }
     }
  }

void ManageHedgeLock()
  {
   if(InpHedgeMode == HEDGE_MODE_OFF) return;
   if(InpHedgeMode == HEDGE_MODE_FIXED)
     {
      if(InpHedgeAbsoluteUSD <= 0.0) return;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
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
      if((long)PositionGetInteger(POSITION_MAGIC) != GetActiveMagicNumber()) continue;
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

bool ManageHedgeRelease()
  {
   if(InpHedgeMode == HEDGE_MODE_OFF) return false;
   if(!g_hedgeActive) return false;

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
      return true;
     }
   return false;
  }

bool ManageHedgePartialRelease()
  {
   if(!InpEnableHedgePartialRelease) return false;
   if(InpHedgeMode == HEDGE_MODE_OFF) return false;
   if(!g_hedgeActive || g_martTotalLots <= 0.0 || g_hedgeLots <= 0.0) return false;
   if(InpHedgePartialRecoverPct <= 0.0 || InpHedgePartialClosePct <= 0.0) return false;
   if(g_hedgeLastPartialTime > 0 && TimeCurrent() - g_hedgeLastPartialTime < InpHedgePartialMinIntervalSec)
      return false;

   double recoveryPct = GetHedgeRecoveryPct();
   if(recoveryPct < InpHedgePartialRecoverPct)
      return false;

   double currentRatio = g_hedgeLots / g_martTotalLots;
   double minKeepRatio = MathMax(0.0, InpHedgeMinRatioAfterPartial);
   if(currentRatio <= minKeepRatio)
      return false;

   double targetClose = g_hedgeLots * InpHedgePartialClosePct / 100.0;
   double maxCloseByKeep = g_hedgeLots - g_martTotalLots * minKeepRatio;
   double closeVol = MathMin(targetClose, maxCloseByKeep);
   if(closeVol < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      return false;
   closeVol = NormalizeVolume(closeVol);
   if(closeVol <= 0.0)
      return false;

   if(CloseHedgeVolume(closeVol))
     {
      g_hedgeLastPartialTime = TimeCurrent();
      g_hedgeMaxMartLoss = MathMax(0.0, -g_cachedMartPnl);
      PrintFormat("[对冲减仓] 浮亏回收%.1f%% >= %.1f%%, 减对冲%.2f手, 保留比例约%.0f%%",
                  recoveryPct, InpHedgePartialRecoverPct, closeVol, InpHedgeMinRatioAfterPartial * 100.0);
      return true;
     }
   return false;
  }

bool TryHedgeRepairAdd()
  {
   if(!InpEnableHedgeRepairAdd) return false;
   if(InpHedgeMode == HEDGE_MODE_OFF) return false;
   if(!g_hedgeActive || g_martDirection == MART_DIR_NONE) return false;
   if(g_hedgeRepairAdds >= InpHedgeRepairMaxAdds) return false;
   if(g_martMaxLayerSeq >= InpMartMaxLayers) return false;
   if(g_martTotalLots >= InpMartMaxTotalLots) return false;
   if(g_hedgeLastRepairTime > 0 && TimeCurrent() - g_hedgeLastRepairTime < InpHedgeRepairMinIntervalSec)
      return false;

   double recoveryPct = GetHedgeRecoveryPct();
   if(recoveryPct < InpHedgeRepairMinRecoverPct)
      return false;

   double atrRatio = GetATRExpansionRatio();
   if(atrRatio > 0.0 && atrRatio > InpATRAddResumeRatio)
     {
      g_noEntryReason = StringFormat("对冲修复等ATR恢复 %.2f>%.2f", atrRatio, InpATRAddResumeRatio);
      return false;
     }

   double avgLots = 0.0;
   double avgPrice = GetBasketMartAvgPriceByMagic(GetActiveMagicNumber(), g_martDirection, avgLots);
   if(avgPrice <= 0.0 || avgLots <= 0.0)
      return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (g_martDirection == MART_DIR_BUY) ? ask : bid;
   double adversePts = (g_martDirection == MART_DIR_BUY) ? (avgPrice - price) / _Point : (price - avgPrice) / _Point;
   if(adversePts < GetMartSpacingPts() * 0.5)
      return false;

   double lot = NormalizeVolume(InpHedgeRepairLot);
   if(lot <= 0.0) return false;
   if(g_martTotalLots + lot > InpMartMaxTotalLots) return false;

   ENUM_POSITION_TYPE side = (g_martDirection == MART_DIR_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   string cmt = MART_COMMENT + "_L" + IntegerToString(g_martMaxLayerSeq) + "_R";
   if(PlaceMarketOrder(side, lot, 0.0, 0.0, cmt))
     {
      g_martLayerCount++;
      g_martMaxLayerSeq++;
      g_martTotalLots += lot;
      g_martLastLayerTime = TimeCurrent();
      g_hedgeLastRepairTime = TimeCurrent();
      g_hedgeRepairAdds++;
      PrintFormat("[对冲修复] 浮亏回收%.1f%%, ATR=%.2f, 开%s %.2f手修复单(%d/%d)",
                  recoveryPct, atrRatio, side == POSITION_TYPE_BUY ? "BUY" : "SELL",
                  lot, g_hedgeRepairAdds, InpHedgeRepairMaxAdds);
      return true;
     }
   return false;
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
   g_sigH4TrendDir     = 0;
   g_sigMartDistToNext = 0;
   g_sigMartBasketPnL  = g_cachedMartPnl;
   g_sigEntryDistSlowAtr = 0.0;
   g_sigEntryBodyAtr     = 0.0;
   g_sigEntryBodyDir     = 0;
   g_sigEntryPrecisionRsi = 0.0;

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

         double atr = GetATRValue(g_hATR_Spacing);
         double open1 = iOpen(_Symbol, InpMartEntryTF, 1);
         if(atr > 0.0 && open1 > 0.0 && emaSlow[1] > 0.0)
           {
            g_sigEntryDistSlowAtr = MathAbs(close1 - emaSlow[1]) / atr;
            double body = close1 - open1;
            g_sigEntryBodyAtr = MathAbs(body) / atr;
            g_sigEntryBodyDir = (body > 0.0) ? 1 : ((body < 0.0) ? -1 : 0);
           }
         if(g_hEntryPrecisionRSI != INVALID_HANDLE)
           {
            double rsi[1];
            if(CopyBuffer(g_hEntryPrecisionRSI, 0, 1, 1, rsi) >= 1)
               g_sigEntryPrecisionRsi = rsi[0];
           }
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
                  if(h4Bull)      g_sigH4TrendDir = 1;
                  else if(h4Bear) g_sigH4TrendDir = -1;
                  g_sigH4Confirmed = ((g_sigMartEmaDir == 1 && h4Bull) ||
                                      (g_sigMartEmaDir == -1 && h4Bear));
                 }
              }
            else  // H4_FILTER_1K
              {
               if(closeH4_1 > emaH4[1])      g_sigH4TrendDir = 1;
               else if(closeH4_1 < emaH4[1]) g_sigH4TrendDir = -1;
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

   // V1.41 uses a single EMA/H4/precision entry path; SMC diagnostics are disabled.
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

string GetEntryReasonLine()
  {
   string reason = GetBlockingReason();
   if(reason != "")
      return "未建仓:" + reason;

   int need = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
   bool emaLongOk = (g_sigMartEmaDir == 1 && g_sigMartEmaScoreLong >= need);
   bool emaShortOk = (g_sigMartEmaDir == -1 && g_sigMartEmaScoreShort >= need);
   bool emaOk = (emaLongOk || emaShortOk);

   if(!emaOk)
      reason = "EMA方向信号未达标";
   else
     {
      int dir = emaLongOk ? 1 : -1;
      if(InpMartH4FilterMode != H4_FILTER_OFF && !g_sigH4Confirmed)
        {
         if(reason != "") reason += "；";
         reason += (dir == 1) ? "H4趋势不支持做多" : "H4趋势不支持做空";
        }
      if(InpUseATRAddPause && g_addAtrPaused)
        {
         if(reason != "") reason += "；";
         reason += "ATR波动扩张，暂停新篮子";
        }
      if(InpUseEntryPrecisionFilter)
        {
         if(dir == 1 && InpEntryBuyRsiMax > 0.0 && g_sigEntryPrecisionRsi >= InpEntryBuyRsiMax)
           {
            if(reason != "") reason += "；";
            reason += "RSI偏高，不适合做多";
           }
         if(dir == -1 && InpEntrySellRsiMin > 0.0 && g_sigEntryPrecisionRsi <= InpEntrySellRsiMin)
           {
            if(reason != "") reason += "；";
            reason += "RSI偏低，不适合做空";
           }
         if(InpEntryMinDistSlowEMA_ATR > 0.0 && g_sigEntryDistSlowAtr < InpEntryMinDistSlowEMA_ATR)
           {
            if(reason != "") reason += "；";
            reason += "距离慢EMA太近，动能不足";
           }
         if(InpEntryMaxPullbackEMA_ATR > 0.0 && g_sigEntryDistSlowAtr > InpEntryMaxPullbackEMA_ATR)
           {
            if(reason != "") reason += "；";
            reason += (dir == 1) ? "距离慢EMA太远，避免追高" : "距离慢EMA太远，避免追低";
           }
         if(InpEntryMinBody_ATR > 0.0 && g_sigEntryBodyAtr < InpEntryMinBody_ATR)
           {
            if(reason != "") reason += "；";
            reason += "上根K线实体太小";
           }
         if(InpEntryRequireBodyDirection && g_sigEntryBodyDir != 0 && g_sigEntryBodyDir != dir)
           {
            if(reason != "") reason += "；";
            reason += (dir == 1) ? "上根K线不是阳线，不确认做多" : "上根K线不是阴线，不确认做空";
           }
        }
     }

   if(reason == "")
      reason = (g_noEntryReason != "") ? g_noEntryReason : "等待下一根有效信号";

   return "未建仓:" + reason;
  }

string GetH4PanelText()
  {
   if(InpMartH4FilterMode == H4_FILTER_OFF)
      return "关";

   string trend = "震荡";
   if(g_sigH4TrendDir == 1)      trend = "多";
   else if(g_sigH4TrendDir == -1) trend = "空";

   if(g_sigMartEmaDir == 0)
      return trend;
   if(g_sigH4Confirmed)
      return trend;
   return "逆" + (g_sigMartEmaDir == 1 ? "多" : "空");
  }

string GetEntryThresholdLine()
  {
   if(!InpUseEntryPrecisionFilter)
      return "精确过滤: 已关闭";

   string rsiText = StringFormat("RSI%.1f 买<=%.0f 卖>=%.0f",
      g_sigEntryPrecisionRsi, InpEntryBuyRsiMax, InpEntrySellRsiMin);
   string distText = StringFormat("距EMA%.2f[%.2f-%.2f]",
      g_sigEntryDistSlowAtr, InpEntryMinDistSlowEMA_ATR, InpEntryMaxPullbackEMA_ATR);
   string bodyText = StringFormat("实体%.2f>=%.2f",
      g_sigEntryBodyAtr, InpEntryMinBody_ATR);
   return "精确:" + rsiText + " | " + distText + " | " + bodyText;
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
   uint bgColor = 0xFF061D1F;  // 深青黑，贴合青鸾背景主色
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

   // 清理旧版遗留的多余行对象，保留新增的诊断行。
   for(int i = 8; i < 10; i++)
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
   ObjectSetInteger(0, OBJ_BG, OBJPROP_COLOR, C'26,169,156');
   ObjectSetInteger(0, OBJ_BG, OBJPROP_BGCOLOR, C'6,29,31');
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
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_COLOR, C'10,102,96');
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BGCOLOR, C'10,72,70');
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
   ObjectSetInteger(0, OBJ_LOGO_FRAME, OBJPROP_COLOR, C'26,169,156');
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
   ObjectSetString(0, OBJ_HEADER, OBJPROP_TEXT, "青鸾 v1.49R");

   ObjectSetString(0, OBJ_HEADER, OBJPROP_TEXT, "青鸾 v1.51R");

   // --- Sub-header ---
   if(ObjectFind(0, OBJ_SUBHDR) < 0)
      ObjectCreate(0, OBJ_SUBHDR, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_XDISTANCE, g_panelX + 88);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_YDISTANCE, g_panelY + 48);
   ObjectSetInteger(0, OBJ_SUBHDR, OBJPROP_COLOR, C'218,255,248');
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

   // --- Info Lines ---
   int lineY = g_panelY + 158;
   int lineGap = 24;
   string lineObjs[] = {OBJ_LINE0, OBJ_LINE1, OBJ_LINE2};
   for(int i = 0; i < 3; ++i)
     {
      if(ObjectFind(0, lineObjs[i]) < 0)
         ObjectCreate(0, lineObjs[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_XDISTANCE, g_panelX + 10);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_YDISTANCE, lineY + i * lineGap);
      ObjectSetInteger(0, lineObjs[i], OBJPROP_COLOR, C'218,255,248');
      ObjectSetInteger(0, lineObjs[i], OBJPROP_FONTSIZE, 10);
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
   ObjectSetInteger(0, OBJ_LINE4, OBJPROP_FONTSIZE, 10);
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
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_COLOR, C'140,155,180');
   ObjectSetString(0, OBJ_LINE5, OBJPROP_TEXT, "");
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_LINE5, OBJPROP_HIDDEN, true);

   // LINE6/7 — 入场条件诊断行
   string extraLineObjs[] = {OBJ_LINE6, OBJ_LINE7};
   for(int j = 0; j < 2; ++j)
     {
      if(ObjectFind(0, extraLineObjs[j]) < 0)
         ObjectCreate(0, extraLineObjs[j], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_XDISTANCE, g_panelX + 10);
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_YDISTANCE, lineY + (5 + j) * lineGap);
      ObjectSetString(0, extraLineObjs[j], OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_COLOR, C'140,155,180');
      ObjectSetString(0, extraLineObjs[j], OBJPROP_TEXT, "");
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, extraLineObjs[j], OBJPROP_HIDDEN, true);
     }

   string condObjs[] = {OBJ_ENTRY_C0, OBJ_ENTRY_C1, OBJ_ENTRY_C2, OBJ_ENTRY_C3, OBJ_ENTRY_C4, OBJ_ENTRY_C5};
   int condX[] = {84, 230, 392};
   int condOrder[] = {0, 1, 5, 2, 3, 4};
   for(int k = 0; k < 6; ++k)
     {
      int idx = condOrder[k];
      if(ObjectFind(0, condObjs[idx]) < 0)
         ObjectCreate(0, condObjs[idx], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, condObjs[idx], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, condObjs[idx], OBJPROP_XDISTANCE, g_panelX + condX[k % 3]);
      ObjectSetInteger(0, condObjs[idx], OBJPROP_YDISTANCE, lineY + (6 + k / 3) * lineGap);
      ObjectSetString(0, condObjs[idx], OBJPROP_FONT, "Microsoft YaHei UI");
      ObjectSetInteger(0, condObjs[idx], OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, condObjs[idx], OBJPROP_COLOR, C'126,190,184');
      ObjectSetString(0, condObjs[idx], OBJPROP_TEXT, "");
      ObjectSetInteger(0, condObjs[idx], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, condObjs[idx], OBJPROP_HIDDEN, true);
     }

   // LINE3 — 不建仓原因行（对冲行下方，初始移至屏幕外，由UpdateStatusPanel按需显示）
   if(ObjectFind(0, OBJ_LINE3) < 0)
      ObjectCreate(0, OBJ_LINE3, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, -9999); // 初始移至屏幕外，避免空文本时MT5显示默认"Label"
   ObjectSetString(0, OBJ_LINE3, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_FONTSIZE, 10);
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
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_COLOR, C'18,120,112');
   ObjectSetInteger(0, OBJ_BTN_BG, OBJPROP_BGCOLOR, C'4,38,40');
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
      ObjectSetInteger(0, speedNames[s], OBJPROP_BGCOLOR, C'11,88,84');
      ObjectSetInteger(0, speedNames[s], OBJPROP_BORDER_COLOR, C'72,220,205');
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
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'20,129,123');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'7,46,48');
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
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, C'126,190,184');
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
   ObjectSetInteger(0, valueName, OBJPROP_COLOR, C'218,255,248');
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
   ObjectSetInteger(0, subName, OBJPROP_COLOR, C'126,190,184');
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
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'20,129,123');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'7,46,48');
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
      ObjectSetInteger(0, OBJ_BTN_TOGGLE, OBJPROP_BORDER_COLOR, C'26,169,156');
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
   double martPnl = g_cachedMartPnl;
   double hedgePnl = g_hedgeActive ? g_hedgePnl : 0.0;
   double effectivePnl = martPnl + hedgePnl;

   // Account type detection
   string acctCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   bool isCent = (StringFind(acctCurrency, "USC") >= 0 || StringFind(acctCurrency, "CEN") >= 0);
   string acctType = isCent ? "美分账户" : "标准账户";

   // Direction text
   string dirText = "待机";
   if(g_martDirection == MART_DIR_BUY)      dirText = "做多";
   else if(g_martDirection == MART_DIR_SELL) dirText = "做空";

   // Sub-header with active entry path. SMC is no longer part of the entry display.
   string trendArrow = "入场:EMA+H4+精确过滤";

   string expiryText = g_licenseExpiry;
   if(StringLen(g_licenseExpiry) >= 8)
      expiryText = StringFormat("%s-%s-%s", StringSubstr(g_licenseExpiry, 0, 4), StringSubstr(g_licenseExpiry, 4, 2), StringSubstr(g_licenseExpiry, 6, 2));
   string subHdr = StringFormat("%s | %s | %s  %s  远程授权至:%s", InpPresetName, _Symbol, acctType, trendArrow, expiryText);
   if(g_remoteRenewWarning)
      subHdr += " [请续费]";
   if(!g_remoteAuthorized && !g_isTester)
      subHdr += " [授权失效]";
   if(g_manualPaused)
      subHdr += " [暂停]";
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_TEXT, subHdr);

   // Top bar color — 仅风控锁定/暂停时变色，持仓方向不改变标题栏颜色
   color topColor = C'10,72,70';
   if(g_dailyLocked || g_martHardSLLocked || g_fastLossLocked)
      topColor = C'160,50,50';
   else if(g_remoteRuntimeWarning)
      topColor = C'160,50,50';
   else if(g_remoteRenewWarning)
      topColor = C'160,110,35';
   else if(g_manualPaused)
      topColor = C'140,110,40';
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_COLOR, topColor);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BGCOLOR, topColor);
   RenderRemoteWarning();

   // --- Card 1: Basket PnL ---
   ObjectSetString(0, OBJ_CARD1_T, OBJPROP_TEXT, g_hedgeActive ? "总浮盈" : "篮子浮盈");
   string pnlText = StringFormat("%+.2f", effectivePnl);
   ObjectSetString(0, OBJ_CARD1_V, OBJPROP_TEXT, pnlText);
   ObjectSetInteger(0, OBJ_CARD1_V, OBJPROP_COLOR, effectivePnl >= 0 ? C'80,200,120' : C'255,80,80');
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
      tpPct = MathMin(100.0, MathMax(0.0, effectivePnl / dynamicTPPanel * 100.0));
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
   string h4Text = GetH4PanelText() + "(" + modeLabel + ")";

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

   double modulePnlNow = g_dayRealizedPnl + effectivePnl;
   double deltaPnl = modulePnlNow - g_dayStartModulePnl;
   double dailyLossPct = 0.0;
   if(eq > 0.0 && deltaPnl < 0.0)
      dailyLossPct = (-deltaPnl) / eq * 100.0;

   double curLossPct = 0.0;
   if(eq > 0.0 && effectivePnl < 0.0)
     {
      double absEquity = eq - effectivePnl;
      if(absEquity > 0.0)
         curLossPct = (-effectivePnl) / absEquity * 100.0;
     }

   string riskDaily = g_dailyLocked ? "锁定" : "正常";
   string riskHardSL = g_martHardSLLocked ? "锁定" : "正常";
   if(g_martHardSLLocked && InpHardSLAllowResume && g_martHardSLResumeTime > TimeCurrent())
      riskHardSL = StringFormat("锁定%d分", (int)MathCeil((double)(g_martHardSLResumeTime - TimeCurrent()) / 60.0));
   string riskFast = g_fastLossLocked ? "锁定" : "正常";

   // Line 0: single entry mode summary
   {
      int need = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
      string passText = g_sigMartEntryOk ? (g_sigMartEmaDir == 1 ? "做多通过" : "做空通过") : "等待";
      string h4Short = GetH4PanelText();
      string scoreLine = StringFormat("入场:%s | EMA多:%d/%d 空:%d/%d | H4:%s | 层:%d/%d 距:%s",
         passText, g_sigMartEmaScoreLong, need, g_sigMartEmaScoreShort, need,
         h4Short, g_martLayerCount, InpMartMaxLayers, distText);

      ObjectSetString(0, OBJ_LINE0, OBJPROP_TEXT, scoreLine);
      color sigColor = (g_sigMartEntryOk && (InpMartH4FilterMode == H4_FILTER_OFF || g_sigH4Confirmed)) ? C'80,200,120' : C'255,200,60';
      if(g_sigMartEmaScoreLong <= 0 && g_sigMartEmaScoreShort <= 0) sigColor = C'140,155,180';
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
         hedgeText = "对冲: 已关闭（不会自动开对冲）";
      else if(g_hedgeActive)
        {
         double totalPnl = effectivePnl;
         int dispEffLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
         double releaseThreshold = (InpHedgeReleaseMode == HEDGE_RELEASE_FIXED) ? InpHedgeReleaseFixed : dispEffLayers * InpHedgeReleaseDynPerLayer;
         hedgeText = StringFormat("对冲: 激活中  总浮盈:%.1f(止盈>%.0f)  回收:%.0f%%  修复:%d/%d  对冲:%.2f手",
            totalPnl, releaseThreshold, GetHedgeRecoveryPct(), g_hedgeRepairAdds, InpHedgeRepairMaxAdds, g_hedgeLots);
        }
      else
        {
         hedgeText = useLadder
            ? StringFormat("对冲: 阶梯待命  %.0f/%.0f/%.0f美分 -> %.0f/%.0f/%.0f%%",
               InpHedgeLadderLoss1, InpHedgeLadderLoss2, InpHedgeLadderLoss3,
               InpHedgeLadderRatio1*100, InpHedgeLadderRatio2*100, InpHedgeLadderRatio3*100)
            : StringFormat("对冲: 固定待命  浮亏>=%.0f美分 -> %.0f%%(%.2f手)",
               InpHedgeAbsoluteUSD, panelHedgeRatio*100, targetHedgeLot);
        }
      ObjectSetString(0, OBJ_LINE5, OBJPROP_TEXT, hedgeText);
      ObjectSetInteger(0, OBJ_LINE5, OBJPROP_COLOR, g_hedgeActive ? C'255,200,60' : C'140,155,180');
   }

   // Lines 6/7/3: 入场阻塞原因和关键阈值，固定紧贴信息区，避免底部大块空白。
   int reasonY = g_panelY + 158 + 5 * 24;
   ObjectSetString(0, OBJ_LINE6, OBJPROP_TEXT, GetEntryReasonLine());
   ObjectSetInteger(0, OBJ_LINE6, OBJPROP_YDISTANCE, reasonY);
   if(StringFind(g_noEntryReason, "锁定") >= 0 || StringFind(g_noEntryReason, "熔断") >= 0)
      ObjectSetInteger(0, OBJ_LINE6, OBJPROP_COLOR, C'255,80,80');
   else if(StringFind(g_noEntryReason, "暂停") >= 0 || StringFind(g_noEntryReason, "休市") >= 0)
      ObjectSetInteger(0, OBJ_LINE6, OBJPROP_COLOR, C'255,200,60');
   else
      ObjectSetInteger(0, OBJ_LINE6, OBJPROP_COLOR, C'180,190,210');

   ObjectSetString(0, OBJ_LINE7, OBJPROP_TEXT, "条件状态:");
   ObjectSetInteger(0, OBJ_LINE7, OBJPROP_YDISTANCE, reasonY + 24);
   ObjectSetInteger(0, OBJ_LINE7, OBJPROP_COLOR, C'126,190,184');

   string condObjs[] = {OBJ_ENTRY_C0, OBJ_ENTRY_C1, OBJ_ENTRY_C2, OBJ_ENTRY_C3, OBJ_ENTRY_C4, OBJ_ENTRY_C5};
   string condTexts[6];
   bool condOk[6];
   int need = (int)MathRound(InpSMCWeightEMA * 2.0 / 3.0);
   bool emaLongOk = (g_sigMartEmaDir == 1 && g_sigMartEmaScoreLong >= need);
   bool emaShortOk = (g_sigMartEmaDir == -1 && g_sigMartEmaScoreShort >= need);
   condOk[0] = (emaLongOk || emaShortOk);
   condTexts[0] = (g_sigMartEmaDir == 1)
      ? StringFormat("EMA:多%d/%d", g_sigMartEmaScoreLong, need)
      : ((g_sigMartEmaDir == -1) ? StringFormat("EMA:空%d/%d", g_sigMartEmaScoreShort, need) : "EMA:无");
   condOk[1] = (InpMartH4FilterMode == H4_FILTER_OFF || (g_sigMartEmaDir != 0 && g_sigH4Confirmed));
   condTexts[1] = "H4:" + GetH4PanelText();
   if(!InpUseEntryPrecisionFilter)
     {
      condOk[2] = true; condTexts[2] = "RSI:关";
      condOk[3] = true; condTexts[3] = "距EMA:关";
      condOk[4] = true; condTexts[4] = "实体:关";
     }
   else
     {
      bool buyRsiOk = (g_sigMartEmaDir == 1 && g_sigEntryPrecisionRsi <= InpEntryBuyRsiMax);
      bool sellRsiOk = (g_sigMartEmaDir == -1 && g_sigEntryPrecisionRsi >= InpEntrySellRsiMin);
      condOk[2] = (buyRsiOk || sellRsiOk);
      condTexts[2] = (g_sigMartEmaDir == 1)
         ? StringFormat("RSI:%.1f<=%.0f", g_sigEntryPrecisionRsi, InpEntryBuyRsiMax)
         : ((g_sigMartEmaDir == -1) ? StringFormat("RSI:%.1f>=%.0f", g_sigEntryPrecisionRsi, InpEntrySellRsiMin) : "RSI:等方向");
      condOk[3] = (g_sigEntryDistSlowAtr >= InpEntryMinDistSlowEMA_ATR && g_sigEntryDistSlowAtr <= InpEntryMaxPullbackEMA_ATR);
      condTexts[3] = StringFormat("距EMA:%.2f", g_sigEntryDistSlowAtr);
      condOk[4] = (g_sigEntryBodyAtr >= InpEntryMinBody_ATR);
      condTexts[4] = StringFormat("实体:%.2f", g_sigEntryBodyAtr);
     }
   condOk[5] = (!InpUseATRAddPause || !g_addAtrPaused);
   condTexts[5] = (InpUseATRAddPause && g_addAtrRatio > 0.0)
      ? StringFormat("ATR:%.2f", g_addAtrRatio)
      : "ATR:正常";

   int condX[] = {84, 230, 392};
   int condOrder[] = {0, 1, 5, 2, 3, 4};
   for(int d = 0; d < 6; ++d)
     {
      int c = condOrder[d];
      ObjectSetString(0, condObjs[c], OBJPROP_TEXT, condTexts[c]);
      ObjectSetInteger(0, condObjs[c], OBJPROP_XDISTANCE, g_panelX + condX[d % 3]);
      ObjectSetInteger(0, condObjs[c], OBJPROP_YDISTANCE, reasonY + 24 + (d / 3) * 24);
      ObjectSetInteger(0, condObjs[c], OBJPROP_COLOR, condOk[c] ? C'40,220,140' : C'255,90,90');
     }

   ObjectSetString(0, OBJ_LINE3, OBJPROP_TEXT, "精确过滤:");
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, reasonY + 48);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_COLOR, C'126,190,184');
   // Line 3 & 4: no longer created, just safety clear
   // V1.41 removed the SMC panel. Keep old helper code below unreachable for legacy compile safety.
   return;

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
      string offsetText = StringFormat("[偏移%.3f 间距%.0f TP%.1f]",
         g_effATRCoeff, g_effBaseSpacing, g_effBasketTP);
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
//| Calculate layer factor for front-tight/back-wide mart spacing      |
//+------------------------------------------------------------------+
double GetMartSpacingLayerFactor()
  {
   int layer = MathMax(1, g_martMaxLayerSeq);
   int stage1Max = MathMax(1, InpMartSpacingStage1MaxLayer);
   int stage2Max = MathMax(stage1Max + 1, InpMartSpacingStage2MaxLayer);
   int stage3Max = MathMax(stage2Max + 1, InpMartSpacingStage3MaxLayer);
   if(layer <= stage1Max) return MathMax(0.10, InpMartSpacingStage1Factor);
   if(layer <= stage2Max) return MathMax(0.10, InpMartSpacingStage2Factor);
   if(layer <= stage3Max) return MathMax(0.10, InpMartSpacingStage3Factor);
   return MathMax(0.10, InpMartSpacingStage4Factor);
  }

//+------------------------------------------------------------------+
//| Calculate dynamic martingale spacing (points)                     |
//| Early layers are tighter; deep layers widen progressively.         |
//| ratio = ATR(short)/ATR(long), clamped to >=1.0                    |
//| Consolidation: ratio≈1, spacing = (base+layer*inc+ATR*coeff)*F    |
//| Strong trend: ratio>1, ATR contribution gets amplified            |
//+------------------------------------------------------------------+
double GetMartSpacingPts()
  {
   double baseSpacing = g_effBaseSpacing + MathMax(0, g_martMaxLayerSeq - 1) * g_effIncSpacing;
   double layerFactor = GetMartSpacingLayerFactor();
   if(g_effATRCoeff <= 0.0 || g_hATR_Spacing == INVALID_HANDLE || g_hATR_SpacingLong == INVALID_HANDLE)
      return baseSpacing * layerFactor;
   double atrShort = GetATRValue(g_hATR_Spacing);
   double atrLong  = GetATRValue(g_hATR_SpacingLong);
   if(atrShort <= 0.0 || atrLong <= 0.0)
      return baseSpacing * layerFactor;
   double ratio = atrShort / atrLong;
   if(ratio < 1.0) ratio = 1.0;
   double expansion = MathPow(ratio, 1.5);
   return (baseSpacing + atrShort / _Point * g_effATRCoeff * expansion) * layerFactor;
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

int FindHistoryRecordByDate(const string dateStr)
{
   for(int i = 0; i < g_historyCount; i++)
   {
      if(g_historyRecords[i].date == dateStr)
         return i;
   }
   return -1;
}

int EnsureHistoryRecord(const string dateStr)
{
   int idx = FindHistoryRecordByDate(dateStr);
   if(idx >= 0)
      return idx;

   g_historyCount++;
   ArrayResize(g_historyRecords, g_historyCount);
   idx = g_historyCount - 1;
   g_historyRecords[idx].date = dateStr;
   g_historyRecords[idx].totalLots = 0.0;
   g_historyRecords[idx].maxLot = 0.0;
   g_historyRecords[idx].tradeCount = 0;
   g_historyRecords[idx].pnl = 0.0;
   g_historyRecords[idx].pnlRatio = 0.0;
   g_historyRecords[idx].balance = 0.0;
   g_historyRecords[idx].maxDrawdown = 0.0;
   g_historyRecords[idx].maxDDPct = 0.0;
   return idx;
}

void SortHistoryRecordsByDateAsc()
{
   for(int i = 0; i < g_historyCount - 1; i++)
   {
      for(int j = i + 1; j < g_historyCount; j++)
      {
         if(g_historyRecords[j].date < g_historyRecords[i].date)
         {
            DailyTradeRecord tmp = g_historyRecords[i];
            g_historyRecords[i] = g_historyRecords[j];
            g_historyRecords[j] = tmp;
         }
      }
   }
}

void RebuildHistoryFromDeals()
{
   if(g_isTester) return;

   datetime chinaNow = GetChinaNow();
   long tzDiff = (long)(chinaNow - TimeCurrent());
   datetime fromServer = TimeCurrent() - (InpHistoryDays + 2) * 86400;
   if(!HistorySelect(fromServer, TimeCurrent()))
      return;

   int touched[];
   ArrayResize(touched, 0);
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if(!IsManagedMagic((long)HistoryDealGetInteger(deal, DEAL_MAGIC))) continue;
      if(!IsManagedSymbol(HistoryDealGetString(deal, DEAL_SYMBOL))) continue;
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;

      datetime dealChina = (datetime)((long)HistoryDealGetInteger(deal, DEAL_TIME) + tzDiff);
      MqlDateTime dt;
      TimeToStruct(dealChina, dt);
      string dateStr = StringFormat("%02d-%02d", dt.mon, dt.day);
      int idx = EnsureHistoryRecord(dateStr);

      bool firstTouch = true;
      for(int k = 0; k < ArraySize(touched); k++)
      {
         if(touched[k] == idx)
         {
            firstTouch = false;
            break;
         }
      }
      if(firstTouch)
      {
         int n = ArraySize(touched);
         ArrayResize(touched, n + 1);
         touched[n] = idx;
         g_historyRecords[idx].totalLots = 0.0;
         g_historyRecords[idx].maxLot = 0.0;
         g_historyRecords[idx].tradeCount = 0;
         g_historyRecords[idx].pnl = 0.0;
         g_historyRecords[idx].pnlRatio = 0.0;
      }

      double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double pnl = HistoryDealGetDouble(deal, DEAL_PROFIT)
         + HistoryDealGetDouble(deal, DEAL_SWAP)
         + HistoryDealGetDouble(deal, DEAL_COMMISSION);
      g_historyRecords[idx].totalLots += volume;
      if(volume > g_historyRecords[idx].maxLot)
         g_historyRecords[idx].maxLot = volume;
      g_historyRecords[idx].tradeCount++;
      g_historyRecords[idx].pnl += pnl;
   }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   MqlDateTime todayDt;
   TimeToStruct(chinaNow, todayDt);
   string today = StringFormat("%02d-%02d", todayDt.mon, todayDt.day);
   for(int i = 0; i < g_historyCount; i++)
   {
      if(g_historyRecords[i].date == today)
      {
         if(g_todayMaxDrawdown > g_historyRecords[i].maxDrawdown)
            g_historyRecords[i].maxDrawdown = g_todayMaxDrawdown;
         if(g_todayMaxDDPct > g_historyRecords[i].maxDDPct)
            g_historyRecords[i].maxDDPct = g_todayMaxDDPct;
      }
      if(g_historyRecords[i].balance <= 0.0 || g_historyRecords[i].date == today)
         g_historyRecords[i].balance = bal;
      if(g_historyRecords[i].balance > 0.0)
         g_historyRecords[i].pnlRatio = g_historyRecords[i].pnl / g_historyRecords[i].balance * 100.0;
   }

   SortHistoryRecordsByDateAsc();
   while(g_historyCount > InpHistoryDays)
   {
      for(int i = 0; i < g_historyCount - 1; i++)
         g_historyRecords[i] = g_historyRecords[i+1];
      g_historyCount--;
   }
   ArrayResize(g_historyRecords, g_historyCount);
   SaveHistoryToFile();
}

void LoadHistoryFromFile()
{
   if(g_isTester) return;  // 回测模式不读文件

   g_historyCount = 0;
   ArrayResize(g_historyRecords, 0);
   
   if(!FileIsExist(HISTORY_FILE_NAME))
   {
      RebuildHistoryFromDeals();
      return;
   }
   
   int handle = FileOpen(HISTORY_FILE_NAME, FILE_READ|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
   {
      RebuildHistoryFromDeals();
      return;
   }
   
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
   RebuildHistoryFromDeals();
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
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, C'26,169,156');
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'6,29,31');
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





