{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UMainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ActiveX,
  Winapi.WebView2,
  System.UITypes,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.Menus,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Edge,
  Dlluminator.CImporter;

type
  TForm1 = class(TForm)
    MainMenu: TMainMenu;
    File1: TMenuItem;
    Quit1: TMenuItem;
    EdgeBrowser: TEdgeBrowser;
    StatusBar: TStatusBar;
    About1: TMenuItem;
    procedure Quit1Click(Sender: TObject);
    procedure About1Click(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FOpenDialog: TOpenDialog;
    FSaveDialog: TSaveDialog;
    FHtmlFolder: string;
    FSettingsFile: string;
    FLogPanelHeight: Integer;
    FTccPath: string;
    FGenerating: Boolean;
    FMappingReady: Boolean;
    FDirty: Boolean;

    // EdgeBrowser event handlers (assigned in code)
    procedure EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs);

    // Message dispatch
    procedure HandleWebMessage(const AJsonStr: string);
    procedure SendToJS(const AJsonMsg: string);

    // Browse commands
    procedure CmdBrowseHeader(const AInitialDir: string);
    procedure CmdBrowseDll(const AInitialDir: string);
    procedure CmdBrowseOutput(const AInitialDir: string);
    procedure CmdBrowseInclude(const AInitialDir: string);
    procedure CmdBrowseSource(const AInitialDir: string);

    // Config commands
    procedure CmdLoadConfig(const AInitialDir: string);
    procedure CmdSaveConfig(const AConfigJson: string;
      const AInitialPath: string);

    // Generate command
    procedure CmdGenerate(const AConfigJson: string;
      const AModes: TArray<string>);

    // CImporter helpers
    procedure ConfigureImporter(const AImporter: TDlmCImporter;
      const AConfigJson: string);
    function StringToBindingMode(const AValue: string): TDlmBindingMode;
    function BindingModeSuffix(const AMode: TDlmBindingMode): string;
    function BuildConfigJsonFromToml(const AFilename: string): string;

    // Helpers
    procedure SetStatusText(const AText: string);
    function BrowseForFile(const ATitle: string;
      const AFilter: string; const AInitialDir: string = ''): string;
    function BrowseForFolder(const ATitle: string;
      const AInitialDir: string = ''): string;
    function ExtractDirFromPath(const APath: string): string;

    // Settings persistence
    procedure LoadSettings();
    procedure SaveSettings();
    procedure ShowAbout();
    procedure AboutLinkClick(Sender: TObject);
  protected
    procedure Loaded(); override;
  public
    procedure AfterConstruction(); override;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  System.JSON,
  System.IOUtils,
  Winapi.ShellAPI,
  Dlluminator,
  Dlluminator.Config,
  Dlluminator.Utils,
  UMessageProtocol;

{ -------------------------------------------------------------------------- }
{ Initialization — called after form and all DFM streaming is complete       }
{ -------------------------------------------------------------------------- }

procedure TForm1.Loaded();
var
  LExeDir: string;
begin
  LExeDir := TPath.GetDirectoryName(Application.ExeName);
  EdgeBrowser.UserDataFolder := TPath.Combine(LExeDir, 'WebView2Data');

  // Assign all events before browser init
  EdgeBrowser.OnCreateWebViewCompleted := EdgeCreateWebViewCompleted;
  EdgeBrowser.OnNavigationCompleted := EdgeNavigationCompleted;
  EdgeBrowser.OnWebMessageReceived := EdgeWebMessageReceived;
  inherited;
end;

procedure TForm1.AfterConstruction();
var
  LExeDir: string;
begin
  inherited;

  FGenerating := False;
  FMappingReady := False;
  FDirty := False;
  FLogPanelHeight := 140;
  FTccPath := '..\..\..\tinycc';

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Options := [ofFileMustExist, ofPathMustExist, ofEnableSizing];

  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Options := [ofOverwritePrompt, ofPathMustExist, ofEnableSizing];

  LExeDir := TPath.GetDirectoryName(Application.ExeName);
  FHtmlFolder := TPath.GetFullPath(TPath.Combine(LExeDir, '..\html'));
  FSettingsFile := TPath.Combine(LExeDir,
    TPath.GetFileNameWithoutExtension(Application.ExeName) + '.toml');

  // Restore window position/size from settings
  LoadSettings();

  Caption := 'Dlluminator CImporter';

  // Navigate to about:blank to trigger WebView2 init
  EdgeBrowser.Navigate('about:blank');
  SetStatusText('Initializing...');
end;

{ -------------------------------------------------------------------------- }
{ DFM-wired event handlers                                                   }
{ -------------------------------------------------------------------------- }

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FGenerating then
  begin
    CanClose := False;
    SetStatusText('Cannot close while generating.');
    Exit;
  end;

  if FDirty then
  begin
    if MessageDlg('You have unsaved changes. Close anyway?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    begin
      CanClose := False;
      Exit;
    end;
  end;

  SaveSettings();
end;

procedure TForm1.Quit1Click(Sender: TObject);
begin
  Close();
end;

procedure TForm1.About1Click(Sender: TObject);
begin
  ShowAbout();
end;

procedure TForm1.ShowAbout();
const
  REPO_URL = 'https://github.com/tinyBigGAMES/Dlluminator';
var
  LForm: TForm;
  LLblTitle: TLabel;
  LLblVersion: TLabel;
  LLblDesc: TLabel;
  LLblCopyright: TLabel;
  LLblLink: TLabel;
  LBtnOk: TButton;
begin
  LForm := TForm.CreateNew(Self);
  try
    LForm.Caption := 'About';
    LForm.ClientWidth := 580;
    LForm.ClientHeight := 260;
    LForm.Position := poMainFormCenter;
    LForm.BorderStyle := bsDialog;

    LLblTitle := TLabel.Create(LForm);
    LLblTitle.Parent := LForm;
    LLblTitle.Left := 24;
    LLblTitle.Top := 16;
    LLblTitle.Caption := 'Dlluminator CImporter';
    LLblTitle.Font.Size := 14;
    LLblTitle.Font.Style := [fsBold];

    LLblVersion := TLabel.Create(LForm);
    LLblVersion.Parent := LForm;
    LLblVersion.Left := 24;
    LLblVersion.Top := 48;
    LLblVersion.Caption := 'Version ' + DLLUMINATOR_VERSION;
    LLblVersion.Font.Size := 10;
    LLblVersion.Font.Color := clGray;

    LLblDesc := TLabel.Create(LForm);
    LLblDesc.Parent := LForm;
    LLblDesc.Left := 24;
    LLblDesc.Top := 80;
    LLblDesc.AutoSize := True;
    LLblDesc.Caption := 'C Header to Delphi unit converter with DLL binding support.';
    LLblDesc.Font.Size := 9;

    LLblCopyright := TLabel.Create(LForm);
    LLblCopyright.Parent := LForm;
    LLblCopyright.Left := 24;
    LLblCopyright.Top := 110;
    LLblCopyright.AutoSize := True;
    LLblCopyright.Caption := 'Copyright '#169' 2025-present tinyBigGAMES'#8482' LLC';
    LLblCopyright.Font.Size := 9;
    LLblCopyright.Font.Color := clGray;

    LLblLink := TLabel.Create(LForm);
    LLblLink.Parent := LForm;
    LLblLink.Left := 24;
    LLblLink.Top := 140;
    LLblLink.AutoSize := True;
    LLblLink.Caption := REPO_URL;
    LLblLink.Font.Size := 9;
    LLblLink.Font.Color := clBlue;
    LLblLink.Font.Style := [fsUnderline];
    LLblLink.Cursor := crHandPoint;
    LLblLink.OnClick := AboutLinkClick;

    LBtnOk := TButton.Create(LForm);
    LBtnOk.Parent := LForm;
    LBtnOk.Caption := 'OK';
    LBtnOk.Width := 80;
    LBtnOk.Height := 34;
    LBtnOk.Left := LForm.ClientWidth - LBtnOk.Width - 16;
    LBtnOk.Top := LForm.ClientHeight - LBtnOk.Height - 16;
    LBtnOk.ModalResult := mrOk;
    LBtnOk.Default := True;

    LForm.ShowModal();
  finally
    LForm.Free();
  end;
end;

procedure TForm1.AboutLinkClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'https://github.com/tinyBigGAMES/Dlluminator',
    nil, nil, SW_SHOWNORMAL);
end;

{ -------------------------------------------------------------------------- }
{ EdgeBrowser event handlers                                                 }
{ -------------------------------------------------------------------------- }

procedure TForm1.EdgeCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
  AResult: HRESULT);
var
  LWebView3: ICoreWebView2_3;
begin
  if not Succeeded(AResult) then
  begin
    SetStatusText('WebView2 init failed');
    Exit;
  end;

  // Set up virtual host mapping — navigation happens later in OnNavigationCompleted
  if Supports(EdgeBrowser.DefaultInterface, ICoreWebView2_3, LWebView3) then
  begin
    LWebView3.SetVirtualHostNameToFolderMapping(
      'app.local',
      PWideChar(FHtmlFolder),
      1); // ALLOW_ALL
    FMappingReady := True;
    SetStatusText('Virtual host mapping ready');
  end;
end;

procedure TForm1.EdgeNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
begin
  // After about:blank finishes and mapping is ready, navigate to the real page
  if FMappingReady then
  begin
    FMappingReady := False; // Only do this once
    EdgeBrowser.Navigate('https://app.local/index.html');
    SetStatusText('Loading UI...');
  end;
end;

procedure TForm1.EdgeWebMessageReceived(Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LMsgPtr: PWideChar;
  LMsg: string;
begin
  if Succeeded(Args.ArgsInterface.TryGetWebMessageAsString(LMsgPtr)) then
  begin
    LMsg := LMsgPtr;
    CoTaskMemFree(LMsgPtr);
    HandleWebMessage(LMsg);
  end;
end;

{ -------------------------------------------------------------------------- }
{ Message dispatch                                                           }
{ -------------------------------------------------------------------------- }

procedure TForm1.HandleWebMessage(const AJsonStr: string);
var
  LCmd: string;
  LConfigJson: string;
  LCurrentPath: string;
  LModes: TArray<string>;
  LVal: TJSONValue;

  function ParseCurrentPath(): string;
  begin
    Result := '';
    LVal := TJSONObject.ParseJSONValue(AJsonStr);
    try
      if (LVal <> nil) and (LVal is TJSONObject) then
        TJSONObject(LVal).TryGetValue<string>('current_path', Result);
    finally
      LVal.Free();
    end;
  end;

begin
  LCmd := TDlmMsgProtocol.ParseCommand(AJsonStr);

  if LCmd = 'browse_header' then
    CmdBrowseHeader(ParseCurrentPath())
  else if LCmd = 'browse_dll' then
    CmdBrowseDll(ParseCurrentPath())
  else if LCmd = 'browse_output' then
    CmdBrowseOutput(ParseCurrentPath())
  else if LCmd = 'browse_include' then
    CmdBrowseInclude(ParseCurrentPath())
  else if LCmd = 'browse_source' then
    CmdBrowseSource(ParseCurrentPath())
  else if LCmd = 'load_config' then
    CmdLoadConfig(ExtractDirFromPath(ParseCurrentPath()))
  else if LCmd = 'save_config' then
  begin
    LConfigJson := TDlmMsgProtocol.ParseConfigJson(AJsonStr);
    LCurrentPath := ParseCurrentPath();
    CmdSaveConfig(LConfigJson, LCurrentPath);
  end
  else if LCmd = 'generate' then
  begin
    LConfigJson := TDlmMsgProtocol.ParseConfigJson(AJsonStr);
    LModes := TDlmMsgProtocol.ParseModes(AJsonStr);
    CmdGenerate(LConfigJson, LModes);
  end
  else if LCmd = 'ready' then
  begin
    // Send stored settings to JS
    SendToJS('{"cmd":"set_log_height","height":' + IntToStr(FLogPanelHeight) + '}');
    SendToJS('{"cmd":"set_app_settings","tcc_path":"' +
      TDlmMsgProtocol.JsonEscape(FTccPath) + '"}');
    SetStatusText('Ready');
  end
  else if LCmd = 'log_height_changed' then
  begin
    LVal := TJSONObject.ParseJSONValue(AJsonStr);
    try
      if (LVal <> nil) and (LVal is TJSONObject) then
        TJSONObject(LVal).TryGetValue<Integer>('height', FLogPanelHeight);
    finally
      LVal.Free();
    end;
  end
  else if LCmd = 'browse_tcc' then
  begin
    LConfigJson := BrowseForFolder('Select TinyCC Folder');
    if LConfigJson <> '' then
      SendToJS('{"cmd":"browse_result","field":"tcc_path","path":"' +
        TDlmMsgProtocol.JsonEscape(LConfigJson) + '"}');
  end
  else if LCmd = 'save_app_settings' then
  begin
    LVal := TJSONObject.ParseJSONValue(AJsonStr);
    try
      if (LVal <> nil) and (LVal is TJSONObject) then
        TJSONObject(LVal).TryGetValue<string>('tcc_path', FTccPath);
    finally
      LVal.Free();
    end;
  end
  else if LCmd = 'dirty_changed' then
  begin
    LVal := TJSONObject.ParseJSONValue(AJsonStr);
    try
      if (LVal <> nil) and (LVal is TJSONObject) then
        TJSONObject(LVal).TryGetValue<Boolean>('dirty', FDirty);
    finally
      LVal.Free();
    end;
  end;
end;

procedure TForm1.SendToJS(const AJsonMsg: string);
begin
  if EdgeBrowser.DefaultInterface <> nil then
    EdgeBrowser.ExecuteScript(
      'if(window.app&&app.handleMessage)app.handleMessage(' + AJsonMsg + ')');
end;

{ -------------------------------------------------------------------------- }
{ Browse commands                                                            }
{ -------------------------------------------------------------------------- }

procedure TForm1.CmdBrowseHeader(const AInitialDir: string);
var
  LPath: string;
begin
  LPath := BrowseForFile('Select C Header File',
    'C Header Files (*.h)|*.h|All Files (*.*)|*.*', AInitialDir);
  if LPath <> '' then
    SendToJS(TDlmMsgProtocol.BuildBrowseResult('header', LPath));
end;

procedure TForm1.CmdBrowseDll(const AInitialDir: string);
var
  LPath: string;
begin
  LPath := BrowseForFile('Select DLL File',
    'DLL Files (*.dll)|*.dll|All Files (*.*)|*.*', AInitialDir);
  if LPath <> '' then
    SendToJS(TDlmMsgProtocol.BuildBrowseResult('dll_path', LPath));
end;

procedure TForm1.CmdBrowseOutput(const AInitialDir: string);
var
  LPath: string;
begin
  LPath := BrowseForFolder('Select Output Folder', ExtractDirFromPath(AInitialDir));
  if LPath <> '' then
    SendToJS(TDlmMsgProtocol.BuildBrowseResult('output_path', LPath));
end;

procedure TForm1.CmdBrowseInclude(const AInitialDir: string);
var
  LPath: string;
begin
  LPath := BrowseForFolder('Select Include Path', ExtractDirFromPath(AInitialDir));
  if LPath <> '' then
    SendToJS(TDlmMsgProtocol.BuildBrowseResult('include_path', LPath));
end;

procedure TForm1.CmdBrowseSource(const AInitialDir: string);
var
  LPath: string;
begin
  LPath := BrowseForFolder('Select Source Path', ExtractDirFromPath(AInitialDir));
  if LPath <> '' then
    SendToJS(TDlmMsgProtocol.BuildBrowseResult('source_path', LPath));
end;

{ -------------------------------------------------------------------------- }
{ Config commands                                                            }
{ -------------------------------------------------------------------------- }

procedure TForm1.CmdLoadConfig(const AInitialDir: string);
var
  LPath: string;
  LConfigJson: string;
begin
  LPath := BrowseForFile('Load CImporter Config',
    'TOML Config Files (*.toml)|*.toml|All Files (*.*)|*.*', AInitialDir);
  if LPath = '' then
    Exit;

  LConfigJson := BuildConfigJsonFromToml(LPath);
  if LConfigJson <> '' then
  begin
    SendToJS(TDlmMsgProtocol.BuildConfigLoaded(LConfigJson));
    SendToJS('{"cmd":"set_project","name":"' +
      TDlmMsgProtocol.JsonEscape(TPath.GetFileNameWithoutExtension(LPath)) +
      '","path":"' + TDlmMsgProtocol.JsonEscape(LPath) + '"}');
    SetStatusText('Config loaded: ' + TPath.GetFileName(LPath));
  end
  else
  begin
    SendToJS(TDlmMsgProtocol.BuildError('Failed to load config file'));
    SetStatusText('Failed to load config');
  end;
end;

procedure TForm1.CmdSaveConfig(const AConfigJson: string;
  const AInitialPath: string);
var
  LImporter: TDlmCImporter;
  LPath: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
  LArr: TJSONArray;
  LI: Integer;
  LModes: string;
  LDir: string;
begin
  FSaveDialog.Title := 'Save CImporter Config';
  FSaveDialog.Filter := 'TOML Config Files (*.toml)|*.toml';
  FSaveDialog.DefaultExt := 'toml';
  FSaveDialog.FileName := '';
  if AInitialPath <> '' then
  begin
    LDir := ExtractDirFromPath(AInitialPath);
    if LDir <> '' then
      FSaveDialog.InitialDir := LDir;
    if LDir <> AInitialPath then
      FSaveDialog.FileName := TPath.GetFileName(AInitialPath);
  end;
  if not FSaveDialog.Execute() then
    Exit;

  LPath := FSaveDialog.FileName;

  LImporter := TDlmCImporter.Create();
  try
    ConfigureImporter(LImporter, AConfigJson);
    if LImporter.SaveToConfig(LPath) then
    begin
      // Append binding_modes array (GUI-specific, not part of engine config)
      LVal := TJSONObject.ParseJSONValue(AConfigJson);
      try
        if (LVal <> nil) and (LVal is TJSONObject) then
        begin
          LObj := TJSONObject(LVal);
          LArr := nil;
          if LObj.TryGetValue<TJSONArray>('binding_modes', LArr) and
             (LArr.Count > 0) then
          begin
            LModes := sLineBreak + 'binding_modes = [';
            for LI := 0 to LArr.Count - 1 do
            begin
              if LI > 0 then
                LModes := LModes + ', ';
              LModes := LModes + '"' + LArr.Items[LI].Value + '"';
            end;
            LModes := LModes + ']';
            TFile.AppendAllText(LPath, LModes, TEncoding.UTF8);
          end;
        end;
      finally
        LVal.Free();
      end;

      SendToJS('{"cmd":"set_project","name":"' +
        TDlmMsgProtocol.JsonEscape(TPath.GetFileNameWithoutExtension(LPath)) +
        '","path":"' + TDlmMsgProtocol.JsonEscape(LPath) + '"}');
      SetStatusText('Config saved: ' + TPath.GetFileName(LPath));
    end
    else
    begin
      SendToJS(TDlmMsgProtocol.BuildError(
        'Failed to save config: ' + LImporter.GetLastError()));
      SetStatusText('Failed to save config');
    end;
  finally
    LImporter.Free();
  end;
end;

{ -------------------------------------------------------------------------- }
{ Generate command                                                           }
{ -------------------------------------------------------------------------- }

procedure TForm1.CmdGenerate(const AConfigJson: string;
  const AModes: TArray<string>);
var
  LImporter: TDlmCImporter;
  LModeStr: string;
  LMode: TDlmBindingMode;
  LSuffix: string;
  LModuleName: string;
  LSuccess: Boolean;
  LResultsArr: TJSONArray;
  LResultObj: TJSONObject;
  LBaseModuleName: string;
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  if FGenerating then
  begin
    SendToJS(TDlmMsgProtocol.BuildError('Generation already in progress'));
    Exit;
  end;

  if Length(AModes) = 0 then
  begin
    SendToJS(TDlmMsgProtocol.BuildError('No binding modes selected'));
    Exit;
  end;

  LSuccess := False;
  FGenerating := True;
  LResultsArr := TJSONArray.Create();
  try
    // Extract base module name from config
    LBaseModuleName := '';
    LVal := TJSONObject.ParseJSONValue(AConfigJson);
    try
      if (LVal <> nil) and (LVal is TJSONObject) then
      begin
        LObj := TJSONObject(LVal);
        LObj.TryGetValue<string>('module_name', LBaseModuleName);
      end;
    finally
      LVal.Free();
    end;

    for LModeStr in AModes do
    begin
      LMode := StringToBindingMode(LModeStr);
      LSuffix := BindingModeSuffix(LMode);

      // Add suffix only when multiple modes selected
      if Length(AModes) > 1 then
        LModuleName := LBaseModuleName + LSuffix
      else
        LModuleName := LBaseModuleName;

      LImporter := TDlmCImporter.Create();
      try
        try
          LImporter.SetStatusCallback(
            procedure(const AText: string; const AUserData: Pointer)
            begin
              SendToJS(TDlmMsgProtocol.BuildStatus(AText));
              Application.ProcessMessages();
            end
          );

          ConfigureImporter(LImporter, AConfigJson);
          LImporter.SetBindingMode(LMode);
          LImporter.SetModuleName(LModuleName);
          LImporter.SetTccPath(FTccPath);

          LSuccess := LImporter.Process();
        except
          on E: Exception do
          begin
            LSuccess := False;
            SendToJS(TDlmMsgProtocol.BuildStatus(E.Message, '#f87171'));
          end;
        end;

        SendToJS(TDlmMsgProtocol.BuildModeComplete(
          LModeStr, LSuccess, LModuleName + '.pas'));

        LResultObj := TJSONObject.Create();
        LResultObj.AddPair('mode', LModeStr);
        LResultObj.AddPair('success', TJSONBool.Create(LSuccess));
        LResultObj.AddPair('output', LModuleName + '.pas');
        if not LSuccess then
          LResultObj.AddPair('error', LImporter.GetLastError());
        LResultsArr.AddElement(LResultObj);
      finally
        LImporter.Free();
      end;

      Application.ProcessMessages();
    end;

    SendToJS(TDlmMsgProtocol.BuildAllComplete(LResultsArr.ToJSON()));
    SetStatusText('Generation complete');
  finally
    LResultsArr.Free();
    FGenerating := False;
  end;
end;

{ -------------------------------------------------------------------------- }
{ CImporter helpers                                                          }
{ -------------------------------------------------------------------------- }

procedure TForm1.ConfigureImporter(const AImporter: TDlmCImporter;
  const AConfigJson: string);
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LArr: TJSONArray;
  LItem: TJSONValue;
  LItemObj: TJSONObject;
  LStr: string;
  LStr2: string;
  LI: Integer;
begin
  LVal := TJSONObject.ParseJSONValue(AConfigJson);
  if LVal = nil then
    Exit;
  try
    if not (LVal is TJSONObject) then
      Exit;
    LObj := TJSONObject(LVal);

    if LObj.TryGetValue<string>('header', LStr) then
      AImporter.SetHeader(LStr);
    if LObj.TryGetValue<string>('module_name', LStr) then
      AImporter.SetModuleName(LStr);
    if LObj.TryGetValue<string>('dll_name', LStr) then
      AImporter.SetDllName(LStr);
    if LObj.TryGetValue<string>('dll_path', LStr) then
      AImporter.SetDllPath(LStr);
    if LObj.TryGetValue<string>('output_path', LStr) then
      AImporter.SetOutputPath(LStr);

    // Boolean
    LItem := LObj.GetValue('save_preprocessed');
    if (LItem <> nil) and (LItem is TJSONBool) and TJSONBool(LItem).AsBoolean then
      AImporter.SetSavePreprocessed(True);

    // Include paths — array of {path, module} objects
    LArr := nil;
    if LObj.TryGetValue<TJSONArray>('include_paths', LArr) then
    begin
      for LI := 0 to LArr.Count - 1 do
      begin
        LItem := LArr.Items[LI];
        if LItem is TJSONObject then
        begin
          LItemObj := TJSONObject(LItem);
          LStr := '';
          LStr2 := '';
          LItemObj.TryGetValue<string>('path', LStr);
          LItemObj.TryGetValue<string>('module', LStr2);
          if LStr <> '' then
            AImporter.AddIncludePath(LStr, LStr2);
        end;
      end;
    end;

    // Source paths
    if LObj.TryGetValue<TJSONArray>('source_paths', LArr) then
      for LI := 0 to LArr.Count - 1 do
      begin
        LStr := LArr.Items[LI].Value;
        if LStr <> '' then
          AImporter.AddSourcePath(LStr);
      end;

    // Excluded types
    if LObj.TryGetValue<TJSONArray>('excluded_types', LArr) then
      for LI := 0 to LArr.Count - 1 do
      begin
        LStr := LArr.Items[LI].Value;
        if LStr <> '' then
          AImporter.AddExcludedType(LStr);
      end;

    // Excluded functions
    if LObj.TryGetValue<TJSONArray>('excluded_functions', LArr) then
      for LI := 0 to LArr.Count - 1 do
      begin
        LStr := LArr.Items[LI].Value;
        if LStr <> '' then
          AImporter.AddExcludedFunction(LStr);
      end;

    // Function renames — array of {original, rename_to}
    if LObj.TryGetValue<TJSONArray>('function_renames', LArr) then
      for LI := 0 to LArr.Count - 1 do
      begin
        LItem := LArr.Items[LI];
        if LItem is TJSONObject then
        begin
          LItemObj := TJSONObject(LItem);
          LStr := '';
          LStr2 := '';
          LItemObj.TryGetValue<string>('original', LStr);
          LItemObj.TryGetValue<string>('rename_to', LStr2);
          if (LStr <> '') and (LStr2 <> '') then
            AImporter.AddFunctionRename(LStr, LStr2);
        end;
      end;

    // Uses units
    if LObj.TryGetValue<TJSONArray>('uses_units', LArr) then
      for LI := 0 to LArr.Count - 1 do
      begin
        LStr := LArr.Items[LI].Value;
        if LStr <> '' then
          AImporter.AddUsesUnit(LStr);
      end;

  finally
    LVal.Free();
  end;
end;

function TForm1.StringToBindingMode(const AValue: string): TDlmBindingMode;
begin
  if AValue = 'static' then
    Result := bmStatic
  else if AValue = 'dynamic' then
    Result := bmDynamic
  else if AValue = 'dynamic_delayed' then
    Result := bmDynamicDelayed
  else if AValue = 'dynamic_custom' then
    Result := bmDynamicCustom
  else if AValue = 'static_vpk' then
    Result := bmStaticVpk
  else
    Result := bmStatic;
end;

function TForm1.BindingModeSuffix(const AMode: TDlmBindingMode): string;
begin
  case AMode of
    bmStatic        : Result := '_static';
    bmDynamic       : Result := '_dynamic';
    bmDynamicDelayed: Result := '_dynamic_delayed';
    bmDynamicCustom : Result := '_dynamic_custom';
    bmStaticVpk     : Result := '_static_vpk';
  else
    Result := '';
  end;
end;

function TForm1.BuildConfigJsonFromToml(const AFilename: string): string;
var
  LConfig: TDlmConfig;
  LRoot: TJSONObject;
  LArr: TJSONArray;
  LObj: TJSONObject;
  LPaths: TArray<string>;
  LPath: string;
  LCount: Integer;
  LI: Integer;
  LStr: string;
  LStr2: string;
begin
  Result := '';
  LConfig := TDlmConfig.Create();
  try
    if not LConfig.LoadFromFile(AFilename) then
      Exit;

    LRoot := TJSONObject.Create();
    try
      if LConfig.HasKey('cimporter.header') then
        LRoot.AddPair('header', LConfig.GetString('cimporter.header'));
      if LConfig.HasKey('cimporter.module_name') then
        LRoot.AddPair('module_name', LConfig.GetString('cimporter.module_name'));
      if LConfig.HasKey('cimporter.dll_name') then
        LRoot.AddPair('dll_name', LConfig.GetString('cimporter.dll_name'));
      if LConfig.HasKey('cimporter.dll_path') then
        LRoot.AddPair('dll_path', LConfig.GetString('cimporter.dll_path'));
      if LConfig.HasKey('cimporter.output_path') then
        LRoot.AddPair('output_path', LConfig.GetString('cimporter.output_path'));

      if LConfig.HasKey('cimporter.save_preprocessed') then
        LRoot.AddPair('save_preprocessed',
          TJSONBool.Create(LConfig.GetBoolean('cimporter.save_preprocessed')));

      // Binding modes (GUI-specific, array of selected modes)
      LPaths := LConfig.GetStringArray('cimporter.binding_modes');
      if Length(LPaths) > 0 then
      begin
        LArr := TJSONArray.Create();
        for LPath in LPaths do
          LArr.Add(LPath);
        LRoot.AddPair('binding_modes', LArr);
      end;

      // Include paths
      LCount := LConfig.GetTableCount('cimporter.include_paths');
      if LCount > 0 then
      begin
        LArr := TJSONArray.Create();
        for LI := 0 to LCount - 1 do
        begin
          LObj := TJSONObject.Create();
          LObj.AddPair('path',
            LConfig.GetTableString('cimporter.include_paths', LI, 'path'));
          LObj.AddPair('module',
            LConfig.GetTableString('cimporter.include_paths', LI, 'module'));
          LArr.AddElement(LObj);
        end;
        LRoot.AddPair('include_paths', LArr);
      end;

      // Source paths
      LPaths := LConfig.GetStringArray('cimporter.source_paths');
      if Length(LPaths) > 0 then
      begin
        LArr := TJSONArray.Create();
        for LPath in LPaths do
          LArr.Add(LPath);
        LRoot.AddPair('source_paths', LArr);
      end;

      // Excluded types
      LPaths := LConfig.GetStringArray('cimporter.excluded_types');
      if Length(LPaths) > 0 then
      begin
        LArr := TJSONArray.Create();
        for LPath in LPaths do
          LArr.Add(LPath);
        LRoot.AddPair('excluded_types', LArr);
      end;

      // Excluded functions
      LPaths := LConfig.GetStringArray('cimporter.excluded_functions');
      if Length(LPaths) > 0 then
      begin
        LArr := TJSONArray.Create();
        for LPath in LPaths do
          LArr.Add(LPath);
        LRoot.AddPair('excluded_functions', LArr);
      end;

      // Function renames
      LCount := LConfig.GetTableCount('cimporter.function_renames');
      if LCount > 0 then
      begin
        LArr := TJSONArray.Create();
        for LI := 0 to LCount - 1 do
        begin
          LStr := LConfig.GetTableString('cimporter.function_renames', LI, 'original');
          LStr2 := LConfig.GetTableString('cimporter.function_renames', LI, 'rename_to');
          if (LStr <> '') and (LStr2 <> '') then
          begin
            LObj := TJSONObject.Create();
            LObj.AddPair('original', LStr);
            LObj.AddPair('rename_to', LStr2);
            LArr.AddElement(LObj);
          end;
        end;
        LRoot.AddPair('function_renames', LArr);
      end;

      // Uses units
      LPaths := LConfig.GetStringArray('cimporter.uses_units');
      if Length(LPaths) > 0 then
      begin
        LArr := TJSONArray.Create();
        for LPath in LPaths do
          LArr.Add(LPath);
        LRoot.AddPair('uses_units', LArr);
      end;

      Result := LRoot.ToJSON();
    finally
      LRoot.Free();
    end;
  finally
    LConfig.Free();
  end;
end;

{ -------------------------------------------------------------------------- }
{ Helpers                                                                    }
{ -------------------------------------------------------------------------- }

procedure TForm1.SetStatusText(const AText: string);
begin
  StatusBar.SimplePanel := True;
  StatusBar.SimpleText := AText;
end;

function TForm1.ExtractDirFromPath(const APath: string): string;
var
  LNormalized: string;
begin
  Result := '';
  if APath = '' then
    Exit;
  LNormalized := APath.Replace('/', '\');
  if TDirectory.Exists(LNormalized) then
    Result := LNormalized
  else
    Result := TPath.GetDirectoryName(LNormalized);
end;

function TForm1.BrowseForFile(const ATitle: string;
  const AFilter: string; const AInitialDir: string): string;
var
  LDir: string;
begin
  Result := '';
  FOpenDialog.Title := ATitle;
  FOpenDialog.Filter := AFilter;
  FOpenDialog.FileName := '';
  if AInitialDir <> '' then
  begin
    LDir := ExtractDirFromPath(AInitialDir);
    if LDir <> '' then
      FOpenDialog.InitialDir := LDir;
    // Pre-populate the filename if the path points to a file
    if LDir <> AInitialDir then
      FOpenDialog.FileName := TPath.GetFileName(AInitialDir);
  end;
  if FOpenDialog.Execute() then
    Result := FOpenDialog.FileName;
end;

function TForm1.BrowseForFolder(const ATitle: string;
  const AInitialDir: string): string;
var
  LDialog: TFileOpenDialog;
begin
  Result := '';
  LDialog := TFileOpenDialog.Create(nil);
  try
    LDialog.Title := ATitle;
    LDialog.Options := [fdoPickFolders, fdoPathMustExist];
    if (AInitialDir <> '') and TDirectory.Exists(AInitialDir) then
      LDialog.DefaultFolder := AInitialDir;
    if LDialog.Execute() then
      Result := LDialog.FileName;
  finally
    LDialog.Free();
  end;
end;

{ -------------------------------------------------------------------------- }
{ Settings persistence                                                       }
{ -------------------------------------------------------------------------- }

procedure TForm1.LoadSettings();
var
  LConfig: TDlmConfig;
  LState: string;
  LMonitor: TMonitor;
begin
  // Set defaults
  Position := poScreenCenter;
  Width := 900;
  Height := 700;

  if not TFile.Exists(FSettingsFile) then
    Exit;

  LConfig := TDlmConfig.Create();
  try
    if not LConfig.LoadFromFile(FSettingsFile) then
      Exit;

    Position := poDesigned;
    Left := LConfig.GetInteger('window.left', Left);
    Top := LConfig.GetInteger('window.top', Top);
    Width := LConfig.GetInteger('window.width', 900);
    Height := LConfig.GetInteger('window.height', 700);
    LState := LConfig.GetString('window.state', 'normal');
    FLogPanelHeight := LConfig.GetInteger('ui.log_panel_height', 140);
    FTccPath := LConfig.GetString('app.tcc_path', '..\..\..\tinycc');

    // Validate: ensure window is at least partially on a monitor
    LMonitor := Screen.MonitorFromRect(Rect(Left, Top,
      Left + Width, Top + Height));
    if LMonitor <> nil then
    begin
      if Left + Width < LMonitor.Left + 100 then
        Left := LMonitor.Left;
      if Top + Height < LMonitor.Top + 100 then
        Top := LMonitor.Top;
      if Left > LMonitor.Left + LMonitor.Width - 100 then
        Left := LMonitor.Left + LMonitor.Width - Width;
      if Top > LMonitor.Top + LMonitor.Height - 100 then
        Top := LMonitor.Top + LMonitor.Height - Height;
    end;

    if LState = 'maximized' then
      WindowState := wsMaximized;

  finally
    LConfig.Free();
  end;
end;

procedure TForm1.SaveSettings();
var
  LConfig: TDlmConfig;
  LPlacement: TWindowPlacement;
  LRect: TRect;
begin
  LConfig := TDlmConfig.Create();
  try
    // Use GetWindowPlacement to get normal bounds even when maximized
    LPlacement.length := SizeOf(TWindowPlacement);
    GetWindowPlacement(Handle, @LPlacement);
    LRect := LPlacement.rcNormalPosition;

    LConfig.SetInteger('window.left', LRect.Left);
    LConfig.SetInteger('window.top', LRect.Top);
    LConfig.SetInteger('window.width', LRect.Right - LRect.Left);
    LConfig.SetInteger('window.height', LRect.Bottom - LRect.Top);

    if WindowState = wsMaximized then
      LConfig.SetString('window.state', 'maximized')
    else
      LConfig.SetString('window.state', 'normal');

    LConfig.SetInteger('ui.log_panel_height', FLogPanelHeight);

    LConfig.SetString('app.tcc_path', FTccPath);

    LConfig.SaveToFile(FSettingsFile);
  finally
    LConfig.Free();
  end;
end;

initialization
  ReportMemoryLeaksOnShutdown := True;

finalization

end.
