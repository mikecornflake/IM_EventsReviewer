Unit FormStarfixAnomalies;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, Menus, ExtCtrls, IniFiles,
  FormMain, FrameImageViewer,
  mssqlconn, sqldb, dblib, DB;

Type

  { TfrmStarfixAnomalies }

  TfrmStarfixAnomalies = Class(TFormMain)
    mnuExit: TMenuItem;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Separator2: TMenuItem;
    mnuDatabaseOpen: TMenuItem;
    mnuDatabase: TMenuItem;
    Separator1: TMenuItem;
    mnuSettings: TMenuItem;
    Splitter1: TSplitter;
    tsImages: TTabSheet;
    tsVideo: TTabSheet;
    ToolBar1: TToolBar;
    Procedure FormCreate(Sender: TObject);
    Procedure FormDestroy(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure mnuDatabaseOpenClick(Sender: TObject);
    Procedure mnuExitClick(Sender: TObject);
    Procedure mnuSettingsClick(Sender: TObject);
  Private
    // Connection Details
    FDatabaseName, FServer: String;
    FUsername, FPassword: String;
    FPort: Integer;

    // Settings
    FImageFolder: String;
    FMasterFilename: String;

    // Database
    FConnection: TMSSQLConnection;
    FTransaction: TSQLTransaction;
    FDriverFilename: String;

    //UI
    FActivated: Boolean;
    FImageViewer: TFrameImageViewer;
  Protected
    Procedure RefreshUI; Override;

    // Stored in ini file with exe - what folders to load etc
    Procedure LoadGlobalSettings(oInifile: TIniFile); Override;
    Procedure SaveGlobalSettings(oInifile: TIniFile); Override;
  Public

  End;

Var
  frmStarfixAnomalies: TfrmStarfixAnomalies;

Implementation

Uses
  DialogSettings, DialogMSSQLConnection, ThirdPartySupport;

  {$R *.lfm}

  { TfrmStarfixAnomalies }

Procedure TfrmStarfixAnomalies.FormCreate(Sender: TObject);
Begin
  // This isn't going to be app that only an Admin can change settings...
  FAlwaysSaveSettings := True;

  // Register the database driver
  FDriverFilename := '';

  // This is in DialogMSSQLConnection
  If MSSQL.Available And RegisterMSSQLDriver Then
    FDriverFilename := IncludeTrailingBackslash(MSSQL.Folder) + 'dblib.dll';

  // Create the Database Connectin
  FConnection := TMSSQLConnection.Create(Self);
  FTransaction := TSQLTransaction.Create(Self);

  FConnection.Transaction := FTransaction;

  // Third party acknowledgements
  ThirdParties.Include([THIRDPARTY_MSSQL]);

  // UI
  FImageViewer := TFrameImageViewer.Create(tsImages);
  FImageViewer.Parent := tsImages;
  FImageViewer.Align := alClient;

  FActivated := False;
End;

Procedure TfrmStarfixAnomalies.FormDestroy(Sender: TObject);
Begin
  FreeAndNil(FImageViewer);

  If FConnection.Connected Then
    FConnection.Connected := False;

  FreeAndNil(FTransaction);
  FreeAndNil(FConnection);
End;

Procedure TfrmStarfixAnomalies.FormShow(Sender: TObject);
Begin
  If Not FActivated Then
  Begin
    // Test
    FImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0525_20260728202906_Centre.jpg',
      'First Image');
    FImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0525_20260728202944_Centre.jpg',
      'Second Image');
    FImageViewer.AddImage(
      'B:\Code\Compile\Test Data\MEDIA\IMAGES\HD Images\507464_SAIPEM_15_0534_20260728193144_Centre.jpg',
      'Third and absolutely final Image');

    FActivated := True;
  End;
End;

Procedure TfrmStarfixAnomalies.LoadGlobalSettings(oInifile: TIniFile);
Begin
  Inherited LoadGlobalSettings(oInifile);

  // Connection
  FDatabaseName := oInifile.ReadString('Database', 'DatabaseName', '');
  FServer := oInifile.ReadString('Database', 'Server', '');
  FUsername := oInifile.ReadString('Database', 'Username', '');
  FPassword := oInifile.ReadString('Database', 'Password', '');
  FPort := oInifile.ReadInteger('Database', 'Port', 1433);

  // Settings
  FMasterFilename := oInifile.ReadString('Settings', 'MasterFilename', '');
  FImageFolder := oInifile.ReadString('Settings', 'ImageFolder', '');
End;

Procedure TfrmStarfixAnomalies.SaveGlobalSettings(oInifile: TIniFile);
Begin
  // Connection
  oInifile.WriteString('Database', 'DatabaseName', FDatabaseName);
  oInifile.WriteString('Database', 'Server', FServer);
  oInifile.WriteString('Database', 'Username', FUsername);
  oInifile.WriteString('Database', 'Password', FPassword);
  oInifile.WriteInteger('Database', 'Port', FPort);

  // Settings
  oInifile.WriteString('Settings', 'MasterFilename', FMasterFilename);
  oInifile.WriteString('Settings', 'ImageFolder', FImageFolder);

  Inherited SaveGlobalSettings(oInifile);
End;

Procedure TfrmStarfixAnomalies.mnuSettingsClick(Sender: TObject);
Var
  oDlg: TdlgSettings;
Begin
  oDlg := TdlgSettings.Create(Self);
  Try

    // Define settings
    oDlg.MasterFilename := FMasterFilename;
    oDlg.ImageFolder := FImageFolder;

    If oDlg.ShowModal = mrOk Then
    Begin
      // Update settings
      FMasterFilename := oDlg.MasterFilename;
      FImageFolder := oDlg.ImageFolder;
    End;
  Finally
    oDlg.Free;
  End;
End;

Procedure TfrmStarfixAnomalies.RefreshUI;
Begin
  Inherited RefreshUI;

  mnuDatabaseOpen.Enabled := MSSQL.Available;
End;

Procedure TfrmStarfixAnomalies.mnuDatabaseOpenClick(Sender: TObject);
Var
  oDlg: TdlgMSSQLConnection;
Begin
  If MSSQL.Available Then
  Begin
    oDlg := TdlgMSSQLConnection.Create(Self);
    Try
      // Define Connection
      oDlg.Database := FDatabaseName;
      oDlg.Server := FServer;
      oDlg.Port := FPort;
      oDlg.Username := FUsername;
      oDlg.Password := FPassword;

      If oDlg.ShowModal = mrOk Then
      Begin
        // Update Connection
        FDatabaseName := oDlg.Database;
        FServer := oDlg.Server;
        FPort := oDlg.Port;
        FUsername := oDlg.Username;
        FPassword := oDlg.Password;

        // Try to connect to database
        If FConnection.Connected Then
          FConnection.Connected := False;

        If (Pos('\', FServer) > 0) Or (Pos(':', FServer) > 0) Then
          FConnection.Hostname := FServer
        Else
          FConnection.Hostname := Format('%s:%d', [FServer, FPort]);
        FConnection.DatabaseName := FDatabaseName;
        FConnection.Username := FUsername;
        FConnection.Password := FPassword;

        // Here to allow debugging in MS SQL
        FConnection.Params.Clear;
        FConnection.Params.Add('APPLICATIONNAME=' + Copy(Application.Title, 1, 25));

        MainForm.Status := 'Connecting to MS SQL';
        MainForm.Busy := True;
        Try
          Try
            FConnection.Connected := True;

            FTransaction.StartTransaction;
            FConnection.ExecuteDirect('SET CONCAT_NULL_YIELDS_NULL ON');
            FConnection.ExecuteDirect('SET QUOTED_IDENTIFIER ON');
            FConnection.ExecuteDirect('SET ANSI_WARNINGS ON');
            FConnection.ExecuteDirect('SET ANSI_PADDING ON');
            FConnection.ExecuteDirect('SET ANSI_NULLS ON');
            FTransaction.Commit;
          Except
            On E: Exception Do
              ShowMessage(E.Message);
          End;
        Finally
          MainForm.Busy := False;
        End;
      End;
    Finally
      oDlg.Free;
    End;
  End;
End;

Procedure TfrmStarfixAnomalies.mnuExitClick(Sender: TObject);
Begin
  Close;
End;

End.
