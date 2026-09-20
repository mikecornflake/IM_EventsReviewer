Unit NavigationController;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl, DataProvider;

Type

  { TIMMessage }

  TIMMessage = Class
  Public
    Sender: TObject;
  End;

  TIMMessageClass = Class Of TIMMessage;

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

  { TRegisteredItem }

  TRegisteredItem = Class
    Requester: TObject;
    MessageClass: TIMMessageClass;
    Callback: TNotifyEvent;
  End;

  { TMessageRegister }

  TMessageRegister = Class(Specialize TFPGObjectList<TRegisteredItem>);

  { TMessageController }

  TMessageController = Class
  Private
    FRegister: TMessageRegister;
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Procedure BroadcastTime(ASender: TObject; ADateTime: TDateTime);
    Procedure BroadcastDataProviderReady(ASender: TObject; ADataProvider: TDataProvider);
    Procedure BroadcastKP(ASender: TObject; AKP: Extended);

    Procedure Register(ARequester: TObject; AMessageClass: TIMMessageClass;
      ACallback: TNotifyEvent);
    Procedure Broadcast(AMessage: TIMMessage);
  End;

Implementation

Uses LazLogger;

  { TMessageController }

Constructor TMessageController.Create;
Begin
  FRegister := TMessageRegister.Create(True);
End;

Destructor TMessageController.Destroy;
Begin
  FreeAndNil(FRegister);
  Inherited Destroy;
End;

Procedure TMessageController.BroadcastTime(ASender: TObject; ADateTime: TDateTime);
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

Procedure TMessageController.BroadcastDataProviderReady(ASender: TObject;
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

Procedure TMessageController.BroadcastKP(ASender: TObject; AKP: Extended);
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

Procedure TMessageController.Register(ARequester: TObject; AMessageClass: TIMMessageClass;
  ACallback: TNotifyEvent);
Var
  oRegisterItem: TRegisteredItem;
Begin
  oRegisterItem := TRegisteredItem.Create;
  oRegisterItem.Requester := ARequester;
  oRegisterItem.MessageClass := AMessageClass;
  oRegisterItem.Callback := ACallback;
  FRegister.Add(oRegisterItem);
End;

Procedure TMessageController.Broadcast(AMessage: TIMMessage);
Var
  oRegisterItem: TRegisteredItem;
Begin
  For oRegisterItem In FRegister Do
    If (AMessage.Sender <> oRegisterItem.Requester) And
      (AMessage Is oRegisterItem.MessageClass) Then
    Begin
      {$IFNDEF RELEASE}
      DebugLn([ClassName, '.', {$I %CURRENTROUTINE%}, ' Sending ',
        AMessage.ClassName, ' from ', AMessage.Sender.ClassName, ' to ',
        oRegisterItem.Requester.ClassName]);
      {$ENDIF}

      oRegisterItem.Callback(AMessage);
    End;
End;

End.
