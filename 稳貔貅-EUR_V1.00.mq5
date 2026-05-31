#property copyright "Golden Pixiu EA"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

enum GRID_DIR
  {
   GRID_NONE = 0,
   GRID_BUY  = 1,
   GRID_SELL = -1
  };

input group "=== 基础设置 ==="
input string          InpPresetName            = "稳貔貅EUR轻网格";
input long            InpMagicNumber           = 26053101;
input string          InpTradeSymbol           = "EURUSDc";

input group "=== 时间与新闻过滤（北京时间） ==="
input int             InpChinaUtcOffsetHours   = 8;
input bool            InpEnableNewsFilter      = true;
input bool            InpNewsBlockThu2030      = true;
input bool            InpNewsBlockFirstFri2030 = true;
input bool            InpAutoUsDstNewsTime     = true;
input int             InpNewsDataHour          = 20;
input int             InpNewsDataMinute        = 30;
input int             InpNewsBlockPreMinutes   = 10;
input int             InpNewsBlockPostMinutes  = 40;
input bool            InpUseManualNewsBlock    = false;
input int             InpNewsBlockStartHour    = 20;
input int             InpNewsBlockStartMinute  = 20;
input int             InpNewsBlockEndHour      = 21;
input int             InpNewsBlockEndMinute    = 10;
input int             InpTradeStartHour        = 7;
input int             InpTradeEndHour          = 23;

input group "=== 风控 ==="
input int             InpMaxSpreadPoints       = 35;
input double          InpMaxDailyLossPercent   = 20.0;
input double          InpBasketHardSL          = 800.0;
input int             InpCooldownSec           = 300;

input group "=== 轻网格 ==="
input double          InpBaseLot               = 0.01;
input bool            InpUseEquityLot          = false;
input double          InpLotPer1000Equity      = 0.01;
input double          InpLotMultiplier         = 1.05;
input int             InpMaxLayers             = 6;
input double          InpMaxTotalLots          = 0.20;
input double          InpATRSpacingMult        = 0.65;
input int             InpMinSpacingPoints      = 120;
input double          InpBasketTP              = 120.0;
input double          InpBasketTPPerLayer      = 35.0;

input group "=== 入场过滤 ==="
input ENUM_TIMEFRAMES InpTrendTF               = PERIOD_H1;
input ENUM_TIMEFRAMES InpEntryTF               = PERIOD_M15;
input int             InpEmaFast               = 50;
input int             InpEmaSlow               = 200;
input int             InpEntryEma              = 20;
input int             InpATRPeriod             = 14;
input int             InpADXPeriod             = 14;
input double          InpMaxADX                = 28.0;
input int             InpRSIPeriod             = 14;
input double          InpBuyRsiMin             = 38.0;
input double          InpBuyRsiMax             = 62.0;
input double          InpSellRsiMin            = 38.0;
input double          InpSellRsiMax            = 62.0;

input group "=== 面板 ==="
input bool            InpShowPanel             = true;
input int             InpPanelX                = 8;
input int             InpPanelY                = 20;

CTrade g_trade;

int g_hEmaFast = INVALID_HANDLE;
int g_hEmaSlow = INVALID_HANDLE;
int g_hEntryEma = INVALID_HANDLE;
int g_hATR = INVALID_HANDLE;
int g_hADX = INVALID_HANDLE;
int g_hRSI = INVALID_HANDLE;

GRID_DIR g_dir = GRID_NONE;
int      g_layers = 0;
double   g_totalLots = 0.0;
double   g_floatPnl = 0.0;
double   g_highestPrice = 0.0;
double   g_lowestPrice = DBL_MAX;
datetime g_lastCloseTime = 0;
bool     g_dailyLocked = false;
int      g_dayKey = -1;
double   g_dayStartEquity = 0.0;
string   g_noEntryReason = "";
bool     g_panelCreated = false;

string OBJ_PREFIX = "WPX_EUR_";

datetime GetChinaNow()
  {
   return TimeGMT() + InpChinaUtcOffsetHours * 3600;
  }

bool IsManagedSymbol(const string sym)
  {
   string s = sym;
   string t = InpTradeSymbol;
   StringToUpper(s);
   StringToUpper(t);
   return (s == t || StringFind(s, "EURUSD") == 0);
  }

double BufVal(const int handle, const int buffer, const int shift)
  {
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyBuffer(handle, buffer, shift, 1, arr) != 1)
      return 0.0;
   return arr[0];
  }

double CloseVal(const ENUM_TIMEFRAMES tf, const int shift)
  {
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyClose(_Symbol, tf, shift, 1, arr) != 1)
      return 0.0;
   return arr[0];
  }

double HighVal(const ENUM_TIMEFRAMES tf, const int shift)
  {
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyHigh(_Symbol, tf, shift, 1, arr) != 1)
      return 0.0;
   return arr[0];
  }

double LowVal(const ENUM_TIMEFRAMES tf, const int shift)
  {
   double arr[];
   ArraySetAsSeries(arr, true);
   if(CopyLow(_Symbol, tf, shift, 1, arr) != 1)
      return 0.0;
   return arr[0];
  }

int DayKey()
  {
   MqlDateTime t;
   TimeToStruct(GetChinaNow(), t);
   return t.year * 10000 + t.mon * 100 + t.day;
  }

void ResetDailyState()
  {
   int key = DayKey();
   if(key == g_dayKey)
      return;
   g_dayKey = key;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dailyLocked = false;
  }

double NormalizeLot(double lot)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return MathFloor(lot / step + 0.5) * step;
  }

double BaseLot()
  {
   if(!InpUseEquityLot)
      return NormalizeLot(InpBaseLot);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return NormalizeLot(MathMax(InpBaseLot, eq / 1000.0 * InpLotPer1000Equity));
  }

bool SpreadBlocked()
  {
   if(InpMaxSpreadPoints <= 0) return false;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0) return true;
   return ((ask - bid) / _Point > InpMaxSpreadPoints);
  }

bool InTradeSession()
  {
   if(InpTradeStartHour == InpTradeEndHour) return true;
   MqlDateTime t;
   TimeToStruct(GetChinaNow(), t);
   int h = t.hour;
   if(InpTradeStartHour < InpTradeEndHour)
      return (h >= InpTradeStartHour && h < InpTradeEndHour);
   return (h >= InpTradeStartHour || h < InpTradeEndHour);
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
   if(startM == endM) return false;
   if(startM < endM) return (nowM >= startM && nowM < endM);
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

int Us0830MinuteBeijing(const MqlDateTime &chinaTime)
  {
   if(!InpAutoUsDstNewsTime)
      return InpNewsDataHour * 60 + InpNewsDataMinute;
   int m = chinaTime.mon;
   int d = chinaTime.day;
   int secondSundayMarch = NthSundayOfMonth(chinaTime.year, 3, 2);
   int firstSundayNovember = NthSundayOfMonth(chinaTime.year, 11, 1);
   bool dst = false;
   if(m > 3 && m < 11) dst = true;
   else if(m == 3 && d >= secondSundayMarch) dst = true;
   else if(m == 11 && d < firstSundayNovember) dst = true;
   return (dst ? 20 : 21) * 60 + 30;
  }

string NewsReason()
  {
   if(!InpEnableNewsFilter && !InpUseManualNewsBlock)
      return "";
   MqlDateTime t;
   TimeToStruct(GetChinaNow(), t);
   int nowMinute = t.hour * 60 + t.min;
   int pre = MathMax(0, InpNewsBlockPreMinutes);
   int post = MathMax(0, InpNewsBlockPostMinutes);
   int dataMinute = Us0830MinuteBeijing(t);
   if(InpEnableNewsFilter)
     {
      if(InpNewsBlockThu2030 && t.day_of_week == 4 && IsMinuteInWindow(nowMinute, dataMinute - pre, dataMinute + post))
         return "新闻过滤:周四数据";
      if(InpNewsBlockFirstFri2030 && t.day_of_week == 5 && t.day <= 7 && IsMinuteInWindow(nowMinute, dataMinute - pre, dataMinute + post))
         return "新闻过滤:非农";
     }
   if(InpUseManualNewsBlock)
     {
      int startM = InpNewsBlockStartHour * 60 + InpNewsBlockStartMinute;
      int endM = InpNewsBlockEndHour * 60 + InpNewsBlockEndMinute;
      if(IsMinuteInWindow(nowMinute, startM, endM))
         return "新闻过滤:自定义";
     }
   return "";
  }

void RefreshBasket()
  {
   g_dir = GRID_NONE;
   g_layers = 0;
   g_totalLots = 0.0;
   g_floatPnl = 0.0;
   g_highestPrice = 0.0;
   g_lowestPrice = DBL_MAX;
   int buys = 0, sells = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      g_layers++;
      double lot = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      g_totalLots += lot;
      g_floatPnl += PositionGetDouble(POSITION_PROFIT);
      if(open > g_highestPrice) g_highestPrice = open;
      if(open < g_lowestPrice) g_lowestPrice = open;
      if(type == POSITION_TYPE_BUY) buys++;
      if(type == POSITION_TYPE_SELL) sells++;
     }
   if(buys > 0 && sells == 0) g_dir = GRID_BUY;
   else if(sells > 0 && buys == 0) g_dir = GRID_SELL;
   if(g_layers == 0) g_lowestPrice = 0.0;
  }

void CloseAll()
  {
   bool closed = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(!IsManagedSymbol(PositionGetString(POSITION_SYMBOL))) continue;
      if(g_trade.PositionClose(ticket)) closed = true;
     }
   if(closed) g_lastCloseTime = TimeCurrent();
  }

double BasketTarget()
  {
   int layers = MathMax(1, g_layers);
   return InpBasketTP + (layers - 1) * InpBasketTPPerLayer;
  }

void ManageRisk()
  {
   RefreshBasket();
   if(g_layers <= 0) return;
   double target = BasketTarget();
   if(g_floatPnl >= target)
     {
      PrintFormat("[稳貔貅EUR] 篮子止盈 %.2f >= %.2f, layers=%d", g_floatPnl, target, g_layers);
      CloseAll();
      return;
     }
   if(InpBasketHardSL > 0.0 && g_floatPnl <= -InpBasketHardSL)
     {
      PrintFormat("[稳貔貅EUR] 篮子硬止损 %.2f <= -%.2f", g_floatPnl, InpBasketHardSL);
      CloseAll();
      g_dailyLocked = true;
     }
  }

GRID_DIR EntrySignal()
  {
   double emaFast = BufVal(g_hEmaFast, 0, 1);
   double emaSlow = BufVal(g_hEmaSlow, 0, 1);
   double h1Close = CloseVal(InpTrendTF, 1);
   double entryEma = BufVal(g_hEntryEma, 0, 1);
   double atr = BufVal(g_hATR, 0, 1);
   double adx = BufVal(g_hADX, 0, 1);
   double rsi = BufVal(g_hRSI, 0, 1);
   double c = CloseVal(InpEntryTF, 1);
   double h = HighVal(InpEntryTF, 1);
   double l = LowVal(InpEntryTF, 1);

   if(emaFast <= 0.0 || emaSlow <= 0.0 || entryEma <= 0.0 || atr <= 0.0 || c <= 0.0)
     {
      g_noEntryReason = "指标未就绪";
      return GRID_NONE;
     }
   if(adx > InpMaxADX)
     {
      g_noEntryReason = "ADX过高";
      return GRID_NONE;
     }

   bool upTrend = (h1Close > emaFast && emaFast > emaSlow);
   bool downTrend = (h1Close < emaFast && emaFast < emaSlow);
   if(upTrend && c > entryEma && l <= entryEma + atr * 0.25 && rsi >= InpBuyRsiMin && rsi <= InpBuyRsiMax)
      return GRID_BUY;
   if(downTrend && c < entryEma && h >= entryEma - atr * 0.25 && rsi >= InpSellRsiMin && rsi <= InpSellRsiMax)
      return GRID_SELL;

   g_noEntryReason = "等待趋势回撤";
   return GRID_NONE;
  }

bool PlaceOrder(const GRID_DIR dir, const double lot, const string comment)
  {
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(20);
   if(dir == GRID_BUY)
      return g_trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, comment);
   if(dir == GRID_SELL)
      return g_trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, comment);
   return false;
  }

void TryEntry()
  {
   if(g_layers > 0) return;
   if(TimeCurrent() - g_lastCloseTime < InpCooldownSec)
     {
      g_noEntryReason = "冷却中";
      return;
     }
   GRID_DIR sig = EntrySignal();
   if(sig == GRID_NONE) return;
   double lot = BaseLot();
   if(PlaceOrder(sig, lot, "WPX_EUR_L1"))
      PrintFormat("[稳貔貅EUR] 首单 %s %.2f", sig == GRID_BUY ? "BUY" : "SELL", lot);
  }

void TryAddLayer()
  {
   if(g_layers <= 0 || g_layers >= InpMaxLayers) return;
   double atr = BufVal(g_hATR, 0, 1);
   if(atr <= 0.0) return;
   double spacing = MathMax(InpMinSpacingPoints * _Point, atr * InpATRSpacingMult);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool add = false;
   if(g_dir == GRID_BUY)
      add = (g_lowestPrice - ask >= spacing);
   else if(g_dir == GRID_SELL)
      add = (bid - g_highestPrice >= spacing);
   if(!add) return;

   double lot = NormalizeLot(BaseLot() * MathPow(InpLotMultiplier, g_layers));
   if(InpMaxTotalLots > 0.0 && g_totalLots + lot > InpMaxTotalLots)
     {
      g_noEntryReason = "总手数上限";
      return;
     }
   string cmt = "WPX_EUR_L" + IntegerToString(g_layers + 1);
   if(PlaceOrder(g_dir, lot, cmt))
      PrintFormat("[稳貔貅EUR] 加层 %d lot=%.2f spacing=%.0f点", g_layers + 1, lot, spacing / _Point);
  }

bool Blocking()
  {
   if(g_dailyLocked)
     {
      g_noEntryReason = "日亏锁定";
      return true;
     }
   if(SpreadBlocked())
     {
      g_noEntryReason = "点差过大";
      return true;
     }
   if(!InTradeSession())
     {
      g_noEntryReason = "非交易时段";
      return true;
     }
   string news = NewsReason();
   if(news != "")
     {
      g_noEntryReason = news;
      return true;
     }
   g_noEntryReason = "";
   return false;
  }

void CreateLabel(const string name, const int x, const int y, const int size, const color clr)
  {
   string obj = OBJ_PREFIX + name;
   if(ObjectFind(0, obj) < 0)
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, obj, OBJPROP_FONT, "Microsoft YaHei UI");
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, obj, OBJPROP_HIDDEN, true);
  }

void CreatePanel()
  {
   string bg = OBJ_PREFIX + "BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 560);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 238);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'15,18,24');
   ObjectSetInteger(0, bg, OBJPROP_COLOR, C'184,136,45');
   ObjectSetInteger(0, bg, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);

   CreateLabel("TITLE", InpPanelX + 18, InpPanelY + 14, 15, C'255,219,125');
   CreateLabel("SUB",   InpPanelX + 20, InpPanelY + 42, 9,  C'180,142,76');
   for(int i = 0; i < 7; ++i)
      CreateLabel("L" + IntegerToString(i), InpPanelX + 18, InpPanelY + 72 + i * 22, 9, C'185,196,210');
   g_panelCreated = true;
  }

void SetText(const string name, const string text, const color clr = clrNONE)
  {
   string obj = OBJ_PREFIX + name;
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   if(clr != clrNONE)
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
  }

void UpdatePanel()
  {
   if(!InpShowPanel) return;
   if(!g_panelCreated) CreatePanel();
   double adx = BufVal(g_hADX, 0, 1);
   double atr = BufVal(g_hATR, 0, 1);
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   string dir = (g_dir == GRID_BUY ? "BUY" : (g_dir == GRID_SELL ? "SELL" : "NONE"));
   double ddPct = 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartEquity > 0.0)
      ddPct = MathMax(0.0, (g_dayStartEquity - eq) / g_dayStartEquity * 100.0);

   SetText("TITLE", "稳貔貅 EUR v1.00");
   SetText("SUB", "EURUSDc Light Grid / H1 Trend Pullback");
   SetText("L0", StringFormat("账户: %.2f  权益: %.2f  日回撤: %.2f%%/%.1f%%", AccountInfoDouble(ACCOUNT_BALANCE), eq, ddPct, InpMaxDailyLossPercent));
   SetText("L1", StringFormat("篮子: %s  层数:%d/%d  手数:%.2f/%.2f  浮盈:%.2f", dir, g_layers, InpMaxLayers, g_totalLots, InpMaxTotalLots, g_floatPnl));
   SetText("L2", StringFormat("TP: %.0f  SL: %.0f  冷却:%ds", BasketTarget(), InpBasketHardSL, InpCooldownSec));
   SetText("L3", StringFormat("ATR: %.1f点  间距: max(%.0f点, ATR×%.2f)  ADX: %.1f/%.1f", atr / _Point, (double)InpMinSpacingPoints, InpATRSpacingMult, adx, InpMaxADX));
   SetText("L4", StringFormat("过滤: 点差 %.0f/%d  新闻:%s  时段:%02d-%02d", spread, InpMaxSpreadPoints, NewsReason() == "" ? "OK" : NewsReason(), InpTradeStartHour, InpTradeEndHour));
   SetText("L5", "信号: H1 EMA50/200趋势 + M15 EMA20回撤 + RSI区间");
   SetText("L6", g_noEntryReason == "" ? "状态: 运行中" : "状态: " + g_noEntryReason, g_noEntryReason == "" ? C'120,220,150' : C'255,190,80');
  }

int OnInit()
  {
   if(!IsManagedSymbol(_Symbol))
     {
      Print("稳貔貅EUR只支持 EURUSDc/EURUSD 系列，当前: ", _Symbol);
      return INIT_FAILED;
     }
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_hEmaFast = iMA(_Symbol, InpTrendTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlow = iMA(_Symbol, InpTrendTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_hEntryEma = iMA(_Symbol, InpEntryTF, InpEntryEma, 0, MODE_EMA, PRICE_CLOSE);
   g_hATR = iATR(_Symbol, InpEntryTF, InpATRPeriod);
   g_hADX = iADX(_Symbol, InpEntryTF, InpADXPeriod);
   g_hRSI = iRSI(_Symbol, InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
   if(g_hEmaFast == INVALID_HANDLE || g_hEmaSlow == INVALID_HANDLE || g_hEntryEma == INVALID_HANDLE ||
      g_hATR == INVALID_HANDLE || g_hADX == INVALID_HANDLE || g_hRSI == INVALID_HANDLE)
      return INIT_FAILED;
   ResetDailyState();
   EventSetTimer(2);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_hEmaFast != INVALID_HANDLE) IndicatorRelease(g_hEmaFast);
   if(g_hEmaSlow != INVALID_HANDLE) IndicatorRelease(g_hEmaSlow);
   if(g_hEntryEma != INVALID_HANDLE) IndicatorRelease(g_hEntryEma);
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hADX != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hRSI != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   ObjectsDeleteAll(0, OBJ_PREFIX);
  }

void OnTimer()
  {
   RefreshBasket();
   UpdatePanel();
  }

void OnTick()
  {
   ResetDailyState();
   RefreshBasket();
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartEquity > 0.0 && InpMaxDailyLossPercent > 0.0)
     {
      double ddPct = (g_dayStartEquity - eq) / g_dayStartEquity * 100.0;
      if(ddPct >= InpMaxDailyLossPercent)
        {
         CloseAll();
         g_dailyLocked = true;
        }
     }

   ManageRisk();
   RefreshBasket();

   bool blocked = Blocking();
   if(!blocked)
     {
      if(g_layers == 0)
         TryEntry();
      else
         TryAddLayer();
     }
   UpdatePanel();
  }
