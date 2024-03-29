//+------------------------------------------------------------------+
//|                                                  SignalTrend.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.0"

#property indicator_chart_window 
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  Red
#property indicator_width1  1
#property indicator_label1  "Sell Signal"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  Blue
#property indicator_width2  1
#property indicator_label2 "Buy Signal"

input int      iADXPeriod = 29;        // (ADX) Período
input double   iADXMin = 11.4;         // (ADX) Força mínima de tendência
input double   iADXMax = 79.6;         // (ADX) Força máxima de tendência
input int      iATRPeriod = 44;        // (ATR) Período
input int      iATRMin = 68;           // (ATR) Probabilidade mínima de reversão
input int      iMAFastPeriod = 33;     // (EMA) Período rápido
input int      iMASlowPeriod = 35;     // (EMA) Período lento

double sellBuffer[];
double buyBuffer[];

int candleMargin;
int period;
int startBars;
int maFastHandle;
int maSlowHandle;
int atrHandle;
int adxHandle;
int newSignal;
int oldSignal;

void OnInit() {
   if (iADXPeriod > iATRPeriod && iADXPeriod > iMASlowPeriod) {
      period = iADXPeriod;
      startBars = iADXPeriod + 1;
   } else if (iATRPeriod > iADXPeriod && iATRPeriod > iMASlowPeriod) {
      period = iATRPeriod;
      startBars = iATRPeriod + 1;
   } else {
      period = iMASlowPeriod;
      startBars = iMASlowPeriod + 1;
   }
   
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, iATRPeriod);
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, iADXPeriod);
   maFastHandle = iMA(_Symbol, PERIOD_CURRENT, iMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandle = iMA(_Symbol, PERIOD_CURRENT, iMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if (atrHandle == INVALID_HANDLE) Print("Não foi possível criar o handle do ATR!");   
   if (adxHandle == INVALID_HANDLE) Print("Não foi possível criar o handle do ADX!");
   if (maFastHandle == INVALID_HANDLE) Print("Não foi possível criar o handle da média móvel rápida!");
   if (maSlowHandle == INVALID_HANDLE) Print("Não foi possível criar o handle da média móvel lenta!");

   candleMargin = 75;

   SetIndexBuffer(0, sellBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, startBars);
   PlotIndexSetString(0, PLOT_LABEL, "Sell Signal");
   PlotIndexSetInteger(0, PLOT_ARROW, 234);
   
   ArraySetAsSeries(sellBuffer, true);

   SetIndexBuffer(1, buyBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, startBars);
   PlotIndexSetString(1, PLOT_LABEL, "Signal Buy");
   PlotIndexSetInteger(1, PLOT_ARROW, 233);

   ArraySetAsSeries(buyBuffer, true);

   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   IndicatorSetString(INDICATOR_SHORTNAME, "Signal Trend for Buy/Sell");
}

int OnCalculate(const int ratesTotal,
                const int prevCalculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tickVolume[],
                const long &volume[],
                const int &spread[]) {
   if (BarsCalculated(atrHandle) < ratesTotal
      || BarsCalculated(adxHandle) < ratesTotal
      || ratesTotal < startBars) return(0);

   int toCopy;
   int limit;
   int bar;
   double atrVal[];
   double adxVal[];
   double plsDI[];
   double minDI[];
   double maFastVal[];
   double maSlowVal[];

   if (prevCalculated > ratesTotal || prevCalculated <= 0) {
      toCopy = ratesTotal;
      limit = ratesTotal - startBars;
   } else {
      toCopy = ratesTotal - prevCalculated + 1;
      limit = ratesTotal - prevCalculated;
   }

   if (CopyBuffer(atrHandle, 0, 0, toCopy, atrVal) <= 0) return(0);
   if (CopyBuffer(adxHandle, 0, 0, toCopy, adxVal) <= 0) return(0);
   if (CopyBuffer(adxHandle, 1, 0, toCopy, plsDI) <= 0) return(0);
   if (CopyBuffer(adxHandle, 2, 0, toCopy, minDI) <= 0) return(0);
   if (CopyBuffer(maFastHandle, 0, 0, toCopy, maFastVal) <= 0) return(0);
   if (CopyBuffer(maSlowHandle, 0, 0, toCopy, maSlowVal) <= 0) return(0);

   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(adxVal, true);
   ArraySetAsSeries(plsDI, true);
   ArraySetAsSeries(minDI, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(maFastVal, true);
   ArraySetAsSeries(maSlowVal, true);

   newSignal = oldSignal;

   for (bar = limit; bar >= 0; bar--) {
      if (ratesTotal != prevCalculated && bar == 0) oldSignal = newSignal;

      sellBuffer[bar] = 0.0;
      buyBuffer[bar] = 0.0;

      if (buyBuffer[bar + 1] != 0 && buyBuffer[bar + 1] != EMPTY_VALUE) newSignal = 1;
      if (sellBuffer[bar + 1] != 0 && sellBuffer[bar + 1] != EMPTY_VALUE) newSignal = 2;
      
      if (close[bar] > close[bar + period]
         && adxVal[bar] <= iADXMax
         && adxVal[bar] >= iADXMin
         && atrVal[bar] >= iATRMin
         && plsDI[bar] > minDI[bar]
         && maFastVal[bar] > maSlowVal[bar]
         && newSignal != 1) {
         buyBuffer[bar] = low[bar] - candleMargin;
      }
      
      if (close[bar] < close[bar + period]
         && adxVal[bar] <= iADXMax
         && adxVal[bar] >= iADXMin
         && atrVal[bar] >= iATRMin
         && plsDI[bar] < minDI[bar]
         && maFastVal[bar] < maSlowVal[bar]
         && newSignal != 2) {
         sellBuffer[bar] = high[bar] + candleMargin;
      }
   }
   
   return(ratesTotal);
}