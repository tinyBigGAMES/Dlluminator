{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
  ----------------------------------------------------------------------------

  Dlluminator.CImporter - C Header to Delphi Unit Converter

  This unit converts C headers into Delphi unit source code. It uses tinycc
  for preprocessing (expanding macros, includes) then parses the
  result to generate Delphi declarations.

  Usage:
    LImporter := TDlmCImporter.Create();
    LImporter.SetModuleName('raylib');           // optional, defaults to header name
    LImporter.SetDllName('raylib.dll');          // optional, defaults to modulename.dll
    LImporter.SetOutputPath('output');           // optional, defaults to header folder
    LImporter.AddIncludePath('path/to/headers'); // optional, user include paths
    LImporter.AddExcludedType('va_list');        // optional, skip unwanted types
    LImporter.AddFunctionRename('SDL_Log', 'SDL_Log_'); // optional, rename for Delphi
    LImporter.InsertFileBefore('end.', 'colors.txt'); // optional, insert content
    LImporter.ImportHeader('raylib.h');          // preprocesses, parses, writes .pas
    LImporter.Free();
===============================================================================}

unit Dlluminator.CImporter;

{$I Dlluminator.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Dlluminator.Utils,
  Dlluminator.Config;

type
  { TCTokenKind }
  TDlmCTokenKind = (
    ctkEOF,
    ctkError,
    ctkIdentifier,
    ctkIntLiteral,
    ctkFloatLiteral,
    ctkStringLiteral,
    ctkTypedef,
    ctkStruct,
    ctkUnion,
    ctkEnum,
    ctkConst,
    ctkVoid,
    ctkChar,
    ctkShort,
    ctkInt,
    ctkLong,
    ctkFloat,
    ctkDouble,
    ctkSigned,
    ctkUnsigned,
    ctkBool,
    ctkExtern,
    ctkStatic,
    ctkInline,
    ctkRestrict,
    ctkVolatile,
    ctkAtomic,
    ctkBuiltin,
    ctkLBrace,
    ctkRBrace,
    ctkLParen,
    ctkRParen,
    ctkLBracket,
    ctkRBracket,
    ctkSemicolon,
    ctkComma,
    ctkStar,
    ctkEquals,
    ctkColon,
    ctkEllipsis,
    ctkDot,
    ctkHash,
    ctkLineMarker
  );

  { TDlmCToken }
  TDlmCToken = record
    Kind: TDlmCTokenKind;
    Lexeme: string;
    IntValue: Int64;
    FloatValue: Double;
    Line: Integer;
    Column: Integer;
  end;

  { TDlmCLexer }
  TDlmCLexer = class(TDlmBaseObject)
  private
    FSource: string;
    FPos: Integer;
    FLine: Integer;
    FColumn: Integer;
    FTokens: TList<TDlmCToken>;
    FCurrentChar: Char;

    procedure Advance();
    {$HINTS OFF}
    function Peek(): Char;
    {$HINTS ON}
    function PeekNext(): Char;
    procedure SkipWhitespace();
    procedure SkipLineComment();
    procedure SkipBlockComment();
    function ScanLineMarker(): TDlmCToken;
    function IsAlpha(const AChar: Char): Boolean;
    function IsDigit(const AChar: Char): Boolean;
    function IsAlphaNumeric(const AChar: Char): Boolean;
    function IsHexDigit(const AChar: Char): Boolean;
    function ScanIdentifier(): TDlmCToken;
    function ScanNumber(): TDlmCToken;
    function ScanString(): TDlmCToken;
    function MakeToken(const AKind: TDlmCTokenKind): TDlmCToken;
    function GetKeywordKind(const AIdent: string): TDlmCTokenKind;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Tokenize(const ASource: string);
    function GetTokenCount(): Integer;
    function GetToken(const AIndex: Integer): TDlmCToken;
    procedure Clear();
  end;

  { TDlmCFieldInfo }
  TDlmCFieldInfo = record
    FieldName: string;
    TypeName: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    ArraySize: Integer;
    BitWidth: Integer;
  end;

  { TDlmCStructInfo }
  TDlmCStructInfo = record
    StructName: string;
    IsUnion: Boolean;
    Fields: TArray<TDlmCFieldInfo>;
  end;

  { TDlmCEnumValue }
  TDlmCEnumValue = record
    ValueName: string;
    Value: Int64;
    HasExplicitValue: Boolean;
  end;

  { TCEnumInfo }
  TDlmCEnumInfo = record
    EnumName: string;
    Values: TArray<TDlmCEnumValue>;
  end;

  { TDlmCDefineInfo }
  TDlmCDefineInfo = record
    DefineName: string;
    DefineValue: string;
    IsInteger: Boolean;
    IntValue: Int64;
    IsFloat: Boolean;
    FloatValue: Double;
    IsString: Boolean;
    StringValue: string;
    IsTypedConstant: Boolean;
    TypedConstType: string;
    TypedConstValues: string;
  end;

  { TDlmCParamInfo }
  TDlmCParamInfo = record
    ParamName: string;
    TypeName: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    IsConst: Boolean;
    IsConstTarget: Boolean;
  end;

  { TDlmCFunctionInfo }
  TDlmCFunctionInfo = record
    FuncName: string;
    ReturnType: string;
    ReturnIsPointer: Boolean;
    ReturnPointerDepth: Integer;
    Params: TArray<TDlmCParamInfo>;
    IsVariadic: Boolean;
  end;

  { TDlmCTypedefInfo }
  TDlmCTypedefInfo = record
    AliasName: string;
    TargetType: string;
    IsPointer: Boolean;
    PointerDepth: Integer;
    IsFunctionPointer: Boolean;
    FuncInfo: TDlmCFunctionInfo;
  end;

  { TDlmInsertionInfo }
  TDlmInsertionInfo = record
    TargetLine: string;
    Content: string;
    InsertBefore: Boolean;
    Occurrence: Integer;
  end;

  { TDlmReplacementInfo }
  TDlmReplacementInfo = record
    OldText: string;
    NewText: string;
    Occurrence: Integer;
  end;

  { TDlmCImporter }
  TDlmCImporter = class(TDlmBaseObject)
  private
    FLexer: TDlmCLexer;
    FPos: Integer;
    FCurrentToken: TDlmCToken;
    FModuleName: string;
    FDllName: string;
    FDllPath: string;
    FResName: string;
    FOutput: TStringBuilder;
    FIndent: Integer;
    FIncludePaths: TList<string>;
    FSourcePaths: TList<string>;
    FExcludedTypes: TList<string>;
    FExcludedFunctions: TList<string>;
    FFunctionRenames: TDictionary<string, string>;
    FUsesUnits: TList<string>;
    FSavePreprocessed: Boolean;
    FOutputPath: string;
    FHeader: string;
    FLastError: string;

    FStructs: TList<TDlmCStructInfo>;
    FEnums: TList<TDlmCEnumInfo>;
    FTypedefs: TList<TDlmCTypedefInfo>;
    FDefines: TList<TDlmCDefineInfo>;
    FFunctions: TList<TDlmCFunctionInfo>;
    FForwardDecls: TList<string>;
    FInsertions: TList<TDlmInsertionInfo>;
    FReplacements: TList<TDlmReplacementInfo>;
    FCurrentSourceFile: string;

    function GetTccExePath(): string;
    function PreprocessHeader(const AHeaderFile: string; out APreprocessedSource: string): Boolean;

    function IsAtEnd(): Boolean;
    {$HINTS OFF}
    function Peek(): TDlmCToken;
    {$HINTS ON}
    function PeekNext(): TDlmCToken;
    procedure Advance();
    function Check(const AKind: TDlmCTokenKind): Boolean;
    function Match(const AKind: TDlmCTokenKind): Boolean;
    function MatchAny(const AKinds: array of TDlmCTokenKind): Boolean;

    procedure SkipToSemicolon();
    procedure SkipToRBrace();
    function IsTypeKeyword(): Boolean;
    function ParseBaseType(): string;
    function ParsePointerDepth(): Integer;

    procedure ParseTopLevel();
    procedure ParseTypedef();
    procedure ParseStruct(const AIsUnion: Boolean; out AInfo: TDlmCStructInfo);
    procedure ParseEnum(out AInfo: TDlmCEnumInfo);
    procedure ParseFunction(const AReturnType: string; const AReturnPtrDepth: Integer; const AFuncName: string);
    procedure ParseStructField(const AStruct: TDlmCStructInfo; var AFields: TArray<TDlmCFieldInfo>);

    procedure EmitLn(const AText: string = '');
    procedure EmitFmt(const AFormat: string; const AArgs: array of const);
    function MapCTypeToDelphi(const ACType: string; const AIsPointer: Boolean; const APtrDepth: Integer; const AIsConstTarget: Boolean = False): string;
    function ResolveTypedefAlias(const ATypeName: string): string;
    function SanitizeIdentifier(const AName: string): string;
    function IsAllowedSourceFile(): Boolean;
    function TypedefReferencesExcludedType(const ATypedef: TDlmCTypedefInfo): Boolean;
    function FunctionReferencesExcludedType(const AFunc: TDlmCFunctionInfo): Boolean;
    function GetDelphiFuncName(const AFuncName: string): string;
    procedure GenerateModule();
    procedure GenerateForwardDecls();
    procedure GenerateAllTypes();
    procedure GenerateFunctions();
    procedure GenerateSimpleConstants();
    procedure GenerateTypedConstants();
    procedure GenerateBindExports();
    procedure GenerateUnbindExports();
    function GenerateResName(): string;
    procedure ProcessInsertions();

    procedure ParseDefines(const APreprocessedSource: string);
    procedure ParsePreprocessed(const APreprocessedSource: string);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure AddIncludePath(const APath: string; const AModuleName: string = '');
    procedure AddSourcePath(const APath: string);
    procedure AddExcludedType(const ATypeName: string);
    procedure AddExcludedFunction(const AFuncName: string);
    procedure AddFunctionRename(const AOriginalName: string; const ADelphiName: string);
    procedure AddUsesUnit(const AUnitName: string);
    procedure SetSavePreprocessed(const AValue: Boolean);
    procedure InsertTextAfter(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1);
    procedure InsertFileAfter(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1);
    procedure InsertTextBefore(const ATargetLine: string; const AText: string; const AOccurrence: Integer = 1);
    procedure InsertFileBefore(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer = 1);
    procedure ReplaceText(const AOldText: string; const ANewText: string; const AOccurrence: Integer = 0);
    procedure SetOutputPath(const APath: string);
    procedure SetHeader(const AFilename: string);
    function Process(): Boolean;
    procedure SetModuleName(const AName: string);
    procedure SetDllName(const ADllName: string);
    procedure SetDllPath(const ADllPath: string);
    function LoadFromConfig(const AFilename: string): Boolean;
    function SaveToConfig(const AFilename: string): Boolean;
    function GetLastError(): string;
    procedure Clear();
  end;

implementation

{ TDlmCLexer }

constructor TDlmCLexer.Create();
begin
  inherited;
  FTokens := TList<TDlmCToken>.Create();
  Clear();
end;

destructor TDlmCLexer.Destroy();
begin
  FTokens.Free();
  inherited;
end;

procedure TDlmCLexer.Advance();
begin
  if FPos <= Length(FSource) then
  begin
    if FCurrentChar = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else
      Inc(FColumn);
    Inc(FPos);
  end;

  if FPos <= Length(FSource) then
    FCurrentChar := FSource[FPos]
  else
    FCurrentChar := #0;
end;

function TDlmCLexer.Peek(): Char;
begin
  Result := FCurrentChar;
end;

function TDlmCLexer.PeekNext(): Char;
begin
  if FPos + 1 <= Length(FSource) then
    Result := FSource[FPos + 1]
  else
    Result := #0;
end;

procedure TDlmCLexer.SkipWhitespace();
begin
  while (FCurrentChar <> #0) and (FCurrentChar <= ' ') do
    Advance();
end;

procedure TDlmCLexer.SkipLineComment();
begin
  while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
    Advance();
end;

procedure TDlmCLexer.SkipBlockComment();
begin
  Advance();
  while FCurrentChar <> #0 do
  begin
    if (FCurrentChar = '*') and (PeekNext() = '/') then
    begin
      Advance();
      Advance();
      Exit;
    end;
    Advance();
  end;
end;

function TDlmCLexer.ScanLineMarker(): TDlmCToken;
var
  LFilename: string;
  LKeyword: string;
begin
  Result.Kind := ctkLineMarker;
  Result.Lexeme := '';
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn;

  // Skip the '#'
  Advance();
  SkipWhitespace();

  // Check if this is a #define directive (skip it, parsed separately)
  if IsAlpha(FCurrentChar) then
  begin
    LKeyword := '';
    while IsAlphaNumeric(FCurrentChar) do
    begin
      LKeyword := LKeyword + FCurrentChar;
      Advance();
    end;
    // Skip rest of line for #define, #undef, etc.
    while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
      Advance();
    // Return empty line marker (will be ignored)
    Result.Lexeme := '';
    Exit;
  end;

  // Skip line number
  while IsDigit(FCurrentChar) do
    Advance();
  SkipWhitespace();

  // Parse filename in quotes
  if FCurrentChar = '"' then
  begin
    Advance(); // skip opening quote
    LFilename := '';
    while (FCurrentChar <> #0) and (FCurrentChar <> '"') and (FCurrentChar <> #10) do
    begin
      LFilename := LFilename + FCurrentChar;
      Advance();
    end;
    if FCurrentChar = '"' then
      Advance(); // skip closing quote
    Result.Lexeme := LFilename;
  end;

  // Skip rest of line (flags)
  while (FCurrentChar <> #0) and (FCurrentChar <> #10) do
    Advance();
end;

function TDlmCLexer.IsAlpha(const AChar: Char): Boolean;
begin
  Result := ((AChar >= 'a') and (AChar <= 'z')) or
            ((AChar >= 'A') and (AChar <= 'Z')) or
            (AChar = '_');
end;

function TDlmCLexer.IsDigit(const AChar: Char): Boolean;
begin
  Result := (AChar >= '0') and (AChar <= '9');
end;

function TDlmCLexer.IsAlphaNumeric(const AChar: Char): Boolean;
begin
  Result := IsAlpha(AChar) or IsDigit(AChar);
end;

function TDlmCLexer.IsHexDigit(const AChar: Char): Boolean;
begin
  Result := IsDigit(AChar) or
            ((AChar >= 'a') and (AChar <= 'f')) or
            ((AChar >= 'A') and (AChar <= 'F'));
end;

function TDlmCLexer.GetKeywordKind(const AIdent: string): TDlmCTokenKind;
begin
  if AIdent = 'typedef' then Result := ctkTypedef
  else if AIdent = 'struct' then Result := ctkStruct
  else if AIdent = 'union' then Result := ctkUnion
  else if AIdent = 'enum' then Result := ctkEnum
  else if AIdent = 'const' then Result := ctkConst
  else if AIdent = 'void' then Result := ctkVoid
  else if AIdent = 'char' then Result := ctkChar
  else if AIdent = 'short' then Result := ctkShort
  else if AIdent = 'int' then Result := ctkInt
  else if AIdent = 'long' then Result := ctkLong
  else if AIdent = 'float' then Result := ctkFloat
  else if AIdent = 'double' then Result := ctkDouble
  else if AIdent = 'signed' then Result := ctkSigned
  else if AIdent = 'unsigned' then Result := ctkUnsigned
  else if AIdent = '_Bool' then Result := ctkBool
  else if AIdent = 'extern' then Result := ctkExtern
  else if AIdent = 'static' then Result := ctkStatic
  else if AIdent = 'inline' then Result := ctkInline
  else if AIdent = '__inline' then Result := ctkInline
  else if AIdent = '__inline__' then Result := ctkInline
  else if AIdent = 'restrict' then Result := ctkRestrict
  else if AIdent = '__restrict' then Result := ctkRestrict
  else if AIdent = '__restrict__' then Result := ctkRestrict
  else if AIdent = 'volatile' then Result := ctkVolatile
  else if AIdent = '_Atomic' then Result := ctkAtomic
  else if AIdent.StartsWith('__builtin') then Result := ctkBuiltin
  else if AIdent.StartsWith('__attribute') then Result := ctkBuiltin
  else if AIdent.StartsWith('__declspec') then Result := ctkBuiltin
  else Result := ctkIdentifier;
end;

function TDlmCLexer.ScanIdentifier(): TDlmCToken;
var
  LStart: Integer;
  LIdent: string;
begin
  LStart := FPos;
  while IsAlphaNumeric(FCurrentChar) do
    Advance();
  LIdent := Copy(FSource, LStart, FPos - LStart);
  Result.Kind := GetKeywordKind(LIdent);
  Result.Lexeme := LIdent;
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn - Length(LIdent);
end;

function TDlmCLexer.ScanNumber(): TDlmCToken;
var
  LStart: Integer;
  LNumStr: string;
  LIsHex: Boolean;
  LIsFloat: Boolean;
begin
  LStart := FPos;
  LIsHex := False;
  LIsFloat := False;

  if (FCurrentChar = '0') and ((PeekNext() = 'x') or (PeekNext() = 'X')) then
  begin
    LIsHex := True;
    Advance();
    Advance();
    while IsHexDigit(FCurrentChar) do
      Advance();
  end
  else
  begin
    while IsDigit(FCurrentChar) do
      Advance();
    if (FCurrentChar = '.') and IsDigit(PeekNext()) then
    begin
      LIsFloat := True;
      Advance();
      while IsDigit(FCurrentChar) do
        Advance();
    end;
    if (FCurrentChar = 'e') or (FCurrentChar = 'E') then
    begin
      LIsFloat := True;
      Advance();
      if (FCurrentChar = '+') or (FCurrentChar = '-') then
        Advance();
      while IsDigit(FCurrentChar) do
        Advance();
    end;
  end;

  while CharInSet(FCurrentChar, ['u', 'U', 'l', 'L', 'f', 'F']) do
    Advance();

  LNumStr := Copy(FSource, LStart, FPos - LStart);

  if LIsFloat then
  begin
    Result.Kind := ctkFloatLiteral;
    Result.FloatValue := StrToFloatDef(LNumStr, 0);
    Result.IntValue := 0;
  end
  else
  begin
    Result.Kind := ctkIntLiteral;
    // Strip suffixes (U, L, LL, ULL, etc.) before parsing
    while (Length(LNumStr) > 0) and CharInSet(LNumStr[Length(LNumStr)], ['u', 'U', 'l', 'L']) do
      LNumStr := Copy(LNumStr, 1, Length(LNumStr) - 1);
    if LIsHex then
      Result.IntValue := StrToInt64Def('$' + Copy(LNumStr, 3, Length(LNumStr)), 0)
    else
      Result.IntValue := StrToInt64Def(LNumStr, 0);
    Result.FloatValue := 0;
  end;
  Result.Lexeme := LNumStr;
  Result.Line := FLine;
  Result.Column := FColumn - Length(LNumStr);
end;

function TDlmCLexer.ScanString(): TDlmCToken;
var
  LStart: Integer;
  LQuote: Char;
begin
  LQuote := FCurrentChar;
  LStart := FPos;
  Advance();
  while (FCurrentChar <> #0) and (FCurrentChar <> LQuote) do
  begin
    if FCurrentChar = '\' then
      Advance();
    Advance();
  end;
  if FCurrentChar = LQuote then
    Advance();
  Result.Kind := ctkStringLiteral;
  Result.Lexeme := Copy(FSource, LStart, FPos - LStart);
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn - Length(Result.Lexeme);
end;

function TDlmCLexer.MakeToken(const AKind: TDlmCTokenKind): TDlmCToken;
begin
  Result.Kind := AKind;
  Result.Lexeme := FCurrentChar;
  Result.IntValue := 0;
  Result.FloatValue := 0;
  Result.Line := FLine;
  Result.Column := FColumn;
  Advance();
end;

procedure TDlmCLexer.Tokenize(const ASource: string);
var
  LToken: TDlmCToken;
begin
  Clear();
  FSource := ASource;
  FPos := 1;
  FLine := 1;
  FColumn := 1;
  if Length(FSource) > 0 then
    FCurrentChar := FSource[1]
  else
    FCurrentChar := #0;

  while FCurrentChar <> #0 do
  begin
    SkipWhitespace();
    if FCurrentChar = #0 then
      Break;

    if (FCurrentChar = '#') and (FColumn = 1) then
    begin
      LToken := ScanLineMarker();
      FTokens.Add(LToken);
      Continue;
    end;

    if (FCurrentChar = '/') and (PeekNext() = '/') then
    begin
      SkipLineComment();
      Continue;
    end;

    if (FCurrentChar = '/') and (PeekNext() = '*') then
    begin
      Advance();
      SkipBlockComment();
      Continue;
    end;

    if IsAlpha(FCurrentChar) then
    begin
      LToken := ScanIdentifier();
      FTokens.Add(LToken);
      Continue;
    end;

    if IsDigit(FCurrentChar) then
    begin
      LToken := ScanNumber();
      FTokens.Add(LToken);
      Continue;
    end;

    if (FCurrentChar = '"') or (FCurrentChar = '''') then
    begin
      LToken := ScanString();
      FTokens.Add(LToken);
      Continue;
    end;

    case FCurrentChar of
      '{': FTokens.Add(MakeToken(ctkLBrace));
      '}': FTokens.Add(MakeToken(ctkRBrace));
      '(': FTokens.Add(MakeToken(ctkLParen));
      ')': FTokens.Add(MakeToken(ctkRParen));
      '[': FTokens.Add(MakeToken(ctkLBracket));
      ']': FTokens.Add(MakeToken(ctkRBracket));
      ';': FTokens.Add(MakeToken(ctkSemicolon));
      ',': FTokens.Add(MakeToken(ctkComma));
      '*': FTokens.Add(MakeToken(ctkStar));
      '=': FTokens.Add(MakeToken(ctkEquals));
      ':': FTokens.Add(MakeToken(ctkColon));
      '#': FTokens.Add(MakeToken(ctkHash));
      '.':
        begin
          if PeekNext() = '.' then
          begin
            Advance();
            Advance();
            if FCurrentChar = '.' then
            begin
              LToken.Kind := ctkEllipsis;
              LToken.Lexeme := '...';
              LToken.Line := FLine;
              LToken.Column := FColumn - 2;
              Advance();
              FTokens.Add(LToken);
            end;
          end
          else
            FTokens.Add(MakeToken(ctkDot));
        end;
    else
      Advance();
    end;
  end;

  LToken.Kind := ctkEOF;
  LToken.Lexeme := '';
  LToken.IntValue := 0;
  LToken.FloatValue := 0;
  LToken.Line := FLine;
  LToken.Column := FColumn;
  FTokens.Add(LToken);
end;

function TDlmCLexer.GetTokenCount(): Integer;
begin
  Result := FTokens.Count;
end;

function TDlmCLexer.GetToken(const AIndex: Integer): TDlmCToken;
begin
  if (AIndex >= 0) and (AIndex < FTokens.Count) then
    Result := FTokens[AIndex]
  else
  begin
    Result.Kind := ctkEOF;
    Result.Lexeme := '';
  end;
end;

procedure TDlmCLexer.Clear();
begin
  FTokens.Clear();
  FSource := '';
  FPos := 1;
  FLine := 1;
  FColumn := 1;
  FCurrentChar := #0;
end;

{ TDlmCImporter }

constructor TDlmCImporter.Create();
begin
  inherited;
  FLexer := TDlmCLexer.Create();
  FOutput := TStringBuilder.Create();
  FStructs := TList<TDlmCStructInfo>.Create();
  FEnums := TList<TDlmCEnumInfo>.Create();
  FTypedefs := TList<TDlmCTypedefInfo>.Create();
  FDefines := TList<TDlmCDefineInfo>.Create();
  FFunctions := TList<TDlmCFunctionInfo>.Create();
  FForwardDecls := TList<string>.Create();
  FInsertions := TList<TDlmInsertionInfo>.Create();
  FReplacements := TList<TDlmReplacementInfo>.Create();
  FIncludePaths := TList<string>.Create();
  FSourcePaths := TList<string>.Create();
  FExcludedTypes := TList<string>.Create();
  FExcludedFunctions := TList<string>.Create();
  FFunctionRenames := TDictionary<string, string>.Create();
  FUsesUnits := TList<string>.Create();
  FSavePreprocessed := False;
  FModuleName := '';
  FDllName := '';
  FOutputPath := '';
  FHeader := '';
  FLastError := '';
  FCurrentSourceFile := '';
  FIndent := 0;
  FPos := 0;

  // Init per-platform dictionaries

  // Exclude standard C library constants that conflict with stdint.h/inttypes.h
  AddExcludedType('true');
  AddExcludedType('false');

  // Exclude Windows platform macros that conflict with compiler-defined macros
  AddExcludedType('WIN32');
  AddExcludedType('WIN64');
  AddExcludedType('WINVER');
  AddExcludedType('NOSERVICE');
  AddExcludedType('NOMCX');
  AddExcludedType('NOIME');
  AddExcludedType('UNICODE');
  AddExcludedType('_UNICODE');

  // Exclude functions that conflict with compiler intrinsics
  AddExcludedType('INT8_MAX');
  AddExcludedType('INT16_MAX');
  AddExcludedType('INT32_MAX');
  AddExcludedType('INT64_MAX');
  AddExcludedType('INT8_MIN');
  AddExcludedType('INT16_MIN');
  AddExcludedType('INT32_MIN');
  AddExcludedType('INT64_MIN');
  AddExcludedType('UINT8_MAX');
  AddExcludedType('UINT16_MAX');
  AddExcludedType('UINT32_MAX');
  AddExcludedType('UINT64_MAX');
  AddExcludedType('INTMAX_MAX');
  AddExcludedType('INTMAX_MIN');
  AddExcludedType('UINTMAX_MAX');
  AddExcludedType('WCHAR_MIN');
  AddExcludedType('WCHAR_MAX');
  AddExcludedType('WINT_MIN');
  AddExcludedType('WINT_MAX');

  // Exclude printf/scanf format specifiers from inttypes.h
  AddExcludedType('PRId8');
  AddExcludedType('PRId16');
  AddExcludedType('PRId32');
  AddExcludedType('PRId64');
  AddExcludedType('PRIdLEAST8');
  AddExcludedType('PRIdLEAST16');
  AddExcludedType('PRIdLEAST32');
  AddExcludedType('PRIdLEAST64');
  AddExcludedType('PRIdFAST8');
  AddExcludedType('PRIdFAST16');
  AddExcludedType('PRIdFAST32');
  AddExcludedType('PRIdFAST64');
  AddExcludedType('PRIdMAX');
  AddExcludedType('PRIdPTR');
  AddExcludedType('PRIi8');
  AddExcludedType('PRIi16');
  AddExcludedType('PRIi32');
  AddExcludedType('PRIi64');
  AddExcludedType('PRIiLEAST8');
  AddExcludedType('PRIiLEAST16');
  AddExcludedType('PRIiLEAST32');
  AddExcludedType('PRIiLEAST64');
  AddExcludedType('PRIiFAST8');
  AddExcludedType('PRIiFAST16');
  AddExcludedType('PRIiFAST32');
  AddExcludedType('PRIiFAST64');
  AddExcludedType('PRIiMAX');
  AddExcludedType('PRIiPTR');
  AddExcludedType('PRIo8');
  AddExcludedType('PRIo16');
  AddExcludedType('PRIo32');
  AddExcludedType('PRIo64');
  AddExcludedType('PRIoLEAST8');
  AddExcludedType('PRIoLEAST16');
  AddExcludedType('PRIoLEAST32');
  AddExcludedType('PRIoLEAST64');
  AddExcludedType('PRIoFAST8');
  AddExcludedType('PRIoFAST16');
  AddExcludedType('PRIoFAST32');
  AddExcludedType('PRIoFAST64');
  AddExcludedType('PRIoMAX');
  AddExcludedType('PRIoPTR');
  AddExcludedType('PRIu8');
  AddExcludedType('PRIu16');
  AddExcludedType('PRIu32');
  AddExcludedType('PRIu64');
  AddExcludedType('PRIuLEAST8');
  AddExcludedType('PRIuLEAST16');
  AddExcludedType('PRIuLEAST32');
  AddExcludedType('PRIuLEAST64');
  AddExcludedType('PRIuFAST8');
  AddExcludedType('PRIuFAST16');
  AddExcludedType('PRIuFAST32');
  AddExcludedType('PRIuFAST64');
  AddExcludedType('PRIuMAX');
  AddExcludedType('PRIuPTR');
  AddExcludedType('PRIx8');
  AddExcludedType('PRIx16');
  AddExcludedType('PRIx32');
  AddExcludedType('PRIx64');
  AddExcludedType('PRIxLEAST8');
  AddExcludedType('PRIxLEAST16');
  AddExcludedType('PRIxLEAST32');
  AddExcludedType('PRIxLEAST64');
  AddExcludedType('PRIxFAST8');
  AddExcludedType('PRIxFAST16');
  AddExcludedType('PRIxFAST32');
  AddExcludedType('PRIxFAST64');
  AddExcludedType('PRIxMAX');
  AddExcludedType('PRIxPTR');
  AddExcludedType('PRIX8');
  AddExcludedType('PRIX16');
  AddExcludedType('PRIX32');
  AddExcludedType('PRIX64');
  AddExcludedType('PRIXLEAST8');
  AddExcludedType('PRIXLEAST16');
  AddExcludedType('PRIXLEAST32');
  AddExcludedType('PRIXLEAST64');
  AddExcludedType('PRIXFAST8');
  AddExcludedType('PRIXFAST16');
  AddExcludedType('PRIXFAST32');
  AddExcludedType('PRIXFAST64');
  AddExcludedType('PRIXMAX');
  AddExcludedType('PRIXPTR');
  AddExcludedType('SCNd8');
  AddExcludedType('SCNd16');
  AddExcludedType('SCNd32');
  AddExcludedType('SCNd64');
  AddExcludedType('SCNdLEAST8');
  AddExcludedType('SCNdLEAST16');
  AddExcludedType('SCNdLEAST32');
  AddExcludedType('SCNdLEAST64');
  AddExcludedType('SCNdFAST8');
  AddExcludedType('SCNdFAST16');
  AddExcludedType('SCNdFAST32');
  AddExcludedType('SCNdFAST64');
  AddExcludedType('SCNdMAX');
  AddExcludedType('SCNdPTR');
  AddExcludedType('SCNi8');
  AddExcludedType('SCNi16');
  AddExcludedType('SCNi32');
  AddExcludedType('SCNi64');
  AddExcludedType('SCNiLEAST8');
  AddExcludedType('SCNiLEAST16');
  AddExcludedType('SCNiLEAST32');
  AddExcludedType('SCNiLEAST64');
  AddExcludedType('SCNiFAST8');
  AddExcludedType('SCNiFAST16');
  AddExcludedType('SCNiFAST32');
  AddExcludedType('SCNiFAST64');
  AddExcludedType('SCNiMAX');
  AddExcludedType('SCNiPTR');
  AddExcludedType('SCNo8');
  AddExcludedType('SCNo16');
  AddExcludedType('SCNo32');
  AddExcludedType('SCNo64');
  AddExcludedType('SCNoLEAST8');
  AddExcludedType('SCNoLEAST16');
  AddExcludedType('SCNoLEAST32');
  AddExcludedType('SCNoLEAST64');
  AddExcludedType('SCNoFAST8');
  AddExcludedType('SCNoFAST16');
  AddExcludedType('SCNoFAST32');
  AddExcludedType('SCNoFAST64');
  AddExcludedType('SCNoMAX');
  AddExcludedType('SCNoPTR');
  AddExcludedType('SCNu8');
  AddExcludedType('SCNu16');
  AddExcludedType('SCNu32');
  AddExcludedType('SCNu64');
  AddExcludedType('SCNuLEAST8');
  AddExcludedType('SCNuLEAST16');
  AddExcludedType('SCNuLEAST32');
  AddExcludedType('SCNuLEAST64');
  AddExcludedType('SCNuFAST8');
  AddExcludedType('SCNuFAST16');
  AddExcludedType('SCNuFAST32');
  AddExcludedType('SCNuFAST64');
  AddExcludedType('SCNuMAX');
  AddExcludedType('SCNuPTR');
  AddExcludedType('SCNx8');
  AddExcludedType('SCNx16');
  AddExcludedType('SCNx32');
  AddExcludedType('SCNx64');
  AddExcludedType('SCNxLEAST8');
  AddExcludedType('SCNxLEAST16');
  AddExcludedType('SCNxLEAST32');
  AddExcludedType('SCNxLEAST64');
  AddExcludedType('SCNxFAST8');
  AddExcludedType('SCNxFAST16');
  AddExcludedType('SCNxFAST32');
  AddExcludedType('SCNxFAST64');
  AddExcludedType('SCNxMAX');
  AddExcludedType('SCNxPTR');

  AddExcludedFunction('alloca');

  //ReplaceText('parent:', 'parent_:');
  //ReplaceText('name:', 'name_:');

end;

destructor TDlmCImporter.Destroy();
begin
  FUsesUnits.Free();
  FExcludedFunctions.Free();
  FFunctionRenames.Free();
  FExcludedTypes.Free();
  FIncludePaths.Free();
  FSourcePaths.Free();
  FReplacements.Free();
  FInsertions.Free();
  FForwardDecls.Free();
  FFunctions.Free();
  FDefines.Free();
  FTypedefs.Free();
  FEnums.Free();
  FStructs.Free();
  FOutput.Free();
  FLexer.Free();

  inherited;
end;

function TDlmCImporter.GetTccExePath(): string;
var
  LBase: string;
begin
  LBase := TPath.GetDirectoryName(ParamStr(0));
  Result := TPath.Combine(LBase, '..\tinycc\tcc.exe');
end;

function TDlmCImporter.PreprocessHeader(const AHeaderFile: string; out APreprocessedSource: string): Boolean;
var
  LTccPath: string;
  LOutputFile: string;
  LOutputDir: string;
  LArgs: string;
  LPath: string;
  LExitCode: Cardinal;
  LWorkDir: string;
  LHeaderFile: string;
  LIncludePath: string;
  LCmdLine: string;
begin
  Result := False;
  APreprocessedSource := '';

  LTccPath := GetTccExePath();
  if not TFile.Exists(LTccPath) then
  begin
    FLastError := 'tcc.exe not found at ' + LTccPath;
    Exit;
  end;

  LHeaderFile := TPath.GetFullPath(AHeaderFile);
  LWorkDir := TPath.GetDirectoryName(LHeaderFile);

  if FOutputPath <> '' then
    LOutputDir := TPath.GetFullPath(FOutputPath)
  else
    LOutputDir := LWorkDir;
  LOutputFile := TPath.Combine(LOutputDir, FModuleName + '_pp.c');

  // Ensure output directory exists
  TDlmUtils.CreateDirInPath(LOutputFile);

  // Build args: cc -E -dD -I<path> ... <header> -o <output>
  LArgs := '-E -dD';
  for LPath in FIncludePaths do
  begin
    LIncludePath := TPath.GetFullPath(LPath).Replace('\', '/');
    LArgs := LArgs + ' -I"' + LIncludePath + '"';
  end;
  LArgs := LArgs + ' "' + LHeaderFile.Replace('\', '/') + '"';

  // tcc -E outputs to stdout, use cmd.exe to redirect
  LCmdLine := Format('/c ""%s" %s > "%s""', [LTccPath, LArgs, LOutputFile]);

  LExitCode := TDlmUtils.RunPE(GetEnvironmentVariable('COMSPEC'), LCmdLine, LWorkDir, True, SW_HIDE);

  if LExitCode <> 0 then
  begin
    FLastError := Format('Preprocessing failed with exit code %d', [LExitCode]);
    if TFile.Exists(LOutputFile) then
      TFile.Delete(LOutputFile);
    Exit;
  end;

  if TFile.Exists(LOutputFile) then
  begin
    APreprocessedSource := TFile.ReadAllText(LOutputFile);
    if not FSavePreprocessed then
      TFile.Delete(LOutputFile);
    Result := True;
  end
  else
    FLastError := 'Preprocessor output file not created';
end;

function TDlmCImporter.IsAtEnd(): Boolean;
begin
  Result := FCurrentToken.Kind = ctkEOF;
end;

function TDlmCImporter.Peek(): TDlmCToken;
begin
  Result := FCurrentToken;
end;

function TDlmCImporter.PeekNext(): TDlmCToken;
begin
  Result := FLexer.GetToken(FPos + 1);
end;

procedure TDlmCImporter.Advance();
begin
  Inc(FPos);
  FCurrentToken := FLexer.GetToken(FPos);
end;

function TDlmCImporter.Check(const AKind: TDlmCTokenKind): Boolean;
begin
  Result := FCurrentToken.Kind = AKind;
end;

function TDlmCImporter.Match(const AKind: TDlmCTokenKind): Boolean;
begin
  if Check(AKind) then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

function TDlmCImporter.FunctionReferencesExcludedType(const AFunc: TDlmCFunctionInfo): Boolean;
var
  LI: Integer;
  LTypedef: TDlmCTypedefInfo;
begin
  // Check return type directly
  if FExcludedTypes.Contains(AFunc.ReturnType) then
    Exit(True);

  // Check if return type is a typedef that references excluded types
  for LTypedef in FTypedefs do
  begin
    if LTypedef.AliasName = AFunc.ReturnType then
    begin
      if TypedefReferencesExcludedType(LTypedef) then
        Exit(True);
      Break;
    end;
  end;

  // Check all parameter types
  for LI := 0 to High(AFunc.Params) do
  begin
    if FExcludedTypes.Contains(AFunc.Params[LI].TypeName) then
      Exit(True);

    // Also check if parameter type is a typedef that references excluded types
    for LTypedef in FTypedefs do
    begin
      if LTypedef.AliasName = AFunc.Params[LI].TypeName then
      begin
        if TypedefReferencesExcludedType(LTypedef) then
          Exit(True);
        Break;
      end;
    end;
  end;

  Result := False;
end;

function TDlmCImporter.GetDelphiFuncName(const AFuncName: string): string;
begin
  if FFunctionRenames.TryGetValue(AFuncName, Result) then
    Exit;
  Result := SanitizeIdentifier(AFuncName);
end;

function TDlmCImporter.MatchAny(const AKinds: array of TDlmCTokenKind): Boolean;
var
  LKind: TDlmCTokenKind;
begin
  for LKind in AKinds do
  begin
    if Check(LKind) then
    begin
      Advance();
      Exit(True);
    end;
  end;
  Result := False;
end;

procedure TDlmCImporter.SkipToSemicolon();
begin
  while not IsAtEnd() and not Check(ctkSemicolon) do
    Advance();
  if Check(ctkSemicolon) then
    Advance();
end;

procedure TDlmCImporter.SkipToRBrace();
var
  LDepth: Integer;
begin
  LDepth := 1;
  while not IsAtEnd() and (LDepth > 0) do
  begin
    if Check(ctkLBrace) then
      Inc(LDepth)
    else if Check(ctkRBrace) then
      Dec(LDepth);
    Advance();
  end;
end;

function TDlmCImporter.IsTypeKeyword(): Boolean;
begin
  Result := FCurrentToken.Kind in [
    ctkVoid, ctkChar, ctkShort, ctkInt, ctkLong,
    ctkFloat, ctkDouble, ctkSigned, ctkUnsigned, ctkBool,
    ctkStruct, ctkUnion, ctkEnum, ctkConst
  ];
end;

function TDlmCImporter.ParseBaseType(): string;
var
  LHasUnsigned: Boolean;
  LHasSigned: Boolean;
  LHasLong: Boolean;
  LLongCount: Integer;
  LHasShort: Boolean;
  LDepth: Integer;
begin
  Result := '';
  LHasUnsigned := False;
  LHasSigned := False;
  LHasLong := False;
  LLongCount := 0;
  LHasShort := False;

  while True do
  begin
    case FCurrentToken.Kind of
      ctkConst, ctkVolatile, ctkRestrict, ctkAtomic, ctkInline, ctkStatic:
        Advance();
      ctkUnsigned:
        begin
          LHasUnsigned := True;
          Advance();
        end;
      ctkSigned:
        begin
          LHasSigned := True;
          Advance();
        end;
      ctkLong:
        begin
          LHasLong := True;
          Inc(LLongCount);
          Advance();
        end;
      ctkShort:
        begin
          LHasShort := True;
          Advance();
        end;
      ctkVoid:
        begin
          Result := 'void';
          Advance();
          Exit;
        end;
      ctkChar:
        begin
          if LHasUnsigned then
            Result := 'unsigned char'
          else if LHasSigned then
            Result := 'signed char'
          else
            Result := 'char';
          Advance();
          Exit;
        end;
      ctkInt:
        begin
          if LHasShort then
          begin
            if LHasUnsigned then Result := 'unsigned short' else Result := 'short';
          end
          else if LHasLong then
          begin
            if LLongCount >= 2 then
            begin
              if LHasUnsigned then Result := 'unsigned long long' else Result := 'long long';
            end
            else
            begin
              if LHasUnsigned then Result := 'unsigned long' else Result := 'long';
            end;
          end
          else
          begin
            if LHasUnsigned then Result := 'unsigned int' else Result := 'int';
          end;
          Advance();
          Exit;
        end;
      ctkFloat:
        begin
          Result := 'float';
          Advance();
          Exit;
        end;
      ctkDouble:
        begin
          if LHasLong then Result := 'long double' else Result := 'double';
          Advance();
          Exit;
        end;
      ctkBool:
        begin
          Result := '_Bool';
          Advance();
          Exit;
        end;
      ctkStruct, ctkUnion:
        begin
          if FCurrentToken.Kind = ctkStruct then Result := 'struct ' else Result := 'union ';
          Advance();
          if Check(ctkIdentifier) then
          begin
            Result := Result + FCurrentToken.Lexeme;
            Advance();
          end;
          if Check(ctkLBrace) then
          begin
            Advance();
            SkipToRBrace();
          end;
          Exit;
        end;
      ctkEnum:
        begin
          Result := 'enum ';
          Advance();
          if Check(ctkIdentifier) then
          begin
            Result := Result + FCurrentToken.Lexeme;
            Advance();
          end;
          if Check(ctkLBrace) then
          begin
            Advance();
            SkipToRBrace();
          end;
          Exit;
        end;
      ctkIdentifier:
        begin
          // If we've seen type modifiers (long, short, unsigned, signed),
          // this identifier is NOT a type name - it's the variable/param name
          if LHasUnsigned or LHasSigned or LHasLong or LHasShort then
            Break;  // Let final logic construct type from modifiers
          Result := FCurrentToken.Lexeme;
          Advance();
          Exit;
        end;
      ctkBuiltin:
        begin
          Result := FCurrentToken.Lexeme;
          Advance();
          if Check(ctkLParen) then
          begin
            LDepth := 1;
            Advance();
            while not IsAtEnd() and (LDepth > 0) do
            begin
              if Check(ctkLParen) then Inc(LDepth)
              else if Check(ctkRParen) then Dec(LDepth);
              Advance();
            end;
          end;
          Exit;
        end;
    else
      Break;
    end;
  end;

  if (Result = '') and (LHasUnsigned or LHasSigned or LHasLong or LHasShort) then
  begin
    if LHasShort then
    begin
      if LHasUnsigned then Result := 'unsigned short' else Result := 'short';
    end
    else if LHasLong then
    begin
      if LLongCount >= 2 then
      begin
        if LHasUnsigned then Result := 'unsigned long long' else Result := 'long long';
      end
      else
      begin
        if LHasUnsigned then Result := 'unsigned long' else Result := 'long';
      end;
    end
    else
    begin
      if LHasUnsigned then Result := 'unsigned int' else Result := 'int';
    end;
  end;
end;

function TDlmCImporter.ParsePointerDepth(): Integer;
begin
  Result := 0;
  while Check(ctkStar) do
  begin
    Inc(Result);
    Advance();
    while MatchAny([ctkConst, ctkVolatile, ctkRestrict]) do
      ;
  end;
end;

procedure TDlmCImporter.ParseTopLevel();
var
  LBaseType: string;
  LPtrDepth: Integer;
  LName: string;
begin
  while not IsAtEnd() do
  begin
    // Handle line markers to track current source file
    if Check(ctkLineMarker) then
    begin
      if FCurrentToken.Lexeme <> '' then
        FCurrentSourceFile := FCurrentToken.Lexeme;
      Advance();
      Continue;
    end;

    while MatchAny([ctkExtern, ctkStatic, ctkInline]) do
      ;

    if Check(ctkTypedef) then
      ParseTypedef()
    else if IsTypeKeyword() or Check(ctkIdentifier) then
    begin
      LBaseType := ParseBaseType();
      LPtrDepth := ParsePointerDepth();

      if Check(ctkIdentifier) then
      begin
        LName := FCurrentToken.Lexeme;
        Advance();

        if Check(ctkLParen) then
          ParseFunction(LBaseType, LPtrDepth, LName)
        else
          SkipToSemicolon();
      end
      else
        SkipToSemicolon();
    end
    else if Check(ctkSemicolon) then
      Advance()
    else
      Advance();
  end;
end;

procedure TDlmCImporter.ParseTypedef();
var
  LInfo: TDlmCTypedefInfo;
  LStructInfo: TDlmCStructInfo;
  LEnumInfo: TDlmCEnumInfo;
  LBaseType: string;
  LPtrDepth: Integer;
  LIsUnion: Boolean;
  LTagName: string;
  LAliasName: string;
  LParam: TDlmCParamInfo;
begin
  Advance();

  if Check(ctkStruct) or Check(ctkUnion) then
  begin
    LIsUnion := Check(ctkUnion);
    Advance();

    LTagName := '';
    if Check(ctkIdentifier) then
    begin
      LTagName := FCurrentToken.Lexeme;
      Advance();
    end;

    if Check(ctkLBrace) then
    begin
      ParseStruct(LIsUnion, LStructInfo);

      if Check(ctkIdentifier) then
      begin
        LStructInfo.StructName := FCurrentToken.Lexeme;
        Advance();
      end
      else if LTagName <> '' then
        LStructInfo.StructName := LTagName;

      if LStructInfo.StructName <> '' then
      begin
        if IsAllowedSourceFile() then
          FStructs.Add(LStructInfo);
      end;
    end
    else
    begin
      // Handle pointer typedefs like: typedef struct X *Y;
      LPtrDepth := ParsePointerDepth();
      if Check(ctkIdentifier) then
      begin
        LAliasName := FCurrentToken.Lexeme;
        Advance();

        if (LTagName <> '') and (LTagName = LAliasName) and (LPtrDepth = 0) then
        begin
          if IsAllowedSourceFile() and not FForwardDecls.Contains(LAliasName) then
            FForwardDecls.Add(LAliasName);
        end
        else if LTagName <> '' then
        begin
          // Add tag name as forward decl if it's an opaque struct (no body defined)
          if IsAllowedSourceFile() and not FForwardDecls.Contains(LTagName) then
            FForwardDecls.Add(LTagName);

          LInfo.AliasName := LAliasName;
          LInfo.TargetType := LTagName;
          LInfo.IsPointer := LPtrDepth > 0;
          LInfo.PointerDepth := LPtrDepth;
          LInfo.IsFunctionPointer := False;
          if IsAllowedSourceFile() then
            FTypedefs.Add(LInfo);
        end;
      end;
    end;
  end
  else if Check(ctkEnum) then
  begin
    Advance();
    LTagName := '';
    if Check(ctkIdentifier) then
    begin
      LTagName := FCurrentToken.Lexeme;
      Advance();
    end;

    if Check(ctkLBrace) then
    begin
      ParseEnum(LEnumInfo);

      if Check(ctkIdentifier) then
      begin
        LEnumInfo.EnumName := FCurrentToken.Lexeme;
        Advance();
      end
      else if LTagName <> '' then
        LEnumInfo.EnumName := LTagName;

      if LEnumInfo.EnumName <> '' then
      begin
        if IsAllowedSourceFile() then
          FEnums.Add(LEnumInfo);
      end;
    end;
  end
  else
  begin
    LBaseType := ParseBaseType();
    LPtrDepth := ParsePointerDepth();

    if Check(ctkLParen) then
    begin
      Advance();
      if Check(ctkStar) then
      begin
        Advance();
        if Check(ctkIdentifier) then
        begin
          LInfo.AliasName := FCurrentToken.Lexeme;
          LInfo.IsFunctionPointer := True;
          LInfo.TargetType := LBaseType;
          LInfo.IsPointer := LPtrDepth > 0;
          LInfo.PointerDepth := LPtrDepth;
          Advance();

          if Check(ctkRParen) then
            Advance();

          // Parse function pointer parameters into FuncInfo
          LInfo.FuncInfo.FuncName := LInfo.AliasName;
          LInfo.FuncInfo.ReturnType := LBaseType;
          LInfo.FuncInfo.ReturnIsPointer := LPtrDepth > 0;
          LInfo.FuncInfo.ReturnPointerDepth := LPtrDepth;
          LInfo.FuncInfo.IsVariadic := False;
          SetLength(LInfo.FuncInfo.Params, 0);

          if Check(ctkLParen) then
          begin
            Advance();

            while not IsAtEnd() and not Check(ctkRParen) do
            begin
              // Check for void parameter list
              if Check(ctkVoid) and (PeekNext().Kind = ctkRParen) then
              begin
                Advance();
                Break;
              end;

              // Check for variadic
              if Check(ctkEllipsis) then
              begin
                LInfo.FuncInfo.IsVariadic := True;
                Advance();
                Break;
              end;

              LParam.IsConst := False;
              LParam.IsConstTarget := False;
              if Check(ctkConst) then
              begin
                LParam.IsConst := True;
                Advance();
              end;

              LParam.TypeName := ParseBaseType();
              LParam.PointerDepth := ParsePointerDepth();
              LParam.IsPointer := LParam.PointerDepth > 0;

              // If const was before type and we have a pointer, it's pointer to const
              if LParam.IsConst and LParam.IsPointer then
                LParam.IsConstTarget := True;

              if Check(ctkConst) then
              begin
                LParam.IsConst := True;
                Advance();
              end;

              if Check(ctkIdentifier) then
              begin
                LParam.ParamName := FCurrentToken.Lexeme;
                Advance();
              end
              else
                LParam.ParamName := '';

              // Handle array parameters as pointers
              if Check(ctkLBracket) then
              begin
                LParam.IsPointer := True;
                Inc(LParam.PointerDepth);
                while not IsAtEnd() and not Check(ctkRBracket) do
                  Advance();
                Match(ctkRBracket);
              end;

              SetLength(LInfo.FuncInfo.Params, Length(LInfo.FuncInfo.Params) + 1);
              LInfo.FuncInfo.Params[High(LInfo.FuncInfo.Params)] := LParam;

              if not Match(ctkComma) then
                Break;
            end;

            Match(ctkRParen);
          end;

          if IsAllowedSourceFile() then
            FTypedefs.Add(LInfo);
        end;
      end
      else
      begin
        SkipToSemicolon();
        Exit;
      end;
    end
    else if Check(ctkIdentifier) then
    begin
      LInfo.AliasName := FCurrentToken.Lexeme;
      LInfo.TargetType := LBaseType;
      LInfo.IsPointer := LPtrDepth > 0;
      LInfo.PointerDepth := LPtrDepth;
      LInfo.IsFunctionPointer := False;
      Advance();
      if IsAllowedSourceFile() then
        FTypedefs.Add(LInfo);
    end;
  end;

  if Check(ctkSemicolon) then
    Advance();
end;

procedure TDlmCImporter.ParseStruct(const AIsUnion: Boolean; out AInfo: TDlmCStructInfo);
begin
  AInfo.StructName := '';
  AInfo.IsUnion := AIsUnion;
  SetLength(AInfo.Fields, 0);

  if not Match(ctkLBrace) then
    Exit;

  while not IsAtEnd() and not Check(ctkRBrace) do
    ParseStructField(AInfo, AInfo.Fields);

  Match(ctkRBrace);
end;

procedure TDlmCImporter.ParseStructField(const AStruct: TDlmCStructInfo; var AFields: TArray<TDlmCFieldInfo>);
var
  LField: TDlmCFieldInfo;
  LBaseType: string;
begin
  // Skip line markers inside structs/unions
  while Check(ctkLineMarker) do
  begin
    FCurrentSourceFile := FCurrentToken.Lexeme;
    Advance();
  end;

  if Check(ctkStruct) or Check(ctkUnion) then
  begin
    Advance();
    if Check(ctkIdentifier) then
      Advance();
    if Check(ctkLBrace) then
    begin
      Advance();
      SkipToRBrace();
    end;
  end;

  LBaseType := ParseBaseType();
  if LBaseType = '' then
  begin
    SkipToSemicolon();
    Exit;
  end;

  repeat
    LField.TypeName := LBaseType;
    LField.PointerDepth := ParsePointerDepth();
    LField.IsPointer := LField.PointerDepth > 0;
    LField.ArraySize := 0;
    LField.BitWidth := 0;

    if Check(ctkIdentifier) then
    begin
      LField.FieldName := FCurrentToken.Lexeme;
      Advance();

      if Check(ctkLBracket) then
      begin
        Advance();
        if Check(ctkIntLiteral) then
        begin
          LField.ArraySize := FCurrentToken.IntValue;
          Advance();
        end;
        Match(ctkRBracket);
      end;

      if Check(ctkColon) then
      begin
        Advance();
        if Check(ctkIntLiteral) then
        begin
          LField.BitWidth := FCurrentToken.IntValue;
          Advance();
        end;
      end;

      SetLength(AFields, Length(AFields) + 1);
      AFields[High(AFields)] := LField;
    end;
  until not Match(ctkComma);

  Match(ctkSemicolon);
end;

procedure TDlmCImporter.ParseEnum(out AInfo: TDlmCEnumInfo);
var
  LValue: TDlmCEnumValue;
  LNextVal: Int64;
begin
  AInfo.EnumName := '';
  SetLength(AInfo.Values, 0);
  LNextVal := 0;

  if not Match(ctkLBrace) then
    Exit;

  while not IsAtEnd() and not Check(ctkRBrace) do
  begin
    if Check(ctkIdentifier) then
    begin
      LValue.ValueName := FCurrentToken.Lexeme;
      LValue.HasExplicitValue := False;
      LValue.Value := LNextVal;
      Advance();

      if Match(ctkEquals) then
      begin
        LValue.HasExplicitValue := True;

        if Check(ctkIntLiteral) then
        begin
          LValue.Value := FCurrentToken.IntValue;
          Advance();
        end
        else
        begin
          // Skip complex expressions (macros, bitwise ops, etc.) until comma or rbrace
          while not IsAtEnd() and not Check(ctkComma) and not Check(ctkRBrace) do
            Advance();
          LValue.HasExplicitValue := False;  // Can't determine value
        end;
      end;

      LNextVal := LValue.Value + 1;
      SetLength(AInfo.Values, Length(AInfo.Values) + 1);
      AInfo.Values[High(AInfo.Values)] := LValue;
    end;

    if not Match(ctkComma) then
      Break;
  end;

  Match(ctkRBrace);
end;

procedure TDlmCImporter.ParseFunction(const AReturnType: string; const AReturnPtrDepth: Integer; const AFuncName: string);
var
  LFunc: TDlmCFunctionInfo;
  LParam: TDlmCParamInfo;
  LExisting: TDlmCFunctionInfo;
  LI: Integer;
begin
  // Skip if we've already seen this function name
  for LExisting in FFunctions do
  begin
    if LExisting.FuncName = AFuncName then
    begin
      // Skip to end of this declaration/definition
      while not IsAtEnd() and not Check(ctkSemicolon) do
      begin
        if Check(ctkLBrace) then
        begin
          Advance();
          SkipToRBrace();
          Exit;
        end;
        Advance();
      end;
      Match(ctkSemicolon);
      Exit;
    end;
  end;

  LFunc.FuncName := AFuncName;
  LFunc.ReturnType := AReturnType;
  LFunc.ReturnIsPointer := AReturnPtrDepth > 0;
  LFunc.ReturnPointerDepth := AReturnPtrDepth;
  LFunc.IsVariadic := False;
  SetLength(LFunc.Params, 0);

  if not Match(ctkLParen) then
  begin
    SkipToSemicolon();
    Exit;
  end;

  while not IsAtEnd() and not Check(ctkRParen) do
  begin
    if Check(ctkVoid) and (PeekNext().Kind = ctkRParen) then
    begin
      Advance();
      Break;
    end;

    if Check(ctkEllipsis) then
    begin
      LFunc.IsVariadic := True;
      Advance();
      Break;
    end;

    LParam.IsConst := False;
    LParam.IsConstTarget := False;
    if Check(ctkConst) then
    begin
      LParam.IsConst := True;
      Advance();
    end;

    LParam.TypeName := ParseBaseType();
    LParam.PointerDepth := ParsePointerDepth();
    LParam.IsPointer := LParam.PointerDepth > 0;

    // If const was before type and we have a pointer, it's pointer to const
    if LParam.IsConst and LParam.IsPointer then
      LParam.IsConstTarget := True;

    if Check(ctkConst) then
    begin
      LParam.IsConst := True;
      Advance();
    end;

    if Check(ctkIdentifier) then
    begin
      LParam.ParamName := FCurrentToken.Lexeme;
      Advance();
    end
    else
      LParam.ParamName := '';

    if Check(ctkLBracket) then
    begin
      LParam.IsPointer := True;
      Inc(LParam.PointerDepth);
      while not IsAtEnd() and not Check(ctkRBracket) do
        Advance();
      Match(ctkRBracket);
    end;

    SetLength(LFunc.Params, Length(LFunc.Params) + 1);
    LFunc.Params[High(LFunc.Params)] := LParam;

    if not Match(ctkComma) then
      Break;
  end;

  Match(ctkRParen);
  Match(ctkSemicolon);

  if IsAllowedSourceFile() then
  begin
    // Don't add malformed functions (parsing errors from macros/inline defs)
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
        Exit;
      if (Length(LFunc.Params[LI].TypeName) = 1) and CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
        Exit;
    end;
    // Final duplicate check
    for LExisting in FFunctions do
    begin
      if LExisting.FuncName = LFunc.FuncName then
        Exit;
    end;
    FFunctions.Add(LFunc);
  end;
end;

procedure TDlmCImporter.EmitLn(const AText: string);
begin
  FOutput.AppendLine(StringOfChar(' ', FIndent * 2) + AText);
end;

procedure TDlmCImporter.EmitFmt(const AFormat: string; const AArgs: array of const);
begin
  EmitLn(Format(AFormat, AArgs));
end;


function TDlmCImporter.MapCTypeToDelphi(const ACType: string; const AIsPointer: Boolean; const APtrDepth: Integer; const AIsConstTarget: Boolean): string;
var
  LBaseType: string;
  LI: Integer;
begin
  LBaseType := ACType;

  // Basic C types → Delphi types
  if LBaseType = 'void' then LBaseType := 'Pointer'
  else if LBaseType = '_Bool' then LBaseType := 'Boolean'
  else if LBaseType = 'bool' then LBaseType := 'Boolean'
  else if LBaseType = 'char' then LBaseType := 'UTF8Char'
  else if LBaseType = 'wchar_t' then LBaseType := 'WideChar'
  else if LBaseType = 'signed char' then LBaseType := 'ShortInt'
  else if LBaseType = 'unsigned char' then LBaseType := 'Byte'
  else if LBaseType = 'short' then LBaseType := 'SmallInt'
  else if LBaseType = 'unsigned short' then LBaseType := 'Word'
  else if LBaseType = 'int' then LBaseType := 'Integer'
  else if LBaseType = 'unsigned int' then LBaseType := 'Cardinal'
  else if LBaseType = 'long' then LBaseType := 'Integer'
  else if LBaseType = 'unsigned long' then LBaseType := 'Cardinal'
  else if LBaseType = 'long long' then LBaseType := 'Int64'
  else if LBaseType = 'unsigned long long' then LBaseType := 'UInt64'
  else if LBaseType = 'float' then LBaseType := 'Single'
  else if LBaseType = 'double' then LBaseType := 'Double'
  else if LBaseType = 'long double' then LBaseType := 'Double'

  // C99 stdint.h exact-width types
  else if LBaseType = 'int8_t' then LBaseType := 'Int8'
  else if LBaseType = 'int16_t' then LBaseType := 'Int16'
  else if LBaseType = 'int32_t' then LBaseType := 'Int32'
  else if LBaseType = 'int64_t' then LBaseType := 'Int64'
  else if LBaseType = 'uint8_t' then LBaseType := 'UInt8'
  else if LBaseType = 'uint16_t' then LBaseType := 'UInt16'
  else if LBaseType = 'uint32_t' then LBaseType := 'UInt32'
  else if LBaseType = 'uint64_t' then LBaseType := 'UInt64'

  // C99 stdint.h pointer/size types (Win64)
  else if LBaseType = 'size_t' then LBaseType := 'NativeUInt'
  else if LBaseType = 'ssize_t' then LBaseType := 'NativeInt'
  else if LBaseType = 'ptrdiff_t' then LBaseType := 'NativeInt'
  else if LBaseType = 'intptr_t' then LBaseType := 'NativeInt'
  else if LBaseType = 'uintptr_t' then LBaseType := 'NativeUInt'
  else if LBaseType = 'intmax_t' then LBaseType := 'Int64'
  else if LBaseType = 'uintmax_t' then LBaseType := 'UInt64'

  // SDL-specific integer types
  else if LBaseType = 'Sint8' then LBaseType := 'Int8'
  else if LBaseType = 'Sint16' then LBaseType := 'Int16'
  else if LBaseType = 'Sint32' then LBaseType := 'Int32'
  else if LBaseType = 'Sint64' then LBaseType := 'Int64'
  else if LBaseType = 'Uint8' then LBaseType := 'UInt8'
  else if LBaseType = 'Uint16' then LBaseType := 'UInt16'
  else if LBaseType = 'Uint32' then LBaseType := 'UInt32'
  else if LBaseType = 'Uint64' then LBaseType := 'UInt64'

  // Variadic argument types
  else if LBaseType = 'va_list' then LBaseType := 'Pointer'
  else if LBaseType = '__va_list_tag' then LBaseType := 'Pointer'

  // Compound type prefixes — strip prefix, keep original name
  else if LBaseType.StartsWith('struct ') then LBaseType := Copy(LBaseType, 8, Length(LBaseType))
  else if LBaseType.StartsWith('union ') then LBaseType := Copy(LBaseType, 7, Length(LBaseType))
  else if LBaseType.StartsWith('enum ') then LBaseType := Copy(LBaseType, 6, Length(LBaseType));

  // Special case: char* → PUTF8Char (most common C string type)
  if (ACType = 'char') and (APtrDepth = 1) then
  begin
    Result := 'PUTF8Char';
    Exit;
  end;

  // Special case: wchar_t* → PWideChar
  if (ACType = 'wchar_t') and (APtrDepth = 1) then
  begin
    Result := 'PWideChar';
    Exit;
  end;

  // Special case: void* → Pointer, void** → PPointer
  if (ACType = 'void') and (APtrDepth > 0) then
  begin
    if APtrDepth = 1 then
      Result := 'Pointer'
    else if APtrDepth = 2 then
      Result := 'PPointer'
    else
    begin
      Result := 'Pointer';
      for LI := 2 to APtrDepth do
        Result := 'P' + Result;
    end;
    Exit;
  end;

  // General pointer handling: T* → PT, T** → PPT
  if AIsPointer or (APtrDepth > 0) then
  begin
    Result := LBaseType;
    for LI := 1 to APtrDepth do
      Result := 'P' + Result;
  end
  else
    Result := LBaseType;
end;

function TDlmCImporter.ResolveTypedefAlias(const ATypeName: string): string;
var
  LTypedef: TDlmCTypedefInfo;
begin
  // Check if this type is a typedef alias and return the target type
  for LTypedef in FTypedefs do
  begin
    if (not LTypedef.IsFunctionPointer) and (LTypedef.AliasName = ATypeName) then
      Exit(LTypedef.TargetType);
  end;
  // Not a typedef alias, return as-is
  Result := ATypeName;
end;

function TDlmCImporter.SanitizeIdentifier(const AName: string): string;
const
  CDelphiKeywords: array[0..64] of string = (
    'and', 'array', 'as', 'asm', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library',
    'mod', 'nil', 'not', 'object', 'of', 'or', 'out', 'packed',
    'procedure', 'program', 'property', 'raise', 'record', 'repeat',
    'resourcestring', 'set', 'shl', 'shr', 'string', 'then', 'threadvar',
    'to', 'try', 'type', 'unit', 'until', 'uses', 'var', 'while',
    'with', 'xor'
  );
var
  LLower: string;
  LKeyword: string;
begin
  Result := AName;
  LLower := LowerCase(AName);
  for LKeyword in CDelphiKeywords do
  begin
    if LLower = LKeyword then
    begin
      Result := AName + '_';
      Exit;
    end;
  end;
end;

function TDlmCImporter.IsAllowedSourceFile(): Boolean;
var
  LPath: string;
  LNormalizedCurrent: string;
  LNormalizedAllowed: string;
  LFilterPaths: TList<string>;
begin
  // Use source paths if specified, otherwise fall back to include paths
  if FSourcePaths.Count > 0 then
    LFilterPaths := FSourcePaths
  else
    LFilterPaths := FIncludePaths;

  // If no filter paths specified, allow all
  if LFilterPaths.Count = 0 then
    Exit(True);

  // If no current source file tracked, allow (safety)
  if FCurrentSourceFile = '' then
    Exit(True);

  // Normalize current file path (forward slashes, lowercase)
  LNormalizedCurrent := LowerCase(FCurrentSourceFile.Replace('\', '/'));

  // Check if current file is under any allowed path
  for LPath in LFilterPaths do
  begin
    LNormalizedAllowed := LowerCase(LPath.Replace('\', '/'));
    // Ensure path ends with /
    if not LNormalizedAllowed.EndsWith('/') then
      LNormalizedAllowed := LNormalizedAllowed + '/';

    if LNormalizedCurrent.Contains(LNormalizedAllowed) then
      Exit(True);
  end;

  // File is from other headers, skip it
  Result := False;
end;

function TDlmCImporter.TypedefReferencesExcludedType(const ATypedef: TDlmCTypedefInfo): Boolean;
var
  LI: Integer;
begin
  // Check alias name
  if FExcludedTypes.Contains(ATypedef.AliasName) then
    Exit(True);

  // Check target type
  if FExcludedTypes.Contains(ATypedef.TargetType) then
    Exit(True);

  // For function pointers, check return type and all parameter types
  if ATypedef.IsFunctionPointer then
  begin
    if FExcludedTypes.Contains(ATypedef.FuncInfo.ReturnType) then
      Exit(True);

    for LI := 0 to High(ATypedef.FuncInfo.Params) do
    begin
      if FExcludedTypes.Contains(ATypedef.FuncInfo.Params[LI].TypeName) then
        Exit(True);
    end;
  end;

  Result := False;
end;

procedure TDlmCImporter.GenerateModule();
var
  LI: Integer;
begin
  FOutput.Clear();

  // === INTERFACE SECTION ===
  EmitFmt('unit %s;', [FModuleName]);
  EmitLn();
  EmitLn('interface');
  EmitLn();
  EmitLn('uses');
  Inc(FIndent);
  if FUsesUnits.Count > 0 then
  begin
    EmitLn('WinApi.Windows,');
    for LI := 0 to FUsesUnits.Count - 2 do
      EmitFmt('%s,', [FUsesUnits[LI]]);
    EmitFmt('%s;', [FUsesUnits[FUsesUnits.Count - 1]]);
  end
  else
    EmitLn('WinApi.Windows;');
  Dec(FIndent);
  EmitLn();

  // Common pointer helper types not declared in Delphi
  EmitLn('type');
  Inc(FIndent);
  EmitLn('PPUTF8Char = ^PUTF8Char;');
  EmitLn('PInt8 = ^Int8;');
  EmitLn('PUInt8 = ^UInt8;');
  EmitLn('PPUInt8 = ^PUInt8;');
  EmitLn('PInt16 = ^Int16;');
  EmitLn('PUInt16 = ^UInt16;');
  EmitLn('PInt32 = ^Int32;');
  EmitLn('PUInt32 = ^UInt32;');
  Dec(FIndent);
  EmitLn();

  // Emit interface content via sub-generators
  GenerateSimpleConstants();
  GenerateForwardDecls();
  GenerateAllTypes();
  GenerateTypedConstants();
  GenerateFunctions();

  // === IMPLEMENTATION SECTION ===
  EmitLn('implementation');
  EmitLn();
  EmitLn('uses');
  Inc(FIndent);
  EmitLn('Dlluminator;');
  Dec(FIndent);
  EmitLn();

  EmitFmt('{$R %s.res}', [FModuleName]);
  EmitLn();
  EmitLn();

  EmitLn('const');
  Inc(FIndent);
  EmitFmt('CDllName = ''%s'';', [FDllName]);
  EmitFmt('CResName = ''%s'';', [FResName]);
  Dec(FIndent);
  EmitLn();

  EmitLn('var');
  Inc(FIndent);
  EmitLn('GDllHandle: THandle = 0;');
  Dec(FIndent);
  EmitLn();

  GenerateBindExports();
  GenerateUnbindExports();

  EmitLn('initialization');
  Inc(FIndent);
  EmitLn('BindExports();');
  Dec(FIndent);
  EmitLn();
  EmitLn('finalization');
  Inc(FIndent);
  EmitLn('UnbindExports();');
  Dec(FIndent);
  EmitLn();
  EmitLn('end.');
end;

procedure TDlmCImporter.GenerateForwardDecls();
var
  LName: string;
  LSanitized: string;
begin
  if FForwardDecls.Count = 0 then
    Exit;

  EmitLn('type');
  Inc(FIndent);
  EmitLn('{ Forward declarations (opaque types) }');
  for LName in FForwardDecls do
  begin
    LSanitized := SanitizeIdentifier(LName);
    EmitFmt('P%s = ^%s;', [LSanitized, LSanitized]);
    EmitFmt('PP%s = ^P%s;', [LSanitized, LSanitized]);
    EmitFmt('%s = record end;', [LSanitized]);
  end;
  Dec(FIndent);
  EmitLn();
end;

procedure TDlmCImporter.GenerateAllTypes();
var
  LStruct: TDlmCStructInfo;
  LEnum: TDlmCEnumInfo;
  LTypedef: TDlmCTypedefInfo;
  LField: TDlmCFieldInfo;
  LValue: TDlmCEnumValue;
  LFieldType: string;
  LTargetType: string;
  LI: Integer;
  LHasTypes: Boolean;
  LParamStr: string;
  LParam: TDlmCParamInfo;
  LParamType: string;
  LParamName: string;
  LReturnType: string;
  LCurrentValue: Int64;
begin
  LHasTypes := (FStructs.Count > 0) or (FEnums.Count > 0) or (FTypedefs.Count > 0);
  if not LHasTypes then
    Exit;

  // 1. Emit enum type aliases
  if FEnums.Count > 0 then
  begin
    EmitLn('type');
    Inc(FIndent);
    for LEnum in FEnums do
    begin
      EmitFmt('%s = Cardinal;', [SanitizeIdentifier(LEnum.EnumName)]);
      EmitFmt('P%s = ^%s;', [SanitizeIdentifier(LEnum.EnumName),
        SanitizeIdentifier(LEnum.EnumName)]);
    end;
    Dec(FIndent);
    EmitLn();

    // 2. Emit enum value const groups
    EmitLn('const');
    Inc(FIndent);
    for LEnum in FEnums do
    begin
      EmitFmt('{ %s }', [LEnum.EnumName]);
      LCurrentValue := 0;
      for LI := 0 to High(LEnum.Values) do
      begin
        LValue := LEnum.Values[LI];
        if LValue.HasExplicitValue then
          LCurrentValue := LValue.Value;
        EmitFmt('%s = %d;', [SanitizeIdentifier(LValue.ValueName), LCurrentValue]);
        Inc(LCurrentValue);
      end;
      EmitLn();
    end;
    Dec(FIndent);
  end;

  // 3. Emit structs, type aliases, and function pointer types
  EmitLn('type');
  Inc(FIndent);

  // 3a. Pointer types + struct/union records
  for LStruct in FStructs do
  begin
    EmitFmt('P%s = ^%s;', [SanitizeIdentifier(LStruct.StructName),
      SanitizeIdentifier(LStruct.StructName)]);
    EmitFmt('PP%s = ^P%s;', [SanitizeIdentifier(LStruct.StructName),
      SanitizeIdentifier(LStruct.StructName)]);

    if LStruct.IsUnion then
    begin
      EmitFmt('%s = record', [SanitizeIdentifier(LStruct.StructName)]);
      Inc(FIndent);
      EmitLn('case Integer of');
      Inc(FIndent);
      for LI := 0 to High(LStruct.Fields) do
      begin
        LField := LStruct.Fields[LI];
        LFieldType := MapCTypeToDelphi(ResolveTypedefAlias(LField.TypeName),
          LField.IsPointer, LField.PointerDepth);
        if LField.ArraySize > 0 then
          EmitFmt('%d: (%s: array[0..%d] of %s);', [LI,
            SanitizeIdentifier(LField.FieldName), LField.ArraySize - 1, LFieldType])
        else
          EmitFmt('%d: (%s: %s);', [LI, SanitizeIdentifier(LField.FieldName), LFieldType]);
      end;
      Dec(FIndent);
      Dec(FIndent);
    end
    else
    begin
      EmitFmt('%s = record', [SanitizeIdentifier(LStruct.StructName)]);
      Inc(FIndent);
      for LField in LStruct.Fields do
      begin
        LFieldType := MapCTypeToDelphi(ResolveTypedefAlias(LField.TypeName),
          LField.IsPointer, LField.PointerDepth);
        if LField.ArraySize > 0 then
          EmitFmt('%s: array[0..%d] of %s;', [SanitizeIdentifier(LField.FieldName),
            LField.ArraySize - 1, LFieldType])
        else if LField.BitWidth > 0 then
          EmitFmt('%s: %s; { bitwidth: %d }', [SanitizeIdentifier(LField.FieldName),
            LFieldType, LField.BitWidth])
        else
          EmitFmt('%s: %s;', [SanitizeIdentifier(LField.FieldName), LFieldType]);
      end;
      Dec(FIndent);
    end;
    EmitLn('end;');
    EmitLn();
  end;

  // 3b. Type aliases (before function pointers, as they can reference aliases)
  for LTypedef in FTypedefs do
  begin
    if TypedefReferencesExcludedType(LTypedef) then
      Continue;
    if LTypedef.IsFunctionPointer then
      Continue;

    LTargetType := MapCTypeToDelphi(LTypedef.TargetType, LTypedef.IsPointer,
      LTypedef.PointerDepth);

    // Skip redundant aliases where both map to the same type
    if MapCTypeToDelphi(LTypedef.AliasName, False, 0) = LTargetType then
      Continue;

    EmitFmt('%s = %s;', [SanitizeIdentifier(LTypedef.AliasName), LTargetType]);
    EmitFmt('P%s = ^%s;', [SanitizeIdentifier(LTypedef.AliasName),
      SanitizeIdentifier(LTypedef.AliasName)]);
  end;
  EmitLn();

  // 3c. Function pointer types
  for LTypedef in FTypedefs do
  begin
    if TypedefReferencesExcludedType(LTypedef) then
      Continue;
    if not LTypedef.IsFunctionPointer then
      Continue;

    LParamStr := '';
    for LI := 0 to High(LTypedef.FuncInfo.Params) do
    begin
      LParam := LTypedef.FuncInfo.Params[LI];
      LParamType := MapCTypeToDelphi(LParam.TypeName, LParam.IsPointer,
        LParam.PointerDepth, LParam.IsConstTarget);
      if LParam.ParamName <> '' then
        LParamName := 'A' + LParam.ParamName
      else
        LParamName := Format('AParam%d', [LI]);
      if LI > 0 then
        LParamStr := LParamStr + '; ';
      LParamStr := LParamStr + Format('const %s: %s',
        [SanitizeIdentifier(LParamName), LParamType]);
    end;

    if (LTypedef.FuncInfo.ReturnType = 'void') and
       not LTypedef.FuncInfo.ReturnIsPointer then
      EmitFmt('%s = procedure(%s);',
        [SanitizeIdentifier(LTypedef.AliasName), LParamStr])
    else
    begin
      LReturnType := MapCTypeToDelphi(LTypedef.FuncInfo.ReturnType,
        LTypedef.FuncInfo.ReturnIsPointer, LTypedef.FuncInfo.ReturnPointerDepth);
      EmitFmt('%s = function(%s): %s;',
        [SanitizeIdentifier(LTypedef.AliasName), LParamStr, LReturnType]);
    end;
    EmitFmt('P%s = ^%s;', [SanitizeIdentifier(LTypedef.AliasName),
      SanitizeIdentifier(LTypedef.AliasName)]);
  end;
  EmitLn();

  Dec(FIndent);
  EmitLn();
end;

procedure TDlmCImporter.GenerateFunctions();
var
  LFunc: TDlmCFunctionInfo;
  LParam: TDlmCParamInfo;
  LReturnType: string;
  LParamStr: string;
  LI: Integer;
  LParamType: string;
  LParamName: string;
  LSkip: Boolean;
begin
  if FFunctions.Count = 0 then
    Exit;

  EmitLn('var');
  Inc(FIndent);

  for LFunc in FFunctions do
  begin
    if FExcludedFunctions.Contains(LFunc.FuncName) then
      Continue;
    if FunctionReferencesExcludedType(LFunc) then
      Continue;

    // Skip malformed functions (parsing errors)
    if (LFunc.ReturnType = '') or (LFunc.ReturnType = 'return') then
      Continue;
    if (Length(LFunc.ReturnType) = 1) and CharInSet(LFunc.ReturnType[1], ['a'..'z', 'A'..'Z']) then
      Continue;

    LSkip := False;
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
      begin
        LSkip := True;
        Break;
      end;
      if (Length(LFunc.Params[LI].TypeName) = 1) and
         CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
      begin
        LSkip := True;
        Break;
      end;
    end;
    if LSkip then
      Continue;

    LParamStr := '';
    for LI := 0 to High(LFunc.Params) do
    begin
      LParam := LFunc.Params[LI];
      LParamType := MapCTypeToDelphi(LParam.TypeName, LParam.IsPointer,
        LParam.PointerDepth, LParam.IsConstTarget);
      if LParam.ParamName <> '' then
        LParamName := 'A' + LParam.ParamName
      else
        LParamName := Format('AParam%d', [LI]);
      if LI > 0 then
        LParamStr := LParamStr + '; ';
      LParamStr := LParamStr + Format('const %s: %s',
        [SanitizeIdentifier(LParamName), LParamType]);
    end;

    if (LFunc.ReturnType = 'void') and not LFunc.ReturnIsPointer then
      EmitFmt('%s: procedure(%s);', [GetDelphiFuncName(LFunc.FuncName), LParamStr])
    else
    begin
      LReturnType := MapCTypeToDelphi(LFunc.ReturnType, LFunc.ReturnIsPointer,
        LFunc.ReturnPointerDepth);
      EmitFmt('%s: function(%s): %s;', [GetDelphiFuncName(LFunc.FuncName),
        LParamStr, LReturnType]);
    end;
  end;

  Dec(FIndent);
  EmitLn();
end;

procedure TDlmCImporter.GenerateSimpleConstants();
var
  LDefine: TDlmCDefineInfo;
  LHasConstants: Boolean;
begin
  LHasConstants := False;
  for LDefine in FDefines do
  begin
    // Skip excluded constants when checking
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;

    if LDefine.IsInteger or LDefine.IsFloat or LDefine.IsString then
    begin
      LHasConstants := True;
      Break;
    end;
  end;

  if not LHasConstants then
    Exit;

  EmitLn('const');
  Inc(FIndent);
  EmitLn('{ Constants from #define }');

  for LDefine in FDefines do
  begin
    // Skip excluded constants (e.g., stdint.h macros)
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;

    if LDefine.IsInteger then
      EmitFmt('%s = %d;', [SanitizeIdentifier(LDefine.DefineName), LDefine.IntValue])
    else if LDefine.IsFloat then
      EmitFmt('%s = %s;', [SanitizeIdentifier(LDefine.DefineName), FloatToStr(LDefine.FloatValue)])
    else if LDefine.IsString then
      EmitFmt('%s = ''%s'';', [SanitizeIdentifier(LDefine.DefineName), LDefine.StringValue.Replace('''', '''''')]);
  end;

  Dec(FIndent);
  EmitLn();
end;

procedure TDlmCImporter.GenerateTypedConstants();
var
  LDefine: TDlmCDefineInfo;
  LHasTypedConstants: Boolean;
  LStruct: TDlmCStructInfo;
  LValues: TArray<string>;
  LFieldInits: string;
  LStructFound: Boolean;
  LI: Integer;
begin
  LHasTypedConstants := False;
  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;

    if LDefine.IsTypedConstant then
    begin
      LHasTypedConstants := True;
      Break;
    end;
  end;

  if not LHasTypedConstants then
    Exit;

  EmitLn('const');
  Inc(FIndent);
  EmitLn('{ Typed constants from compound literals }');

  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;

    if LDefine.IsTypedConstant then
    begin
      // Look up struct to get field names for Delphi record constant syntax
      LStructFound := False;
      for LStruct in FStructs do
      begin
        if LStruct.StructName = LDefine.TypedConstType then
        begin
          LStructFound := True;
          Break;
        end;
      end;

      if LStructFound then
      begin
        // Split values and pair with field names: (field1: val1; field2: val2)
        LValues := LDefine.TypedConstValues.Split([',']);
        LFieldInits := '';
        for LI := 0 to High(LValues) do
        begin
          if LI > High(LStruct.Fields) then
            Break;
          if LI > 0 then
            LFieldInits := LFieldInits + '; ';
          LFieldInits := LFieldInits + LStruct.Fields[LI].FieldName + ': ' + LValues[LI].Trim();
        end;
        EmitFmt('%s: %s = (%s);', [
          SanitizeIdentifier(LDefine.DefineName),
          SanitizeIdentifier(LDefine.TypedConstType),
          LFieldInits
        ]);
      end
      else
      begin
        // Fallback — no struct found, emit positional
        EmitFmt('%s: %s = (%s);', [
          SanitizeIdentifier(LDefine.DefineName),
          SanitizeIdentifier(LDefine.TypedConstType),
          LDefine.TypedConstValues
        ]);
      end;
    end;
  end;

  Dec(FIndent);
  EmitLn();
end;

procedure TDlmCImporter.ParseDefines(const APreprocessedSource: string);
var
  LLines: TArray<string>;
  LLine: string;
  LTrimmed: string;
  LDefineInfo: TDlmCDefineInfo;
  LSpacePos: Integer;
  LValue: string;
  LIntVal: Int64;
  LFloatVal: Double;
  LQuoteStart: Integer;
  LQuoteEnd: Integer;
  LParenPos: Integer;
  LBracePos: Integer;
  LPrefix: string;
  LBraceEnd: Integer;
  LTypeStart: Integer;
  LTypeName: string;
  LValues: string;
  LCastEnd: Integer;
  LInnerValue: string;
begin
  // Parse #define directives from preprocessed source
  // Format: #define NAME value
  LLines := APreprocessedSource.Split([#10]);
  for LLine in LLines do
  begin
    LTrimmed := LLine.Trim();

    // Check for line marker to track current source file
    // Format: # linenum "filename" [flags]
    if (Length(LTrimmed) > 2) and (LTrimmed[1] = '#') and (LTrimmed[2] = ' ') and
       CharInSet(LTrimmed[3], ['0'..'9']) then
    begin
      LQuoteStart := Pos('"', LTrimmed);
      if LQuoteStart > 0 then
      begin
        LQuoteEnd := Pos('"', LTrimmed, LQuoteStart + 1);
        if LQuoteEnd > LQuoteStart then
          FCurrentSourceFile := Copy(LTrimmed, LQuoteStart + 1, LQuoteEnd - LQuoteStart - 1);
      end;
      Continue;
    end;

    // Skip if not a #define
    if not LTrimmed.StartsWith('#define ') then
      Continue;

    // Skip defines from non-allowed source files
    if not IsAllowedSourceFile() then
      Continue;

    // Extract name and value: "#define NAME value"
    LTrimmed := Copy(LTrimmed, 9, Length(LTrimmed)); // Skip "#define "
    LTrimmed := LTrimmed.TrimLeft();

    // Skip function-like macros (parenthesis immediately after name, before space)
    // Function-like: #define FOO(x) -> "FOO(x) ..."
    // Value with cast: #define FOO ((Type) val) -> "FOO ((Type) val)"
    LSpacePos := Pos(' ', LTrimmed);
    LParenPos := Pos('(', LTrimmed);
    if (LParenPos > 0) and ((LSpacePos = 0) or (LParenPos < LSpacePos)) then
      Continue;

    // Find space separating name from value (already found above)
    if LSpacePos = 0 then
      Continue; // No value, skip

    LDefineInfo.DefineName := Copy(LTrimmed, 1, LSpacePos - 1);
    LValue := Copy(LTrimmed, LSpacePos + 1, Length(LTrimmed)).Trim();
    LDefineInfo.DefineValue := LValue;

    // Skip empty values
    if LValue = '' then
      Continue;

    // Skip internal/system defines (start with underscore)
    if LDefineInfo.DefineName.StartsWith('_') then
      Continue;

    // Determine value type
    LDefineInfo.IsInteger := False;
    LDefineInfo.IsFloat := False;
    LDefineInfo.IsString := False;
    LDefineInfo.IsTypedConstant := False;
    LDefineInfo.IntValue := 0;
    LDefineInfo.FloatValue := 0;
    LDefineInfo.StringValue := '';
    LDefineInfo.TypedConstType := '';
    LDefineInfo.TypedConstValues := '';

    // Handle compound literals: IDENTIFIER(Type){ val1, val2, ... } or (Type){ val1, val2, ... }
    // Examples: CLITERAL(Color){ 200, 200, 200, 255 }, (Vector2){ 1.0f, 2.0f }
    LBracePos := Pos('{', LValue);
    if LBracePos > 1 then
    begin
      LPrefix := Copy(LValue, 1, LBracePos - 1).Trim();
      LBraceEnd := Pos('}', LValue);
      if (LBraceEnd > LBracePos) and LPrefix.EndsWith(')') then
      begin
        // Extract type name from IDENTIFIER(Type) or (Type)
        LTypeStart := Pos('(', LPrefix);
        if LTypeStart > 0 then
        begin
          LTypeName := Copy(LPrefix, LTypeStart + 1, Length(LPrefix) - LTypeStart - 1);
          // Extract values between { and }
          LValues := Copy(LValue, LBracePos + 1, LBraceEnd - LBracePos - 1).Trim();
          if (LTypeName <> '') and (LValues <> '') then
          begin
            LDefineInfo.IsTypedConstant := True;
            LDefineInfo.TypedConstType := LTypeName;
            LDefineInfo.TypedConstValues := LValues;
            FDefines.Add(LDefineInfo);
            Continue;
          end;
        end;
      end;
    end;

    // Handle C cast expressions: ((TypeName) value) or (TypeName) value
    // Examples: ((SDL_AudioDeviceID) 0xFFFFFFFFu), (int) 42
    if LValue.StartsWith('(') then
    begin
      // Find the closing paren of the cast type
      LCastEnd := Pos(')', LValue);
      if LCastEnd > 0 then
      begin
        // Extract everything after the cast
        LInnerValue := Copy(LValue, LCastEnd + 1, Length(LValue)).Trim();
        // Strip outer parens if present: ((Type) val) -> val)
        if LInnerValue.EndsWith(')') then
          LInnerValue := Copy(LInnerValue, 1, Length(LInnerValue) - 1).Trim();
        // Use extracted value for further parsing
        if LInnerValue <> '' then
          LValue := LInnerValue;
      end;
    end;

    // Check for hex integer
    if LValue.StartsWith('0x') or LValue.StartsWith('0X') then
    begin
      // Strip suffixes
      while (Length(LValue) > 0) and CharInSet(LValue[Length(LValue)], ['u', 'U', 'l', 'L']) do
        LValue := Copy(LValue, 1, Length(LValue) - 1);
      if TryStrToInt64('$' + Copy(LValue, 3, Length(LValue)), LIntVal) then
      begin
        LDefineInfo.IsInteger := True;
        LDefineInfo.IntValue := LIntVal;
      end;
    end
    // Check for decimal integer
    else if (Length(LValue) > 0) and (CharInSet(LValue[1], ['0'..'9', '-'])) then
    begin
      // Strip suffixes
      while (Length(LValue) > 0) and CharInSet(LValue[Length(LValue)], ['u', 'U', 'l', 'L', 'f', 'F']) do
        LValue := Copy(LValue, 1, Length(LValue) - 1);

      // Try integer first
      if TryStrToInt64(LValue, LIntVal) then
      begin
        LDefineInfo.IsInteger := True;
        LDefineInfo.IntValue := LIntVal;
      end
      // Try float
      else if TryStrToFloat(LValue, LFloatVal) then
      begin
        LDefineInfo.IsFloat := True;
        LDefineInfo.FloatValue := LFloatVal;
      end;
    end
    // Check for string literal
    else if LValue.StartsWith('"') and LValue.EndsWith('"') then
    begin
      LDefineInfo.IsString := True;
      LDefineInfo.StringValue := Copy(LValue, 2, Length(LValue) - 2);
    end;

    // Only add if we parsed a value
    if LDefineInfo.IsInteger or LDefineInfo.IsFloat or LDefineInfo.IsString then
      FDefines.Add(LDefineInfo);
  end;
end;

procedure TDlmCImporter.ParsePreprocessed(const APreprocessedSource: string);
begin
  // Parse #define directives first (before tokenization strips them)
  ParseDefines(APreprocessedSource);

  FLexer.Tokenize(APreprocessedSource);
  FPos := 0;
  FCurrentToken := FLexer.GetToken(0);
  ParseTopLevel();
  GenerateModule();
  ProcessInsertions();
end;

procedure TDlmCImporter.AddIncludePath(const APath: string; const AModuleName: string);
var
  LPath: string;
begin
  LPath := TPath.GetFullPath(APath).Replace('\', '/');
  if not FIncludePaths.Contains(LPath) then
    FIncludePaths.Add(LPath);
end;

procedure TDlmCImporter.AddSourcePath(const APath: string);
var
  LPath: string;
begin
  LPath := TPath.GetFullPath(APath).Replace('\', '/');
  if not FSourcePaths.Contains(LPath) then
    FSourcePaths.Add(LPath);
end;

procedure TDlmCImporter.AddExcludedType(const ATypeName: string);
begin
  if not FExcludedTypes.Contains(ATypeName) then
    FExcludedTypes.Add(ATypeName);
end;

procedure TDlmCImporter.AddExcludedFunction(const AFuncName: string);
begin
  if not FExcludedFunctions.Contains(AFuncName) then
    FExcludedFunctions.Add(AFuncName);
end;

procedure TDlmCImporter.AddFunctionRename(const AOriginalName: string; const ADelphiName: string);
begin
  FFunctionRenames.AddOrSetValue(AOriginalName, ADelphiName);
end;

procedure TDlmCImporter.AddUsesUnit(const AUnitName: string);
begin
  if not FUsesUnits.Contains(AUnitName) then
    FUsesUnits.Add(AUnitName);
end;

procedure TDlmCImporter.SetSavePreprocessed(const AValue: Boolean);
begin
  FSavePreprocessed := AValue;
end;

procedure TDlmCImporter.InsertTextAfter(const ATargetLine: string; const AText: string; const AOccurrence: Integer);
var
  LInfo: TDlmInsertionInfo;
begin
  LInfo.TargetLine := ATargetLine;
  LInfo.Content := AText;
  LInfo.InsertBefore := False;
  LInfo.Occurrence := AOccurrence;
  FInsertions.Add(LInfo);
end;

procedure TDlmCImporter.InsertFileAfter(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer);
var
  LContent: string;
begin
  if TFile.Exists(AFilePath) then
  begin
    LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
    InsertTextAfter(ATargetLine, LContent, AOccurrence);
  end;
end;

procedure TDlmCImporter.InsertTextBefore(const ATargetLine: string; const AText: string; const AOccurrence: Integer);
var
  LInfo: TDlmInsertionInfo;
begin
  LInfo.TargetLine := ATargetLine;
  LInfo.Content := AText;
  LInfo.InsertBefore := True;
  LInfo.Occurrence := AOccurrence;
  FInsertions.Add(LInfo);
end;

procedure TDlmCImporter.InsertFileBefore(const ATargetLine: string; const AFilePath: string; const AOccurrence: Integer);
var
  LContent: string;
begin
  if TFile.Exists(AFilePath) then
  begin
    LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
    InsertTextBefore(ATargetLine, LContent, AOccurrence);
  end;
end;

procedure TDlmCImporter.ReplaceText(const AOldText: string; const ANewText: string; const AOccurrence: Integer);
var
  LInfo: TDlmReplacementInfo;
begin
  LInfo.OldText := AOldText;
  LInfo.NewText := ANewText;
  LInfo.Occurrence := AOccurrence;
  FReplacements.Add(LInfo);
end;

procedure TDlmCImporter.GenerateBindExports();
var
  LFunc: TDlmCFunctionInfo;
  LI: Integer;
  LSkip: Boolean;
begin
  if FFunctions.Count = 0 then
    Exit;

  EmitLn('procedure BindExports();');
  EmitLn('begin');
  Inc(FIndent);
  EmitLn('RegisterDllData(CDllName, CResName);');
  EmitLn('GDllHandle := Dlluminator.LoadLibrary(CDllName);');
  EmitLn('if GDllHandle = 0 then');
  Inc(FIndent);
  EmitLn('Exit;');
  Dec(FIndent);

  for LFunc in FFunctions do
  begin
    if FExcludedFunctions.Contains(LFunc.FuncName) then
      Continue;
    if FunctionReferencesExcludedType(LFunc) then
      Continue;
    if (LFunc.ReturnType = '') or (LFunc.ReturnType = 'return') then
      Continue;
    if (Length(LFunc.ReturnType) = 1) and CharInSet(LFunc.ReturnType[1], ['a'..'z', 'A'..'Z']) then
      Continue;

    LSkip := False;
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
      begin
        LSkip := True;
        Break;
      end;
      if (Length(LFunc.Params[LI].TypeName) = 1) and
         CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
      begin
        LSkip := True;
        Break;
      end;
    end;
    if LSkip then
      Continue;

    EmitFmt('@%s := GetProcAddress(GDllHandle, ''%s'');', [
      GetDelphiFuncName(LFunc.FuncName), LFunc.FuncName]);
  end;

  Dec(FIndent);
  EmitLn('end;');
  EmitLn();
end;

procedure TDlmCImporter.GenerateUnbindExports();
var
  LFunc: TDlmCFunctionInfo;
  LI: Integer;
  LSkip: Boolean;
begin
  if FFunctions.Count = 0 then
    Exit;

  EmitLn('procedure UnbindExports();');
  EmitLn('begin');
  Inc(FIndent);

  for LFunc in FFunctions do
  begin
    if FExcludedFunctions.Contains(LFunc.FuncName) then
      Continue;
    if FunctionReferencesExcludedType(LFunc) then
      Continue;
    if (LFunc.ReturnType = '') or (LFunc.ReturnType = 'return') then
      Continue;
    if (Length(LFunc.ReturnType) = 1) and CharInSet(LFunc.ReturnType[1], ['a'..'z', 'A'..'Z']) then
      Continue;

    LSkip := False;
    for LI := 0 to High(LFunc.Params) do
    begin
      if LFunc.Params[LI].TypeName = '' then
      begin
        LSkip := True;
        Break;
      end;
      if (Length(LFunc.Params[LI].TypeName) = 1) and
         CharInSet(LFunc.Params[LI].TypeName[1], ['a'..'z', 'A'..'Z']) then
      begin
        LSkip := True;
        Break;
      end;
    end;
    if LSkip then
      Continue;

    EmitFmt('@%s := nil;', [GetDelphiFuncName(LFunc.FuncName)]);
  end;

  EmitLn('if GDllHandle <> 0 then');
  EmitLn('begin');
  Inc(FIndent);
  EmitLn('FreeLibrary(GDllHandle);');
  EmitLn('GDllHandle := 0;');
  Dec(FIndent);
  EmitLn('end;');

  Dec(FIndent);
  EmitLn('end;');
  EmitLn();
end;

function TDlmCImporter.GenerateResName(): string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := LowerCase(GUIDToString(LGuid));
  Result := StringReplace(Result, '{', '', []);
  Result := StringReplace(Result, '}', '', []);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := 'r' + Result;
end;

procedure TDlmCImporter.ProcessInsertions();
var
  LOutput: string;
  LInsertion: TDlmInsertionInfo;
  LReplacement: TDlmReplacementInfo;
  LOccurrenceCount: Integer;
  LTargetTrimmed: string;
  LLines: TArray<string>;
  LLine: string;
  LTrimmedLine: string;
  LResult: TStringBuilder;
  LI: Integer;
  LInserted: Boolean;
  LPos: Integer;
  LCount: Integer;
  LSearchStart: Integer;
begin
  if (FInsertions.Count = 0) and (FReplacements.Count = 0) then
    Exit;

  LOutput := FOutput.ToString();

  for LInsertion in FInsertions do
  begin
    LTargetTrimmed := LowerCase(Trim(LInsertion.TargetLine));
    LOccurrenceCount := 0;
    LInserted := False;

    // Split preserving empty lines
    LLines := LOutput.Split([#13#10, #10], TStringSplitOptions.None);

    LResult := TStringBuilder.Create();
    try
      for LI := 0 to High(LLines) do
      begin
        LLine := LLines[LI];
        LTrimmedLine := LowerCase(Trim(LLine));

        if (not LInserted) and (LTrimmedLine = LTargetTrimmed) then
        begin
          Inc(LOccurrenceCount);
          if LOccurrenceCount = LInsertion.Occurrence then
          begin
            if LInsertion.InsertBefore then
            begin
              LResult.Append(LInsertion.Content);
              LResult.AppendLine(LLine);
            end
            else
            begin
              LResult.AppendLine(LLine);
              LResult.Append(LInsertion.Content);
            end;
            LInserted := True;
          end
          else
          begin
            LResult.AppendLine(LLine);
          end;
        end
        else
        begin
          // Don't add newline after last line
          if LI < High(LLines) then
            LResult.AppendLine(LLine)
          else
            LResult.Append(LLine);
        end;
      end;

      LOutput := LResult.ToString();
    finally
      LResult.Free();
    end;
  end;

  // Update output
  FOutput.Clear();
  FOutput.Append(LOutput);

  // Process replacements
  if FReplacements.Count > 0 then
  begin
    LOutput := FOutput.ToString();

    for LReplacement in FReplacements do
    begin
      if LReplacement.Occurrence = 0 then
      begin
        // Replace all occurrences
        LOutput := LOutput.Replace(LReplacement.OldText, LReplacement.NewText);
      end
      else
      begin
        // Replace specific occurrence
        LCount := 0;
        LSearchStart := 1;

        while LSearchStart <= Length(LOutput) do
        begin
          LPos := Pos(LReplacement.OldText, LOutput, LSearchStart);
          if LPos = 0 then
            Break;

          Inc(LCount);
          if LCount = LReplacement.Occurrence then
          begin
            // Replace this occurrence
            LOutput := Copy(LOutput, 1, LPos - 1) +
                       LReplacement.NewText +
                       Copy(LOutput, LPos + Length(LReplacement.OldText), MaxInt);
            Break;
          end;

          LSearchStart := LPos + Length(LReplacement.OldText);
        end;
      end;
    end;

    FOutput.Clear();
    FOutput.Append(LOutput);
  end;
end;

procedure TDlmCImporter.SetOutputPath(const APath: string);
begin
  FOutputPath := APath.Replace('\', '/');
end;

procedure TDlmCImporter.SetHeader(const AFilename: string);
begin
  FHeader := AFilename.Replace('\', '/');
end;

function TDlmCImporter.Process(): Boolean;
var
  LPreprocessedSource: string;
  LHeaderName: string;
  LOutputFile: string;
  LOutputDir: string;
  LStructCount: Integer;
  LUnionCount: Integer;
  LEnumCount: Integer;
  LTypedefCount: Integer;
  LFuncPtrCount: Integer;
  LDefineCount: Integer;
  LStruct: TDlmCStructInfo;
  LTypedef: TDlmCTypedefInfo;
  LDefine: TDlmCDefineInfo;
  LRcFile: string;
  LResFile: string;
begin
  Result := False;
  FLastError := '';

  if FHeader = '' then
  begin
    FLastError := 'No header file specified';
    Exit;
  end;

  FLexer.Clear();
  FOutput.Clear();
  FStructs.Clear();
  FEnums.Clear();
  FTypedefs.Clear();
  FDefines.Clear();
  FFunctions.Clear();
  FForwardDecls.Clear();
  FCurrentSourceFile := '';
  FPos := 0;
  FIndent := 0;

  LHeaderName := TPath.GetFileNameWithoutExtension(FHeader);

  if FModuleName = '' then
    FModuleName := LHeaderName;

  if FDllName = '' then
    FDllName := FModuleName + '.dll';

  if FDllPath = '' then
    FDllPath := FDllName;

  FResName := GenerateResName();

  if FOutputPath <> '' then
    LOutputDir := FOutputPath
  else
    LOutputDir := TPath.GetDirectoryName(TPath.GetFullPath(FHeader));

  LOutputFile := TPath.Combine(LOutputDir, FModuleName + '.pas').Replace('\', '/');

  // Header info
  Status(COLOR_CYAN + 'CImporter' + COLOR_RESET + ' - C Header to Delphi Unit Converter', []);
  Status(COLOR_WHITE + '  Header: ' + COLOR_RESET + '%s', [FHeader]);
  Status(COLOR_WHITE + '  Unit:   ' + COLOR_RESET + '%s', [FModuleName]);
  Status('', []);

  // Preprocessing phase
  Status(COLOR_CYAN + 'Preprocessing...' + COLOR_RESET, []);
  if not PreprocessHeader(FHeader, LPreprocessedSource) then
  begin
    Status(COLOR_RED + '  Failed: ' + COLOR_RESET + '%s', [FLastError]);
    Exit;
  end;
  Status(COLOR_WHITE + '  Preprocessed size: ' + COLOR_RESET + '%d bytes', [Length(LPreprocessedSource)]);
  if FSavePreprocessed then
    Status(COLOR_WHITE + '  Saved preprocessed: ' + COLOR_RESET + '%s_pp.c', [FModuleName]);

  // Parsing phase
  Status(COLOR_CYAN + 'Parsing declarations...' + COLOR_RESET, []);
  ParsePreprocessed(LPreprocessedSource);

  // Count structs vs unions
  LStructCount := 0;
  LUnionCount := 0;
  for LStruct in FStructs do
  begin
    if LStruct.IsUnion then
      Inc(LUnionCount)
    else
      Inc(LStructCount);
  end;

  // Count typedefs vs function pointers
  LTypedefCount := 0;
  LFuncPtrCount := 0;
  for LTypedef in FTypedefs do
  begin
    if LTypedef.IsFunctionPointer then
      Inc(LFuncPtrCount)
    else
      Inc(LTypedefCount);
  end;

  LEnumCount := FEnums.Count;

  // Count defines that pass the exclusion filter
  LDefineCount := 0;
  for LDefine in FDefines do
  begin
    if FExcludedTypes.Contains(LDefine.DefineName) then
      Continue;
    if LDefine.IsInteger or LDefine.IsFloat or LDefine.IsString then
      Inc(LDefineCount);
  end;

  Status(COLOR_WHITE + '  Forward decls:    ' + COLOR_RESET + '%d', [FForwardDecls.Count]);
  Status(COLOR_WHITE + '  Structs:          ' + COLOR_RESET + '%d', [LStructCount]);
  Status(COLOR_WHITE + '  Unions:           ' + COLOR_RESET + '%d', [LUnionCount]);
  Status(COLOR_WHITE + '  Enums:            ' + COLOR_RESET + '%d', [LEnumCount]);
  Status(COLOR_WHITE + '  Type aliases:     ' + COLOR_RESET + '%d', [LTypedefCount]);
  Status(COLOR_WHITE + '  Function ptrs:    ' + COLOR_RESET + '%d', [LFuncPtrCount]);
  Status(COLOR_WHITE + '  Functions:        ' + COLOR_RESET + '%d', [FFunctions.Count]);
  Status(COLOR_WHITE + '  Defines:          ' + COLOR_RESET + '%d', [LDefineCount]);

  // Writing phase
  Status(COLOR_CYAN + 'Writing output...' + COLOR_RESET, []);
  try
    TDlmUtils.CreateDirInPath(LOutputFile);
    TFile.WriteAllText(LOutputFile, FOutput.ToString(), TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FLastError := 'Failed to write output file: ' + E.Message;
      Status(COLOR_RED + '  Failed: ' + COLOR_RESET + '%s', [FLastError]);
      Exit;
    end;
  end;

  Status(COLOR_WHITE + '  Output: ' + COLOR_RESET + '%s', [LOutputFile]);

  // Generate .rc resource script
  LRcFile := TPath.Combine(LOutputDir, FModuleName + '.rc').Replace('\', '/');
  LResFile := TPath.Combine(LOutputDir, FModuleName + '.res').Replace('\', '/');
  try
    TFile.WriteAllText(LRcFile, FResName + ' RCDATA "' + TPath.GetFullPath(FDllPath) + '"', TEncoding.ANSI);
    Status(COLOR_WHITE + '  RC:     ' + COLOR_RESET + '%s', [LRcFile]);
  except
    on E: Exception do
    begin
      Status(COLOR_YELLOW + '  Warning: ' + COLOR_RESET + 'Failed to write .rc file: %s', [E.Message]);
    end;
  end;

  // Attempt to compile .rc to .res via brcc32
  if TDlmUtils.RunPE(GetEnvironmentVariable('COMSPEC'),
    Format('/c brcc32.exe "%s"', [TPath.GetFileName(LRcFile)]), LOutputDir, True, SW_HIDE) = 0 then
  begin
    if TFile.Exists(LResFile) then
      Status(COLOR_WHITE + '  RES:    ' + COLOR_RESET + '%s', [LResFile])
    else
      Status(COLOR_YELLOW + '  Warning: ' + COLOR_RESET + 'brcc32 did not produce .res file', []);
  end
  else
    Status(COLOR_YELLOW + '  Warning: ' + COLOR_RESET + 'brcc32 failed or not found, .rc not compiled to .res', []);

  Status('', []);
  Status(COLOR_GREEN + 'Import complete.' + COLOR_RESET, []);

  Result := True;
end;

procedure TDlmCImporter.SetModuleName(const AName: string);
begin
  FModuleName := AName;
end;

procedure TDlmCImporter.SetDllName(const ADllName: string);
begin
  FDllName := ADllName;
  if not FDllName.EndsWith('.dll', True) then
    FDllName := FDllName + '.dll';
end;

procedure TDlmCImporter.SetDllPath(const ADllPath: string);
begin
  FDllPath := ADllPath;
end;

function TDlmCImporter.LoadFromConfig(const AFilename: string): Boolean;
var
  LConfig: TDlmConfig;
  LPaths: TArray<string>;
  LPath: string;
  LInsertionCount: Integer;
  LI: Integer;
  LTarget: string;
  LContent: string;
  LFilePath: string;
  LPosition: string;
  LOccurrence: Integer;
begin
  Result := False;

  LConfig := TDlmConfig.Create();
  try
    if not LConfig.LoadFromFile(AFilename) then
    begin
      FLastError := LConfig.GetLastError();
      Exit;
    end;

    // Header (required)
    if not LConfig.HasKey('cimporter.header') then
    begin
      FLastError := 'No header file specified in configuration';
      Exit;
    end;
    SetHeader(LConfig.GetString('cimporter.header'));

    // Simple settings
    if LConfig.HasKey('cimporter.module_name') then
      SetModuleName(LConfig.GetString('cimporter.module_name'));

    if LConfig.HasKey('cimporter.dll_name') then
      SetDllName(LConfig.GetString('cimporter.dll_name'));

    if LConfig.HasKey('cimporter.output_path') then
      SetOutputPath(LConfig.GetString('cimporter.output_path'));

    // Include paths (array of tables with path and optional module)
    LInsertionCount := LConfig.GetTableCount('cimporter.include_paths');
    if LInsertionCount > 0 then
    begin
      for LI := 0 to LInsertionCount - 1 do
      begin
        LPath := LConfig.GetTableString('cimporter.include_paths', LI, 'path');
        LContent := LConfig.GetTableString('cimporter.include_paths', LI, 'module');
        if LPath <> '' then
          AddIncludePath(LPath, LContent);
      end;
    end
    else
    begin
      // Fallback: simple string array for backward compatibility
      LPaths := LConfig.GetStringArray('cimporter.include_paths');
      for LPath in LPaths do
        AddIncludePath(LPath);
    end;

    // Source paths (for filtering output)
    LPaths := LConfig.GetStringArray('cimporter.source_paths');
    for LPath in LPaths do
      AddSourcePath(LPath);

    // Excluded types
    LPaths := LConfig.GetStringArray('cimporter.excluded_types');
    for LPath in LPaths do
      AddExcludedType(LPath);

    // Excluded functions
    LPaths := LConfig.GetStringArray('cimporter.excluded_functions');
    for LPath in LPaths do
      AddExcludedFunction(LPath);

    // Function renames (array of tables with original and rename_to)
    LInsertionCount := LConfig.GetTableCount('cimporter.function_renames');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LContent := LConfig.GetTableString('cimporter.function_renames', LI, 'original');
      LTarget := LConfig.GetTableString('cimporter.function_renames', LI, 'rename_to');
      if (LContent <> '') and (LTarget <> '') then
        AddFunctionRename(LContent, LTarget);
    end;

    // Uses units (additional units for interface uses clause)
    LPaths := LConfig.GetStringArray('cimporter.uses_units');
    for LPath in LPaths do
      AddUsesUnit(LPath);

    // Save preprocessed flag
    if LConfig.HasKey('cimporter.save_preprocessed') then
      SetSavePreprocessed(LConfig.GetBoolean('cimporter.save_preprocessed'));

    // Insertions (array of tables)
    LInsertionCount := LConfig.GetTableCount('cimporter.insertions');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LTarget := LConfig.GetTableString('cimporter.insertions', LI, 'target');
      LContent := LConfig.GetTableString('cimporter.insertions', LI, 'content');
      LFilePath := LConfig.GetTableString('cimporter.insertions', LI, 'file');
      LPosition := LConfig.GetTableString('cimporter.insertions', LI, 'position', 'after');
      LOccurrence := LConfig.GetTableInteger('cimporter.insertions', LI, 'occurrence', 1);

      if LFilePath <> '' then
      begin
        if LPosition = 'before' then
          InsertFileBefore(LTarget, LFilePath, LOccurrence)
        else
          InsertFileAfter(LTarget, LFilePath, LOccurrence);
      end
      else if LContent <> '' then
      begin
        if LPosition = 'before' then
          InsertTextBefore(LTarget, LContent, LOccurrence)
        else
          InsertTextAfter(LTarget, LContent, LOccurrence);
      end;
    end;

    // Replacements (array of tables)
    LInsertionCount := LConfig.GetTableCount('cimporter.replacements');
    for LI := 0 to LInsertionCount - 1 do
    begin
      LContent := LConfig.GetTableString('cimporter.replacements', LI, 'old_text');
      LTarget := LConfig.GetTableString('cimporter.replacements', LI, 'new_text');
      LOccurrence := LConfig.GetTableInteger('cimporter.replacements', LI, 'occurrence', 0);

      if LContent <> '' then
        ReplaceText(LContent, LTarget, LOccurrence);
    end;

    Result := True;
  finally
    LConfig.Free();
  end;
end;

function TDlmCImporter.SaveToConfig(const AFilename: string): Boolean;
var
  LConfig: TDlmConfig;
  LPaths: TArray<string>;
  LI: Integer;
  LInsertion: TDlmInsertionInfo;
  LReplacement: TDlmReplacementInfo;
  LOutput: TStringBuilder;
  LContent: string;
  LKey: string;
begin
  Result := False;

  LConfig := TDlmConfig.Create();
  try
    // Header
    if FHeader <> '' then
      LConfig.SetString('cimporter.header', FHeader);

    // Module name
    if FModuleName <> '' then
      LConfig.SetString('cimporter.module_name', FModuleName);

    // DLL name
    if FDllName <> '' then
      LConfig.SetString('cimporter.dll_name', FDllName);

    // Output path
    if FOutputPath <> '' then
      LConfig.SetString('cimporter.output_path', FOutputPath);

    // Include paths saved separately as array of tables (below)

    // Source paths
    if FSourcePaths.Count > 0 then
    begin
      SetLength(LPaths, FSourcePaths.Count);
      for LI := 0 to FSourcePaths.Count - 1 do
        LPaths[LI] := FSourcePaths[LI];
      LConfig.SetStringArray('cimporter.source_paths', LPaths);
    end;

    // Excluded types
    if FExcludedTypes.Count > 0 then
    begin
      SetLength(LPaths, FExcludedTypes.Count);
      for LI := 0 to FExcludedTypes.Count - 1 do
        LPaths[LI] := FExcludedTypes[LI];
      LConfig.SetStringArray('cimporter.excluded_types', LPaths);
    end;

    // Excluded functions
    if FExcludedFunctions.Count > 0 then
    begin
      SetLength(LPaths, FExcludedFunctions.Count);
      for LI := 0 to FExcludedFunctions.Count - 1 do
        LPaths[LI] := FExcludedFunctions[LI];
      LConfig.SetStringArray('cimporter.excluded_functions', LPaths);
    end;

    // Uses units
    if FUsesUnits.Count > 0 then
    begin
      SetLength(LPaths, FUsesUnits.Count);
      for LI := 0 to FUsesUnits.Count - 1 do
        LPaths[LI] := FUsesUnits[LI];
      LConfig.SetStringArray('cimporter.uses_units', LPaths);
    end;

    // Save preprocessed flag
    if FSavePreprocessed then
      LConfig.SetBoolean('cimporter.save_preprocessed', True);

    // Save base config first
    if not LConfig.SaveToFile(AFilename) then
    begin
      FLastError := LConfig.GetLastError();
      Exit;
    end;

    // Append include_paths as array of tables
    if FIncludePaths.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FIncludePaths.Count - 1 do
        begin
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.include_paths]]');
          LOutput.AppendLine(Format('path = "%s"', [FIncludePaths[LI].Replace('\', '\\')]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append insertions manually (array of tables not supported by generic SetXxx)
    if FInsertions.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FInsertions.Count - 1 do
        begin
          LInsertion := FInsertions[LI];
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.insertions]]');
          LOutput.AppendLine(Format('target = "%s"', [LInsertion.TargetLine]));

          LContent := LInsertion.Content;
          if (Pos(#10, LContent) > 0) or (Pos(#13, LContent) > 0) then
            LOutput.AppendLine('content = """' + #10 + LContent + '"""')
          else
            LOutput.AppendLine(Format('content = "%s"', [LContent]));

          if LInsertion.InsertBefore then
            LOutput.AppendLine('position = "before"')
          else
            LOutput.AppendLine('position = "after"');

          if LInsertion.Occurrence <> 1 then
            LOutput.AppendLine(Format('occurrence = %d', [LInsertion.Occurrence]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append replacements manually (array of tables not supported by generic SetXxx)
    if FReplacements.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LI := 0 to FReplacements.Count - 1 do
        begin
          LReplacement := FReplacements[LI];
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.replacements]]');
          LOutput.AppendLine(Format('old_text = "%s"', [LReplacement.OldText]));
          LOutput.AppendLine(Format('new_text = "%s"', [LReplacement.NewText]));

          if LReplacement.Occurrence <> 0 then
            LOutput.AppendLine(Format('occurrence = %d', [LReplacement.Occurrence]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    // Append function renames manually (array of tables)
    if FFunctionRenames.Count > 0 then
    begin
      LOutput := TStringBuilder.Create();
      try
        LOutput.Append(TFile.ReadAllText(AFilename, TEncoding.UTF8));

        for LKey in FFunctionRenames.Keys do
        begin
          LOutput.AppendLine('');
          LOutput.AppendLine('[[cimporter.function_renames]]');
          LOutput.AppendLine(Format('original = "%s"', [LKey]));
          LOutput.AppendLine(Format('rename_to = "%s"', [FFunctionRenames[LKey]]));
        end;

        TFile.WriteAllText(AFilename, LOutput.ToString(), TEncoding.UTF8);
      finally
        LOutput.Free();
      end;
    end;

    Result := True;
  finally
    LConfig.Free();
  end;
end;

function TDlmCImporter.GetLastError(): string;
begin
  Result := FLastError;
end;

procedure TDlmCImporter.Clear();
begin
  FLexer.Clear();
  FOutput.Clear();
  FStructs.Clear();
  FEnums.Clear();
  FTypedefs.Clear();
  FDefines.Clear();
  FFunctions.Clear();
  FForwardDecls.Clear();
  FInsertions.Clear();
  FReplacements.Clear();
  FIncludePaths.Clear();
  FSourcePaths.Clear();
  FExcludedTypes.Clear();
  FExcludedFunctions.Clear();
  FFunctionRenames.Clear();
  FUsesUnits.Clear();
  FSavePreprocessed := False;
  FModuleName := '';
  FDllName := '';
  FOutputPath := '';
  FHeader := '';
  FLastError := '';
  FCurrentSourceFile := '';
  FPos := 0;
  FIndent := 0;
end;

end.
