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
input ENUM_TIMEFRAMES   pPeriod = PERIOD_CURRENT;        // Período
input int               pStopLoss = 150;                 // Stop Loss
input int               pTakeProfit = 600;               // Take Profit
input bool              pUseMACrossing = false;          // Utiliza cruzamento de médias móveis
input int               pSlowMAPeriod = 72;              // Média móvel lenta
input int               pSlowMAShift = 0;                // Deslocamento da média móvel lenta
input int               pFastMAPeriod = 2;               // Média móvel rápida
input int               pFastMAShift = 9;                // Deslocamento da média móvel rápida
input int               pIntermediateMAPeriod = 92;      // Média móvel intermediária
input int               pIntermediateMAShift = 9;        // Deslocamento da média móvel intermediária
input int               pEAMagic = 54632;                // EA Magic Number
input int               pLot = 1;                        // Volume
input int               pMaxSimultaneously = 3;          // Máximo de posições simultâneas iguais abertas
input bool              pUseGainLimit = false;           // Utiliza limitador de ganho
input double            pGainLimit = 200;                // Ganho mínimo diário
input bool              pUseLossLimit = false;           // Utiliza limitador de perda
input double            pLossLimit = 100;                // Limite de perda diária
input int               pADXPeriod = 29;                 // Período do ADX
input double            pADXMin = 8.0;                   // Valor mínimo do ADX
input bool              pUseTrend = true;                // Utiliza tendência

// Variáveis globais
int maSlowHandle;             // Handle para a média móvel lenta
int maFastHandle;             // Handle para a média móvel rápida
int maIntermediateHandle;     // Handle para a média móvel intermediária
double maSlowVal[];           // Array para guardar os valores da média móvel lenta para cada candle
double maFastVal[];           // Array para guardar os valores da média móvel rápida para cada candle
double maIntermediateVal[];   // Array para guardar os valores da média móvel rápida para cada candle
double candleClose;           // Fechamento do candle
double openingBalance;        // Fechamento do candle
bool buyOpened;               // Flag para indicar a posição comprada
bool sellOpened;              // Flag para indicar a posição vendida
int adxHandle;                // Handle para o ADX
double plsDI[];               // Array guardar os valores do -DI para cada candle
double minDI[];               // Array guardar os valores do +DI para cada candle
double adxVal[];              // Array guardar os valores do ADX para cada candle
int totalPositions;           // Total de posições abertas

MqlTick vLatestPrice;
MqlTradeRequest vRequest;
MqlTradeResult vResult;
MqlRates vRates[];
CTrade vCTrade;

int OnInit() {
   openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   maSlowHandle = iMA(_Symbol, pPeriod, pSlowMAPeriod, pSlowMAShift, MODE_EMA, PRICE_CLOSE);
   maFastHandle = iMA(_Symbol, pPeriod, pFastMAPeriod, pFastMAShift, MODE_EMA, PRICE_CLOSE);
   maIntermediateHandle = iMA(_Symbol, pPeriod, pIntermediateMAPeriod, pIntermediateMAShift, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, pPeriod, pADXPeriod);
   
   if (maSlowHandle < 0 ||  maFastHandle < 0 || maIntermediateHandle < 0 || adxHandle < 0) {
      Alert("Não foi possível criar os handles dos indicadores: ", GetLastError(), "!");
      return(INIT_FAILED);
   } else {
      return(INIT_SUCCEEDED);
   }
}

void OnDeinit(const int reason) {
   IndicatorRelease(maFastHandle);
   IndicatorRelease(maSlowHandle);
   IndicatorRelease(maIntermediateHandle);
   IndicatorRelease(adxHandle);
}

void CheckPosition() {
   buyOpened = false;
   sellOpened = false;

   if (PositionSelect(_Symbol) == true) {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         buyOpened = true;
      } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         sellOpened = true;
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

void MoveStopLoss() {
   if (PositionSelect(_Symbol)) {
      long positionType = PositionGetInteger(POSITION_TYPE);
      long positionId = PositionGetInteger(POSITION_IDENTIFIER);
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      
      if (positionType == 0
         && buyOpened == true
         && (vLatestPrice.ask - positionPriceOpen) >= 400
         && positionSl < (positionPriceOpen + 100)) {
         if(!vCTrade.PositionModify(_Symbol, (positionPriceOpen + 100), positionTp)) {
            Alert("(Buy) Não foi possível ajustar o stop loss: "
               , vCTrade.ResultRetcode()
               , ". Code Desc.: "
               , vCTrade.ResultRetcodeDescription());
         } else {
            Alert("(Buy) Stop loss ajustado com sucesso: "
               , positionSl
               , " --> "
               , positionPriceOpen
               , " - Ret code: "
               , vCTrade.ResultRetcode()
               , " ("
               , vCTrade.ResultRetcodeDescription()
               , ")");
         }
      } else if (positionType == 1
         && sellOpened == true
         && (positionPriceOpen - vLatestPrice.ask) <= 400
         && positionSl > (positionPriceOpen - 100)) {
         if(!vCTrade.PositionModify(_Symbol, (positionPriceOpen - 100), positionTp)) {
            Alert("(Sell) Não foi possível ajustar o stop loss: "
               , vCTrade.ResultRetcode()
               , ". Code Desc.: "
               , vCTrade.ResultRetcodeDescription());
         } else {
            Alert("(Sell) Stop loss ajustado com sucesso: "
               , positionSl
               , " --> "
               , positionPriceOpen
               , " - Ret code: "
               , vCTrade.ResultRetcode()
               , " ("
               , vCTrade.ResultRetcodeDescription()
               , ")");
         }
      }   
   }
}

void OnTick() { 
   if (Bars(_Symbol, _Period) < 20) {
      Alert("Temos menos que 20 candles para o pregão! Precisamos de no mínimo 20.");
      return;
   }

   static datetime vOldTime;
   datetime vNewTime[1];
   bool vIsNewBar = false;

   int vCopied = CopyTime(_Symbol, _Period, 0, 1, vNewTime);
   
   if (vCopied > 0) {
      if (vOldTime != vNewTime[0]) {
         vIsNewBar = true;
         if (MQL5InfoInteger(MQL5_DEBUGGING)) {
            Print("Novo candle: ", vNewTime[0], ", candle anterior: ", vOldTime);
         }
         vOldTime = vNewTime[0];
        }
   } else {
      Alert("Erro ao obter o histórico de tempo: ", GetLastError());
      ResetLastError();
      return;
   }

   if (vIsNewBar == false) {
      return;
   }
 
   int vBars = Bars(_Symbol, _Period);
   
   if (vBars < 20) {
      Alert("Temos menos que 20 candles para o pregão! Precisamos de no mínimo 20.");
      return;
   }
   
   ArraySetAsSeries(vRates, true);
   ArraySetAsSeries(maSlowVal, true);
   ArraySetAsSeries(maFastVal, true);
   ArraySetAsSeries(maIntermediateVal, true);
   ArraySetAsSeries(plsDI, true);
   ArraySetAsSeries(minDI, true);
   ArraySetAsSeries(adxVal, true);

   if (!SymbolInfoTick(_Symbol, vLatestPrice)) {
      Alert("Erro ao copiar o último preço:", GetLastError());
      return;
   }

   if (CopyRates(_Symbol, _Period, 0, 5, vRates) < 0) {
      Alert("Erro ao copiar o histórico de tempos: ", GetLastError(), "!");
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(maSlowHandle, 0, 0, 5, maSlowVal) < 0) {
      Alert("Erro ao copiar o buffer da média móvel lenta: ", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(maFastHandle, 0, 0, 5, maFastVal) < 0) {
      Alert("Erro ao copiar o buffer da média móvel rápida: ", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(maIntermediateHandle, 0, 0, 5, maIntermediateVal) < 0) {
      Alert("Erro ao copiar o buffer da média móvel intermediária: ", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(adxHandle, 0, 0, 3, adxVal) < 0
      || CopyBuffer(adxHandle, 1, 0, 3, plsDI) < 0
      || CopyBuffer(adxHandle, 2, 0, 3, minDI) < 0) {
      Alert("Erro ao copiar o buffer do ADX: ", GetLastError(), "!");
      ResetLastError();
      return;
   }
   
   CheckPosition();
   CheckLimits();
   MoveStopLoss();

   candleClose = vRates[1].close;
   
   bool vBuyCrossingMACondition = pUseMACrossing
      && (maIntermediateVal[0] > maSlowVal[0])
      && (maIntermediateVal[1] > maSlowVal[1])
      && (maIntermediateVal[2] < maSlowVal[2])
      && (maIntermediateVal[3] < maSlowVal[3])
      && (candleClose > maFastVal[1]);
   
   bool vBuyTrendCondition = pUseTrend
      && (maFastVal[0] > maFastVal[1])
      && (maFastVal[1] > maFastVal[2])
      && (maIntermediateVal[0] > maIntermediateVal[1])
      && (maIntermediateVal[1] > maIntermediateVal[2])
      && (candleClose > maFastVal[1])
      && (adxVal[0] > pADXMin)
      && (plsDI[0] > minDI[0]);
  
   if (vBuyCrossingMACondition || vBuyTrendCondition) {
      if (buyOpened) {
         return;
      } else {
         ZeroMemory(vRequest);
         
         vRequest.action = TRADE_ACTION_DEAL;
         vRequest.price = vLatestPrice.ask;
         vRequest.sl = vLatestPrice.ask - pStopLoss;
         vRequest.tp = vLatestPrice.ask + pTakeProfit;
         vRequest.symbol = _Symbol;
         vRequest.volume = pLot;
         vRequest.magic = pEAMagic;
         vRequest.type = ORDER_TYPE_BUY;                                       
         vRequest.type_filling = ORDER_FILLING_FOK;
         vRequest.deviation = 100;

         bool check = OrderSend(vRequest, vResult);

         if (check == true && (vResult.retcode == TRADE_RETCODE_DONE || vResult.retcode == TRADE_RETCODE_PLACED)) {
            Alert("Ordem de compra adicionada com sucesso: ", vResult.order, "!");
         } else if (check == false) {
            Alert("A verificação básica de estruturas encontrou um problema na requisição.");
         } else {
            Alert("A requisição de compra não foi completada com sucesso: ", GetLastError());
            ResetLastError();           
            return;
         }
      }
   }
   
   bool vSellCrossingCondition = pUseMACrossing
      && (maIntermediateVal[0] < maSlowVal[0])
      && (maIntermediateVal[1] < maSlowVal[1])
      && (maIntermediateVal[2] > maSlowVal[2])
      && (maIntermediateVal[3] > maSlowVal[3])
      && (candleClose < maFastVal[1]);
      
   bool vSellTrendCondition = pUseTrend
      && (maFastVal[0] < maFastVal[1])
      && (maFastVal[1] < maFastVal[2])
      && (maIntermediateVal[0] < maIntermediateVal[1])
      && (maIntermediateVal[1] < maIntermediateVal[2])
      && (candleClose < maFastVal[1])
      && (adxVal[0] > pADXMin)
      && (plsDI[0] < minDI[0]);

   if (vSellCrossingCondition || vSellTrendCondition) {
      if (sellOpened) {
         return;
      } else {
         ZeroMemory(vRequest);
         
         vRequest.action = TRADE_ACTION_DEAL;
         vRequest.price = vLatestPrice.bid;
         vRequest.sl = vLatestPrice.bid + pStopLoss;
         vRequest.tp = vLatestPrice.bid - pTakeProfit;
         vRequest.symbol = _Symbol;
         vRequest.volume = pLot;
         vRequest.magic = pEAMagic;
         vRequest.type= ORDER_TYPE_SELL;
         vRequest.type_filling = ORDER_FILLING_FOK;
         vRequest.deviation = 100;
         
         bool check = OrderSend(vRequest, vResult);
         
         if (check == true && (vResult.retcode == TRADE_RETCODE_DONE || vResult.retcode == TRADE_RETCODE_PLACED)) {
            Alert("Ordem de venda adicionada com sucesso: ", vResult.order, "!");
         } else if (check == false) {
            Alert("A verificação básica de estruturas encontrou um problema na requisição.");
         } else {
            Alert("A requisição de compra não foi completada com sucesso: ", GetLastError());
            ResetLastError();
            return;
         }
      }
   }
}