Unit AppMessaging;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, IMMessaging, DataProvider;

Type
  { TIMMessageTime }

  TIMMessageTime = Class(TIMMessage)
  Public
    DateTime: TDateTime;
  End;

  { TIMMessageKP }

  TIMMessageKP = Class(TIMMessage)
  Public
    KP: Extended;
  End;

  { TIMMessageDataProviderReady }

  TIMMessageDataProviderReady = Class(TIMMessage)
  Public
    DataProvider: TDataProvider;
  End;

  { TIMMessageFilterChanged }

  TIMMessageFilterChanged = Class(TIMMessage)
  Public
    DataProvider: TDataProvider;
  End;

  { TMessageController }

  { TAppMessageBus }

  TAppMessageBus = Class(TMessageBus)
  Public
    Procedure BroadcastTime(ASender: TObject; ADateTime: TDateTime);
    Procedure BroadcastKP(ASender: TObject; AKP: Extended);
    Procedure BroadcastDataProviderReady(ASender: TObject; ADataProvider: TDataProvider);
    Procedure BroadcastFilterChanged(ASender: TObject; ADataProvider: TDataProvider);
  End;

Implementation

Procedure TAppMessageBus.BroadcastTime(ASender: TObject; ADateTime: TDateTime);
Var
  oMessage: TIMMessageTime;
Begin
  oMessage := TIMMessageTime.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.DateTime := ADateTime;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

Procedure TAppMessageBus.BroadcastDataProviderReady(ASender: TObject;
  ADataProvider: TDataProvider);
Var
  oMessage: TIMMessageDataProviderReady;
Begin
  oMessage := TIMMessageDataProviderReady.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.DataProvider := ADataProvider;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

Procedure TAppMessageBus.BroadcastFilterChanged(ASender: TObject; ADataProvider: TDataProvider);
Var
  oMessage: TIMMessageFilterChanged;
Begin
  oMessage := TIMMessageFilterChanged.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.DataProvider := ADataProvider;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

Procedure TAppMessageBus.BroadcastKP(ASender: TObject; AKP: Extended);
Var
  oMessage: TIMMessageKP;
Begin
  oMessage := TIMMessageKP.Create;
  Try
    oMessage.Sender := ASender;
    oMessage.KP := AKP;

    Broadcast(oMessage);
  Finally
    oMessage.Free;
  End;
End;

End.
