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
input ENUM_TIMEFRAMES   pPeriod = PERIOD_CURRENT;       // Período
input int               pStopLoss = 150;                // Stop Loss
input int               pTakeProfit = 600;              // Take Profit
input int               pMAPeriod = 21;                 // Média móvel
input int               pMAShift = 0;                   // Deslocamento da média móvel
input int               pADXPeriod = 42;                // Período do ADX
input double            pADXMin = 23.0;                 // Valor mínimo do ADX
input int               pEAMagic = 65432;               // EA Magic Number
input int               pLot = 1;                       // Volume
input bool              pUseGainLimit = false;          // Utiliza limitador de ganho
input double            pGainLimit = 60;                // Ganho mínimo diário
input bool              pUseLossLimit = true;           // Utiliza limitador de perda
input double            pLossLimit = 100;               // Limite de perda diária

string hmaNotePeriod = "";
string hmaNoteSound = "";
string hmaSoundFile = "";
string hmaPotentialSoundFile = "";
int hmaPeriod = 21;
bool hmaSoundOn = true;
bool hmaAlertOn = true;
bool hmaMailOn = false;
bool hmaPushOn = false;
bool hmaCurrBarMessage = true;
ENUM_MA_METHOD hmaMethod = MODE_LWMA;
ENUM_APPLIED_PRICE hmaPrice = PRICE_CLOSE;
int hmaHandle;

// Variáveis globais
int maHandle;                 // Handle para a média móvel
double maVal[];               // Array para guardar os valores da média móvel para cada candle
double openingBalance;        // Saldo inicial
bool buyOpened;               // Flag para indicar a posição comprada
bool sellOpened;              // Flag para indicar a posição vendida
int adxHandle;                // Handle para o ADX
double plsDI[];               // Array guardar os valores do -DI para cada candle
double minDI[];               // Array guardar os valores do +DI para cada candle
double adxVal[];              // Array guardar os valores do ADX para cada candle
double slMove;                // Variável auxiliar do stop móvel

MqlTick vLatestPrice;
MqlRates vRates[];

CTrade vCTrade;

int OnInit() {
   openingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   maHandle = iMA(_Symbol, pPeriod, pMAPeriod, pMAShift, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, pPeriod, pADXPeriod);
   
   hmaHandle = iCustom(_Symbol
      , pPeriod
      , "Market\\HMA Color with Alerts MT5"
      , hmaNotePeriod
      , hmaPeriod
      , hmaMethod
      , hmaPrice
      , hmaNoteSound
      , hmaSoundOn
      , hmaAlertOn
      , hmaMailOn
      , hmaPushOn
      , hmaSoundFile
      , hmaPotentialSoundFile
      , hmaCurrBarMessage); 
   
   if (maHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || hmaHandle == INVALID_HANDLE) {
      Alert("Não foi possível criar os handles dos indicadores: ", GetLastError(), "!");
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
   IndicatorRelease(maHandle);
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
      bool modify = false;
      double newSl = NULL;
      
      long positionType = PositionGetInteger(POSITION_TYPE);
      long positionId = PositionGetInteger(POSITION_IDENTIFIER);
      double positionPriceOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double positionSl = PositionGetDouble(POSITION_SL);
      double positionTp = PositionGetDouble(POSITION_TP);
      
      if (positionType == POSITION_TYPE_BUY
         && buyOpened == true) {
         if ((vLatestPrice.ask - positionPriceOpen) >= 150
            && (vLatestPrice.ask - positionPriceOpen) < 300) {
            newSl = positionPriceOpen + 150;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 300
            && (vLatestPrice.ask - positionPriceOpen) < 450) {
            newSl = positionPriceOpen + 200;
            modify = true;
         } else if ((vLatestPrice.ask - positionPriceOpen) >= 450) {
            newSl = positionPriceOpen + 300;
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
         
         if (modify && newSl != positionSl) {
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
      } else if (positionType == POSITION_TYPE_SELL
         && sellOpened == true) {
         
         if ((positionPriceOpen - vLatestPrice.ask) >= 150
            && (positionPriceOpen - vLatestPrice.ask) < 300) {
            newSl = positionPriceOpen - 150;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.ask) >= 300
            && (positionPriceOpen - vLatestPrice.ask) < 450) {
            newSl = positionPriceOpen - 200;
            modify = true;
         } else if ((positionPriceOpen - vLatestPrice.ask) >= 450) {
            newSl = positionPriceOpen - 300;
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
         
         if (modify && newSl != positionSl) {
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
   ArraySetAsSeries(maVal, true);
   ArraySetAsSeries(plsDI, true);
   ArraySetAsSeries(minDI, true);
   ArraySetAsSeries(adxVal, true);

   if (!SymbolInfoTick(_Symbol, vLatestPrice)) {
      Alert("Erro ao copiar o último preço:", GetLastError());
      return;
   }

   if (CopyRates(_Symbol, _Period, 0, 5, vRates) < 0) {
      Alert("Erro ao copiar o histórico de tempos: ", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(maHandle, 0, 0, 5, maVal) < 0) {
      Alert("Erro ao copiar o buffer da média móvel: ", GetLastError());
      ResetLastError();
      return;
   }
   
   if (CopyBuffer(adxHandle, 0, 0, 5, adxVal) < 0
      || CopyBuffer(adxHandle, 1, 0, 5, plsDI) < 0
      || CopyBuffer(adxHandle, 2, 0, 5, minDI) < 0) {
      Alert("Erro ao copiar o buffer do ADX: ", GetLastError());
      ResetLastError();
      return;
   }
   
   CheckPosition();
   CheckLimits();
   MoveStopLoss();

   bool vBuyCondition = (maVal[0] > maVal[1])
      && (maVal[1] > maVal[2])
      && (maVal[2] > maVal[3])
      && (vRates[0].close > vRates[1].close)
      && (vRates[1].close > vRates[2].close)
      && (vRates[0].close > maVal[1])
      && (adxVal[0] >= pADXMin)
      && (plsDI[0] > minDI[0]);
  
   if (vBuyCondition) {
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
            
         Alert(comment);
            
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
      
   bool vSellCondition = (maVal[0] < maVal[1])
      && (maVal[1] < maVal[2])
      && (maVal[2] < maVal[3])
      && (vRates[0].close < vRates[1].close)
      && (vRates[1].close < vRates[2].close)
      && (vRates[0].close < maVal[1])
      && (adxVal[0] >= pADXMin)
      && (plsDI[0] < minDI[0]);

   if (vSellCondition) {
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
         
         Alert(comment);
         
         slMove = sl;
         
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