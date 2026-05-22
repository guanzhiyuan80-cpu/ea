#property copyright "Golden Pixiu EA - EUR"
#property version   "1.00"
#property strict
#property description "金貔貅-EUR 马丁网格EA - EURUSD适配版"

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
   ENTRY_RSI_BB_ONLY = 0,   // 仅RSI+布林带
   ENTRY_EMA_ONLY    = 1,   // 仅H4 EMA
   ENTRY_COMBINED    = 2    // 综合评分（默认）
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

#ifndef DEF_PRESET_NAME
#define DEF_PRESET_NAME "金貔貅-EUR"
#endif
#ifndef DEF_MAGIC_NUMBER
#define DEF_MAGIC_NUMBER 26050001
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
#define DEF_MAX_SPREAD_POINTS 30
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
#define DEF_MART_BASE_SPACING 40
#endif
#ifndef DEF_MART_INC_SPACING
#define DEF_MART_INC_SPACING 10
#endif
#ifndef DEF_MART_ATR_SPACING_COEFF
#define DEF_MART_ATR_SPACING_COEFF 0.08
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
#define DEF_MART_BASKET_TP 5.0   // 基础止盈(美分), 动态TP=基础+(层数-1)×每层增量
#endif
#ifndef DEF_MART_BASKET_TP_PER_LAYER
#define DEF_MART_BASKET_TP_PER_LAYER 3.0  // 每增加一层的TP增量(美分)
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
#define DEF_MART_ENTRY_TF PERIOD_M15
#endif
#ifndef DEF_HISTORY_DAYS
#define DEF_HISTORY_DAYS 15
#endif
#define HISTORY_FILE_NAME "EUR_Grid_History.csv"
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
#ifndef DEF_FAST_LOSS_RECOVERY
#define DEF_FAST_LOSS_RECOVERY 400
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
#define DEF_HEDGE_ABSOLUTE_USD 200.0  // 绝对金额触发(美分)
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

// === 入场信号指标参数 ===
#ifndef DEF_RSI_PERIOD
#define DEF_RSI_PERIOD 14
#endif
#ifndef DEF_RSI_OVERSOLD
#define DEF_RSI_OVERSOLD 30
#endif
#ifndef DEF_RSI_OVERBOUGHT
#define DEF_RSI_OVERBOUGHT 70
#endif
#ifndef DEF_BB_PERIOD
#define DEF_BB_PERIOD 20
#endif
#ifndef DEF_BB_DEVIATION
#define DEF_BB_DEVIATION 2.0
#endif
#ifndef DEF_ADX_PERIOD
#define DEF_ADX_PERIOD 14
#endif
#ifndef DEF_ADX_MAX_LEVEL
#define DEF_ADX_MAX_LEVEL 25
#endif
#ifndef DEF_STOCH_K
#define DEF_STOCH_K 5
#endif
#ifndef DEF_STOCH_D
#define DEF_STOCH_D 3
#endif
#ifndef DEF_STOCH_SLOWING
#define DEF_STOCH_SLOWING 3
#endif
#ifndef DEF_STOCH_OVERSOLD
#define DEF_STOCH_OVERSOLD 20
#endif
#ifndef DEF_STOCH_OVERBOUGHT
#define DEF_STOCH_OVERBOUGHT 80
#endif
#ifndef DEF_H4_EMA_PERIOD
#define DEF_H4_EMA_PERIOD 50
#endif

// === 综合评分参数 ===
#ifndef DEF_SCORE_THRESHOLD
#define DEF_SCORE_THRESHOLD 30
#endif
#ifndef DEF_WEIGHT_RSI
#define DEF_WEIGHT_RSI 25
#endif
#ifndef DEF_WEIGHT_BB
#define DEF_WEIGHT_BB 25
#endif
#ifndef DEF_WEIGHT_STOCH
#define DEF_WEIGHT_STOCH 15
#endif
#ifndef DEF_WEIGHT_EMA
#define DEF_WEIGHT_EMA 20
#endif

input group "=== 基础设置 ==="
input string           InpPresetName             = DEF_PRESET_NAME;           // ▶ 策略预设名称
input long             InpMagicNumber            = DEF_MAGIC_NUMBER;          // ▶ EA唯一标识号(Magic)
input string           InpLicenseKey             = "";                        // ▶ 授权码(联系管理员获取)

input group "=== 时间与交易时段（北京时间） ==="
input int              InpChinaUtcOffsetHours    = DEF_CN_OFFSET;             // ▶ 北京时区=UTC+8
input bool             InpAutoServerUtcOffset    = DEF_AUTO_SERVER_OFFSET;    // ▶ 自动检测服务器时区
input int              InpServerUtcOffsetHours   = DEF_SERVER_OFFSET;         // ▶ 服务器UTC偏移(手动)
input bool             InpUseManualNewsBlock     = DEF_USE_NEWS_BLOCK;        // ▶ 启用定时停止交易
input int              InpNewsBlockStartHour     = DEF_NEWS_BLOCK_START;      // ▶ 停止交易开始(北京时整点)
input int              InpNewsBlockEndHour       = DEF_NEWS_BLOCK_END;        // ▶ 停止交易结束(北京时整点)

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
input double           InpMartMaxTotalLots       = DEF_MART_MAX_TOTAL_LOTS;   // ▶ 所有层加起来最大手数

input group "=== 止盈止损 ==="
input double           InpMartBasketTP_USD       = DEF_MART_BASKET_TP;        // ▶ 篮子止盈基础(美分,0=关闭)
input double           InpMartBasketTPPerLayer   = DEF_MART_BASKET_TP_PER_LAYER; // ▶ 每层TP增量(美分)
input double           InpMartHardSL_USD         = DEF_MART_HARD_SL;          // ▶ 整篮子亏损多少强平(美分)
input double           InpMartTrailPct           = DEF_MART_TRAIL_PCT;        // ▶ 浮盈保留峰值%平仓(70=回撤到峰值70%平仓,0=关闭)
input double           InpMartTrailMinProfitPerLayer = DEF_MART_TRAIL_MIN_PROFIT_PER_LAYER; // ▶ 追踪启动门槛(占TP的%,60=浮盈达60%TP启动)
input int              InpMartCooldownSec        = DEF_MART_COOLDOWN_SEC;     // ▶ 平仓后等几秒再开新单

input group "=== 入场信号 ==="
input ENUM_TIMEFRAMES  InpMartEntryTF            = DEF_MART_ENTRY_TF;         // ▶ 入场信号的K线周期
input int              InpRSIPeriod              = DEF_RSI_PERIOD;            // ▶ RSI周期
input int              InpRSIOversold            = DEF_RSI_OVERSOLD;          // ▶ RSI超卖阈值
input int              InpRSIOverbought          = DEF_RSI_OVERBOUGHT;        // ▶ RSI超买阈值
input int              InpBBPeriod               = DEF_BB_PERIOD;             // ▶ 布林带周期
input double           InpBBDeviation            = DEF_BB_DEVIATION;          // ▶ 布林带偏差
input int              InpADXPeriod              = DEF_ADX_PERIOD;            // ▶ ADX周期
input int              InpADXMaxLevel            = DEF_ADX_MAX_LEVEL;         // ▶ ADX最大值过滤(超过禁止开仓)
input int              InpStochK                 = DEF_STOCH_K;               // ▶ Stochastic K周期
input int              InpStochD                 = DEF_STOCH_D;               // ▶ Stochastic D周期
input int              InpStochSlowing           = DEF_STOCH_SLOWING;         // ▶ Stochastic减速
input int              InpStochOversold          = DEF_STOCH_OVERSOLD;        // ▶ Stochastic超卖
input int              InpStochOverbought        = DEF_STOCH_OVERBOUGHT;      // ▶ Stochastic超买
input int              InpH4EmaPeriod            = DEF_H4_EMA_PERIOD;         // ▶ H4 EMA周期
input ENUM_H4_FILTER_MODE InpMartH4FilterMode  = DEF_MART_H4_FILTER_MODE;   // ▶ H4趋势过滤模式(关闭/1K/2K,默认2K)
input int              InpMartStartHour          = DEF_MART_START_HOUR;       // ▶ 每天几点开始交易(0=全天)
input int              InpMartEndHour            = DEF_MART_END_HOUR;         // ▶ 每天几点停止交易(0=全天)

input group "=== 综合评分 ==="
input ENUM_ENTRY_MODE  InpEntryMode              = DEF_ENTRY_MODE;            // ▶ 入场模式(仅RSI+BB/仅H4 EMA/综合评分)
input int              InpScoreThreshold         = DEF_SCORE_THRESHOLD;       // ▶ 综合评分入场阈值(0-100)
input int              InpWeightRSI              = DEF_WEIGHT_RSI;            // ▶ 权重-RSI
input int              InpWeightBB               = DEF_WEIGHT_BB;             // ▶ 权重-布林带
input int              InpWeightStoch            = DEF_WEIGHT_STOCH;          // ▶ 权重-Stochastic
input int              InpWeightEMA              = DEF_WEIGHT_EMA;            // ▶ 权重-H4 EMA

input group "=== 高级风控（默认关闭） ==="
input bool             InpEnableFastLoss        = DEF_ENABLE_FAST_LOSS;      // ▶ 启用快速亏损紧急停止
input int              InpFastLossDistance      = DEF_FAST_LOSS_DISTANCE;    // ▶ 多少金额亏损触发停止
input int              InpFastLossTime          = DEF_FAST_LOSS_TIME;        // ▶ 在几秒内发生算快速亏损
input int              InpFastLossRecoveryDistance = DEF_FAST_LOSS_RECOVERY; // ▶ 回本多少金额解除停止
input bool             InpEnableHedge           = DEF_ENABLE_HEDGE;           // ▶ 启用亏损自动对冲保护
input HEDGE_TRIGGER_MODE InpHedgeTriggerMode    = DEF_HEDGE_TRIGGER_MODE;     // ▶ 对冲触发方式
input double           InpHedgeLossPercent      = DEF_HEDGE_LOSS_PCT;        // ▶ [权益%模式]亏损占权益多少%触发
input double           InpHedgeAbsoluteUSD      = DEF_HEDGE_ABSOLUTE_USD;    // ▶ [绝对金额模式]亏损多少美分触发
input double           InpHedgeRatio            = 0.5;                       // ▶ 对冲手数比例(0.5=50%)

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

// === 指标句柄 ===
int    g_hRSI          = INVALID_HANDLE;   // RSI句柄
int    g_hBB           = INVALID_HANDLE;   // 布林带句柄
int    g_hADX          = INVALID_HANDLE;   // ADX句柄
int    g_hStoch        = INVALID_HANDLE;   // Stochastic句柄
int    g_hATR          = INVALID_HANDLE;   // ATR句柄(入场TF,14)
int    g_hH4EMA        = INVALID_HANDLE;   // H4 EMA句柄
int    g_hATRShort     = INVALID_HANDLE;   // ATR动态间距-短(入场TF,3)
int    g_hATRLong      = INVALID_HANDLE;   // ATR动态间距-长(入场TF,6)

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

// Fast loss breaker state
double     g_fastLossStartEquity = 0.0;
datetime   g_fastLossStartTime   = 0;
double     g_fastLossMinEquity   = 0.0;
bool       g_fastLossLocked      = false;

bool       g_closedPnlDirty = true;        // 标记需要重新计算

string MART_COMMENT = "EUR_MART";
#define HEDGE_COMMENT "EUR_HEDGE"   // 对冲单专用注释（不含MART_COMMENT前缀）

// Hedge state
bool   g_hedgeActive = false;      // 是否有活跃对冲单
int    g_hedgeCount = 0;           // 对冲单数量
double g_hedgeLots = 0.0;          // 对冲单总手数
double g_hedgePnl = 0.0;           // 对冲单浮盈

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
string OBJ_SMC_BG1    = "HYB_SMC_BG1";    // 指标卡片1背景
string OBJ_SMC_BG2    = "HYB_SMC_BG2";    // 指标卡片2背景
string OBJ_SMC_BG3    = "HYB_SMC_BG3";    // 指标卡片3背景
string OBJ_SMC_T1     = "HYB_SMC_T1";     // 指标标题1
string OBJ_SMC_T2     = "HYB_SMC_T2";     // 指标标题2
string OBJ_SMC_T3     = "HYB_SMC_T3";     // 指标标题3
string OBJ_SMC_D1A    = "HYB_SMC_D1A";    // RSI
string OBJ_SMC_D1B    = "HYB_SMC_D1B";    // 布林带
string OBJ_SMC_D1S    = "HYB_SMC_D1S";    // 第一组小计
string OBJ_SMC_D2A    = "HYB_SMC_D2A";    // Stochastic
string OBJ_SMC_D2B    = "HYB_SMC_D2B";    // ADX
string OBJ_SMC_D2S    = "HYB_SMC_D2S";    // 第二组小计
string OBJ_SMC_D3A    = "HYB_SMC_D3A";    // H4 EMA
string OBJ_SMC_D3B    = "HYB_SMC_D3B";    // H4 K线确认
string OBJ_SMC_D3S    = "HYB_SMC_D3S";    // 第三组小计
string OBJ_SMC_TOTAL  = "HYB_SMC_TOTAL";  // 综合得分行
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
double g_sigRSIVal          = 0.0;     // RSI当前值
double g_sigBBUpper         = 0.0;     // 布林带上轨
double g_sigBBLower         = 0.0;     // 布林带下轨
double g_sigStochK          = 0.0;     // Stochastic K值
double g_sigADXVal          = 0.0;     // ADX值
double g_sigH4EmaVal        = 0.0;     // H4 EMA值
bool   g_sigH4Confirmed     = false;
int    g_sigMartDistToNext  = 0;       // points to next layer trigger
double g_sigMartBasketPnL   = 0.0;     // current basket floating PnL

// 指标信号缓存
int    g_gridDirection      = 0;       // 1=看涨, -1=看跌, 0=中立
int    g_gridBullScore      = 0;       // 多头得分
int    g_gridBearScore      = 0;       // 空头得分
int    g_gridRSIResult      = 0;       // RSI: 1=看涨, -1=看跌, 0=无
int    g_gridBBResult       = 0;       // 布林带: 1=看涨, -1=看跌, 0=无
int    g_gridStochResult    = 0;       // Stochastic: 1=看涨, -1=看跌, 0=无
int    g_gridEMAResult      = 0;       // H4 EMA: 1=看涨, -1=看跌, 0=无

void   ComputeSignalDiagnostics();
string GetBlockingReason();

// ========== 离线授权码验证 ==========
#define LICENSE_XOR_KEY "JPXEUR2026GridEA!@#"   // XOR密钥，必须与Python生成工具一致

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

   // === 创建指标句柄 ===
   g_hRSI  = iRSI(_Symbol, InpMartEntryTF, InpRSIPeriod, PRICE_CLOSE);
   g_hBB   = iBands(_Symbol, InpMartEntryTF, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   g_hADX  = iADX(_Symbol, InpMartEntryTF, InpADXPeriod);
   g_hStoch = iStochastic(_Symbol, InpMartEntryTF, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_hATR  = iATR(_Symbol, InpMartEntryTF, 14);
   g_hH4EMA = iMA(_Symbol, PERIOD_H4, InpH4EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(g_hRSI == INVALID_HANDLE || g_hBB == INVALID_HANDLE || g_hADX == INVALID_HANDLE
      || g_hStoch == INVALID_HANDLE || g_hATR == INVALID_HANDLE || g_hH4EMA == INVALID_HANDLE)
     {
      Print("指标句柄初始化失败");
      return(INIT_FAILED);
     }

   // ATR spacing handles (entry TF, short+long periods for expansion detection)
   g_hATRShort = iATR(_Symbol, InpMartEntryTF, InpMartATRSpacingPeriod);
   g_hATRLong  = iATR(_Symbol, InpMartEntryTF, InpMartATRSpacingLongPeriod);
   if(g_hATRShort == INVALID_HANDLE || g_hATRLong == INVALID_HANDLE)
      Print("[Mart] ATR间距句柄初始化失败, 动态间距已禁用");
   else
      PrintFormat("[Mart] ATR间距OK: TF=%d, short=%d, long=%d", InpMartEntryTF, InpMartATRSpacingPeriod, InpMartATRSpacingLongPeriod);

   if(!IsHedgingAccount())
      Print("Warning: non-hedging account detected. Martingale requires hedging.");

   // Cent account check
   string acctCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   bool isCent = (StringFind(acctCurrency, "USC") >= 0 || StringFind(acctCurrency, "CEN") >= 0);
   if(!isCent)
      Print("Warning: non-cent account (", acctCurrency, "). All PnL values are in account currency units. For cent accounts expect USC/CEN.");
   else
      Print("Cent account detected (", acctCurrency, "). PnL values in cents.");

   ResetDailyState(true);
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
   if(g_hRSI != INVALID_HANDLE)       IndicatorRelease(g_hRSI);
   if(g_hBB != INVALID_HANDLE)        IndicatorRelease(g_hBB);
   if(g_hADX != INVALID_HANDLE)       IndicatorRelease(g_hADX);
   if(g_hStoch != INVALID_HANDLE)     IndicatorRelease(g_hStoch);
   if(g_hATR != INVALID_HANDLE)       IndicatorRelease(g_hATR);
   if(g_hH4EMA != INVALID_HANDLE)     IndicatorRelease(g_hH4EMA);
   if(g_hATRShort != INVALID_HANDLE)  IndicatorRelease(g_hATRShort);
   if(g_hATRLong != INVALID_HANDLE)   IndicatorRelease(g_hATRLong);
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
      g_noEntryReason = "快速亏损熔断";
      return;
     }

   if(IsSpreadTooHigh())
     {
      g_noEntryReason = "点差过大(" + DoubleToString(GetCurrentSpreadPoints(),0) + ">" + IntegerToString(InpMaxSpreadPoints) + ")";
      return;
     }

   // News block: force flat if configured
   if(IsManualNewsBlocked())
     {
      CloseAllMartPositions();
      g_noEntryReason = "定时休市中";
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
      // 暂停时仍执行止盈止损和风控
      int totalPos = CountMartPositions();
      if(totalPos > 0)
        {
         RefreshMartBasketState();
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

//=== 马丁辅助函数 ===

datetime GetChinaNow()
  {
   if(InpAutoServerUtcOffset)
      return TimeGMT() + InpChinaUtcOffsetHours * 3600;
   return TimeCurrent() + InpServerUtcOffsetHours * 3600 + InpChinaUtcOffsetHours * 3600;
  }

void CloseAllMartPositions()
  {
   bool hadPositions = false;
   double totalClosedLots = 0.0;
   double totalClosedPnl = 0.0;
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
      totalClosedLots += PositionGetDouble(POSITION_VOLUME);
      totalClosedPnl  += PositionGetDouble(POSITION_PROFIT);
      ClosePositionChecked(ticket);
      hadPositions = true;
     }
   CancelMartOrders();
   if(hadPositions)
     {
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
         if(layerSeq >= 0 && layerSeq < 1000)
           {
            if(layerSeq + 1 > g_martMaxLayerSeq) g_martMaxLayerSeq = layerSeq + 1;
           }
         else
           {
            PrintFormat("[EUR] 警告: 订单#%d 注释层序号异常: %s", ticket, seqStr);
           }
        }
      else if(StringFind(cmt, MART_COMMENT) >= 0)
        {
         PrintFormat("[EUR] 警告: 马丁订单#%d 缺少_L层序号标记, comment=%s", ticket, cmt);
        }

      if(type == POSITION_TYPE_BUY)
        {
         buys++;
        }
      else
        {
         sells++;
        }
      if(openPrice > g_martHighestPrice) g_martHighestPrice = openPrice;
      if(openPrice < g_martLowestPrice) g_martLowestPrice = openPrice;
     }

   if(g_martLowestPrice == DBL_MAX) g_martLowestPrice = 0.0;

   if(buys > 0 && sells == 0) g_martDirection = MART_DIR_BUY;
   else if(sells > 0 && buys == 0) g_martDirection = MART_DIR_SELL;
   else g_martDirection = MART_DIR_NONE;

   // 回退逻辑：若注释解析失败但有持仓，用持仓数推算层序号
   if(g_martMaxLayerSeq == 0 && g_martLayerCount > 1)
     {
      g_martMaxLayerSeq = g_martLayerCount;
      PrintFormat("[EUR] 层序号回退: 使用持仓数 %d 作为 g_martMaxLayerSeq", g_martLayerCount);
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

//=== 入场信号函数 ===

// 综合评分入场信号（替代原版GetMartSignal）
bool GetGridSignal(bool &longSignal, bool &shortSignal)
  {
   longSignal = false;
   shortSignal = false;

   // --- 读取指标数据 ---
   // RSI
   double rsiBuf[2];
   if(CopyBuffer(g_hRSI, 0, 0, 2, rsiBuf) < 2) { g_noEntryReason = "RSI数据读取失败"; return false; }
   double rsiVal = rsiBuf[1];  // 上一根已收盘K线

   // 布林带 (0=Base, 1=Upper, 2=Lower)
   double bbBase[2], bbUpper[2], bbLower[2];
   if(CopyBuffer(g_hBB, 0, 0, 2, bbBase) < 2 ||
      CopyBuffer(g_hBB, 1, 0, 2, bbUpper) < 2 ||
      CopyBuffer(g_hBB, 2, 0, 2, bbLower) < 2)
     { g_noEntryReason = "布林带数据读取失败"; return false; }

   // ADX (0=Main, 1=+DI, 2=-DI)
   double adxMain[2], adxPlusDI[2], adxMinusDI[2];
   if(CopyBuffer(g_hADX, 0, 0, 2, adxMain) < 2 ||
      CopyBuffer(g_hADX, 1, 0, 2, adxPlusDI) < 2 ||
      CopyBuffer(g_hADX, 2, 0, 2, adxMinusDI) < 2)
     { g_noEntryReason = "ADX数据读取失败"; return false; }
   double adxVal = adxMain[1];

   // Stochastic (0=Main/K, 1=Signal/D)
   double stochK[2], stochD[2];
   if(CopyBuffer(g_hStoch, 0, 0, 2, stochK) < 2 ||
      CopyBuffer(g_hStoch, 1, 0, 2, stochD) < 2)
     { g_noEntryReason = "Stochastic数据读取失败"; return false; }

   double close1 = iClose(_Symbol, InpMartEntryTF, 1);
   if(close1 <= 0.0) { g_noEntryReason = "收盘价读取失败"; return false; }

   // --- ADX过滤：ADX > InpADXMaxLevel 时趋势太强，不适合网格逆势 ---
   if(adxVal > InpADXMaxLevel)
     {
      g_noEntryReason = "ADX趋势过滤(ADX=" + IntegerToString((int)adxVal) + ">" + IntegerToString(InpADXMaxLevel) + ")";
      return true;  // 数据读取成功，但信号为空
     }

   // --- H4 EMA方向判断 ---
   bool h4Bullish = false;
   bool h4Bearish = false;
   double h4EmaVal = 0.0;
   if(InpMartH4FilterMode != H4_FILTER_OFF || InpEntryMode == ENTRY_EMA_ONLY || InpEntryMode == ENTRY_COMBINED)
     {
      int needBars = (InpMartH4FilterMode == H4_FILTER_2K) ? 3 : 2;
      double emaH4[];
      ArraySetAsSeries(emaH4, true);
      if(CopyBuffer(g_hH4EMA, 0, 0, needBars, emaH4) >= needBars)
        {
         h4EmaVal = emaH4[1];
         double closeH4_1 = iClose(_Symbol, PERIOD_H4, 1);
         if(closeH4_1 > 0.0)
           {
            if(InpMartH4FilterMode == H4_FILTER_2K)
              {
               double closeH4_2 = iClose(_Symbol, PERIOD_H4, 2);
               if(closeH4_2 > 0.0)
                 {
                  h4Bullish = (closeH4_1 > emaH4[1] && closeH4_2 > emaH4[2]);
                  h4Bearish = (closeH4_1 < emaH4[1] && closeH4_2 < emaH4[2]);
                 }
              }
            else  // H4_FILTER_1K
              {
               h4Bullish = (closeH4_1 > emaH4[1]);
               h4Bearish = (closeH4_1 < emaH4[1]);
              }
           }
        }
      else
        {
         Print("[EUR] H4 EMA CopyBuffer失败, 跳过H4滤波");
        }
     }

   // --- 评分计算 ---
   int bullScore = 0;
   int bearScore = 0;

   // RSI评分
   g_gridRSIResult = 0;
   if(rsiVal < InpRSIOversold)
     { bullScore += InpWeightRSI; g_gridRSIResult = 1; }
   else if(rsiVal > InpRSIOverbought)
     { bearScore += InpWeightRSI; g_gridRSIResult = -1; }

   // 布林带评分
   g_gridBBResult = 0;
   if(close1 <= bbLower[1])
     { bullScore += InpWeightBB; g_gridBBResult = 1; }
   else if(close1 >= bbUpper[1])
     { bearScore += InpWeightBB; g_gridBBResult = -1; }

   // Stochastic评分
   g_gridStochResult = 0;
   if(stochK[1] < InpStochOversold)
     { bullScore += InpWeightStoch; g_gridStochResult = 1; }
   else if(stochK[1] > InpStochOverbought)
     { bearScore += InpWeightStoch; g_gridStochResult = -1; }

   // H4 EMA方向评分
   g_gridEMAResult = 0;
   if(close1 > h4EmaVal && h4EmaVal > 0.0)
     { bullScore += InpWeightEMA; g_gridEMAResult = 1; }
   else if(close1 < h4EmaVal && h4EmaVal > 0.0)
     { bearScore += InpWeightEMA; g_gridEMAResult = -1; }

   // 缓存评分
   g_gridBullScore = bullScore;
   g_gridBearScore = bearScore;
   g_gridDirection = (bullScore > bearScore) ? 1 : ((bearScore > bullScore) ? -1 : 0);

   // --- H4过滤模式（1K/2K确认逻辑，应用于所有入场模式） ---
   if(InpMartH4FilterMode != H4_FILTER_OFF)
     {
      // 对多头信号：H4必须看涨
      if(bullScore > 0 && !h4Bullish)
        {
         bullScore = 0;  // H4趋势不支持做多，取消多头信号
        }
      // 对空头信号：H4必须看跌
      if(bearScore > 0 && !h4Bearish)
        {
         bearScore = 0;  // H4趋势不支持做空，取消空头信号
        }
     }

   // --- 根据入场模式返回信号 ---
   switch(InpEntryMode)
     {
      case ENTRY_RSI_BB_ONLY:
         // 仅看RSI+布林带得分（不包含Stochastic和EMA权重）
         {
            int rsiBbBull = (g_gridRSIResult == 1 ? InpWeightRSI : 0) + (g_gridBBResult == 1 ? InpWeightBB : 0);
            int rsiBbBear = (g_gridRSIResult == -1 ? InpWeightRSI : 0) + (g_gridBBResult == -1 ? InpWeightBB : 0);
            // H4过滤
            if(InpMartH4FilterMode != H4_FILTER_OFF)
              {
               if(rsiBbBull > 0 && !h4Bullish) rsiBbBull = 0;
               if(rsiBbBear > 0 && !h4Bearish) rsiBbBear = 0;
              }
            longSignal  = (rsiBbBull >= InpScoreThreshold && rsiBbBull > rsiBbBear);
            shortSignal = (rsiBbBear >= InpScoreThreshold && rsiBbBear > rsiBbBull);
            if(!longSignal && !shortSignal && g_noEntryReason == "")
               g_noEntryReason = "RSI+BB评分不足(多:" + IntegerToString(rsiBbBull) + " 空:" + IntegerToString(rsiBbBear) + " 需≥" + IntegerToString(InpScoreThreshold) + ")";
         }
         break;

      case ENTRY_EMA_ONLY:
         // 仅看H4 EMA方向（含H4过滤确认）
         longSignal  = h4Bullish;
         shortSignal = h4Bearish;
         if(!longSignal && !shortSignal && g_noEntryReason == "")
            g_noEntryReason = "H4 EMA无方向信号";
         break;

      case ENTRY_COMBINED:
         // 综合评分 >= 阈值 且 一方占优
         longSignal  = (bullScore >= InpScoreThreshold && bullScore > bearScore);
         shortSignal = (bearScore >= InpScoreThreshold && bearScore > bullScore);
         if(!longSignal && !shortSignal && g_noEntryReason == "")
            g_noEntryReason = "综合评分不足(多:" + IntegerToString(bullScore) + " 空:" + IntegerToString(bearScore) + " 需≥" + IntegerToString(InpScoreThreshold) + ")";
         break;
     }

   return true;
  }

//=== 马丁核心交易函数 ===

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
   if(!GetGridSignal(longSig, shortSig)) return;
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
   if(g_martMaxLayerSeq >= InpMartMaxLayers) return;
   if(g_martTotalLots >= InpMartMaxTotalLots) return;

   // Layer cooldown: prevent rapid-fire layer additions
   if(g_martLastLayerTime > 0 && TimeCurrent() - g_martLastLayerTime < InpMartCooldownSec)
      return;

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
   // 动态TP = 基础 + (层数-1) × 每层增量
   int layers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTP = InpMartBasketTP_USD + (layers - 1) * InpMartBasketTPPerLayer;
   double pnl = GetEffectivePnL();
   if(pnl >= dynamicTP)
     {
      CloseAllMartPositions();
      PrintFormat("篮子动态TP触发: 浮盈=%.2f >= 目标=%.2f (基础%.0f+(%d-1)×%.0f)", pnl, dynamicTP, InpMartBasketTP_USD, layers, InpMartBasketTPPerLayer);
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
   double dynamicTP = InpMartBasketTP_USD + (layers - 1) * InpMartBasketTPPerLayer;
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
      g_fastLossLocked = false;
      g_todayMaxDrawdown = 0.0;
      g_todayMaxDDPct = 0.0;
      g_fastLossStartEquity = 0.0;
      g_fastLossStartTime = 0;
      g_fastLossMinEquity = 0.0;
     }
  }


bool IsManualNewsBlocked()
  {
   if(!InpUseManualNewsBlock)
      return false;

   datetime chinaNow = GetChinaNow();
   MqlDateTime t;
   TimeToStruct(chinaNow, t);
   int h = t.hour;

   if(InpNewsBlockStartHour == InpNewsBlockEndHour)
      return false;

   if(InpNewsBlockStartHour < InpNewsBlockEndHour)
      return (h >= InpNewsBlockStartHour && h < InpNewsBlockEndHour);

   return (h >= InpNewsBlockStartHour || h < InpNewsBlockEndHour);
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
   // 自动匹配同基础品种名(EURUSD = EURUSDc = EURUSDm = EURUSDmicro)
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

//=== 风控管理模块 ===

void CheckFastLossBreaker()
  {
   if(!InpEnableFastLoss) return;

   if(!g_fastLossLocked)
     {
      // 使用EA仓位盈亏而非整个账户权益
      double martPnl = GetEffectivePnL();

      // 初始化或滑动窗口更新
      if(g_fastLossStartTime == 0)
        {
         g_fastLossStartEquity = martPnl;
         g_fastLossStartTime = TimeCurrent();
         g_fastLossMinEquity = martPnl;
         return;
        }

      // 更新最低点
      if(martPnl < g_fastLossMinEquity)
         g_fastLossMinEquity = martPnl;

      // 检查从峰值到谷值的跌幅
      double dropAmount = g_fastLossStartEquity - g_fastLossMinEquity;
      if(dropAmount >= InpFastLossDistance)
        {
         g_fastLossLocked = true;
         g_fastLossMinEquity = martPnl;
         CloseAllMartPositions();
         PrintFormat("快速熔断触发: 浮盈从%.2f跌至%.2f, 跌幅=%.2f >= 阈值%d",
                     g_fastLossStartEquity, g_fastLossMinEquity, dropAmount, InpFastLossDistance);
         return;
        }

      // 滑动窗口：如果盈亏改善，更新起始基准
      if(martPnl > g_fastLossStartEquity)
        {
         g_fastLossStartEquity = martPnl;
         g_fastLossMinEquity = martPnl;
         g_fastLossStartTime = TimeCurrent();
        }
      // 超时但未触发：不完全重置，只更新起始点为当前值（滑动）
      else if(TimeCurrent() - g_fastLossStartTime > InpFastLossTime)
        {
         g_fastLossStartEquity = martPnl;
         g_fastLossStartTime = TimeCurrent();
         // 注意：g_fastLossMinEquity 不重置，保持追踪最低点
        }
     }
   else
     {
      // Locked: wait for recovery
      double martPnl = GetEffectivePnL();
      double recoveryPoints = martPnl - g_fastLossMinEquity;
      if(recoveryPoints >= InpFastLossRecoveryDistance)
        {
         g_fastLossLocked = false;
         g_fastLossStartEquity = 0.0;
         g_fastLossStartTime = 0;
         g_fastLossMinEquity = 0.0;
         Print("Fast loss breaker recovered: martPnl recovered ", recoveryPoints, " currency units");
        }
     }
  }

void ManageHedgeLock()
  {
   if(!InpEnableHedge) return;
   if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT && InpHedgeLossPercent <= 0.0) return;
   if(InpHedgeTriggerMode == HEDGE_BY_ABSOLUTE && InpHedgeAbsoluteUSD <= 0.0) return;

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
      double targetHedgeVol = NormalizeVolume(totalVolume * InpHedgeRatio);
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

   // 根据触发模式判断是否启动对冲
   bool triggerHedge = false;
   if(floatingPnl >= 0.0) return;  // 没有浮亏不触发

   if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq <= 0.0) return;
      double absEquity = eq - floatingPnl;
      if(absEquity <= 0.0) return;
      double lossPct = (-floatingPnl) / absEquity * 100.0;
      triggerHedge = (lossPct >= InpHedgeLossPercent);
     }
   else // HEDGE_BY_ABSOLUTE
     {
      triggerHedge = ((-floatingPnl) >= InpHedgeAbsoluteUSD);
     }

   if(triggerHedge)
     {
      double hedgeVol = NormalizeVolume(totalVolume * InpHedgeRatio);
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
   if(!InpEnableHedge) return;
   if(!g_hedgeActive) return;

   // 计算马丁+对冲的总浮盈
   double totalPnl = g_cachedMartPnl + g_hedgePnl;

   // 计算止盈阈值
   double releaseThreshold = 0.0;
   if(InpHedgeReleaseMode == HEDGE_RELEASE_FIXED)
      releaseThreshold = InpHedgeReleaseFixed;
   else
      releaseThreshold = g_martLayerCount * InpHedgeReleaseDynPerLayer;

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
   // Reset diagnostics
   g_sigMartEntryOk    = false;
   g_sigMartEmaDir     = 0;
   g_sigRSIVal         = 0.0;
   g_sigBBUpper        = 0.0;
   g_sigBBLower        = 0.0;
   g_sigStochK         = 0.0;
   g_sigADXVal         = 0.0;
   g_sigH4Confirmed    = false;
   g_sigH4EmaVal       = 0.0;
   g_sigMartDistToNext = 0;
   g_sigMartBasketPnL  = g_cachedMartPnl;

   // Read indicator values for diagnostics
   double rsiBuf[2];
   if(CopyBuffer(g_hRSI, 0, 0, 2, rsiBuf) >= 2)
      g_sigRSIVal = rsiBuf[1];

   double bbUpper[2], bbLower[2];
   if(CopyBuffer(g_hBB, 1, 0, 2, bbUpper) >= 2)
      g_sigBBUpper = bbUpper[1];
   if(CopyBuffer(g_hBB, 2, 0, 2, bbLower) >= 2)
      g_sigBBLower = bbLower[1];

   double stochK[2];
   if(CopyBuffer(g_hStoch, 0, 0, 2, stochK) >= 2)
      g_sigStochK = stochK[1];

   double adxMain[2];
   if(CopyBuffer(g_hADX, 0, 0, 2, adxMain) >= 2)
      g_sigADXVal = adxMain[1];

   // Determine overall signal direction for display
   g_sigMartEmaDir = g_gridDirection;

   // H4 EMA diagnostics
   {
      int needBars = (InpMartH4FilterMode == H4_FILTER_2K) ? 3 : 2;
      double emaH4[];
      ArraySetAsSeries(emaH4, true);
      if(CopyBuffer(g_hH4EMA, 0, 0, needBars, emaH4) >= needBars)
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

   // Distance to next layer trigger
   g_sigMartDistToNext = 0;
   if(g_martDirection != MART_DIR_NONE && g_martLayerCount > 0 && g_martMaxLayerSeq < InpMartMaxLayers)
     {
      double spacingPts = GetMartSpacingPts();
      double spacingPrice = spacingPts * _Point;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_martDirection == MART_DIR_BUY && g_martLowestPrice > 0.0)
        {
         double triggerPrice = g_martLowestPrice - spacingPrice;
         g_sigMartDistToNext = (int)MathRound((ask - triggerPrice) / _Point);
        }
      else if(g_martDirection == MART_DIR_SELL && g_martHighestPrice > 0.0)
        {
         double triggerPrice = g_martHighestPrice + spacingPrice;
         g_sigMartDistToNext = (int)MathRound((triggerPrice - bid) / _Point);
        }
     }

   g_sigMartEntryOk = (g_gridBullScore >= InpScoreThreshold || g_gridBearScore >= InpScoreThreshold);
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
      return StringFormat("定时休市(%d-%d时)", InpNewsBlockStartHour, InpNewsBlockEndHour);
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

double GetATRValue(int handle, int shift=1)
  {
   double buf[2];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
  }

double GetMartSpacingPts()
  {
   double baseSpacing = InpMartBaseSpacingPts + (g_martMaxLayerSeq + 1) * InpMartIncSpacingPts;
   if(InpMartATRSpacingCoeff <= 0.0 || g_hATRShort == INVALID_HANDLE || g_hATRLong == INVALID_HANDLE)
      return baseSpacing;
   double atrShort = GetATRValue(g_hATRShort);
   double atrLong  = GetATRValue(g_hATRLong);
   if(atrShort <= 0.0 || atrLong <= 0.0)
      return baseSpacing;
   double ratio = atrShort / atrLong;
   if(ratio < 1.0) ratio = 1.0;
   double expansion = MathPow(ratio, 1.5);
   return InpMartBaseSpacingPts + (g_martMaxLayerSeq + 1) * InpMartIncSpacingPts
          + atrShort / _Point * InpMartATRSpacingCoeff * expansion;
  }

// ===== 面板UI系统 =====

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

   double scaleX = (double)targetW / g_logoSrcW;
   double scaleY = (double)targetH / g_logoSrcH;
   double scale  = MathMin(scaleX, scaleY);
   int drawW = (int)(g_logoSrcW * scale);
   int drawH = (int)(g_logoSrcH * scale);
   int offsetX = (targetW - drawW) / 2;
   int offsetY = (targetH - drawH) / 2;

   uint bgColor = 0xFF141A25;
   ArrayInitialize(scaled, bgColor);

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

   double scaleX = (double)targetW / g_bgSrcW;
   double scaleY = (double)targetH / g_bgSrcH;
   double scale  = MathMax(scaleX, scaleY);

   int srcDrawW = (int)(targetW / scale);
   int srcDrawH = (int)(targetH / scale);
   int srcOffX  = (g_bgSrcW - srcDrawW) / 2;
   int srcOffY  = (g_bgSrcH - srcDrawH) / 2;

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
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, x + 6);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, y + 3);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, C'140,155,180');
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, titleName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "");

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

void CreateStatusPanel()
  {
   if(g_isTester) return;
   if(!InpShowStatusPanel)
      return;

   for(int i = 5; i < 10; i++)
     {
      string oldLine = "HYB_LINE" + IntegerToString(i);
      if(ObjectFind(0, oldLine) >= 0)
         ObjectDelete(0, oldLine);
     }

   ResolvePanelLayout();

   // --- Chart background ---
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

   // --- Panel background ---
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

   // --- Top bar ---
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

   // --- Logo Frame ---
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

   // --- Logo ---
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
   ObjectSetString(0, OBJ_HEADER, OBJPROP_TEXT, "金貔貅-EUR v1.00");

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
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_TEXT, "EURUSDc | 美分账户 | 网格策略");

   // --- 3 Stat Cards ---
   int cardY = g_panelY + 90;
   int cardH = 60;
   int cardGap = 6;
   int cardW = (contentW - 16 - cardGap * 2) / 3;
   int cardX1 = g_panelX + 8;
   int cardX2 = cardX1 + cardW + cardGap;
   int cardX3 = cardX2 + cardW + cardGap;

   CreateCardObj(OBJ_CARD1_BG, OBJ_CARD1_T, OBJ_CARD1_V, OBJ_CARD1_S, cardX1, cardY, cardW, cardH);
   CreateCardObj(OBJ_CARD2_BG, OBJ_CARD2_T, OBJ_CARD2_V, OBJ_CARD2_S, cardX2, cardY, cardW, cardH);
   CreateCardObj(OBJ_CARD3_BG, OBJ_CARD3_T, OBJ_CARD3_V, OBJ_CARD3_S, cardX3, cardY, cardW, cardH);

   // --- 指标卡片区（替换SMC区域） ---
   int smcY = g_panelY + 158;
   int smcCardH = 65;
   int smcX1 = cardX1;
   int smcX2 = cardX2;
   int smcX3 = cardX3;

   // 卡片1: 趋势过滤 (ADX + H4 EMA)
   CreateSmcCard(OBJ_SMC_BG1, OBJ_SMC_T1, OBJ_SMC_D1A, OBJ_SMC_D1B, OBJ_SMC_D1S, smcX1, smcY, cardW, smcCardH);
   // 卡片2: 均值回归 (RSI + BB)
   CreateSmcCard(OBJ_SMC_BG2, OBJ_SMC_T2, OBJ_SMC_D2A, OBJ_SMC_D2B, OBJ_SMC_D2S, smcX2, smcY, cardW, smcCardH);
   // 卡片3: 动量确认 (Stochastic)
   CreateSmcCard(OBJ_SMC_BG3, OBJ_SMC_T3, OBJ_SMC_D3A, OBJ_SMC_D3B, OBJ_SMC_D3S, smcX3, smcY, cardW, smcCardH);

   // 综合评分行
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

   // --- Info Lines ---
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

   // LINE4 — 止盈止损参数行
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

   // LINE5 — 对冲信息行
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

   // LINE3 — 不建仓原因行
   if(ObjectFind(0, OBJ_LINE3) < 0)
      ObjectCreate(0, OBJ_LINE3, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_XDISTANCE, g_panelX + 10);
   ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, -9999);
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
   if(g_manualPaused)
      ObjectSetString(0, OBJ_BTN6, OBJPROP_TEXT, "恢复交易");

   // --- 历史明细按钮 ---
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

   // --- Toggle Button ---
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
  }

void SetPanelVisibility(bool visible)
  {
   g_panelVisible = visible;

   if(!visible)
     {
      DestroyStatusPanel();
      g_panelCreated = false;

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
      ObjectDelete(0, OBJ_BTN_TOGGLE);
      g_panelCreated = false;
     }

   ChartRedraw(0);
  }

void DestroyStatusPanel()
  {
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
   for(int i = 0; i < 10; i++)
     {
      string lineName = "HYB_LINE" + IntegerToString(i);
      ObjectDelete(0, lineName);
     }
   ObjectDelete(0, OBJ_BTN1); ObjectDelete(0, OBJ_BTN2); ObjectDelete(0, OBJ_BTN3);
   ObjectDelete(0, OBJ_BTN4); ObjectDelete(0, OBJ_BTN5); ObjectDelete(0, OBJ_BTN6);
   ObjectDelete(0, "HYB_BTN_HIST");
   ResourceFree(LOGO_RES);
   ResourceFree(BG_RES);
  }

void UpdateStatusPanel()
  {
   if(g_isTester) return;
   if(!InpShowStatusPanel)
      return;
   if(!g_panelVisible) return;

   if(!g_panelCreated)
     {
      CreateStatusPanel();
      g_panelCreated = true;
     }

   // 定期确保面板文字标签在前景层
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
   double floatingPnl = GetEffectivePnL();

   string acctCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   bool isCent = (StringFind(acctCurrency, "USC") >= 0 || StringFind(acctCurrency, "CEN") >= 0);
   string acctType = isCent ? "美分账户" : "标准账户";

   // 方向文本
   string dirText = "待机";
   if(g_martDirection == MART_DIR_BUY)       dirText = "做多";
   else if(g_martDirection == MART_DIR_SELL)  dirText = "做空";

   // 综合评分方向
   string trendArrow = "";
   int bestScore = MathMax(g_gridBullScore, g_gridBearScore);
   if(g_gridBullScore > g_gridBearScore)        trendArrow = StringFormat("评分:多%d", g_gridBullScore);
   else if(g_gridBearScore > g_gridBullScore)    trendArrow = StringFormat("评分:空%d", g_gridBearScore);
   else                                          trendArrow = StringFormat("评分:平(%d:%d)", g_gridBullScore, g_gridBearScore);

   string subHdr = StringFormat("EURUSDc | %s | 网格策略  %s  授权至:%s-%s-%s",
      acctType, trendArrow,
      StringSubstr(g_licenseExpiry, 0, 4), StringSubstr(g_licenseExpiry, 4, 2), StringSubstr(g_licenseExpiry, 6, 2));
   if(g_manualPaused)
      subHdr += " [暂停]";
   ObjectSetString(0, OBJ_SUBHDR, OBJPROP_TEXT, subHdr);

   // 顶栏颜色
   color topColor = C'45,55,75';
   if(g_dailyLocked || g_martHardSLLocked || g_fastLossLocked)
      topColor = C'160,50,50';
   else if(g_manualPaused)
      topColor = C'140,110,40';
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_COLOR, topColor);
   ObjectSetInteger(0, OBJ_TOPBAR, OBJPROP_BGCOLOR, topColor);

   // --- Card 1: 篮子浮盈 ---
   ObjectSetString(0, OBJ_CARD1_T, OBJPROP_TEXT, g_hedgeActive ? "总浮盈" : "篮子浮盈");
   string pnlText = StringFormat("%+.2f", floatingPnl);
   ObjectSetString(0, OBJ_CARD1_V, OBJPROP_TEXT, pnlText);
   ObjectSetInteger(0, OBJ_CARD1_V, OBJPROP_COLOR, floatingPnl >= 0 ? C'80,200,120' : C'255,80,80');
   color pnlColor = (g_dayRealizedPnl >= 0) ? C'0,200,120' : C'255,80,80';
   ObjectSetInteger(0, OBJ_CARD1_S, OBJPROP_COLOR, pnlColor);
   ObjectSetString(0, OBJ_CARD1_S, OBJPROP_TEXT, StringFormat("当日已平: %.2f", g_dayRealizedPnl));

   // --- Card 2: 持仓手数 ---
   ObjectSetString(0, OBJ_CARD2_T, OBJPROP_TEXT, "持仓手数");
   ObjectSetString(0, OBJ_CARD2_V, OBJPROP_TEXT, StringFormat("%.2f手", g_martTotalLots));
   ObjectSetString(0, OBJ_CARD2_S, OBJPROP_TEXT, StringFormat("%d/%d层", g_martLayerCount, InpMartMaxLayers));

   // --- Card 3: TP进度 ---
   double tpPct = 0.0;
   int tpLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
   double dynamicTPPanel = InpMartBasketTP_USD + (tpLayers - 1) * InpMartBasketTPPerLayer;
   if(dynamicTPPanel > 0.0)
      tpPct = MathMin(100.0, MathMax(0.0, floatingPnl / dynamicTPPanel * 100.0));
   ObjectSetString(0, OBJ_CARD3_T, OBJPROP_TEXT, "TP进度");
   ObjectSetString(0, OBJ_CARD3_V, OBJPROP_TEXT, StringFormat("%.1f%%", tpPct));
   ObjectSetInteger(0, OBJ_CARD3_V, OBJPROP_COLOR, tpPct >= 75.0 ? C'80,200,120' : C'224,231,255');
   ObjectSetString(0, OBJ_CARD3_S, OBJPROP_TEXT, StringFormat("目标:%.0f", dynamicTPPanel));

   // === 指标卡片更新 ===

   // --- 卡片1: 趋势过滤 (ADX + H4 EMA) ---
   ObjectSetString(0, OBJ_SMC_T1, OBJPROP_TEXT, "趋势过滤");

   // ADX值
   double adxVal = g_sigADXVal;
   string adxText = StringFormat("ADX: %.1f  %s", adxVal,
      adxVal < InpADXMaxLevel ? "[弱趋势]" : "[强趋势禁单]");
   ObjectSetString(0, OBJ_SMC_D1A, OBJPROP_TEXT, adxText);
   ObjectSetInteger(0, OBJ_SMC_D1A, OBJPROP_COLOR, adxVal < InpADXMaxLevel ? C'80,200,120' : C'255,80,80');

   // H4 EMA方向
   double close1 = iClose(_Symbol, InpMartEntryTF, 1);
   string emaDir = "";
   color emaDirColor = C'90,100,120';
   if(g_sigH4EmaVal > 0.0)
     {
      if(close1 > g_sigH4EmaVal)  { emaDir = "↑看多"; emaDirColor = C'80,200,120'; }
      else                         { emaDir = "↓看空"; emaDirColor = C'255,80,80';  }
     }
   else emaDir = "待计算";
   string emaText = StringFormat("H4 EMA(%d): %s", InpH4EmaPeriod, emaDir);
   ObjectSetString(0, OBJ_SMC_D1B, OBJPROP_TEXT, emaText);
   ObjectSetInteger(0, OBJ_SMC_D1B, OBJPROP_COLOR, emaDirColor);

   // H4过滤状态小计
   string h4FilterMode = (InpMartH4FilterMode == H4_FILTER_OFF) ? "关闭" : ((InpMartH4FilterMode == H4_FILTER_1K) ? "1K" : "2K");
   string h4Status = (InpMartH4FilterMode == H4_FILTER_OFF) ? "已关闭" : (g_sigH4Confirmed ? "已通过" : "未通过");
   ObjectSetString(0, OBJ_SMC_D1S, OBJPROP_TEXT, StringFormat("H4过滤(%s): %s", h4FilterMode, h4Status));
   ObjectSetInteger(0, OBJ_SMC_D1S, OBJPROP_COLOR, (g_sigH4Confirmed || InpMartH4FilterMode == H4_FILTER_OFF) ? C'80,200,120' : C'255,200,60');

   // --- 卡片2: 均值回归 (RSI + BB) ---
   ObjectSetString(0, OBJ_SMC_T2, OBJPROP_TEXT, "均值回归");

   // RSI值
   double rsiVal = g_sigRSIVal;
   string rsiText = StringFormat("RSI(%d): %.1f", InpRSIPeriod, rsiVal);
   color rsiColor = C'140,155,180';
   if(rsiVal < InpRSIOversold)       { rsiText += " [超卖]"; rsiColor = C'80,200,120'; }
   else if(rsiVal > InpRSIOverbought) { rsiText += " [超买]"; rsiColor = C'255,80,80';  }
   ObjectSetString(0, OBJ_SMC_D2A, OBJPROP_TEXT, rsiText);
   ObjectSetInteger(0, OBJ_SMC_D2A, OBJPROP_COLOR, rsiColor);

   // BB位置
   double curPrice = iClose(_Symbol, InpMartEntryTF, 1);
   string bbPos = "";
   color bbColor = C'140,155,180';
   double bbRange = g_sigBBUpper - g_sigBBLower;
   if(bbRange > 0.0 && g_sigBBUpper > 0.0)
     {
      double bbMid = (g_sigBBUpper + g_sigBBLower) / 2.0;
      double upperZone = g_sigBBUpper - bbRange * 0.15;
      double lowerZone = g_sigBBLower + bbRange * 0.15;
      if(curPrice >= upperZone)       { bbPos = "上轨附近"; bbColor = C'255,80,80';   }
      else if(curPrice <= lowerZone)  { bbPos = "下轨附近"; bbColor = C'80,200,120';  }
      else                            { bbPos = "中轨附近"; bbColor = C'140,155,180'; }
     }
   else bbPos = "待计算";
   ObjectSetString(0, OBJ_SMC_D2B, OBJPROP_TEXT, StringFormat("BB(%d): %s", InpBBPeriod, bbPos));
   ObjectSetInteger(0, OBJ_SMC_D2B, OBJPROP_COLOR, bbColor);

   // RSI信号小计
   string rsiSignal = (g_gridRSIResult == 1) ? "看多" : ((g_gridRSIResult == -1) ? "看空" : "无信号");
   string bbSignal  = (g_gridBBResult == 1) ? "看多" : ((g_gridBBResult == -1) ? "看空" : "无信号");
   ObjectSetString(0, OBJ_SMC_D2S, OBJPROP_TEXT, StringFormat("RSI:%s  BB:%s", rsiSignal, bbSignal));
   ObjectSetInteger(0, OBJ_SMC_D2S, OBJPROP_COLOR, C'224,231,255');

   // --- 卡片3: 动量确认 (Stochastic) ---
   ObjectSetString(0, OBJ_SMC_T3, OBJPROP_TEXT, "动量确认");

   // Stochastic K值
   double stochK = g_sigStochK;
   double stochD = 0.0;
   if(g_hStoch != INVALID_HANDLE)
     {
      double dBuf[2];
      if(CopyBuffer(g_hStoch, 1, 1, 1, dBuf) >= 1)
         stochD = dBuf[0];
     }
   string stochKText = StringFormat("K(%d): %.1f", InpStochK, stochK);
   color stochKColor = C'140,155,180';
   if(stochK < InpStochOversold)       { stochKText += " [超卖]"; stochKColor = C'80,200,120'; }
   else if(stochK > InpStochOverbought) { stochKText += " [超买]"; stochKColor = C'255,80,80';  }
   ObjectSetString(0, OBJ_SMC_D3A, OBJPROP_TEXT, stochKText);
   ObjectSetInteger(0, OBJ_SMC_D3A, OBJPROP_COLOR, stochKColor);

   string stochDText = StringFormat("D(%d): %.1f", InpStochD, stochD);
   color stochDColor = C'140,155,180';
   if(stochD < InpStochOversold)       { stochDText += " [超卖区]"; stochDColor = C'80,200,120'; }
   else if(stochD > InpStochOverbought) { stochDText += " [超买区]"; stochDColor = C'255,80,80';  }
   ObjectSetString(0, OBJ_SMC_D3B, OBJPROP_TEXT, stochDText);
   ObjectSetInteger(0, OBJ_SMC_D3B, OBJPROP_COLOR, stochDColor);

   string stochSignal = (g_gridStochResult == 1) ? "看多" : ((g_gridStochResult == -1) ? "看空" : "无信号");
   string emaSignal   = (g_gridEMAResult == 1) ? "看多" : ((g_gridEMAResult == -1) ? "看空" : "无信号");
   ObjectSetString(0, OBJ_SMC_D3S, OBJPROP_TEXT, StringFormat("Stoch:%s  EMA:%s", stochSignal, emaSignal));
   ObjectSetInteger(0, OBJ_SMC_D3S, OBJPROP_COLOR, C'224,231,255');

   // --- 综合评分行 ---
   {
      int maxScore = InpWeightRSI + InpWeightBB + InpWeightStoch + InpWeightEMA;
      string dirLabel = (g_gridBullScore >= g_gridBearScore) ? "多" : "空";
      int topScore = MathMax(g_gridBullScore, g_gridBearScore);
      string passMark = (topScore >= InpScoreThreshold && g_gridBullScore != g_gridBearScore) ? "✓" : "✗";
      string distText = "";
      double curSpacing = GetMartSpacingPts();
      if(g_martLayerCount >= InpMartMaxLayers)
         distText = "-";
      else if(g_martLayerCount <= 0)
         distText = StringFormat("%.0f点", curSpacing);
      else if(g_sigMartDistToNext < 0)
         distText = StringFormat("已触发[%.0f]", curSpacing);
      else
         distText = StringFormat("%d|%.0f", g_sigMartDistToNext, curSpacing);

      string totalText = StringFormat("综合: 多:%d 空:%d [%s%d/%d 阈:%d]%s  %d/%d层 距:%s",
         g_gridBullScore, g_gridBearScore,
         dirLabel, topScore, maxScore, InpScoreThreshold, passMark,
         g_martLayerCount, InpMartMaxLayers, distText);
      ObjectSetString(0, OBJ_SMC_TOTAL, OBJPROP_TEXT, totalText);
      ObjectSetInteger(0, OBJ_SMC_TOTAL, OBJPROP_COLOR,
         topScore >= InpScoreThreshold ? C'80,200,120' : C'140,155,180');
   }

   // === 信息行 ===
   double spread = GetCurrentSpreadPoints();

   // Line 0: 综合评分与马丁状态
   {
      string sigText = "待机";
      if(g_sigMartEntryOk)
        {
         if(g_sigMartEmaDir == 1)       sigText = "做多";
         else if(g_sigMartEmaDir == -1)  sigText = "做空";
        }
      string modeLabel = "";
      if(InpEntryMode == ENTRY_RSI_BB_ONLY)   modeLabel = "RSI+BB";
      else if(InpEntryMode == ENTRY_EMA_ONLY)  modeLabel = "仅EMA";
      else                                     modeLabel = "综合";
      ObjectSetString(0, OBJ_LINE0, OBJPROP_TEXT,
         StringFormat("模式:%s  信号:%s  多:%d 空:%d  点差:%.0f  方向:%s",
            modeLabel, sigText, g_gridBullScore, g_gridBearScore, spread, dirText));
      color sigColor = C'140,155,180';
      int bs = g_gridBullScore, br = g_gridBearScore;
      if(MathMax(bs, br) >= InpScoreThreshold && bs != br) sigColor = C'80,200,120';
      else if(bs > 0 || br > 0) sigColor = C'255,200,60';
      ObjectSetInteger(0, OBJ_LINE0, OBJPROP_COLOR, sigColor);
   }

   // Line 1: 账户风控
   {
      double modulePnlNow = g_dayRealizedPnl + floatingPnl;
      double deltaPnl = modulePnlNow - g_dayStartModulePnl;
      double dailyLossPct = 0.0;
      if(eq > 0.0 && deltaPnl < 0.0)
         dailyLossPct = (-deltaPnl) / eq * 100.0;
      string riskDaily  = g_dailyLocked     ? "锁定" : "正常";
      string riskHardSL = g_martHardSLLocked ? "锁定" : "正常";
      string riskFast   = g_fastLossLocked   ? "锁定" : "正常";
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

   // Line 2: 回撤浮亏
   {
      double curLossPct = 0.0;
      if(eq > 0.0 && floatingPnl < 0.0)
        {
         double absEquity = eq - floatingPnl;
         if(absEquity > 0.0)
            curLossPct = (-floatingPnl) / absEquity * 100.0;
        }
      string line2Text = StringFormat("最大回撤:%.2f(%.2f%%)  当前浮亏:%.2f%%",
         dayDd, g_todayMaxDDPct, curLossPct);
      if(InpEnableHedge && !g_hedgeActive)
        {
         if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
            line2Text += StringFormat("  对冲需:%.1f%%", InpHedgeLossPercent);
         else
            line2Text += StringFormat("  对冲需:%.0f美分", InpHedgeAbsoluteUSD);
        }
      else if(g_hedgeActive)
         line2Text += StringFormat("  对冲:%d单/%.2f手", g_hedgeCount, g_hedgeLots);
      ObjectSetString(0, OBJ_LINE2, OBJPROP_TEXT, line2Text);
      ObjectSetInteger(0, OBJ_LINE2, OBJPROP_COLOR, C'140,155,180');
   }

   // Line 4: 止盈止损参数
   {
      int dispLayers = (g_martLayerCount > 0) ? g_martLayerCount : 1;
      double dynamicTP = InpMartBasketTP_USD + (dispLayers - 1) * InpMartBasketTPPerLayer;
      string tpText = (InpMartBasketTP_USD <= 0.0) ? "不限制" : StringFormat("%.0f美分", dynamicTP);
      string slText = (InpMartHardSL_USD <= 0.0) ? "不限制" : StringFormat("%.0f美分", InpMartHardSL_USD);
      double trailMinProfit = dynamicTP * InpMartTrailMinProfitPerLayer / 100.0;
      string trailText = "";
      if(InpMartTrailPct <= 0.0)
         trailText = "关闭";
      else
         trailText = StringFormat("%.0f%% 门:%.0f(TP×%.0f%%) 峰:%.1f", InpMartTrailPct, trailMinProfit, InpMartTrailMinProfitPerLayer, g_martBasketPeakPnL);
      ObjectSetString(0, OBJ_LINE4, OBJPROP_TEXT,
         StringFormat("TP:%s(%d层)  SL:%s  追踪:%s", tpText, g_martLayerCount, slText, trailText));
      ObjectSetInteger(0, OBJ_LINE4, OBJPROP_COLOR, C'140,155,180');
   }

   // Line 5: 对冲信息
   {
      string hedgeText = "";
      double targetHedgeLot = NormalizeVolume(g_martTotalLots * InpHedgeRatio);
      if(!InpEnableHedge)
         hedgeText = StringFormat("对冲: 已关闭  比例:%.0f%%(%.2f手)  [权益%%:%.1f%%  绝对:%.0f美分]",
            InpHedgeRatio*100, targetHedgeLot, InpHedgeLossPercent, InpHedgeAbsoluteUSD);
      else if(g_hedgeActive)
        {
         double totalPnl = floatingPnl + g_hedgePnl;
         double releaseThreshold = (InpHedgeReleaseMode == HEDGE_RELEASE_FIXED) ? InpHedgeReleaseFixed : g_martLayerCount * InpHedgeReleaseDynPerLayer;
         hedgeText = StringFormat("对冲: 激活中  总浮盈:%.1f(止盈>%.0f)  马丁:%.1f  对冲:%.1f  单数:%d  手数:%.2f",
            totalPnl, releaseThreshold, floatingPnl, g_hedgePnl, g_hedgeCount, g_hedgeLots);
        }
      else
        {
         if(InpHedgeTriggerMode == HEDGE_BY_EQUITY_PCT)
            hedgeText = StringFormat("对冲: 待命  模式:权益%%  触发:浮亏超%.1f%%  比例:%.0f%%(%.2f手)  [绝对:%.0f美分]",
               InpHedgeLossPercent, InpHedgeRatio*100, targetHedgeLot, InpHedgeAbsoluteUSD);
         else
            hedgeText = StringFormat("对冲: 待命  模式:绝对金额  触发:浮亏超%.0f美分  比例:%.0f%%(%.2f手)  [权益:%.1f%%]",
               InpHedgeAbsoluteUSD, InpHedgeRatio*100, targetHedgeLot, InpHedgeLossPercent);
        }
      ObjectSetString(0, OBJ_LINE5, OBJPROP_TEXT, hedgeText);
      ObjectSetInteger(0, OBJ_LINE5, OBJPROP_COLOR, g_hedgeActive ? C'255,200,60' : C'140,155,180');
   }

   // Line 3: 不建仓原因
   int line3Y = g_panelY + 250 + 5 * 20;
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
      ObjectSetInteger(0, OBJ_LINE3, OBJPROP_YDISTANCE, -9999);
     }

   ChartRedraw(0);
  }

//===== 历史记录系统 =====

void RecordTradeToHistory(double closedLots, double closedPnl)
  {
   if(g_isTester) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   string today = StringFormat("%02d-%02d", dt.mon, dt.day);

   LoadHistoryFromFile();

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
      g_historyCount++;
      ArrayResize(g_historyRecords, g_historyCount);
      todayIdx = g_historyCount - 1;
      g_historyRecords[todayIdx].date        = today;
      g_historyRecords[todayIdx].totalLots   = 0;
      g_historyRecords[todayIdx].maxLot      = 0;
      g_historyRecords[todayIdx].tradeCount  = 0;
      g_historyRecords[todayIdx].pnl         = 0;
      g_historyRecords[todayIdx].maxDrawdown = 0;
      g_historyRecords[todayIdx].maxDDPct    = 0;
     }

   g_historyRecords[todayIdx].totalLots += closedLots;
   if(closedLots > g_historyRecords[todayIdx].maxLot)
      g_historyRecords[todayIdx].maxLot = closedLots;
   g_historyRecords[todayIdx].tradeCount++;
   g_historyRecords[todayIdx].pnl += closedPnl;
   g_historyRecords[todayIdx].balance = bal;

   if(g_todayMaxDrawdown > g_historyRecords[todayIdx].maxDrawdown)
      g_historyRecords[todayIdx].maxDrawdown = g_todayMaxDrawdown;
   if(g_todayMaxDDPct > g_historyRecords[todayIdx].maxDDPct)
      g_historyRecords[todayIdx].maxDDPct = g_todayMaxDDPct;

   if(bal > 0)
      g_historyRecords[todayIdx].pnlRatio = g_historyRecords[todayIdx].pnl / bal * 100.0;

   while(g_historyCount > InpHistoryDays)
     {
      for(int i = 0; i < g_historyCount - 1; i++)
         g_historyRecords[i] = g_historyRecords[i+1];
      g_historyCount--;
      ArrayResize(g_historyRecords, g_historyCount);
     }

   SaveHistoryToFile();
  }

void SaveHistoryToFile()
  {
   int handle = FileOpen(HISTORY_FILE_NAME, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle == INVALID_HANDLE) return;

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
   if(g_isTester) return;

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

      g_historyRecords[idx].date        = dateStr;
      g_historyRecords[idx].totalLots   = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxLot      = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].tradeCount  = (int)StringToInteger(FileReadString(handle));
      g_historyRecords[idx].pnl         = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].pnlRatio    = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].balance     = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxDrawdown = StringToDouble(FileReadString(handle));
      g_historyRecords[idx].maxDDPct    = StringToDouble(FileReadString(handle));
     }
   FileClose(handle);

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

   ObjectsDeleteAll(0, "HYB_HIST_");

   int panelWidth  = 750;
   int rowHeight   = 20;
   int headerHeight = 25;
   int rows        = g_historyCount + 3;
   int panelHeight = rows * rowHeight + 10;

   int margin = 10;
   int startY = 10;
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int startX = chartW - panelWidth - margin;
   if(startX < 0) startX = 0;

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

   CreateHistLabel("HYB_HIST_TITLE", panelWidth - 20, y, "EUR网格 历史交易明细", C'200,210,230', 10);
   CreateHistLabel("HYB_HIST_CLOSE", 25, y, "X", C'255,160,60', 10);
   y += headerHeight;

   string headers[] = {"日期", "手数", "最大手", "次数", "盈亏", "盈亏比", "余额", "最大浮亏", "最大浮亏比"};
   int colX[] = {panelWidth-20, panelWidth-80, panelWidth-140, panelWidth-200, panelWidth-255,
                 panelWidth-330, panelWidth-410, panelWidth-490, panelWidth-580};

   for(int c = 0; c < 9; c++)
     {
      string name = "HYB_HIST_HDR_" + IntegerToString(c);
      CreateHistLabel(name, colX[c], y, headers[c], C'140,155,180', 9);
     }
   y += rowHeight;

   for(int i = g_historyCount - 1; i >= 0; i--)
     {
      string rowPrefix = "HYB_HIST_R" + IntegerToString(g_historyCount - 1 - i) + "_";
      color pnlClr = (g_historyRecords[i].pnl >= 0) ? C'80,200,120' : C'255,80,80';
      color ddClr  = C'255,80,80';

      CreateHistLabel(rowPrefix + "0", colX[0], y, g_historyRecords[i].date, C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "1", colX[1], y, DoubleToString(g_historyRecords[i].totalLots, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "2", colX[2], y, DoubleToString(g_historyRecords[i].maxLot, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "3", colX[3], y, IntegerToString(g_historyRecords[i].tradeCount), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "4", colX[4], y, StringFormat("%+.2f", g_historyRecords[i].pnl), pnlClr, 9);
      CreateHistLabel(rowPrefix + "5", colX[5], y, DoubleToString(g_historyRecords[i].pnlRatio, 2) + "%", pnlClr, 9);
      CreateHistLabel(rowPrefix + "6", colX[6], y, DoubleToString(g_historyRecords[i].balance, 2), C'200,210,230', 9);
      CreateHistLabel(rowPrefix + "7", colX[7], y, StringFormat("-%.2f", g_historyRecords[i].maxDrawdown), ddClr, 9);
      CreateHistLabel(rowPrefix + "8", colX[8], y, DoubleToString(g_historyRecords[i].maxDDPct, 2) + "%", ddClr, 9);
      y += rowHeight;
     }

   // 汇总行
   double sumLots = 0, sumPnl = 0;
   int sumCount = 0;
   for(int i = 0; i < g_historyCount; i++)
     {
      sumLots  += g_historyRecords[i].totalLots;
      sumCount += g_historyRecords[i].tradeCount;
      sumPnl   += g_historyRecords[i].pnl;
     }
   double latestBal  = (g_historyCount > 0) ? g_historyRecords[g_historyCount-1].balance : AccountInfoDouble(ACCOUNT_BALANCE);
   double sumRatio   = (latestBal > 0) ? sumPnl / latestBal * 100.0 : 0.0;
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

void UpdateHistoryPanel()
  {
   if(g_isTester) return;
   if(!g_historyPanelVisible) return;
   DestroyHistoryPanel();
   CreateHistoryPanel();
  }
