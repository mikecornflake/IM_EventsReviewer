Unit DataProvider;

{$mode ObjFPC}{$H+}
{$interfaces corba}

Interface

Uses
  Classes, SysUtils, MediaTypes, DB, BufDataset, Inifiles,
  IMMessaging, AppMessaging, FramePipelineView, DataFilters;

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
  Protected
    // FIELDNAMES
    FFieldStartKP, FFieldStartTime, FFieldAnomalyReference: String;

    // State
    FLoaded: Boolean;

    // Filters
    FFilter: String;
    FDataFilters: TDataFilters;

    // While the Master Events dataset will vary between implementations
    // the Filtered dataset will always be a TBufDataset
    FFilteredDataset: TBufDataset;
    FUpdatingFilteredDataset: Boolean;
    FUpdatingMasterDataset: Boolean;

    FOnProviderReady: TNotifyEvent;
    FOnDataChanged: TDataChangedEvent;

    Function ProcessEventnameForReport(Var AType: String): Boolean; Virtual;

    Function GetDataSet: TDataSet; Virtual; Abstract;

    Function GetFiltered: Boolean;
    Procedure SetFilter(Const AValue: String);
    Function GetFilter: String; Virtual;

    Procedure DoDataFilterExecute(Sender: TObject); Virtual;

    Procedure DoProviderReady;

    Function GetReady: Boolean; Virtual; Abstract;

    Function GetOnProviderReady: TNotifyEvent;
    Procedure SetOnProviderReady(AValue: TNotifyEvent);

    Function GetOnDataChanged: TDataChangedEvent;
    Procedure SetOnDataChanged(AValue: TDataChangedEvent);

    Procedure DoReceiveSeekTimeMessage(AMessage: TIMMessage);
    Procedure DoReceiveSeekKPMessage(AMessage: TIMMessage);

    Procedure DoMasterChanged(Const AAnomalyReference: String; Const ADateTime: TDateTime);
    Procedure DoMasterAfterScroll(ADataSet: TDataSet);
    Procedure DoFilterAfterScroll(ADataSet: TDataSet);

    // For both Filtered and Master datasets
    Procedure DoDatasetAfterOpen(ADataSet: TDataSet);
    Procedure DoDatasetApplyFormats(ADataSet: TDataSet); Virtual;

    // State Management
    Procedure GotoNearestValue(AFieldname: String; AValue: Double; AThreshold: Double);
  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Function Open: Boolean; Virtual; Abstract;
    Function Refresh: Boolean; Virtual; Abstract;
    Function Close: Boolean; Virtual; Abstract;

    Function Title: String; Virtual; Abstract;

    Function GetVideoFilesForTime(Const ADateTime: TDateTime): TVideoFiles; Virtual; Abstract;

    Function PopulatePipelineView(APipelineView: TFramePipelineView): Boolean; Virtual;

    // Filters are options presented to the user interface.
    // If the user wants to apply a filter, it's up to the UI to pass the correct filter
    // back to the DataProvider
    // Naming them DataFilters during development to avoid confusion with existing
    // Filters
    Procedure ApplyDataFilter(ADataFilter: TDataFilter); Virtual;

    Function DateTime: TDateTime;
    Function AnomalyReference: String;

    Procedure LoadSettings(AInifile: TIniFile); Virtual; Abstract;
    Procedure SaveSettings(AInifile: TIniFile); Virtual; Abstract;

    Property DataFilters: TDataFilters Read FDataFilters;

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
  FormEventsReviewer, DBSupport, Menus;

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

  // Filters
  FDataFilters := TDataFilters.Create(True);

  // Messages
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageTime, @DoReceiveSeekTimeMessage);
  frmEventsReviewer.MessageBus.Subscribe(Self, TIMMessageKP, @DoReceiveSeekKPMessage);
End;

Destructor TDataProvider.Destroy;
Begin
  FreeAndNil(FDataFilters);
  FreeAndNil(FFilteredDataset);

  Inherited Destroy;
End;

Function TDataProvider.PopulatePipelineView(APipelineView: TFramePipelineView): Boolean;
Var
  bmOriginal: TBookMark;
  oKP, oLen, oType, oAnom: TField;
  sType: String;
  dKP, dLen: Extended;
Begin
  Result := False;

  APipelineView.Clear;

  If Not DataSet.Active Then
    Exit;

  frmEventsReviewer.Status := 'Loading chart';

  oKP := DataSet.FieldByName(FFieldStartKP);
  oLen := DataSet.FieldByName('Length_(m)');
  oType := DataSet.FieldByName('Type');
  oAnom := DataSet.FieldByName('Anomaly');

  DataSet.DisableControls;
  bmOriginal := DataSet.GetBookmark;
  Try
    DataSet.First;
    APipelineView.BeginUpdate;

    While Not DataSet.EOF Do
    Begin
      sType := oType.AsString;
      dKP := oKP.AsExtended;
      If (oLen.IsNull) Or (oLen.AsFloat <= 1) Then
        dLen := 0.001
      Else
        dLen := oLen.AsFloat / 1000;

      If ProcessEventnameForReport(sType) Then
        APipelineView.AddData(sType, dKP, dLen, (oAnom.AsString = 'Y'));

      DataSet.Next;
    End;
    DataSet.GotoBookmark(bmOriginal);
  Finally
    DataSet.FreeBookmark(bmOriginal);
    DataSet.EnableControls;
    APipelineView.EndUpdate;

    frmEventsReviewer.Status := 'Finished loading chart';
    frmEventsReviewer.Status := '';
  End;
End;

Procedure TDataProvider.ApplyDataFilter(ADataFilter: TDataFilter);
Begin

End;

Function TDataProvider.ProcessEventnameForReport(Var AType: String): Boolean;
Begin
  Result := True;
End;

Function TDataProvider.GetFiltered: Boolean;
Begin
  Result := Trim(FFilter) <> '';
End;

Procedure TDataProvider.SetFilter(Const AValue: String);
Var
  dtCurrent: TDateTime;
Begin
  FFilter := AValue;

  dtCurrent := DateTime;

  If Filtered Then
  Begin
    BuildFilteredDataset(DataSet, FFilteredDataset, AValue);

    FFilteredDataset.Open;
  End
  Else If FFilteredDataset.Active Then
    FFilteredDataset.Close;

  frmEventsReviewer.MessageBus.Broadcast(Self, TIMMessageFilterChanged);

  // -1 means "closest"
  GotoNearestValue(FFieldStartTime, dtCurrent, -1);
End;

Procedure TDataProvider.GotoNearestValue(AFieldname: String; AValue: Double; AThreshold: Double);
Var
  bMoved: Boolean;
Begin
  If Filtered Then
  Begin
    FUpdatingFilteredDataset := True;
    Try
      bMoved := DBSupport.GotoNearestValue(FFilteredDataset, AFieldname, AValue, AThreshold);
    Finally
      FUpdatingFilteredDataset := False;
    End;

    // This was suppressed by the above and by FUpdatingFilteredDataset,
    //  This call is sufficent to keep the Master scrolled to correct record
    If bMoved Then
      DoFilterAfterScroll(FFilteredDataset);
  End
  Else
  Begin
    FUpdatingMasterDataset := True;
    Try
      If DBSupport.GotoNearestValue(DataSet, AFieldname, AValue, AThreshold) Then
      Begin
        // The above suppressed OnAfterScroll, so we need to manually raise
        // This time within the protection of FUpdatingMasterDataset
        DoMasterAfterScroll(DataSet);
      End;
    Finally
      FUpdatingMasterDataset := False;
    End;
  End;
End;

Function TDataProvider.GetFilter: String;
Begin
  Result := FFilter;
End;

Procedure TDataProvider.DoDataFilterExecute(Sender: TObject);
Var
  oFilter: TDataFilter;
Begin
  If Not (Sender Is TMenuItem) Then
    Exit;

  oFilter := TDataFilter(TMenuItem(Sender).Tag);

  Filter := oFilter.Filter;
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
  DoDatasetApplyFormats(ADataSet);
End;

Procedure TDataProvider.DoDatasetApplyFormats(ADataSet: TDataSet);
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

Procedure TDataProvider.DoReceiveSeekTimeMessage(AMessage: TIMMessage);
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

    GotoNearestValue(FFieldStartTime, oMessage.DateTime, dtThreshold);

    If (abs(dStartKP - oKP.AsExtended) > 0.001) Then
      frmEventsReviewer.MessageBus.BroadcastKP(Self, oKP.AsExtended);
  End;
End;

Procedure TDataProvider.DoReceiveSeekKPMessage(AMessage: TIMMessage);
Var
  oMessage: TIMMessageKP;
  oTime: TField;
  dtTime: TDateTime;
  dtThreshold: Extended;
Begin
  If Not (AMessage Is TIMMessageKP) Then
    Exit;

  If Ready And (DataSet.Active) And (DataSet.RecordCount > 0) Then
  Begin
    oMessage := TIMMessageKP(AMessage);

    oTime := DataSet.FieldByName(FFieldStartTime);
    dtTime := oTime.AsDateTime;
    dtThreshold := 0.001; // Nearest m

    GotoNearestValue(FFieldStartKP, oMessage.KP, dtThreshold);

    If (abs(dtTime - oTime.AsDateTime) > (1 / SecsPerDay)) Then
      frmEventsReviewer.MessageBus.BroadcastTime(Self, oTime.AsDateTime);
  End;
End;

End.
