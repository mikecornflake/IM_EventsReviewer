Unit FrameCampaignRules;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons, ComCtrls, FrameBase,
  CampaignRules;

Type

  { TfmeCampaignRules }

  TfmeCampaignRules = Class(TFrameBase)
    edtDisplayname: TEdit;
    ImageList1: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    lbRules: TListBox;
    memIncludeKeywords: TMemo;
    memExcludeKeywords: TMemo;
    ToolBar1: TToolBar;
    btnAddRule: TToolButton;
    btnDeleteRule: TToolButton;
    ToolButton1: TToolButton;
    btnUp: TToolButton;
    btnDown: TToolButton;
    Procedure btnAddRuleClick(Sender: TObject);
    Procedure btnDeleteRuleClick(Sender: TObject);
    Procedure btnDownClick(Sender: TObject);
    Procedure btnUpClick(Sender: TObject);
    procedure lbRulesClick(Sender: TObject);
    procedure lbRulesSelectionChange(Sender: TObject; User: boolean);
    Procedure RuleChanged(Sender: TObject);
  Private
    FCampaignEventRules: TCampaignEventRules;
    FLoadingRule: Boolean;

    Procedure LoadRule(ACampaignEventRule: TCampaignEventRule);
    Procedure LoadRules;
    Procedure SaveRule;
  Public
    Constructor Create(TheOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure RefreshUI; Override;

    Procedure CopyFrom(ASource: TCampaignEventRules);

    // We'll have our own copy
    Property CampaignEventRules: TCampaignEventRules Read FCampaignEventRules;
  End;

Implementation

{$R *.lfm}

{ TfmeCampaignRules }

Constructor TfmeCampaignRules.Create(TheOwner: TComponent);
Begin
  Inherited Create(TheOwner);

  FCampaignEventRules := TCampaignEventRules.Create(True);
End;

Destructor TfmeCampaignRules.Destroy;
Begin
  FreeAndNil(FCampaignEventRules);

  Inherited Destroy;
End;

Procedure TfmeCampaignRules.CopyFrom(ASource: TCampaignEventRules);
begin
  FCampaignEventRules.CopyFrom(ASource);

  LoadRules;
end;

Procedure TfmeCampaignRules.LoadRules;
Var
  oRule: TCampaignEventRule;
Begin
  lbRules.Items.Clear;

  For oRule In FCampaignEventRules Do
    lbRules.Items.Add(oRule.DisplayName);

  If lbRules.Items.Count > 0 Then
  Begin
    lbRules.ItemIndex := 0;
    LoadRule(FCampaignEventRules[0]);
  End;

  RefreshUI;
End;

Procedure TfmeCampaignRules.RefreshUI;
Begin
  Inherited RefreshUI;

  btnAddRule.Enabled := True;
  btnDeleteRule.Enabled := (lbRules.ItemIndex >= 0) And (lbRules.ItemIndex < lbRules.Items.Count);

  btnUp.Enabled := (lbRules.ItemIndex > 0) And (lbRules.ItemIndex < lbRules.Items.Count);
  btnDown.Enabled := (lbRules.ItemIndex >= 0) And (lbRules.ItemIndex < lbRules.Items.Count - 1);

  edtDisplayname.Enabled := btnDeleteRule.Enabled;
  memIncludeKeywords.Enabled := btnDeleteRule.Enabled;
  memExcludeKeywords.Enabled := btnDeleteRule.Enabled;
End;

Procedure TfmeCampaignRules.LoadRule(ACampaignEventRule: TCampaignEventRule);
Begin
  FLoadingRule := True;
  Try
    If Assigned(ACampaignEventRule) Then
    Begin
      edtDisplayname.Text := ACampaignEventRule.DisplayName;
      memIncludeKeywords.Lines.Assign(ACampaignEventRule.IncludeKeywords);
      memExcludeKeywords.Lines.Assign(ACampaignEventRule.ExcludeKeywords);
    End
    Else
    Begin
      edtDisplayname.Clear;
      memIncludeKeywords.Clear;
      memExcludeKeywords.Clear;
    End;
  Finally
    FLoadingRule := False;
  End;
End;

Procedure TfmeCampaignRules.SaveRule;
Var
  oRule: TCampaignEventRule;
Begin
  If (lbRules.ItemIndex >= 0) And (lbRules.ItemIndex < lbRules.Items.Count) Then
  Begin
    oRule := FCampaignEventRules[lbRules.ItemIndex];
    oRule.DisplayName := edtDisplayname.Text;
    oRule.IncludeKeywords.Assign(memIncludeKeywords.Lines);
    oRule.ExcludeKeywords.Assign(memExcludeKeywords.Lines);
  End;
End;

Procedure TfmeCampaignRules.btnAddRuleClick(Sender: TObject);
Var
  oRule: TCampaignEventRule;
Begin
  oRule := TCampaignEventRule.Create;
  oRule.DisplayName := 'New Rule';

  FCampaignEventRules.Add(oRule);

  lbRules.Items.Add(oRule.DisplayName);
  lbRules.ItemIndex := lbRules.Items.Count - 1;

  LoadRule(oRule);
  RefreshUI;

  edtDisplayname.SetFocus;
  edtDisplayname.SelectAll;
End;

Procedure TfmeCampaignRules.btnDeleteRuleClick(Sender: TObject);
Var
  i: Integer;
Begin
  i := lbRules.ItemIndex;
  If (i < 0) Or (i >= FCampaignEventRules.Count) Then
    Exit;

  FCampaignEventRules.Delete(i);
  lbRules.Items.Delete(i);

  // Select the next rule, or the previous one if we deleted the last
  If i >= lbRules.Items.Count Then
    i := lbRules.Items.Count - 1;

  lbRules.ItemIndex := i;

  If i >= 0 Then
    LoadRule(FCampaignEventRules[i])
  Else
    LoadRule(nil);

  RefreshUI;
End;

Procedure TfmeCampaignRules.btnUpClick(Sender: TObject);
Var
  i: Integer;
Begin
  i := lbRules.ItemIndex;
  If (i <= 0) Or (i >= FCampaignEventRules.Count) Then
    Exit;

  FCampaignEventRules.Exchange(i, i - 1);
  lbRules.Items.Exchange(i, i - 1);

  lbRules.ItemIndex := i - 1;
  RefreshUI;
End;

procedure TfmeCampaignRules.lbRulesClick(Sender: TObject);
Begin

End;

procedure TfmeCampaignRules.lbRulesSelectionChange(Sender: TObject; User: boolean);
begin
  If (lbRules.ItemIndex >= 0) And
     (lbRules.ItemIndex < FCampaignEventRules.Count) Then
    LoadRule(FCampaignEventRules[lbRules.ItemIndex]);

  RefreshUI;
end;

Procedure TfmeCampaignRules.btnDownClick(Sender: TObject);
Var
  i: Integer;
Begin
  i := lbRules.ItemIndex;
  If (i < 0) Or (i >= FCampaignEventRules.Count - 1) Then
    Exit;

  FCampaignEventRules.Exchange(i, i + 1);
  lbRules.Items.Exchange(i, i + 1);

  lbRules.ItemIndex := i + 1;
  RefreshUI;
End;

Procedure TfmeCampaignRules.RuleChanged(Sender: TObject);
Begin
  If FLoadingRule Then
    Exit;

  SaveRule;

  // DisplayName is also the listbox caption
  If (Sender = edtDisplayname) And (lbRules.ItemIndex >= 0) Then
    lbRules.Items[lbRules.ItemIndex] := edtDisplayname.Text;
End;

End.
