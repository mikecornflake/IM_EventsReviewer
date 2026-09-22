Unit DataProvider;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, MediaTypes, DB, BufDataset, Inifiles,
  IMMessaging, AppMessaging, FramePipelineView;

Type
  TDataChangedEvent = Procedure(Sender: TObject; Const AAnomalyReference: String;
    Const ADateTime: TDateTime) Of Object;

  { IIM_Persistent }
  IIM_Persistent = Interface
    Procedure LoadSettings(AInifile: TIniFile);
    Procedure SaveSettings(AInifile: TIniFile);
  End;

  { TDataProvider }
  TDataProvider = Class(TObject, IIM_Persistent)
  private
  Protected
    // FIELDNAMES
    FFieldStartKP, FFieldStartTime, FFieldAnomalyReference: String;

    // State
    FLoaded: Boolean;
    FFilter: String;

    // While the Master Events dataset will vary between implementations
    // the Filtered dataset will always be a TBufDataset
    FFilteredDataset: TBufDataset;
    FUpdatingFilteredDataset: Boolean;
    FUpdatingMasterDataset: Boolean;

    FOnProviderReady: TNotifyEvent;
    FOnDataChanged: TDataChangedEvent;

    Function GetDataSet: TDataSet; Virtual; Abstract;

    Function GetFiltered: Boolean;
    Procedure SetFilter(Const AValue: String);
    Function GetFilter: String; Virtual;

    Procedure DoProviderReady;

    Function GetReady: Boolean; Virtual; Abstract;

    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnDataChanged: TDataChangedEvent;
    Procedure SetOnDataChanged(AValue: TDataChangedEvent);

    Procedure DoReceiveTimeSeekMessage(AMessage: TIMMessage);

    Procedure DoMasterChanged(Const AAnomalyReference: String; Const ADateTime: TDateTime);
    Procedure DoMasterAfterScroll(ADataSet: TDataSet);
    Procedure DoFilterAfterScroll(ADataSet: TDataSet);

    // For both Filtered and Master datasets
    Procedure DoDatasetAfterOpen(ADataSet: TDataSet);
    Procedure DoDatasetApplyFormats(ADataset: TDataset); Virtual;
  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Function Open: Boolean; Virtual; Abstract;
    Function Refresh: Boolean; Virtual; Abstract;
    Function Close: Boolean; Virtual; Abstract;

    Function Title: String; Virtual; Abstract;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Virtual; Abstract;

    Function PopulatePipelineView(APipelineView: TFramePipelineView): Boolean;  Virtual;

    Function DateTime: TDateTime;
    Function AnomalyReference: String;

    Procedure LoadSettings(AInifile: TIniFile); Virtual; Abstract;
    Procedure SaveSettings(AInifile: TIniFile); Virtual; Abstract;

    // Properties
    Property Ready: Boolean Read GetReady;

    Property DataSet: TDataSet Read GetDataSet;

    Property FilteredDataSet: TBufDataset Read FFilteredDataset;
    Property Filtered: Boolean Read GetFiltered;
    Property Filter: String Read FFilter Write SetFilter;

    // Events
    Property OnProviderReady: TNotifyEvent Read GetOnProviderReady Write SetOnProviderReady;
    Property OnDataChanged: TDataChangedEvent Read GetOnDataChanged Write SetOnDataChanged;
  End;

Implementation

Uses
  FormEventsReviewer, DBSupport;

  { TDataProvider }

Constructor TDataProvider.Create;
Begin
  // Default fieldnames
  FFieldStartKP := 'KP';
  FFieldStartTime := 'Start_(UTC)';
  FFieldAnomalyReference := 'Anomaly_No';

  // Dataset and dataset management
  FFilteredDataset := TBufDataset.Create(nil);
  FFilteredDataset.AfterScroll := @DoFilterAfterScroll;
  FFilteredDataset.AfterOpen := @DoDatasetAfterOpen;
  FUpdatingFilteredDataset := False;
  FUpdatingMasterDataset := False;

  // Messages
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveTimeSeekMessage);
End;

Destructor TDataProvider.Destroy;
Begin
  FreeAndNil(FFilteredDataset);

  Inherited Destroy;
End;

Function TDataProvider.PopulatePipelineView(APipelineView: TFramePipelineView): Boolean;
Var
  bmOriginal: TBookMark;
  oKP, oLen, oType, oAnom: TField;
  sType: String;
  dKP, dLen: Extended;
begin
  Result := False;

  APipelineView.Clear;

  If Not Dataset.Active Then
    Exit;

  frmEventsReviewer.Status := 'Loading chart';

  oKP := Dataset.FieldByName(FFieldStartKP);
  oLen := Dataset.FieldByName('Length_(m)');
  oType := Dataset.FieldByName('Type');
  oAnom := Dataset.FieldByName('Anomaly');

  Dataset.DisableControls;
  bmOriginal := Dataset.GetBookmark;
  Try
    Dataset.First;
    APipelineView.BeginUpdate;

    While Not Dataset.EOF Do
    Begin
      sType := oType.AsString;
      dKP := oKP.AsExtended;
      If (oLen.IsNull) Or (oLen.AsFloat <= 1) Then
        dLen := 0.001
      Else
        dLen := oLen.AsFloat / 1000;

      // Starfix Database processing only...
      If sType.Contains(' Joint') Then
        sType := 'Fieldjoint';

      // Starfix Database processing only...
      If sType.EndsWith(' Start') Then
        sType.Replace(' Start', '');

      // Starfix Database processing only...
      If Not sType.Contains(' End') Then
        APipelineView.AddData(sType, dKP, dLen, (oAnom.AsString = 'Y'));

      Dataset.Next;
    End;
    Dataset.GotoBookmark(bmOriginal);
  Finally
    Dataset.FreeBookmark(bmOriginal);
    Dataset.EnableControls;
    APipelineView.EndUpdate;

    frmEventsReviewer.Status := '';
  End;
end;

Function TDataProvider.GetFiltered: Boolean;
Begin
  Result := Trim(FFilter) <> '';
End;

Procedure TDataProvider.SetFilter(Const AValue: String);
Begin
  FFilter := AValue;

  If Filtered Then
  Begin
    BuildFilteredDataset(DataSet, FFilteredDataset, AValue);

    FFilteredDataset.Open;
  End
  Else If FFilteredDataset.Active Then
    FFilteredDataset.Close;

  frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageFilterChanged);
End;

Function TDataProvider.GetFilter: String;
Begin
  Result := FFilter;
End;

Procedure TDataProvider.DoProviderReady;
Begin
  If Assigned(FOnProviderReady) Then
    FOnProviderReady(Self);
End;

Function TDataProvider.GetOnProviderReady: TNotifyEvent;
Begin
  Result := FOnProviderReady;
End;

Procedure TDataProvider.SetOnProviderReady(AValue: TNotifyEvent);
Begin
  FOnProviderReady := AValue;
End;

Function TDataProvider.GetOnDataChanged: TDataChangedEvent;
Begin
  Result := FOnDataChanged;
End;

Procedure TDataProvider.SetOnDataChanged(AValue: TDataChangedEvent);
Begin
  FOnDataChanged := AValue;
End;

Function TDataProvider.DateTime: TDateTime;
Begin
  If Ready And Assigned(DataSet) And (DataSet.Active) And (DataSet.RecordCount > 0) Then
    Result := DataSet.FieldByName(FFieldStartTime).AsDateTime
  Else
    Result := 0;
End;

Function TDataProvider.AnomalyReference: String;
Begin
  If Ready And Assigned(DataSet) And (DataSet.Active) And (DataSet.RecordCount > 0) Then
    Result := DataSet.FieldByName(FFieldAnomalyReference).AsString
  Else
    Result := '';
End;

// AAnomalyNo (aka Anomaly Reference) is not guaranteed to be set
Procedure TDataProvider.DoMasterChanged(Const AAnomalyReference: String;
  Const ADateTime: TDateTime);
Begin
  If Assigned(FOnDataChanged) Then
    FOnDataChanged(Self, AAnomalyReference, ADateTime);
End;

Procedure TDataProvider.DoMasterAfterScroll(ADataSet: TDataSet);
Var
  sAnomalyNo: String;
  dtDateTime: TDateTime;
  dKP: Extended;
Begin
  If Ready And Assigned(FOnDataChanged) And Not ADataSet.ControlsDisabled Then
  Begin
    sAnomalyNo := ADataSet.FieldByName(FFieldAnomalyReference).AsString;
    dtDateTime := ADataSet.FieldByName(FFieldStartTime).AsDateTime;
    dKP := ADataSet.FieldByName(FFieldStartKP).AsExtended;

    DoMasterChanged(sAnomalyNo, dtDateTime);

    If Not FUpdatingMasterDataset Then
      frmEventsReviewer.MessageBus.BroadcastTime(Self, dtDateTime);

    frmEventsReviewer.MessageBus.BroadcastKP(Self, dKP);
  End;
End;

// Keep the Master Events synchronised with the filtered dataset
Procedure TDataProvider.DoFilterAfterScroll(ADataSet: TDataSet);
Begin
  If FUpdatingFilteredDataset Then
    Exit;

  If Not ADataSet.ControlsDisabled And Ready And DataSet.Active And FFilteredDataset.Active Then
    DataSet.RecNo := FFilteredDataset.FieldByName(MASTER_RECNO_FIELD).AsInteger;
End;

// If supported, set known fields to valid formats
Procedure TDataProvider.DoDatasetAfterOpen(ADataSet: TDataSet);
Begin
  DoDatasetApplyFormats(ADataset);
End;

Procedure TDataProvider.DoDatasetApplyFormats(ADataset: TDataset);
Var
  oField: TField;
Begin
  For oField In ADataSet.Fields Do
    If (oField Is TFloatField) Then
    Begin
      If (oField.FieldName = FFieldStartKP) Then
        TFloatField(oField).DisplayFormat := '0.000'
      Else
        TFloatField(oField).DisplayFormat := '0.00';
    End;
End;

Procedure TDataProvider.DoReceiveTimeSeekMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageTime;
  oKP: TField;
  dStartKP: Extended;
  dtThreshold: TDateTime;
Begin
  If Not (AMessage Is TIMMessageTime) Then
    Exit;

  If Ready And (DataSet.Active) And (DataSet.RecordCount > 0) Then
  Begin
    oMessage := TIMMessageTime(AMessage);

    // Are we being asked to jump to a potentially distant point on the video?
    // If yes - ensure UI syncs to nearest event
    // otherwise - only sync to next event if we're now within 10 seconds
    If frmEventsReviewer.ExactTimeSeek Then
      dtThreshold := -1
    Else
      dtThreshold := 10 / SecsPerDay;

    oKP := DataSet.FieldByName(FFieldStartKP);
    dStartKP := oKP.AsExtended;

    // Check FUpdatingMasterDataset when responding to subsequence seektime requests
    // if FUpdatingMasterDataset is true, then we know we made the call and don't need
    // to respond
    FUpdatingMasterDataset := True;
    Try
      If GotoNearestTime(DataSet, FFieldStartTime, oMessage.DateTime, dtThreshold) Then
      Begin
        // The above suppressed OnAfterScroll, so we need to manually raise
        DoMasterAfterScroll(DataSet);
      End;
    Finally
      FUpdatingMasterDataset := False;
    End;

    If Filtered Then
    Begin
      // Check FUpdatingFilteredDataset when responding to subsequence seektime requests
      // if FUpdatingFilteredDataset is true, then we know we made the call and don't need
      // to respond
      FUpdatingFilteredDataset := True;
      Try
        GotoNearestTime(FFilteredDataset, FFieldStartTime, oMessage.DateTime, dtThreshold);
      Finally
        FUpdatingFilteredDataset := False;
      End;
    End;

    If (abs(dStartKP - oKP.AsExtended) > 0.001) Then
      frmEventsReviewer.MessageBus.BroadcastKP(Self, oKP.AsExtended);
  End;
End;

End.
