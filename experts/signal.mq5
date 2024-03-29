//+------------------------------------------------------------------+
//|                                                     SignalEA.mq5 |
//|                                         Matheus Filipe T. Chaves |
//|                                      matheus.ft.chaves@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Matheus Filipe T. Chaves"
#property link      "matheus.ft.chaves@gmail.com"
#property version   "1.00"

#include <BasicEA.mqh>

input int      iSignalPeriod = 49;           // (Signal) Período
input double   iMinSignalStrength = 20.0;    // (Signal) Força mínima do sinal
input int      iEAMagic = 67365161;          // (EA) Magic Number

bool buySignal;
bool sellSignal;
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
      , "Signal"
      , iSignalPeriod
      , iMinSignalStrength);
      
   if (signalHandle == INVALID_HANDLE) {
      Alert("Não foi possível criar o handle do indicador: ", GetLastError());
      return INIT_FAILED;
   } else {
      buySignal = false;
      sellSignal = false;
      
      PrepareTrade(iEAMagic);
   
      return INIT_SUCCEEDED;
   }
}

void OnDeinit(const int reason) {
   IndicatorRelease(signalHandle);
}

void OnTick() {
   if (IsClose() && CheckPosition()) trade.PositionClose(_Symbol, 50);
   
   if (!CheckMinBars(60)) return;
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
   
   buySignal = buySignalVal[0] > 0.0;
   sellSignal = sellSignalVal[0] > 0.0;
   
   if ((buySignal && sellOpened) || (sellSignal && buyOpened)) CloseAllPosition();
   
   if (IsOpen()) {
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
   } else {
      return;
   }
}