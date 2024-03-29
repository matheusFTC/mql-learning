//+------------------------------------------------------------------+
//|                                                     PrinceNY.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

// Parâmetros da alegria, quando se usa ordens pendentes... heheheheheheh
// StopLoss: 30   TakeProfit: 245   PrincePeriod: 5 --> R$ 14.716,00 - 02/01/2019 à 08/05/2019
// StopLoss: 5    TakeProfit: 245   PrincePeriod: 3 --> R$ 40.600,00 - 02/01/2019 à 08/05/2019
// StopLoss: 10   TakeProfit: 425   PrincePeriod: 4 --> R$ 31.112,00 - 02/01/2019 à 08/05/2019

// Parâmetros da alegria, quando se usa ordens a mercado... heheheheheheh
// StopLoss: 165   TakeProfit: 55   PrincePeriod: 5 --> R$ 3.330,00 - 02/01/2019 à 08/05/2019

input bool pUseBuyAndSellMarket = true;   // Usar ordens à mercado?
input int pDistance = 50;                 // Distância
input int pStopLoss = 165;                // Stop Loss
input int pTakeProfit = 55;               // Take Profit
input int pPrincePeriod = 5;              // Período do indicador do Cohen
input int pEAMagic = 4434456;             // EA Magic Number
input int pLot = 1;                       // Volume
input string pStartTime = "09:00";        // Horário de inicio
input string pEndTime = "17:00";          // Horário de termino
input string pCloseTime = "17:30";        // Horário de fechamento

bool buyOpened;
bool sellOpened;
double slMove;
int princeHandle;
double princeVal[];

MqlDateTime vScheduleStart;
MqlDateTime vScheduleEnded;
MqlDateTime vScheduleClosing;
MqlDateTime vScheduleCurrent;
MqlTick vLatestPrice;
MqlRates vRates[];

CTrade vCTrade;

int OnInit() {
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
   
   princeHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "PrinceNY"
      , pPrincePeriod);
      
   if (princeHandle == INVALID_HANDLE) {
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
   IndicatorRelease(princeHandle);
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

void MoveStopLoss() {
   if (CheckPosition()) {
      bool modify = false;
      double newSl = NULL;
      
      long positionId = PositionGetInteger(POSITION_IDENTIFIER);
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      
      if (buyOpened) {
         if ((vLatestPrice.ask - positionPriceOpen) >= 200) {
            newSl = positionPriceOpen + 100;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 150
            && (vLatestPrice.ask - positionPriceOpen) < 200) {
            newSl = positionPriceOpen + 50;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 100
            && (vLatestPrice.ask - positionPriceOpen) < 150) {
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
         if ((positionPriceOpen - vLatestPrice.bid) >= 200) {
            newSl = positionPriceOpen - 100;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 150
            && (positionPriceOpen - vLatestPrice.bid) < 200) {
            newSl = positionPriceOpen - 50;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.bid) >= 100
            && (positionPriceOpen - vLatestPrice.bid) < 150) {
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

void DeletePendingOrdes() {
   Alert("Removendo as ordens pendentes, devido ao novo sinal...");
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderGetTicket(i) > 0) vCTrade.OrderDelete(OrderGetTicket(i));
   }
}

double MaxHigh() {
   double maxHigh = 0;
   
   for (int i = 0; i <= 4; i++) {
      if (vRates[i].high > maxHigh) {
         maxHigh = vRates[i].high;
      }
   }
   
   return(maxHigh);
}

double MaxLow() {
   double maxLow = 0;
   
   for (int i = 0; i <= 4; i++) {
      if (vRates[i].low < maxLow) {
         maxLow = vRates[i].low;
      }
   }
   
   return(maxLow);
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
      } else if (!CheckNewBar()) {
         return;
      } else {
         CheckPosition();
         MoveStopLoss();
         
         ArraySetAsSeries(vRates, true);
         ArraySetAsSeries(princeVal, true);
   
         if (CopyRates(_Symbol, _Period, 0, 5, vRates) < 0) {
            Alert("Erro ao copiar o histórico de tempos: ", GetLastError());
            ResetLastError();
            return;
         }
      
         if (CopyBuffer(princeHandle, 3, 0, 3, princeVal) < 1) {
            Alert("Erro ao copiar o buffer do indicador: ", GetLastError());
            ResetLastError();
            return;
         }
         
         bool buyCondition = princeVal[1] == 1;
         
         if (CopyBuffer(princeHandle, 4, 0, 3, princeVal) < 1) {
            Alert("Erro ao copiar o buffer do indicador: ", GetLastError());
            ResetLastError();
            return;
         }
         
         bool sellCondition = princeVal[1] == 1;
         
         if (CheckPosition()) {
            if ((buyOpened && sellCondition) || (sellOpened && buyCondition)) {
               Alert("Fechando posição atual devido a sinalização de reversão...");
               vCTrade.PositionClose(_Symbol, 50);
            }
         }
         
         if ((buyOpened && buyCondition) || (sellOpened && sellCondition)) {
            DeletePendingOrdes();
         }
         
         if (buyCondition) {
            if (buyOpened) {
               return;
            } else {
               double maxLow = MaxLow();
               
               double price = pUseBuyAndSellMarket ? vLatestPrice.ask : (vLatestPrice.ask + pDistance);
               double sl = price - pStopLoss < maxLow ? maxLow : price - pStopLoss;
               double tp = price + pTakeProfit;
               double volume = pLot;
               
               string comment = StringFormat("Buy %s, %G, Volume: %G, SL: %G TP: %G"
                  , _Symbol
                  , volume
                  , price
                  , sl
                  , tp);
                  
               Alert(comment);
               
               bool check;
               
               if (pUseBuyAndSellMarket) {
                  check = vCTrade.Buy(volume, _Symbol, price, sl, tp, comment);
               } else {
                  check = vCTrade.BuyStop(volume, price, _Symbol, sl, tp, NULL, NULL, comment);
               }
      
               if (check == true && (vCTrade.ResultRetcode() == TRADE_RETCODE_DONE || vCTrade.ResultRetcode() == TRADE_RETCODE_PLACED)) {
                  Alert("Ordem de compra adicionada com sucesso!");
               } else {
                  Alert("Não foi possível realizar a operação de compra. Code: "
                     , vCTrade.ResultRetcode()
                     , " - ", vCTrade.ResultRetcodeDescription());
               }
            }
         }
         
         if (sellCondition) {
            if (sellOpened) {
               return;
            } else {
               double maxHigh = MaxHigh();
               
               double price = pUseBuyAndSellMarket ? vLatestPrice.bid : (vLatestPrice.bid - pDistance);
               double sl = price + pStopLoss > maxHigh ? maxHigh : price + pStopLoss;
               double tp = price - pTakeProfit;
               double volume = pLot;
               
               string comment = StringFormat("Sell %s, %G, Volume: %G, SL: %G TP: %G"
                  , _Symbol
                  , volume
                  , price
                  , sl
                  , tp);
                  
               Alert(comment);
                  
               bool check;
               
               if (pUseBuyAndSellMarket) {
                  check = vCTrade.Sell(volume, _Symbol, price, sl, tp, comment);
               } else {
                  check = vCTrade.SellStop(volume, price, _Symbol, sl, tp, NULL, NULL, comment);
               }
               
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
}
