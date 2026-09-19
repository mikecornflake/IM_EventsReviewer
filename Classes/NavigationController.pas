Unit NavigationController;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, fgl;

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

  { TRegisteredItem }

  TRegisteredItem = Class
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

    Procedure Register(AMessageClass: TIMMessageClass; ACallback: TNotifyEvent);
    Procedure Broadcast(AMessage: TIMMessage);
  End;

Implementation

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
var
  oMessage: TIMMessageTime;
begin
  oMessage := TIMMessageTime.Create;
  oMessage.Sender := ASender;
  oMessage.DateTime:=ADateTime;

  Broadcast(oMessage);
end;

Procedure TMessageController.Register(AMessageClass: TIMMessageClass; ACallback: TNotifyEvent);
Var
  oRegisterItem: TRegisteredItem;
Begin
  oRegisterItem := TRegisteredItem.Create;
  oRegisterItem.MessageClass := AMessageClass;
  oRegisterItem.Callback := ACallback;
  FRegister.Add(oRegisterItem);
End;

Procedure TMessageController.Broadcast(AMessage: TIMMessage);
Var
  oRegisterItem: TRegisteredItem;
Begin
  For oRegisterItem In FRegister Do
    If AMessage Is oRegisterItem.MessageClass Then
      oRegisterItem.Callback(AMessage);
End;

End.
