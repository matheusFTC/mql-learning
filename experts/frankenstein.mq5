//+------------------------------------------------------------------+
//|                                                     SurferEA.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum PeriodOptions { 
   M1,  // 1 minuto
   M2,  // 2 minutos
   M3,  // 3 minutos
   M5,  // 5 minutos
   M15, // 15 minutos
   CURRENT // Período do gráfico
};

enum ATROptions { 
   TREND,  // Tendência
   PANIC,  // Pânico
   TREND_AND_PANIC // Tendência e pânico
}; 

// Parâmetros de entrada
input PeriodOptions  pPeriodOptions = M1;             // Período dos indicadores 
input int            pStopLoss = 210;                 // Stop Loss
input bool           pStopLossCondition = true;       // Irá stop loss condicional?
input int            pTakeProfit = 585;               // Take Profit
input bool           pUseTrailingStop = false;        // Irá usar stop loss móvel?
input int            pTrailingStop = 35;              // Stop móvel
input bool           pUsePartialExit = false;         // Irá usar saída parcial?
input int            pPartialLot = 2;                 // Pontos de saída parcial
input int            pPartialExit = 110;              // Pontos de saída parcial
input int            pDistance = 180;                 // Distância
input int            pFastMAPeriod = 15;              // Média móvel rápida
input int            pFastMAShift = 1;                // Deslocamento da média móvel rápida
input bool           pUseSlowMA = true;               // Irá usar média móvel lenta
input int            pSlowMAPeriod = 35;              // Média móvel lenta
input int            pSlowMAShift = 10;               // Deslocamento da média móvel lenta
input bool           pUseInflection = false;          // Irá usar ponto de inflexão?
input double         pInflectionPoint = 85.0;         // Ponto de inflexão
input int            pBuyInflectionFirstIndex = 7;    // Índice do maior valor da inflexão para compra
input int            pBuyInflectionSecondIndex = 7;   // Índice do menor valor da inflexão para compra
input int            pSellInflectionFirstIndex = 7;   // Índice do maior valor da inflexão para venda
input int            pSellInflectionSecondIndex = 9;  // Índice do menor valor da inflexão para venda
input int            pNumRates = 10;                  // Número de preços a considerar
input bool           pUseConfirmationCandle = false;  // Irá usar candle de confirmação
input int            pConfirmationCandleIndex = 0;    // Índice do candle de confirmação
input int            pConfirmationMAIndex = 6;        // Índice do preço da média móvel rápida de confirmação
input bool           pUseADX = true;                  // Irá usar o indicador ADX?
input int            pADXPeriod = 9;                  // Período do ADX
input double         pADXMin = 37.0;                  // Valor mínimo do ADX
input bool           pUseATR = true;                  // Irá usar o indicador ATR?
input ATROptions     pATROptions = TREND;             // Modo de uso do ATR 
input int            pATRPeriod = 19;                 // Período do ATR
input int            pATRMax = 141.0;                 // Valor máximo do ATR
input int            pATRPanic = 290.0;               // Valor do ATR para fechar posições
input int            pEAMagic = 67365161;             // EA Magic Number
input int            pLot = 1;                        // Volume
input bool           pUseGainLimit = false;           // Irá usar limitador de ganho diário?
input double         pGainLimit = 200;                // Objetivo de ganho diário
input bool           pUseLossLimit = false;           // Irá usar limitador de perda diária?
input double         pLossLimit = 100;                // Limite de perda diária
input string         pStartTime = "09:10";            // Horário de inicio
input string         pEndTime = "17:00";              // Horário de termino
input string         pCloseTime = "17:30";            // Horário de fechamento

// Variáveis globais
bool buyOpened;
bool sellOpened;
int maFastHandle;
int maSlowHandle;
int adxHandle;
int atrHandle;
double maFastVal[];
double maSlowVal[];
double plsDI[];
double minDI[];
double adxVal[];
double atrVal[];
double openingBalance;

ENUM_TIMEFRAMES period;

MqlDateTime scheduleStart;
MqlDateTime scheduleEnded;
MqlDateTime scheduleClosing;
MqlDateTime scheduleCurrent;
MqlRates rates[];
MqlTick latestPrice;

CTrade trade;

int OnInit() {
   openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   TimeToStruct(StringToTime(pStartTime), scheduleStart);
   TimeToStruct(StringToTime(pEndTime), scheduleEnded);
   TimeToStruct(StringToTime(pCloseTime), scheduleClosing);
   
   if ((scheduleStart.hour > scheduleEnded.hour || (scheduleStart.hour == scheduleEnded.hour
               && scheduleStart.min > scheduleEnded.min))
         || (scheduleEnded.hour > scheduleClosing.hour || (scheduleEnded.hour == scheduleClosing.hour
                     && scheduleEnded.min>scheduleClosing.min))) {
      Alert("Horários invalidos!");
      
      return INIT_FAILED;
   }
   
   switch(pPeriodOptions) { 
      case M1: period = PERIOD_M1; break;
      case M2: period = PERIOD_M2; break; 
      case M3: period = PERIOD_M3; break; 
      case M5: period = PERIOD_M5; break; 
      case M15: period = PERIOD_M15; break;
      default: period = PERIOD_CURRENT; break;
   } 
   
   maFastHandle = iMA(_Symbol, period, pFastMAPeriod, pFastMAShift, MODE_EMA, PRICE_CLOSE);
   
   if (pUseSlowMA) maSlowHandle = iMA(_Symbol, period, pSlowMAPeriod, pSlowMAShift, MODE_EMA, PRICE_CLOSE);
   if (pUseADX) adxHandle = iADX(_Symbol, period, pADXPeriod);
   if (pUseATR) atrHandle = iATR(_Symbol, period, pATRPeriod);
   
   if (maFastHandle == INVALID_HANDLE
      || maSlowHandle == INVALID_HANDLE
      || adxHandle == INVALID_HANDLE
      || atrHandle == INVALID_HANDLE) {
      Alert("Não foi possível criar os handles dos indicadores: ", GetLastError());
      return(INIT_FAILED);
   } else {
      trade.SetExpertMagicNumber(pEAMagic);
      trade.SetDeviationInPoints(10);
      trade.SetTypeFilling(ORDER_FILLING_FOK);
      trade.LogLevel(1); 
      trade.SetAsyncMode(true);
   
      return(INIT_SUCCEEDED);
   }
}

void OnDeinit(const int reason) {
   IndicatorRelease(maFastHandle);
   
   if (pUseSlowMA) IndicatorRelease(maSlowHandle);
   if (pUseADX) IndicatorRelease(adxHandle);
   if (pUseATR) IndicatorRelease(atrHandle);
}

bool IsOpen() {
   TimeToStruct(TimeCurrent(), scheduleCurrent);

   if (scheduleCurrent.hour >= scheduleStart.hour && scheduleCurrent.hour <= scheduleEnded.hour) {
      if (scheduleCurrent.hour == scheduleStart.hour) {
         if (scheduleCurrent.min >= scheduleStart.min) {
            return true;
         } else {
            return false;
         }
      }
      
      if (scheduleCurrent.hour == scheduleEnded.hour) {
         if (scheduleCurrent.min <= scheduleEnded.min) {
            return true;
         } else {
            return false;
         }
      }
      
      return true;
   }
   
   return false;
}

bool IsClose() {
   TimeToStruct(TimeCurrent(), scheduleCurrent);
      
   if (scheduleCurrent.hour >= scheduleClosing.hour) {
      if (scheduleCurrent.hour == scheduleClosing.hour) {
         if (scheduleCurrent.min >= scheduleClosing.min) {
            return true;
         } else {
            return false;
         }
      }
      return true;
   }
   
   return false;
}

bool CheckPosition() {
   buyOpened = false;
   sellOpened = false;
   
   if (PositionSelect(_Symbol)) {
	  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
		 buyOpened = true;
	  } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
		 sellOpened = true;
	  }
	  
	  return(true);
   } else {
	  return(false);
   }
}

bool CheckNewBar() {
   static datetime vOldTime;
   datetime vNewTime[];
   
   bool vIsNewBar = false;
   
   int vCopied = CopyTime(_Symbol, _Period, 0, 1, vNewTime);
   
   if (vCopied > 0) {
      if (vOldTime != vNewTime[0]) {
         vIsNewBar = true;
         vOldTime = vNewTime[0];
      }
   } else {
      Alert("Erro ao obter o histórico de tempo: ", GetLastError());
      
      ResetLastError();
      
      return(false);
   }

   return(vIsNewBar);
}

void ParticalRun() {
   if (CheckPosition()) {
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentVolume = PositionGetDouble(POSITION_VOLUME);
      
      if (currentVolume > 1) {
         if (buyOpened) {
            if (latestPrice.bid - positionPriceOpen > pPartialExit) {
               double price = NormalizeDouble(latestPrice.bid, _Digits);
               double sl = NULL;
               double tp = NULL;
               double volume = pPartialLot;
               
               string comment = StringFormat("Partical Sell %s, %G, Volume: %G"
                  , _Symbol
                  , volume
                  , price);
               
               bool check = trade.Sell(volume, _Symbol, price, sl, tp, comment);
               
               if (check == true && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
                  Alert("Ordem de venda parcial adicionada com sucesso!");
               } else {
                  Alert("Não foi possível realizar a operação de venda parcial. Code: "
                     , trade.ResultRetcode()
                     , " - ", trade.ResultRetcodeDescription());
               }
            }
         } else {
            if (positionPriceOpen - latestPrice.ask > pPartialExit) {
               double price = NormalizeDouble(latestPrice.ask, _Digits);
               double sl = NULL;
               double tp = NULL;
               double volume = pPartialLot;
               
               string comment = StringFormat("Partical Buy %s, %G, Volume: %G"
                  , _Symbol
                  , volume
                  , price);
               
               bool check = trade.Buy(volume, _Symbol, price, sl, tp, comment);
      
               if (check == true && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
                  Alert("Ordem de compra parcial adicionada com sucesso!");
               } else {
                  Alert("Não foi possível realizar a operação de compra parcial. Code: "
                     , trade.ResultRetcode()
                     , " - ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

void MoveStopLoss() {
   if (CheckPosition()) {
      bool modify = false;
      double newSl = NULL;
      
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      
      if (buyOpened) {
         if ((latestPrice.bid - positionPriceOpen) > (Point() * pTrailingStop)) {
            if (positionSl < (latestPrice.bid - Point() * pTrailingStop)) {
               newSl = latestPrice.bid - Point() * pTrailingStop;
               
               if (!trade.PositionModify(_Symbol, newSl, positionTp)) {
                  Alert("(Buy) Não foi possível ajustar o stop loss: "
                     , trade.ResultRetcode()
                     , ". Code Desc.: "
                     , trade.ResultRetcodeDescription());
               } else {
                  Alert("(Buy) Stop loss ajustado com sucesso: "
                     , positionSl
                     , " --> "
                     , newSl
                     , " - Code: "
                     , trade.ResultRetcode()
                     , " ("
                     , trade.ResultRetcodeDescription()
                     , ")");
               }
            }
         }   
      } else {
         if ((positionPriceOpen - latestPrice.ask) > (Point() * pTrailingStop)){
            if (positionSl > (latestPrice.ask + Point() * pTrailingStop)) {
               newSl = latestPrice.ask + Point() * pTrailingStop;
               
               if (!trade.PositionModify(_Symbol, newSl, positionTp)) {
                  Alert("(Sell) Não foi possível ajustar o stop loss: "
                     , trade.ResultRetcode()
                     , ". Code Desc.: "
                     , trade.ResultRetcodeDescription());
               } else {
                  Alert("(Sell) Stop loss ajustado com sucesso: "
                     , positionSl
                     , " --> "
                     , newSl
                     , " - Code: "
                     , trade.ResultRetcode()
                     , " ("
                     , trade.ResultRetcodeDescription()
                     , ")");
               }
            }
         }
      }
   }
}

void PanicATR() {
   if (CheckPosition()) {
   	if (pUseATR && (pATROptions == PANIC || pATROptions == TREND_AND_PANIC) && atrVal[0] >= pATRPanic) {
	      Alert("Fechando posição atual devido a sinalização do ATR...");
   
         trade.PositionClose(_Symbol, 50);
	   }
   }
}

bool CheckLimits() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
   if (pUseGainLimit && balance >= openingBalance + pGainLimit) {
      return(true);
   } else if (pUseLossLimit && balance <= openingBalance - pLossLimit) {
      return(true);
   } else {
      return(false);
   }
}

double MaxHigh() {
   double maxHigh = 0;
   
   for (int i = 0; i < pNumRates; i++) {
      if (rates[i].high > maxHigh) {
         maxHigh = rates[i].high;
      }
   }
   
   return(maxHigh);
}

double MaxLow() {
   double maxLow = 0;
   
   for (int i = 0; i < pNumRates; i++) {
      if (rates[i].low < maxLow) {
         maxLow = rates[i].low;
      }
   }
   
   return(maxLow);
}

void OnTick() {
   if (IsClose()) {
      if (CheckPosition()) {
         Alert("Fechando posição atual devido a fechamento do mercado...");
      
         trade.PositionClose(_Symbol, 50);
      }
      
      openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   if (IsOpen() && !CheckLimits()) {
      if (!CheckNewBar()) return;
      if (Bars(_Symbol, period) < 60) return;
      
      if (!SymbolInfoTick(_Symbol, latestPrice)) {
         Alert("Erro ao copiar o último preço: ", GetLastError());
         return;
      }
      
      if (CopyRates(_Symbol, _Period, 0, pNumRates, rates) != pNumRates) {
         Alert("Erro ao copiar o histórico de tempos: ", GetLastError(), "!");
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(rates, true);
      
      if (CopyBuffer(maFastHandle, 0, 0, pNumRates, maFastVal) != pNumRates) {
         Alert("Erro ao copiar o buffer da média móvel rápida: ", GetLastError());
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(maFastVal, true);
      
      if (pUseSlowMA) {
         if (CopyBuffer(maSlowHandle, 0, 0, pNumRates, maSlowVal) != pNumRates) {
            Alert("Erro ao copiar o buffer da média móvel lenta: ", GetLastError());
            ResetLastError();
            return;
         }
         
         ArraySetAsSeries(maSlowVal, true);
      }
      
      if (pUseADX) {
         if (CopyBuffer(adxHandle, 0, 0, 1, adxVal) != 1
            || CopyBuffer(adxHandle, 1, 0, 1, plsDI) != 1
            || CopyBuffer(adxHandle, 2, 0, 1, minDI) != 1) {
            Alert("Erro ao copiar o buffer do ADX: ", GetLastError());
            ResetLastError();
            return;
         }
         
         ArraySetAsSeries(adxVal, true);
         ArraySetAsSeries(plsDI, true);
         ArraySetAsSeries(minDI, true);
      }
      
      if (pUseATR) {
         if (CopyBuffer(atrHandle, 0, 0, 1, atrVal) != 1) {
            Alert("Erro ao copiar o buffer do ATR: ", GetLastError());
            ResetLastError();
            return;
         }
         
         ArraySetAsSeries(atrVal, true);
      }
   	
   	if (pUseATR) PanicATR();
	   if (pUseTrailingStop) MoveStopLoss();
   	if (pUsePartialExit) ParticalRun();
      
      double confirmationCandle = pUseConfirmationCandle ? rates[pConfirmationCandleIndex].close : NULL;
      
      bool buyMAFastCondition = true;
      
      for (int i = 0; i < pNumRates; i++) {
         if (buyMAFastCondition && (i + 1) < pNumRates) {
            buyMAFastCondition = maFastVal[i] > maFastVal[i + 1];
         } else {
            break;
         }
      }
      
      double buyFastInflection = pUseInflection ? (maFastVal[pBuyInflectionFirstIndex] / maFastVal[pBuyInflectionSecondIndex]) * 100 : NULL;
      
      bool buyMASlowCondition = true;
      double buySlowInflection = NULL;
      
      if (pUseSlowMA) {
         for (int i = 0; i < pNumRates; i++) {
            if (buyMASlowCondition && (i + 1) < pNumRates) {
               buyMASlowCondition = maSlowVal[i] > maSlowVal[i + 1];
            } else {
               break;
            }
         }
         
         if (pUseInflection) buySlowInflection = (maSlowVal[pBuyInflectionFirstIndex] / maSlowVal[pBuyInflectionSecondIndex]) * 100;
      }
   	
   	bool buyCondition = (buyMAFastCondition && buyMASlowCondition)
   	   && ((latestPrice.ask - pDistance) <= maFastVal[0])
   	   && (pUseInflection ? (buyFastInflection >= pInflectionPoint)  : true)
   	   && (pUseSlowMA && pUseInflection ? (buySlowInflection >= pInflectionPoint)  : true)
         && (pUseConfirmationCandle ? (confirmationCandle > maFastVal[pConfirmationMAIndex]) : true)
   	   && (pUseADX ? (adxVal[0] >= pADXMin && plsDI[0] > minDI[0]) : true)
   	   && (pUseATR && (pATROptions == TREND || pATROptions == TREND_AND_PANIC) ? (atrVal[0] <= pATRMax) : true);
     
      if (buyCondition) {
         if (buyOpened || sellOpened) {
            return;
         } else {
            double maxLow = MaxLow();
            
            double price = NormalizeDouble(latestPrice.ask, _Digits);
            double sl = pStopLossCondition ? (price - pStopLoss < maxLow ? maxLow : price - pStopLoss) : price - pStopLoss;
            double tp = price + pTakeProfit;
            double volume = pUsePartialExit ? (pLot + pPartialLot) : pLot;
            
            string comment = StringFormat("Buy %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
            
            bool check = trade.Buy(volume, _Symbol, price, sl, tp, comment);
   
            if (check == true && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
               Alert("Ordem de compra adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de compra. Code: "
                  , trade.ResultRetcode()
                  , " - ", trade.ResultRetcodeDescription());
            }
         }
      }
      
      bool sellMAFastCondition = true;
      
      for (int i = 0; i < pNumRates; i++) {
         if (buyMAFastCondition) {
            buyMAFastCondition = maFastVal[i] < maFastVal[i + 1];
         } else {
            break;
         }
      }
      
      double sellFastInflection = pUseInflection ? (maFastVal[pSellInflectionFirstIndex] / maFastVal[pSellInflectionSecondIndex]) * 100 : NULL;
      
      bool sellMASlowCondition = true;
      double sellSlowInflection = NULL;
      
      if (pUseSlowMA) {
         for (int i = 0; i < pNumRates; i++) {
            if (buyMASlowCondition) {
               buyMASlowCondition = maSlowVal[i] < maSlowVal[i + 1];
            } else {
               break;
            }
         }
         
         if (pUseInflection) sellSlowInflection = (maSlowVal[pSellInflectionFirstIndex] / maSlowVal[pSellInflectionSecondIndex]) * 100;
      }
      
      bool sellCondition = (sellMAFastCondition && sellMASlowCondition)
         && ((latestPrice.bid + pDistance) >= maFastVal[0])
         && (pUseInflection ? (sellFastInflection >= pInflectionPoint && sellSlowInflection >= pInflectionPoint) : true)
   	   && (pUseConfirmationCandle ? (confirmationCandle < maFastVal[pConfirmationMAIndex]) : true)
   	   && (pUseADX ? (adxVal[0] >= pADXMin && plsDI[0] < minDI[0]) :  true)
   	   && (pUseATR && (pATROptions == TREND || pATROptions == TREND_AND_PANIC) ? (atrVal[0] <= pATRMax) : true);
   
      if (sellCondition) {
         if (buyOpened || sellOpened) {
            return;
         } else {
            double maxHigh = MaxHigh();
            
            double price = NormalizeDouble(latestPrice.bid, _Digits);
            double sl = pStopLossCondition ? (price + pStopLoss > maxHigh ? maxHigh : price + pStopLoss) : price + pStopLoss;
            double tp = price - pTakeProfit;
            double volume = pUsePartialExit ? (pLot + pPartialLot) : pLot;
            
            string comment = StringFormat("Sell %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
            
            bool check = trade.Sell(volume, _Symbol, price, sl, tp, comment);
            
            if (check == true && (trade.ResultRetcode() == TRADE_RETCODE_DONE || trade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
               Alert("Ordem de venda adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de venda. Code: "
                  , trade.ResultRetcode()
                  , " - ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}
