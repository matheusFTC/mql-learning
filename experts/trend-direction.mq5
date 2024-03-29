//+------------------------------------------------------------------+
//|                                                      FirstEA.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

// Parâmetros de entrada
input int      pStopLoss = 270;        // Stop Loss
input int      pTakeProfit = 210;      // Take Profit
input int      pHMAFastPeriod = 34;    // Período da HMA rápido
input bool     pUseHMAMiddle = false;  // Flag para uso do HMA intermediário
input int      pHMAMiddlePeriod = 52;  // Período da HMA intermediário
input bool     pUseHMASlow = false;    // Flag para uso do HMA lento
input int      pHMASlowPeriod = 74;    // Período da HMA lento
input bool     pUseADX = true;         // Flag para uso do ADX
input int      pADXPeriod = 10;        // Período do ADX
input double   pADXMin = 24.0;         // Valor mínimo do ADX
input int      pEAMagic = 65432;       // EA Magic Number
input int      pLot = 1;               // Volume
input double   pLossLimit = 100;       // Limite de perda diária
input string   pStartTime = "09:00";   // Horário de inicio
input string   pEndTime = "17:00";     // Horário de termino
input string   pCloseTime = "17:30";   // Horário de fechamento

// Variáveis globais
bool buyOpened;
bool sellOpened;
bool upFastSignal;
bool downFastSignal;
bool upMiddleSignal;
bool downMiddleSignal;
bool upSlowSignal;
bool downSlowSignal;
bool upFastTrend;
bool downFastTrend;
bool upMiddleTrend;
bool downMiddleTrend;
bool upSlowTrend;
bool downSlowTrend;
double openingBalance;
int hmaFastHandle;
double hmaFastVal[];
int hmaSlowHandle;
double hmaMiddleVal[];
int hmaMiddleHandle;
double hmaSlowVal[];
int adxHandle;
double plsDI[];
double minDI[];
double adxVal[];
double slMove;

MqlDateTime vScheduleStart;
MqlDateTime vScheduleEnded;
MqlDateTime vScheduleClosing;
MqlDateTime vScheduleCurrent;
MqlTick vLatestPrice;

CTrade vCTrade;

int OnInit() {
   upFastSignal = false;
   downFastSignal = false;
   upMiddleSignal = false;
   downMiddleSignal = false;
   upSlowSignal = false;
   downSlowSignal = false;
   upFastTrend = false;
   downFastTrend = false;
   upMiddleTrend = false;
   downMiddleTrend = false;
   upSlowTrend = false;
   downSlowTrend = false;
   
   openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   TimeToStruct(StringToTime(pStartTime), vScheduleStart);
   TimeToStruct(StringToTime(pEndTime), vScheduleEnded);
   TimeToStruct(StringToTime(pCloseTime), vScheduleClosing);
   
   if ((vScheduleStart.hour > vScheduleEnded.hour || (vScheduleStart.hour == vScheduleEnded.hour
               && vScheduleStart.min > vScheduleEnded.min))
         || (vScheduleEnded.hour > vScheduleClosing.hour || (vScheduleEnded.hour == vScheduleClosing.hour
                     && vScheduleEnded.min>vScheduleClosing.min))) {
      Alert("Horários invalidos!");
      
      return INIT_FAILED;
   }
   
   hmaFastHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "Market\\HMA Color with Alerts MT5"
      , ""
      , pHMAFastPeriod
      , MODE_LWMA
      , PRICE_CLOSE
      , ""
      , false
      , false
      , false
      , false
      , ""
      , ""
      , true);
      
   if (pUseHMAMiddle) {
      hmaMiddleHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "Market\\HMA Color with Alerts MT5"
      , ""
      , pHMAMiddlePeriod
      , MODE_LWMA
      , PRICE_CLOSE
      , ""
      , false
      , false
      , false
      , false
      , ""
      , ""
      , true);   
   }
   
   if (pUseHMASlow) {
      hmaSlowHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "Market\\HMA Color with Alerts MT5"
      , ""
      , pHMASlowPeriod
      , MODE_LWMA
      , PRICE_CLOSE
      , ""
      , false
      , false
      , false
      , false
      , ""
      , ""
      , true);
   }   
   
   if (pUseADX) {
      adxHandle = iADX(_Symbol, PERIOD_CURRENT, pADXPeriod);   
   }
   
   if (hmaFastHandle == INVALID_HANDLE
         || (pUseHMAMiddle ? hmaMiddleHandle == INVALID_HANDLE : false)
         || (pUseHMASlow ? hmaSlowHandle == INVALID_HANDLE : false)
         || (pUseADX ? adxHandle == INVALID_HANDLE : false)) {
      Alert("Não foi possível criar os handles dos indicadores: ", GetLastError());
      return(INIT_FAILED);
   } else {
      vCTrade.SetExpertMagicNumber(pEAMagic);
      vCTrade.SetDeviationInPoints(10);
      vCTrade.SetTypeFilling(ORDER_FILLING_FOK);
      vCTrade.LogLevel(1); 
      vCTrade.SetAsyncMode(true);
   
      return(INIT_SUCCEEDED);
   }
}

void OnDeinit(const int reason) {
   IndicatorRelease(hmaFastHandle);
   if (pUseHMAMiddle) IndicatorRelease(hmaMiddleHandle);
   if (pUseHMASlow) IndicatorRelease(hmaSlowHandle);
   if (pUseADX) IndicatorRelease(adxHandle);
}

bool IsOpen() {
   TimeToStruct(TimeCurrent(), vScheduleCurrent);

   if (vScheduleCurrent.hour >= vScheduleStart.hour && vScheduleCurrent.hour <= vScheduleEnded.hour) {
      if (vScheduleCurrent.hour == vScheduleStart.hour) {
         if (vScheduleCurrent.min >= vScheduleStart.min) {
            return true;
         } else {
            return false;
         }
      }
      
      if (vScheduleCurrent.hour == vScheduleEnded.hour) {
         if (vScheduleCurrent.min <= vScheduleEnded.min) {
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
   TimeToStruct(TimeCurrent(), vScheduleCurrent);
      
   if (vScheduleCurrent.hour >= vScheduleClosing.hour) {
      if (vScheduleCurrent.hour == vScheduleClosing.hour) {
         if (vScheduleCurrent.min >= vScheduleClosing.min) {
            return true;
         } else {
            return false;
         }
      }
      return true;
   }
   
   return false;
}

void CheckLimits() {
   if (buyOpened == false && sellOpened == false) {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if (balance <= openingBalance - pLossLimit) {
         Alert("Atingido o limite de perda.");
         
         vCTrade.PositionClose(_Symbol, 50);
         
         TerminalClose(0);
      }
   }
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

void MoveStopLoss() {
   if (CheckPosition()) {
      bool modify = false;
      double newSl = NULL;
      
      long positionId = PositionGetInteger(POSITION_IDENTIFIER);
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      
      if (buyOpened) {
         if ((vLatestPrice.ask - positionPriceOpen) >= 700) {
            newSl = positionPriceOpen + 300;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 600
            && (vLatestPrice.ask - positionPriceOpen) < 700) {
            newSl = positionPriceOpen + 250;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 500
            && (vLatestPrice.ask - positionPriceOpen) < 600) {
            newSl = positionPriceOpen + 200;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 400
            && (vLatestPrice.ask - positionPriceOpen) < 500) {
            newSl = positionPriceOpen + 150;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 300
            && (vLatestPrice.ask - positionPriceOpen) < 400) {
            newSl = positionPriceOpen + 100;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 200
            && (vLatestPrice.ask - positionPriceOpen) < 300) {
            newSl = positionPriceOpen + 50;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 100
            && (vLatestPrice.ask - positionPriceOpen) < 200) {
            newSl = positionPriceOpen;
            modify = true;
         } else {
            modify = false;
         }
         
         if (slMove == NULL) {
            slMove = newSl;
         } else {
            if (newSl != slMove) {
               slMove = newSl;
            } else {
               modify = false;
            }
         }
         
         if (modify && newSl > positionSl) {
            if (!vCTrade.PositionModify(_Symbol, newSl, positionTp)) {
               Alert("(Buy) Não foi possível ajustar o stop loss: "
                  , vCTrade.ResultRetcode()
                  , ". Code Desc.: "
                  , vCTrade.ResultRetcodeDescription());
            } else {
               Alert("(Buy) Stop loss ajustado com sucesso: "
                  , positionSl
                  , " --> "
                  , newSl
                  , " - Code: "
                  , vCTrade.ResultRetcode()
                  , " ("
                  , vCTrade.ResultRetcodeDescription()
                  , ")");
            }
         }
      }
      
      if (sellOpened) {
         if ((positionPriceOpen - vLatestPrice.bid) >= 700) {
            newSl = positionPriceOpen - 300;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 600
            && (positionPriceOpen - vLatestPrice.bid) < 700) {
            newSl = positionPriceOpen - 250;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 500
            && (positionPriceOpen - vLatestPrice.bid) < 600) {
            newSl = positionPriceOpen - 200;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 400
            && (positionPriceOpen - vLatestPrice.bid) < 500) {
            newSl = positionPriceOpen - 150;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 300
            && (positionPriceOpen - vLatestPrice.bid) < 400) {
            newSl = positionPriceOpen - 100;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 200
            && (positionPriceOpen - vLatestPrice.bid) < 300) {
            newSl = positionPriceOpen - 50;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 100
            && (positionPriceOpen - vLatestPrice.bid) < 200) {
            newSl = positionPriceOpen;
            modify = true;
         } else {
            modify = false;
         }
         
         if (slMove == NULL) {
            slMove = newSl;
         } else {
            if (newSl != slMove) {
               slMove = newSl;
            } else {
               modify = false;
            }
         }
         
         if (modify && newSl < positionSl) {
            if (!vCTrade.PositionModify(_Symbol, newSl, positionTp)) {
               Alert("(Sell) Não foi possível ajustar o stop loss: "
                  , vCTrade.ResultRetcode()
                  , ". Code Desc.: "
                  , vCTrade.ResultRetcodeDescription());
            } else {
               Alert("(Sell) Stop loss ajustado com sucesso: "
                  , positionSl
                  , " --> "
                  , newSl
                  , " - Code: "
                  , vCTrade.ResultRetcode()
                  , " ("
                  , vCTrade.ResultRetcodeDescription()
                  , ")");
            }
         }
      }   
   }
}

void OnTick() {
   if (IsClose() && CheckPosition()) {
      Alert("Fechando posição atual devido a fechamento do mercado...");
      vCTrade.PositionClose(_Symbol, 50);
   }
   
   if (IsOpen()) {
      if (!SymbolInfoTick(_Symbol, vLatestPrice)) {
         Alert("Erro ao copiar o último preço: ", GetLastError());
         return;
      }
      
      ArraySetAsSeries(hmaFastVal, true);
      if (pUseHMAMiddle) ArraySetAsSeries(hmaMiddleVal, true);
      if (pUseHMASlow) ArraySetAsSeries(hmaSlowVal, true);
      if (pUseADX) {
         ArraySetAsSeries(adxVal, true);
         ArraySetAsSeries(plsDI, true);
         ArraySetAsSeries(minDI, true);
      }
      
      if (CopyBuffer(hmaFastHandle, 1, 0, 3, hmaFastVal) != 3) {
         Alert("Erro ao copiar o buffer do HMA rápido: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (pUseHMAMiddle && CopyBuffer(hmaMiddleHandle, 1, 0, 3, hmaMiddleVal) != 3) {
         Alert("Erro ao copiar o buffer do HMA intermediário: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (pUseHMASlow && CopyBuffer(hmaSlowHandle, 1, 0, 3, hmaSlowVal) != 3) {
         Alert("Erro ao copiar o buffer do HMA lento: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (pUseADX && (CopyBuffer(adxHandle, 0, 0, 5, adxVal) < 0
         || CopyBuffer(adxHandle, 1, 0, 5, plsDI) < 0
         || CopyBuffer(adxHandle, 2, 0, 5, minDI) < 0)) {
         Alert("Erro ao copiar o buffer do ADX: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (!CheckNewBar()) return;
      
      CheckLimits();
      MoveStopLoss();
      
      if (hmaFastVal[0] == 0 && hmaFastVal[1] == 1) {
         upFastSignal = true;
		   downFastSignal = false;
      }
      
      if (hmaFastVal[0] == 1 && hmaFastVal[1] == 0) {
         upFastSignal = false;
		   downFastSignal = true;
      }
      
      if (pUseHMAMiddle && hmaMiddleVal[0] == 0 && hmaMiddleVal[1] == 1) {
         upMiddleSignal = true;
		   downMiddleSignal = false;
      }
      
      if (pUseHMAMiddle && hmaMiddleVal[0] == 1 && hmaMiddleVal[1] == 0) {
         upMiddleSignal = false;
		   downMiddleSignal = true;
      }
      
      if (pUseHMASlow && hmaSlowVal[0] == 0 && hmaSlowVal[1] == 1) {
         upSlowSignal = true;
		   downSlowSignal = false;
      }
      
      if (pUseHMASlow && hmaSlowVal[0] == 1 && hmaSlowVal[1] == 0) {
         upSlowSignal = false;
		   downSlowSignal = true;
      }
      
      if (hmaFastVal[1] == 0 && hmaFastVal[2] == 1) {
   	   upFastTrend = true;
   	   downFastTrend = false;
   	}
   	
   	if (hmaFastVal[1] == 1 && hmaFastVal[2] == 0) {
   	   upFastTrend = false;
   	   downFastTrend = true;
   	}
   	
   	if (pUseHMAMiddle && hmaMiddleVal[1] == 0 && hmaMiddleVal[2] == 1) {
   	   upMiddleTrend = true;
   	   downMiddleTrend = false;
   	}
   	
   	if (pUseHMAMiddle && hmaMiddleVal[1] == 1 && hmaMiddleVal[2] == 0) {
   	   upMiddleTrend = false;
   	   downMiddleTrend = true;
   	}
   	
   	if (pUseHMASlow && hmaSlowVal[1] == 0 && hmaSlowVal[2] == 1) {
	      upSlowTrend = true;
		   downSlowTrend = false;
	   }
	   
	   if (pUseHMASlow && hmaSlowVal[1] == 1 && hmaSlowVal[2] == 0) {
		   upSlowTrend = false;
		   downSlowTrend = true;
	   }
   	
   	// Se sinalizado reversão em relação a posição, caso haja uma posição aberta.
      if (!IsClose() && CheckPosition()) {
         if ((buyOpened && downFastTrend) || (sellOpened && upFastTrend)
            || (pUseHMAMiddle ? ((buyOpened && downMiddleTrend) || (sellOpened && upMiddleTrend)) : false)
            || (pUseHMASlow ? ((buyOpened && downSlowTrend) || (sellOpened && upSlowTrend)) : false)) {
            Alert("Fechando posição atual devido a sinalização de reversão...");
            vCTrade.PositionClose(_Symbol, 50);
         }
      }
   	
   	bool buyAdxCondition = pUseADX ? (adxVal[0] >= pADXMin && plsDI[0] > minDI[0]) : true;
     
      if (upFastTrend
         && (pUseHMAMiddle ? upMiddleTrend : true)
         && (pUseHMASlow ? upSlowTrend : true)
         && buyAdxCondition) {
         if (buyOpened) {
            return;
         } else {
            double price = vLatestPrice.ask;
            double sl = vLatestPrice.ask - pStopLoss;
            double tp = vLatestPrice.ask + pTakeProfit;
            double volume = pLot;
            
            string comment = StringFormat("Buy %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
               
            slMove = sl;
            
            bool check = vCTrade.Buy(volume, _Symbol, price, sl, tp, comment);
   
            if (check == true && (vCTrade.ResultRetcode() == TRADE_RETCODE_DONE || vCTrade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
               Alert("Ordem de compra adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de compra. Code: "
                  , vCTrade.ResultRetcode()
                  , " - ", vCTrade.ResultRetcodeDescription());
            }
         }
      }
      
      bool sellAdxCondition = pUseADX ? (adxVal[0] >= pADXMin && plsDI[0] < minDI[0]) :  true;
   
      if (downFastTrend
         && (pUseHMAMiddle ? downMiddleTrend : true)
         && (pUseHMASlow ? downSlowTrend : true)
         && sellAdxCondition) {
         if (sellOpened) {
            return;
         } else {
            double price = vLatestPrice.bid;
            double sl = vLatestPrice.bid + pStopLoss;
            double tp = vLatestPrice.bid - pTakeProfit;
            double volume = pLot;
            
            string comment = StringFormat("Sell %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
               
            slMove = sl;
            
            bool check = vCTrade.Sell(volume, _Symbol, price, sl, tp, comment);
            
            if (check == true && (vCTrade.ResultRetcode() == TRADE_RETCODE_DONE || vCTrade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
               slMove = sl;
               
               Alert("Ordem de venda adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de venda. Code: "
                  , vCTrade.ResultRetcode()
                  , " - ", vCTrade.ResultRetcodeDescription());
            }
         }
      }
   }
}