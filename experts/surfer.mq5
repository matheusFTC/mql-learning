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
input int      pStopLoss = 295;           // Stop Loss
input int      pTakeProfit = 70;          // Take Profit
input bool     pUseTrailingStop = true;   // Irá usar stop loss móvel?
input int      pTrailingStop = 10;        // Stop móvel
input int      pHMAPeriod = 17;           // Período da HMA
input bool     pCloseInSignal = false;    // Irá fechar a operação ao sinal de reversão?
input bool     pUseADX = false;           // Irá usar o indicador ADX?
input int      pADXPeriod = 15;           // Período do ADX
input double   pADXMin = 35.0;            // Valor mínimo do ADX
input int      pEAMagic = 67365161;       // EA Magic Number
input int      pLot = 1;                  // Volume
input bool     pUseGainLimit = false;     // Irá usar limitador de ganho diário?
input double   pGainLimit = 200;          // Objetivo de ganho diário
input bool     pUseLossLimit = true;      // Irá usar limitador de perda diária?
input double   pLossLimit = 100;          // Limite de perda diária
input string   pStartTime = "09:00";      // Horário de inicio
input string   pEndTime = "17:20";        // Horário de termino
input string   pCloseTime = "17:30";      // Horário de fechamento

// Variáveis globais
bool buyOpened;
bool sellOpened;
bool upSignal;
bool downSignal;
bool upTrend;
bool downTrend;
int hmaHandle;
double hmaVal[];
int adxHandle;
double plsDI[];
double minDI[];
double adxVal[];
double slMove;
double openingBalance;

MqlDateTime vScheduleStart;
MqlDateTime vScheduleEnded;
MqlDateTime vScheduleClosing;
MqlDateTime vScheduleCurrent;
MqlTick vLatestPrice;

CTrade vCTrade;

int OnInit() {
   openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   upSignal = false;
   downSignal = false;
   upTrend = false;
   downTrend = false;
   
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
   
   hmaHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "Market\\HMA Color with Alerts MT5"
      , ""
      , pHMAPeriod
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
      
   if (pUseADX) adxHandle = iADX(_Symbol, PERIOD_CURRENT, pADXPeriod);
   
   if (hmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE) {
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
   IndicatorRelease(hmaHandle);
   
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
         if ((vLatestPrice.bid - positionPriceOpen) > (Point() * pTrailingStop)) {
            if (positionSl < (vLatestPrice.bid - Point() * pTrailingStop)) {
               newSl = vLatestPrice.bid - Point() * pTrailingStop;
               
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
      }
      
      if (sellOpened) {
         if ((positionPriceOpen - vLatestPrice.ask) > (Point() * pTrailingStop)){
            if (positionSl > (vLatestPrice.ask + Point() * pTrailingStop)) {
               newSl = vLatestPrice.ask + Point() * pTrailingStop;
               
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
}

void CheckLimits() {
   if (buyOpened == false && sellOpened == false) {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if (pUseGainLimit && balance >= openingBalance + pGainLimit) {
         Alert("Atingido o objetivo de ganho.");
         TerminalClose(0);
      } else if (pUseLossLimit && balance <= openingBalance - pLossLimit) {
         Alert("Atingido o limite de perda.");
         TerminalClose(0);
      }
   }
}

void OnTick() {
   if (IsClose() && CheckPosition()) {
      Alert("Fechando posição atual devido a fechamento do mercado...");
      
      vCTrade.PositionClose(_Symbol, 50);
      
      openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   if (IsOpen()) {
      CheckLimits();
      
      if (!SymbolInfoTick(_Symbol, vLatestPrice)) {
         Alert("Erro ao copiar o último preço: ", GetLastError());
         return;
      }
      
      ArraySetAsSeries(hmaVal, true);
      
      if (CopyBuffer(hmaHandle, 1, 0, 3, hmaVal) != 3) {
         Alert("Erro ao copiar o buffer do HMA rápido: ", GetLastError());
         ResetLastError();
         return;
      }
      
      if (pUseADX) {
         ArraySetAsSeries(adxVal, true);
         ArraySetAsSeries(plsDI, true);
         ArraySetAsSeries(minDI, true);
         
         if (CopyBuffer(adxHandle, 0, 0, 5, adxVal) < 0
            || CopyBuffer(adxHandle, 1, 0, 5, plsDI) < 0
            || CopyBuffer(adxHandle, 2, 0, 5, minDI) < 0) {
            Alert("Erro ao copiar o buffer do ADX: ", GetLastError());
            ResetLastError();
            return;
         }
      }
      
      if (hmaVal[0] == 0 && hmaVal[1] == 1) {
         upSignal = true;
		   downSignal = false;
		   
		   Alert("Identificando sinal de alta...");
      }
      
      if (hmaVal[0] == 1 && hmaVal[1] == 0) {
         upSignal = false;
		   downSignal = true;
		   
		   Alert("Identificando sinal de baixa...");
      }
      
      if (hmaVal[1] == 0 && hmaVal[2] == 1) {
   	   upTrend = true;
   	   downTrend = false;
   	   
   	   Alert("Confirmado sinal de alta!");
   	}
   	
   	if (hmaVal[1] == 1 && hmaVal[2] == 0) {
   	   upTrend = false;
   	   downTrend = true;
   	   
   	   Alert("Confirmado sinal de baixa!");
   	}
   	
   	if (!CheckNewBar()) return;
   	
   	if (CheckPosition()) {
         if ((buyOpened && (pCloseInSignal ? downSignal : downTrend))
            || (sellOpened && (pCloseInSignal ? upSignal : upTrend))) {
            Alert("Fechando posição atual devido a sinalização de reversão...");
            
            vCTrade.PositionClose(_Symbol, 50);
         } else {
            if (pUseTrailingStop) MoveStopLoss();
         }
      }
   	
   	bool buyAdxCondition = pUseADX ? (adxVal[0] >= pADXMin && plsDI[0] > minDI[0]) : true;
     
      if (upTrend && buyAdxCondition) {
         if (buyOpened) {
            return;
         } else {
            double price = NormalizeDouble(vLatestPrice.ask, _Digits);
            double sl = price - pStopLoss;
            double tp = price + pTakeProfit;
            double volume = pLot;
            
            string comment = StringFormat("Buy %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
            
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
   
      if (downTrend && sellAdxCondition) {
         if (sellOpened) {
            return;
         } else {
            double price = NormalizeDouble(vLatestPrice.bid, _Digits);
            double sl = price + pStopLoss;
            double tp = price - pTakeProfit;
            double volume = pLot;
            
            string comment = StringFormat("Sell %s, %G, Volume: %G, SL: %G TP: %G"
               , _Symbol
               , volume
               , price
               , sl
               , tp);
            
            bool check = vCTrade.Sell(volume, _Symbol, price, sl, tp, comment);
            
            if (check == true && (vCTrade.ResultRetcode() == TRADE_RETCODE_DONE || vCTrade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
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
