//+------------------------------------------------------------------+
//|                                                        Trend.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.0"

#include <MovingAverages.mqh>

#property indicator_separate_window
#property indicator_applied_price   PRICE_CLOSE
#property indicator_minimum			-1.4
#property indicator_maximum			+1.4
#property indicator_buffers 	      1
#property indicator_plots   	      1
#property indicator_type1   	      DRAW_HISTOGRAM
#property indicator_color1  	      Black
#property indicator_width1		      2

input int   iMASlowPeriod = 21;     // Período lento
input int   iMAMiddlePeriod = 14;   // Período intermediário
input int   iMAFastPeriod = 9;      // Período rápido

double trendBuffer[];

void OnInit() {
   SetIndexBuffer(0, trendBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, iMASlowPeriod);
   PlotIndexSetString(0, PLOT_LABEL, "Trend");
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Up/Down Trend ("
      + IntegerToString(iMAFastPeriod)
      + ", "
      + IntegerToString(iMAMiddlePeriod)
      + ", "
      + IntegerToString(iMASlowPeriod)
      + ")");
}

int OnCalculate(const int _rates_total,
                const int _prev_calculated,
                const int _begin,
                const double &_price[]) {
   int start;

   if(_rates_total < iMASlowPeriod) {
      return(0);
   }

   if (_prev_calculated == 0) {
      start = iMASlowPeriod;
   } else {
      start = _prev_calculated - 1;
   }
   
   for(int i = start; i <_rates_total; i++) {
      trendBuffer[i] = TrendDetector(i, _price);
   }

   return(_rates_total);
}

int TrendDetector(int _shift, const double &_price[]) {
   double currentMASlow;
   double currentMAMiddle;
   double currentMAFast;
   
   int trendDirection;

   currentMASlow = SimpleMA(_shift, iMASlowPeriod, _price);
   currentMAMiddle = SimpleMA(_shift, iMAMiddlePeriod, _price);
   currentMAFast = SimpleMA(_shift, iMAFastPeriod, _price);

   if(currentMAFast > currentMAMiddle && currentMAMiddle > currentMASlow) {
      trendDirection = 1;
   } else if(currentMAFast < currentMAMiddle && currentMAMiddle < currentMASlow) {
      trendDirection = -1;
   } else {
      trendDirection = 0;
   }

   return(trendDirection);
}