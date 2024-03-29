//+------------------------------------------------------------------+
//|                                                     SurferEA.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

// Parâmetros de entrada
input int            pStopLoss = 235;                 // (Ordem) Stop Loss
input int            pTakeProfit = 150;               // (Ordem) Take Profit
input int            pLot = 1;                        // (Ordem) Volume
input bool           pUseTrailingStop = false;        // (Stop Móvel) Ativar?
input int            pTrailingStop = 35;              // (Stop Móvel) Pontos
input int            pBuyNumRates = 10;               // (Preço) Número de preços a considerar para compra
input int            pSellNumRates = 10;              // (Preço) Número de preços a considerar para venda
input int            pMAPeriod = 7;                   // (Média móvel) Período
input int            pMAShift = 0;                    // (Média móvel) Deslocamento
input ENUM_MA_METHOD pMAMode = MODE_EMA;              // (Média móvel) Tipo
input int            pBuyNumMARates = 15;             // (Média móvel) Número de preços a considerar para compra
input int            pSellNumMARates = 4;             // (Média móvel) Número de preços a considerar para venda
input int            pMaxDistance = 120;              // (Média móvel) Distância máxima
input int            pADXPeriod = 19;                 // (ADX) Período
input double         pADXMin = 30.0;                  // (ADX) Valor mínimo
input int            pATRPeriod = 16;                 // (ATR) Período
input int            pATRMax = 161.0;                 // (ATR) Valor máximo
input bool           pUseGainLimit = false;           // (Limitador) Irá usar limitador de ganho diário?
input double         pGainLimit = 200;                // (Limitador) Objetivo de ganho diário
input bool           pUseLossLimit = true;            // (Limitador) Irá usar limitador de perda diária?
input double         pLossLimit = 100;                // (Limitador) Limite de perda diária
input int            pEAMagic = 67365161;             // EA Magic Number
input string         pStartTime = "09:10";            // Horário de inicio
input string         pEndTime = "17:00";              // Horário de termino
input string         pCloseTime = "17:30";            // Horário de fechamento

// Variáveis globais
bool buyOpened;
bool sellOpened;
int maHandle;
int adxHandle;
int atrHandle;
double maBuyVal[];
double maSellVal[];
double plsDI[];
double minDI[];
double adxVal[];
double atrVal[];
double openingBalance;

MqlTick latestPrice;
MqlRates ratesBuy[];
MqlRates ratesSell[];
MqlDateTime scheduleStart;
MqlDateTime scheduleEnded;
MqlDateTime scheduleClosing;
MqlDateTime scheduleCurrent;

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
   
   maHandle = iMA(_Symbol, PERIOD_CURRENT, pMAPeriod, pMAShift, pMAMode, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, pADXPeriod);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, pATRPeriod);
   
   if (maHandle == INVALID_HANDLE
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
   IndicatorRelease(maHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(atrHandle);
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
   
   int vCopied = CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, vNewTime);
   
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

void MoveStopLoss() {
   if (CheckPosition() && pUseTrailingStop) {
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

void OnTick() {
   if (IsClose()) {
      if (CheckPosition()) {
         Alert("Fechando posição atual devido a fechamento do mercado...");
      
         trade.PositionClose(_Symbol, 50);
      }
      
      openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   if (IsOpen() && !CheckLimits()) {
      if (Bars(_Symbol, PERIOD_CURRENT) < 60) return;
      
      if (!CheckNewBar()) return;
      
      if (!SymbolInfoTick(_Symbol, latestPrice)) {
         Alert("Erro ao copiar o último preço: ", GetLastError());
         return;
      }
      
      if (CopyRates(_Symbol, PERIOD_CURRENT, 0, pBuyNumRates, ratesBuy) != pBuyNumRates) {
         Alert("Erro ao copiar o histórico de tempos: ", GetLastError(), "!");
         ResetLastError();
         return;
      }
      
      if (CopyRates(_Symbol, PERIOD_CURRENT, 0, pSellNumRates, ratesSell) != pSellNumRates) {
         Alert("Erro ao copiar o histórico de tempos: ", GetLastError(), "!");
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(ratesBuy, true);
      ArraySetAsSeries(ratesSell, true);
      
      bool buyRatesCondition = true;
      
      for (int i = 0; i < pBuyNumRates; i++) {
         if (buyRatesCondition && (i + 1) < pBuyNumRates) {
            buyRatesCondition = ratesBuy[i].close > ratesBuy[i + 1].close;
         } else {
            break;
         }
      }
      
      bool sellRatesCondition = true;
      
      for (int i = 0; i < pSellNumRates; i++) {
         if (sellRatesCondition && (i + 1) < pSellNumRates) {
            sellRatesCondition = ratesSell[i].close < ratesSell[i + 1].close;
         } else {
            break;
         }
      }
      
      if (CopyBuffer(maHandle, 0, 0, pBuyNumMARates, maBuyVal) != pBuyNumMARates) {
         Alert("Erro ao copiar o buffer da média móvel para compra: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (CopyBuffer(maHandle, 0, 0, pSellNumMARates, maSellVal) != pSellNumMARates) {
         Alert("Erro ao copiar o buffer da média móvel para venda: ", GetLastError());
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(maBuyVal, true);
      ArraySetAsSeries(maSellVal, true);
      
      bool buyMACondition = true;
      
      for (int i = 0; i < pBuyNumMARates; i++) {
         if (buyMACondition && (i + 1) < pBuyNumMARates) {
            buyMACondition = maBuyVal[i] > maBuyVal[i + 1];
         } else {
            break;
         }
      }
      
      bool sellMACondition = true;
      
      for (int i = 0; i < pSellNumMARates; i++) {
         if (sellMACondition && (i + 1) < pSellNumMARates) {
            sellMACondition = maSellVal[i] < maSellVal[i + 1];
         } else {
            break;
         }
      }
      
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
      
      if (CopyBuffer(atrHandle, 0, 0, 1, atrVal) != 1) {
         Alert("Erro ao copiar o buffer do ATR: ", GetLastError());
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(atrVal, true);
      
   	CheckPosition();
   	MoveStopLoss();
   	
   	bool buyCondition = buyMACondition
   	   && buyRatesCondition
   	   && (latestPrice.ask >= maBuyVal[0] && latestPrice.ask <= latestPrice.ask + pMaxDistance)
   	   && (adxVal[0] >= pADXMin && plsDI[0] > minDI[0])
   	   && (atrVal[0] <= pATRMax);
      
      bool sellCondition = sellMACondition
         && sellRatesCondition
         && (latestPrice.bid <= maSellVal[0] && latestPrice.ask >= latestPrice.bid - pMaxDistance)
         && (adxVal[0] >= pADXMin && plsDI[0] < minDI[0])
   	   && (atrVal[0] <= pATRMax);
   	   
   	if ((buyCondition && sellOpened) || (sellCondition && buyOpened)) {
   	   Alert("Fechando posição atual devido ao sinal de reversão...");
      
         trade.PositionClose(_Symbol, 50);
   	}
      
      if (buyCondition) {
         if (buyOpened || sellOpened) {
            return;
         } else {
            double price = NormalizeDouble(latestPrice.ask, _Digits);
            double sl = price - pStopLoss;
            double tp = price + pTakeProfit;
            double volume = pLot;
            
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
      
      if (sellCondition) {
         if (buyOpened || sellOpened) {
            return;
         } else {
            double price = NormalizeDouble(latestPrice.bid, _Digits);
            double sl = price + pStopLoss;
            double tp = price - pTakeProfit;
            double volume = pLot;
            
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
