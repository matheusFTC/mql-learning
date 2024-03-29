//+------------------------------------------------------------------+
//|                                                     SignalEA.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <BasicEA.mqh>

input int      iADXPeriod = 29;        // (SignalTrend: ADX) Período
input double   iADXMin = 11.4;         // (SignalTrend: ADX) Força mínima de tendência
input double   iADXMax = 79.6;         // (SignalTrend: ADX) Força máxima de tendência
input int      iATRPeriod = 44;        // (SignalTrend: ATR) Período
input int      iATRMin = 68;           // (SignalTrend: ATR) Probabilidade mínima de reversão
input int      iMAFastPeriod = 33;     // (SignalTrend: EMA) Período rápido
input int      iMASlowPeriod = 35;     // (SignalTrend: EMA) Período lento
input int      iEAMagic = 67365161;    // (EA) Magic Number

int signalHandle;
double buySignalVal[];
double sellSignalVal[];

int OnInit() {
   if (!CheckSchedule()) {
      Alert("Horários invalidos!");
      
      return INIT_FAILED;
   }
   
   signalHandle = iCustom(_Symbol
      , PERIOD_CURRENT
      , "SignalTrend"
      , iADXPeriod
      , iADXMin
      , iADXMax
      , iATRPeriod
      , iATRMin
      , iMAFastPeriod
      , iMASlowPeriod);
      
   if (signalHandle == INVALID_HANDLE) {
      Alert("Não foi possível criar o handle do indicador: ", GetLastError());
      return INIT_FAILED;
   } else {
      PrepareTrade(iEAMagic);
   
      return INIT_SUCCEEDED;
   }
}

void OnDeinit(const int reason) {
   IndicatorRelease(signalHandle);
}

void OnTick() {
   if (IsClose() && CheckPosition()) trade.PositionClose(_Symbol, 50);
   
   if (IsOpen()) {
      if (!CheckNewBar()) return;
      if (!UpdateLatestPrice()) return;
      if (CheckLimits()) return;
      
      if (CopyBuffer(signalHandle, 1, 1, 1, buySignalVal) != 1) {
         Alert("Erro ao copiar o buffer para compra: ", GetLastError(), "!");
         ResetLastError();
         return;
      }
         
      if (CopyBuffer(signalHandle, 0, 1, 1, sellSignalVal) != 1) {
         Alert("Erro ao copiar o buffer para venda: ", GetLastError(), "!");
         ResetLastError();
         return;
      }
      
      ArraySetAsSeries(buySignalVal, true);
      ArraySetAsSeries(sellSignalVal, true);
       
      CheckPosition();
      MoveStopLoss();
      
      bool buySignal = buySignalVal[0] > 0.0;
      bool sellSignal = sellSignalVal[0] > 0.0;
      
      if ((buySignal && sellOpened) || (sellSignal && buyOpened)) CloseAllPosition();
      
      if (buySignal) {
         if (buyOpened) {
            return;
         } else {
            bool check = Buy();
            
            if (check) {
               Alert("Ordem de compra adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de compra.");
            }
         }
      }
      
      if (sellSignal) {
         if (sellOpened) {
            return;
         } else {
            bool check = Sell();
   
            if (check) {
               Alert("Ordem de venda adicionada com sucesso!");
            } else {
               Alert("Não foi possível realizar a operação de venda.");
            }
         }
      }
   }
}