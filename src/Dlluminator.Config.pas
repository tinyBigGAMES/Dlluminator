{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}


unit Dlluminator.Config;

{$I Dlluminator.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  System.Generics.Collections,
  Dlluminator.Utils,
  Dlluminator.TOML;

type
  { TDlmConfig }
  TDlmConfig = class(TDlmBaseObject)
  private
    FToml:      TDlmToml;
    FLastError: string;
    FFilename:  string;

    function  NavigateToTable(const AKeyPath: string;
      const ACreateMissing: Boolean; out ATable: TDlmToml;
      out AFinalKey: string): Boolean;
    function  GetValueAtPath(const AKeyPath: string;
      out AValue: TDlmTomlValue): Boolean;
    procedure SerializeToml(const AToml: TDlmToml;
      const ABuilder: TStringBuilder; const AIndent: Integer;
      const ATablePath: string);
    procedure SerializeValue(const AValue: TDlmTomlValue;
      const ABuilder: TStringBuilder);
    function  EscapeString(const AValue: string): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // File operations
    function LoadFromFile(const AFilename: string): Boolean;
    function LoadFromString(const ASource: string): Boolean;
    function SaveToFile(const AFilename: string): Boolean;
    function GetLastError(): string;
    procedure Clear();

    // Key existence
    function HasKey(const AKeyPath: string): Boolean;

    // String
    function GetString(const AKeyPath: string;
      const ADefault: string = ''): string;
    procedure SetString(const AKeyPath: string; const AValue: string);

    // Integer
    function GetInteger(const AKeyPath: string;
      const ADefault: Int64 = 0): Int64;
    procedure SetInteger(const AKeyPath: string; const AValue: Int64);

    // Float
    function GetFloat(const AKeyPath: string;
      const ADefault: Double = 0.0): Double;
    procedure SetFloat(const AKeyPath: string; const AValue: Double);

    // Boolean
    function GetBoolean(const AKeyPath: string;
      const ADefault: Boolean = False): Boolean;
    procedure SetBoolean(const AKeyPath: string; const AValue: Boolean);

    // DateTime
    function GetDateTime(const AKeyPath: string;
      const ADefault: TDateTime = 0): TDateTime;
    procedure SetDateTime(const AKeyPath: string; const AValue: TDateTime);

    // String Array
    function GetStringArray(const AKeyPath: string): TArray<string>;
    procedure SetStringArray(const AKeyPath: string;
      const AValues: TArray<string>);

    // Integer Array
    function GetIntegerArray(const AKeyPath: string): TArray<Int64>;
    procedure SetIntegerArray(const AKeyPath: string;
      const AValues: TArray<Int64>);

    // Float Array
    function GetFloatArray(const AKeyPath: string): TArray<Double>;
    procedure SetFloatArray(const AKeyPath: string;
      const AValues: TArray<Double>);

    // Array of Tables access (for [[section]] syntax)
    function GetTableCount(const AKeyPath: string): Integer;
    function GetTableString(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: string = ''): string;
    function GetTableInteger(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Int64 = 0): Int64;
    function GetTableFloat(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Double = 0.0): Double;
    function GetTableBoolean(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const ADefault: Boolean = False): Boolean;

    // Array of Tables write (for [[section]] syntax)
    function  AddTableEntry(const AKeyPath: string): Integer;
    procedure SetTableString(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: string);
    procedure SetTableInteger(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Int64);
    procedure SetTableFloat(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Double);
    procedure SetTableBoolean(const AKeyPath: string; const AIndex: Integer;
      const AField: string; const AValue: Boolean);

    // Array of Tables — string array field access
    function GetTableStringArray(const AKeyPath: string;
      const AIndex: Integer; const AField: string): TArray<string>;
    procedure SetTableStringArray(const AKeyPath: string;
      const AIndex: Integer; const AField: string;
      const AValues: TArray<string>);

    // Comment preservation
    function GetFileComment(): string;
    procedure SetFileComment(const AComment: string);
    function GetTableComment(const AKeyPath: string;
      const AIndex: Integer): string;
    procedure SetTableComment(const AKeyPath: string;
      const AIndex: Integer; const AComment: string);
  end;

implementation

{ TDlmConfig }

constructor TDlmConfig.Create();
begin
  inherited;
  FToml      := nil;
  FLastError := '';
  FFilename  := '';
end;

destructor TDlmConfig.Destroy();
begin
  Clear();
  inherited;
end;

procedure TDlmConfig.Clear();
begin
  if Assigned(FToml) then
  begin
    FToml.Free();
    FToml := nil;
  end;
  FLastError := '';
  FFilename  := '';
end;

function TDlmConfig.GetLastError(): string;
begin
  Result := FLastError;
end;

function TDlmConfig.NavigateToTable(const AKeyPath: string;
  const ACreateMissing: Boolean; out ATable: TDlmToml;
  out AFinalKey: string): Boolean;
var
  LParts: TArray<string>;
  LI:     Integer;
  LValue: TDlmTomlValue;
begin
  Result    := False;
  ATable    := nil;
  AFinalKey := '';

  if not Assigned(FToml) then
    Exit;

  LParts := AKeyPath.Split(['.']);
  if Length(LParts) = 0 then
    Exit;

  AFinalKey := LParts[High(LParts)];
  ATable    := FToml;

  // Navigate through all parts except the last one
  for LI := 0 to High(LParts) - 1 do
  begin
    if ATable.TryGetValue(LParts[LI], LValue) then
    begin
      if LValue.Kind = tvkTable then
        ATable := LValue.AsTable()
      else
        Exit; // Path element is not a table
    end
    else if ACreateMissing then
      ATable := ATable.GetOrCreateTable(LParts[LI])
    else
      Exit; // Path not found
  end;

  Result := True;
end;

function TDlmConfig.GetValueAtPath(const AKeyPath: string;
  out AValue: TDlmTomlValue): Boolean;
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  Result := False;

  if not NavigateToTable(AKeyPath, False, LTable, LFinalKey) then
    Exit;

  Result := LTable.TryGetValue(LFinalKey, AValue);
end;

function TDlmConfig.LoadFromFile(const AFilename: string): Boolean;
begin
  Result := False;
  Clear();

  if not TFile.Exists(AFilename) then
  begin
    FLastError := 'File not found: ' + AFilename;
    Exit;
  end;

  try
    FToml     := TDlmToml.FromFile(AFilename);
    FFilename := AFilename;
    Result    := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to parse TOML: ' + E.Message;
      FToml      := nil;
    end;
  end;
end;

function TDlmConfig.LoadFromString(const ASource: string): Boolean;
begin
  Result := False;
  Clear();

  try
    FToml  := TDlmToml.FromString(ASource);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to parse TOML: ' + E.Message;
      FToml      := nil;
    end;
  end;
end;

function TDlmConfig.EscapeString(const AValue: string): string;
begin
  Result := AValue;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#9,  '\t');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#13, '\r');
end;

procedure TDlmConfig.SerializeValue(const AValue: TDlmTomlValue;
  const ABuilder: TStringBuilder);
var
  LArray: TDlmTomlArray;
  LI:     Integer;
begin
  if AValue.Kind = tvkString then
  begin
    if (Pos(#10, AValue.AsString()) > 0) or
       (Pos(#13, AValue.AsString()) > 0) then
      ABuilder.Append('"""' + #10 + AValue.AsString() + '"""')
    else
      ABuilder.Append('"' + EscapeString(AValue.AsString()) + '"');
  end
  else if AValue.Kind = tvkInteger then
    ABuilder.Append(IntToStr(AValue.AsInteger()))
  else if AValue.Kind = tvkFloat then
    ABuilder.Append(FloatToStr(AValue.AsFloat()))
  else if AValue.Kind = tvkBoolean then
  begin
    if AValue.AsBoolean() then
      ABuilder.Append('true')
    else
      ABuilder.Append('false');
  end
  else if AValue.Kind = tvkDateTime then
    ABuilder.Append(DateToISO8601(AValue.AsDateTime()))
  else if AValue.Kind = tvkArray then
  begin
    LArray := AValue.AsArray();
    if LArray.Count = 0 then
      ABuilder.Append('[]')
    else
    begin
      ABuilder.Append('[');
      for LI := 0 to LArray.Count - 1 do
      begin
        ABuilder.AppendLine();
        ABuilder.Append('  ');
        SerializeValue(LArray[LI], ABuilder);
        if LI < LArray.Count - 1 then
          ABuilder.Append(',');
      end;
      ABuilder.AppendLine();
      ABuilder.Append(']');
    end;
  end;
end;

procedure TDlmConfig.SerializeToml(const AToml: TDlmToml;
  const ABuilder: TStringBuilder; const AIndent: Integer;
  const ATablePath: string);
var
  LKeys:     TArray<string>;
  LKey:      string;
  LValue:    TDlmTomlValue;
  LSubTable: TDlmToml;
  LNewPath:  string;
  LArray:    TDlmTomlArray;
  LI:        Integer;
  LItem:     TDlmTomlValue;
  LComment:  string;
begin
  LKeys := AToml.Keys;

  // Emit root table comment (file header)
  if (ATablePath = '') and (AToml.Comment <> '') then
  begin
    ABuilder.Append(AToml.Comment);
    ABuilder.AppendLine();
  end;

  // First pass: simple scalar values
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if (LValue.Kind <> tvkTable) and
         not ((LValue.Kind = tvkArray) and (LValue.AsArray().Count > 0) and
              (LValue.AsArray()[0].Kind = tvkTable)) then
      begin
        // Emit key comment if present
        LComment := AToml.GetKeyComment(LKey);
        if LComment <> '' then
        begin
          ABuilder.Append(LComment);
          ABuilder.AppendLine();
        end;
        ABuilder.Append(LKey + ' = ');
        SerializeValue(LValue, ABuilder);
        ABuilder.AppendLine();
      end;
    end;
  end;

  // Second pass: nested tables
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if LValue.Kind = tvkTable then
      begin
        if ATablePath = '' then
          LNewPath := LKey
        else
          LNewPath := ATablePath + '.' + LKey;

        ABuilder.AppendLine();

        LSubTable := LValue.AsTable();

        // Emit table comment if present
        if LSubTable.Comment <> '' then
        begin
          ABuilder.Append(LSubTable.Comment);
          ABuilder.AppendLine();
        end;

        ABuilder.AppendLine('[' + LNewPath + ']');
        SerializeToml(LSubTable, ABuilder, AIndent, LNewPath);
      end;
    end;
  end;

  // Third pass: arrays of tables
  for LKey in LKeys do
  begin
    if AToml.TryGetValue(LKey, LValue) then
    begin
      if (LValue.Kind = tvkArray) and (LValue.AsArray().Count > 0) and
         (LValue.AsArray()[0].Kind = tvkTable) then
      begin
        if ATablePath = '' then
          LNewPath := LKey
        else
          LNewPath := ATablePath + '.' + LKey;

        LArray := LValue.AsArray();
        for LI := 0 to LArray.Count - 1 do
        begin
          LItem := LArray[LI];
          if LItem.Kind = tvkTable then
          begin
            ABuilder.AppendLine();
            // Emit entry comment if present
            if LItem.AsTable().Comment <> '' then
            begin
              ABuilder.Append(LItem.AsTable().Comment);
              ABuilder.AppendLine();
            end;
            ABuilder.AppendLine('[[' + LNewPath + ']]');
            SerializeToml(LItem.AsTable(), ABuilder, AIndent, '');
          end;
        end;
      end;
    end;
  end;
end;

function TDlmConfig.SaveToFile(const AFilename: string): Boolean;
var
  LBuilder: TStringBuilder;
begin
  Result := False;

  if not Assigned(FToml) then
  begin
    FLastError := 'No configuration loaded';
    Exit;
  end;

  LBuilder := TStringBuilder.Create();
  try
    SerializeToml(FToml, LBuilder, 0, '');

    try
      TDlmUtils.CreateDirInPath(AFilename);
      TFile.WriteAllText(AFilename,
        LBuilder.ToString().Trim() + #10, TEncoding.UTF8);
      FFilename := AFilename;
      Result    := True;
    except
      on E: Exception do
        FLastError := 'Failed to write file: ' + E.Message;
    end;
  finally
    LBuilder.Free();
  end;
end;

function TDlmConfig.HasKey(const AKeyPath: string): Boolean;
var
  LValue: TDlmTomlValue;
begin
  Result := GetValueAtPath(AKeyPath, LValue);
end;

// -- String -------------------------------------------------------------------

function TDlmConfig.GetString(const AKeyPath: string;
  const ADefault: string): string;
var
  LValue: TDlmTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkString) then
    Result := LValue.AsString()
  else
    Result := ADefault;
end;

procedure TDlmConfig.SetString(const AKeyPath: string;
  const AValue: string);
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetString(LFinalKey, AValue);
end;

// -- Integer ------------------------------------------------------------------

function TDlmConfig.GetInteger(const AKeyPath: string;
  const ADefault: Int64): Int64;
var
  LValue: TDlmTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkInteger) then
    Result := LValue.AsInteger()
  else
    Result := ADefault;
end;

procedure TDlmConfig.SetInteger(const AKeyPath: string;
  const AValue: Int64);
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetInteger(LFinalKey, AValue);
end;

// -- Float --------------------------------------------------------------------

function TDlmConfig.GetFloat(const AKeyPath: string;
  const ADefault: Double): Double;
var
  LValue: TDlmTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkFloat) then
    Result := LValue.AsFloat()
  else
    Result := ADefault;
end;

procedure TDlmConfig.SetFloat(const AKeyPath: string;
  const AValue: Double);
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetFloat(LFinalKey, AValue);
end;

// -- Boolean ------------------------------------------------------------------

function TDlmConfig.GetBoolean(const AKeyPath: string;
  const ADefault: Boolean): Boolean;
var
  LValue: TDlmTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkBoolean) then
    Result := LValue.AsBoolean()
  else
    Result := ADefault;
end;

procedure TDlmConfig.SetBoolean(const AKeyPath: string;
  const AValue: Boolean);
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetBoolean(LFinalKey, AValue);
end;

// -- DateTime -----------------------------------------------------------------

function TDlmConfig.GetDateTime(const AKeyPath: string;
  const ADefault: TDateTime): TDateTime;
var
  LValue: TDlmTomlValue;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkDateTime) then
    Result := LValue.AsDateTime()
  else
    Result := ADefault;
end;

procedure TDlmConfig.SetDateTime(const AKeyPath: string;
  const AValue: TDateTime);
var
  LTable:    TDlmToml;
  LFinalKey: string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
    LTable.SetValue(LFinalKey, TDlmTomlValue.CreateDateTime(AValue));
end;

// -- String Array -------------------------------------------------------------

function TDlmConfig.GetStringArray(const AKeyPath: string): TArray<string>;
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkString then
        Result[LI] := LArray[LI].AsString()
      else
        Result[LI] := '';
    end;
  end;
end;

procedure TDlmConfig.SetStringArray(const AKeyPath: string;
  const AValues: TArray<string>);
var
  LTable:    TDlmToml;
  LFinalKey: string;
  LArray:    TDlmTomlArray;
  LValue:    string;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    // Remove existing key to clear old array
    LTable.RemoveKey(LFinalKey);
    // Create new array and populate
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddString(LValue);
  end;
end;

// -- Integer Array ------------------------------------------------------------

function TDlmConfig.GetIntegerArray(const AKeyPath: string): TArray<Int64>;
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkInteger then
        Result[LI] := LArray[LI].AsInteger()
      else
        Result[LI] := 0;
    end;
  end;
end;

procedure TDlmConfig.SetIntegerArray(const AKeyPath: string;
  const AValues: TArray<Int64>);
var
  LTable:    TDlmToml;
  LFinalKey: string;
  LArray:    TDlmTomlArray;
  LValue:    Int64;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LTable.RemoveKey(LFinalKey);
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddInteger(LValue);
  end;
end;

// -- Float Array --------------------------------------------------------------

function TDlmConfig.GetFloatArray(const AKeyPath: string): TArray<Double>;
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LI:     Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    SetLength(Result, LArray.Count);
    for LI := 0 to LArray.Count - 1 do
    begin
      if LArray[LI].Kind = tvkFloat then
        Result[LI] := LArray[LI].AsFloat()
      else
        Result[LI] := 0.0;
    end;
  end;
end;

procedure TDlmConfig.SetFloatArray(const AKeyPath: string;
  const AValues: TArray<Double>);
var
  LTable:    TDlmToml;
  LFinalKey: string;
  LArray:    TDlmTomlArray;
  LValue:    Double;
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LTable.RemoveKey(LFinalKey);
    LArray := LTable.GetOrCreateArray(LFinalKey);
    for LValue in AValues do
      LArray.AddFloat(LValue);
  end;
end;

// -- Array of Tables (read) ---------------------------------------------------

function TDlmConfig.GetTableCount(const AKeyPath: string): Integer;
var
  LValue: TDlmTomlValue;
begin
  Result := 0;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
    Result := LValue.AsArray().Count;
end;

function TDlmConfig.GetTableString(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: string): string;
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldValue: TDlmTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkString) then
        Result := LFieldValue.AsString();
    end;
  end;
end;

function TDlmConfig.GetTableInteger(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Int64): Int64;
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldValue: TDlmTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkInteger) then
        Result := LFieldValue.AsInteger();
    end;
  end;
end;

function TDlmConfig.GetTableFloat(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Double): Double;
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldValue: TDlmTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkFloat) then
        Result := LFieldValue.AsFloat();
    end;
  end;
end;

function TDlmConfig.GetTableBoolean(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const ADefault: Boolean): Boolean;
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldValue: TDlmTomlValue;
begin
  Result := ADefault;

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkBoolean) then
        Result := LFieldValue.AsBoolean();
    end;
  end;
end;

// -- Array of Tables (write) --------------------------------------------------

function TDlmConfig.AddTableEntry(const AKeyPath: string): Integer;
var
  LTable:    TDlmToml;
  LFinalKey: string;
  LArray:    TDlmTomlArray;
  LNewTable: TDlmToml;
begin
  Result := -1;

  if not Assigned(FToml) then
    FToml := TDlmToml.Create();

  if NavigateToTable(AKeyPath, True, LTable, LFinalKey) then
  begin
    LArray    := LTable.GetOrCreateArray(LFinalKey);
    LNewTable := LTable.CreateOwnedTable();
    LArray.Add(TDlmTomlValue.CreateTable(LNewTable));
    Result := LArray.Count - 1;
  end;
end;

procedure TDlmConfig.SetTableString(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: string);
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LTable: TDlmToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetString(AField, AValue);
    end;
  end;
end;

procedure TDlmConfig.SetTableInteger(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Int64);
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LTable: TDlmToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetInteger(AField, AValue);
    end;
  end;
end;

procedure TDlmConfig.SetTableFloat(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Double);
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LTable: TDlmToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetFloat(AField, AValue);
    end;
  end;
end;

procedure TDlmConfig.SetTableBoolean(const AKeyPath: string;
  const AIndex: Integer; const AField: string; const AValue: Boolean);
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
  LTable: TDlmToml;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.SetBoolean(AField, AValue);
    end;
  end;
end;

// -- Array of Tables — string array field ------------------------------------

function TDlmConfig.GetTableStringArray(const AKeyPath: string;
  const AIndex: Integer; const AField: string): TArray<string>;
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldValue: TDlmTomlValue;
  LFieldArray: TDlmTomlArray;
  LI:          Integer;
begin
  SetLength(Result, 0);

  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      if LTable.TryGetValue(AField, LFieldValue) and
         (LFieldValue.Kind = tvkArray) then
      begin
        LFieldArray := LFieldValue.AsArray();
        SetLength(Result, LFieldArray.Count);
        for LI := 0 to LFieldArray.Count - 1 do
        begin
          if LFieldArray[LI].Kind = tvkString then
            Result[LI] := LFieldArray[LI].AsString()
          else
            Result[LI] := '';
        end;
      end;
    end;
  end;
end;

procedure TDlmConfig.SetTableStringArray(const AKeyPath: string;
  const AIndex: Integer; const AField: string;
  const AValues: TArray<string>);
var
  LValue:      TDlmTomlValue;
  LArray:      TDlmTomlArray;
  LTable:      TDlmToml;
  LFieldArray: TDlmTomlArray;
  LItem:       string;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
    begin
      LTable := LArray[AIndex].AsTable();
      LTable.RemoveKey(AField);
      LFieldArray := LTable.GetOrCreateArray(AField);
      for LItem in AValues do
        LFieldArray.AddString(LItem);
    end;
  end;
end;

// -- Comment preservation -----------------------------------------------------

function TDlmConfig.GetFileComment(): string;
begin
  if Assigned(FToml) then
    Result := FToml.Comment
  else
    Result := '';
end;

procedure TDlmConfig.SetFileComment(const AComment: string);
begin
  if not Assigned(FToml) then
    FToml := TDlmToml.Create();
  FToml.Comment := AComment;
end;

function TDlmConfig.GetTableComment(const AKeyPath: string;
  const AIndex: Integer): string;
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
begin
  Result := '';
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
      Result := LArray[AIndex].AsTable().Comment;
  end;
end;

procedure TDlmConfig.SetTableComment(const AKeyPath: string;
  const AIndex: Integer; const AComment: string);
var
  LValue: TDlmTomlValue;
  LArray: TDlmTomlArray;
begin
  if GetValueAtPath(AKeyPath, LValue) and (LValue.Kind = tvkArray) then
  begin
    LArray := LValue.AsArray();
    if (AIndex >= 0) and (AIndex < LArray.Count) and
       (LArray[AIndex].Kind = tvkTable) then
      LArray[AIndex].AsTable().Comment := AComment;
  end;
end;

end.
