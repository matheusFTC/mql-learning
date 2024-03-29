//+------------------------------------------------------------------+
//|                                                       Signal.mq5 |
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

input int      iPeriod = 14;         // Período
input double   iMinStrength = 20.0;  // Força mínima

double sellBuffer[];
double buyBuffer[];

int startBars;
int atrHandle;
int adxHandle;
int ltr;
int ltr_;

void OnInit() {
   startBars = iPeriod + 1;

   atrHandle = iATR(NULL, 0, iPeriod);
   adxHandle = iADX(NULL, 0, iPeriod);
   
   if (atrHandle == INVALID_HANDLE) Print("Não foi possível criar o handle do ATR!");   
   if (adxHandle == INVALID_HANDLE) Print("Não foi possível criar o handle do ADX!");

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
   IndicatorSetString(INDICATOR_SHORTNAME, "Buy/Sell Signal (" + IntegerToString(iPeriod) + ")");
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
   if (BarsCalculated(atrHandle) < ratesTotal || BarsCalculated(adxHandle) < ratesTotal || ratesTotal < startBars) return(0);

   int toCopy;
   int limit;
   int bar;
   double atrVal[];
   double adxVal[];
   double plsDI[];
   double minDI[];

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

   ArraySetAsSeries(atrVal, true);
   ArraySetAsSeries(adxVal, true);
   ArraySetAsSeries(plsDI, true);
   ArraySetAsSeries(minDI, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   ltr = ltr_;

   for (bar = limit; bar >= 0; bar--) {
      if (ratesTotal != prevCalculated && bar == 0) ltr_ = ltr;

      sellBuffer[bar] = 0.0;
      buyBuffer[bar] = 0.0;

      if (buyBuffer[bar + 1] != 0 && buyBuffer[bar + 1] != EMPTY_VALUE) ltr = 1;
      if (sellBuffer[bar + 1] != 0 && sellBuffer[bar + 1] != EMPTY_VALUE) ltr = 2;
      
      if (close[bar] > close[bar + iPeriod]
         && adxVal[bar] >= iMinStrength
         && plsDI[bar] > minDI[bar]
         && ltr != 1) {
         buyBuffer[bar] = low[bar] - atrVal[bar] * 0.75;
      }
      
      if (close[bar] < close[bar + iPeriod]
         && adxVal[bar] >= iMinStrength
         && plsDI[bar] < minDI[bar]
         && ltr != 2) {
         sellBuffer[bar] = high[bar] + atrVal[bar] * 0.75;
      }
   }
   
   return(ratesTotal);
}