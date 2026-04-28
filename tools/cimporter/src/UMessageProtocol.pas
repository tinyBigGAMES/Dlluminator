unit UMessageProtocol;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  System.Generics.Collections;

type
  { TDlmMsgProtocol }
  TDlmMsgProtocol = class
  public
    // Delphi -> JS message builders
    class function BuildBrowseResult(const AField: string; const APath: string): string; static;
    class function BuildConfigLoaded(const AConfigJson: string): string; static;
    class function BuildStatus(const AText: string; const AColor: string = ''): string; static;
    class function BuildModeComplete(const AMode: string; const ASuccess: Boolean; const AOutput: string): string; static;
    class function BuildAllComplete(const AResultsArray: string): string; static;
    class function BuildError(const AMessage: string): string; static;

    // JS -> Delphi message parsers
    class function ParseCommand(const AJson: string): string; static;
    class function ParseField(const AJson: string): string; static;
    class function ParseConfigJson(const AJson: string): string; static;
    class function ParseModes(const AJson: string): TArray<string>; static;

    // Utility
    class function StripAnsiColors(const AText: string): string; static;
    class function AnsiColorToHtml(const AAnsiCode: string): string; static;
    class function JsonEscape(const AText: string): string; static;
    class function BuildStatusSegments(const ARawText: string): string; static;
  end;

implementation

{ TDlmMsgProtocol }

class function TDlmMsgProtocol.BuildBrowseResult(const AField: string; const APath: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'browse_result');
    LObj.AddPair('field', AField);
    LObj.AddPair('path', APath);
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.BuildConfigLoaded(const AConfigJson: string): string;
var
  LObj: TJSONObject;
  LConfig: TJSONValue;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'config_loaded');
    LConfig := TJSONObject.ParseJSONValue(AConfigJson);
    if LConfig <> nil then
      LObj.AddPair('config', LConfig)
    else
      LObj.AddPair('config', TJSONObject.Create());
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.BuildStatus(const AText: string; const AColor: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'status');
    LObj.AddPair('text', StripAnsiColors(AText));
    LObj.AddPair('segments', TJSONObject.ParseJSONValue(BuildStatusSegments(AText)));
    if AColor <> '' then
      LObj.AddPair('color', AColor);
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.BuildModeComplete(const AMode: string; const ASuccess: Boolean; const AOutput: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'mode_complete');
    LObj.AddPair('mode', AMode);
    LObj.AddPair('success', TJSONBool.Create(ASuccess));
    LObj.AddPair('output', AOutput);
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.BuildAllComplete(const AResultsArray: string): string;
var
  LObj: TJSONObject;
  LArr: TJSONValue;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'all_complete');
    LArr := TJSONObject.ParseJSONValue(AResultsArray);
    if LArr <> nil then
      LObj.AddPair('results', LArr)
    else
      LObj.AddPair('results', TJSONArray.Create());
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.BuildError(const AMessage: string): string;
var
  LObj: TJSONObject;
begin
  LObj := TJSONObject.Create();
  try
    LObj.AddPair('cmd', 'error');
    LObj.AddPair('message', AMessage);
    Result := LObj.ToJSON();
  finally
    LObj.Free();
  end;
end;

class function TDlmMsgProtocol.ParseCommand(const AJson: string): string;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  Result := '';
  LVal := TJSONObject.ParseJSONValue(AJson);
  try
    if (LVal <> nil) and (LVal is TJSONObject) then
    begin
      LObj := TJSONObject(LVal);
      LObj.TryGetValue<string>('cmd', Result);
    end;
  finally
    LVal.Free();
  end;
end;

class function TDlmMsgProtocol.ParseField(const AJson: string): string;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
begin
  Result := '';
  LVal := TJSONObject.ParseJSONValue(AJson);
  try
    if (LVal <> nil) and (LVal is TJSONObject) then
    begin
      LObj := TJSONObject(LVal);
      LObj.TryGetValue<string>('field', Result);
    end;
  finally
    LVal.Free();
  end;
end;

class function TDlmMsgProtocol.ParseConfigJson(const AJson: string): string;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LConfig: TJSONValue;
begin
  Result := '{}';
  LVal := TJSONObject.ParseJSONValue(AJson);
  try
    if (LVal <> nil) and (LVal is TJSONObject) then
    begin
      LObj := TJSONObject(LVal);
      LConfig := LObj.GetValue('config');
      if LConfig <> nil then
        Result := LConfig.ToJSON();
    end;
  finally
    LVal.Free();
  end;
end;

class function TDlmMsgProtocol.ParseModes(const AJson: string): TArray<string>;
var
  LVal: TJSONValue;
  LObj: TJSONObject;
  LArr: TJSONArray;
  LI: Integer;
  LList: TList<string>;
begin
  Result := nil;
  LVal := TJSONObject.ParseJSONValue(AJson);
  try
    if (LVal <> nil) and (LVal is TJSONObject) then
    begin
      LObj := TJSONObject(LVal);
      LArr := nil;
      LObj.TryGetValue<TJSONArray>('modes', LArr);
      if LArr <> nil then
      begin
        LList := TList<string>.Create();
        try
          for LI := 0 to LArr.Count - 1 do
            LList.Add(LArr.Items[LI].Value);
          Result := LList.ToArray();
        finally
          LList.Free();
        end;
      end;
    end;
  finally
    LVal.Free();
  end;
end;

class function TDlmMsgProtocol.StripAnsiColors(const AText: string): string;
var
  LI: Integer;
  LLen: Integer;
begin
  Result := '';
  LI := 1;
  LLen := Length(AText);
  while LI <= LLen do
  begin
    // Detect ESC character (#27)
    if (AText[LI] = #27) and (LI + 1 <= LLen) and (AText[LI + 1] = '[') then
    begin
      // Skip past the 'm' terminator
      Inc(LI, 2);
      while (LI <= LLen) and (AText[LI] <> 'm') do
        Inc(LI);
      // Skip the 'm' itself
      if LI <= LLen then
        Inc(LI);
    end
    else
    begin
      Result := Result + AText[LI];
      Inc(LI);
    end;
  end;
end;

class function TDlmMsgProtocol.AnsiColorToHtml(const AAnsiCode: string): string;
begin
  if AAnsiCode = #27'[31m' then
    Result := '#FF4444'
  else if AAnsiCode = #27'[32m' then
    Result := '#44FF44'
  else if AAnsiCode = #27'[33m' then
    Result := '#FFFF44'
  else if AAnsiCode = #27'[34m' then
    Result := '#4488FF'
  else if AAnsiCode = #27'[35m' then
    Result := '#FF44FF'
  else if AAnsiCode = #27'[36m' then
    Result := '#00BFFF'
  else if AAnsiCode = #27'[37m' then
    Result := '#CCCCCC'
  else if AAnsiCode = #27'[97m' then
    Result := '#FFFFFF'
  else if AAnsiCode = #27'[1m' then
    Result := '#FFFFFF'
  else if AAnsiCode = #27'[0m' then
    Result := ''
  else
    Result := '';
end;

class function TDlmMsgProtocol.JsonEscape(const AText: string): string;
var
  LI: Integer;
  LCh: Char;
begin
  Result := '';
  for LI := 1 to Length(AText) do
  begin
    LCh := AText[LI];
    if LCh = '\' then
      Result := Result + '\\'
    else if LCh = '"' then
      Result := Result + '\"'
    else if LCh = #13 then
      Result := Result + '\r'
    else if LCh = #10 then
      Result := Result + '\n'
    else if LCh = #9 then
      Result := Result + '\t'
    else if LCh < #32 then
      Result := Result + '\u' + IntToHex(Ord(LCh), 4)
    else
      Result := Result + LCh;
  end;
end;

class function TDlmMsgProtocol.BuildStatusSegments(const ARawText: string): string;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  LI: Integer;
  LLen: Integer;
  LCurrentColor: string;
  LBuffer: string;
  LAnsiCode: string;
begin
  // Parse ANSI color codes from raw status text and produce a JSON array
  // of {text, color} segments for the JS UI to render
  LArr := TJSONArray.Create();
  try
    LI := 1;
    LLen := Length(ARawText);
    LCurrentColor := '';
    LBuffer := '';

    while LI <= LLen do
    begin
      // Detect ESC character
      if (ARawText[LI] = #27) and (LI + 1 <= LLen) and (ARawText[LI + 1] = '[') then
      begin
        // Flush buffer with current color
        if LBuffer <> '' then
        begin
          LObj := TJSONObject.Create();
          LObj.AddPair('text', LBuffer);
          LObj.AddPair('color', LCurrentColor);
          LArr.AddElement(LObj);
          LBuffer := '';
        end;

        // Extract the ANSI code sequence
        LAnsiCode := #27 + '[';
        Inc(LI, 2);
        while (LI <= LLen) and (ARawText[LI] <> 'm') do
        begin
          LAnsiCode := LAnsiCode + ARawText[LI];
          Inc(LI);
        end;
        if LI <= LLen then
        begin
          LAnsiCode := LAnsiCode + 'm';
          Inc(LI);
        end;

        LCurrentColor := AnsiColorToHtml(LAnsiCode);
      end
      else
      begin
        LBuffer := LBuffer + ARawText[LI];
        Inc(LI);
      end;
    end;

    // Flush remaining buffer
    if LBuffer <> '' then
    begin
      LObj := TJSONObject.Create();
      LObj.AddPair('text', LBuffer);
      LObj.AddPair('color', LCurrentColor);
      LArr.AddElement(LObj);
    end;

    Result := LArr.ToJSON();
  finally
    LArr.Free();
  end;
end;

end.
