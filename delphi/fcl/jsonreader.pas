{
    This file is part of the Free Component Library

    JSON SAX-like Reader
    Copyright (c) 2007 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{ Ported for Delphi by the TyAdvanceChart project in November 2026 from Free Pascal 3.2.2,
  packages/fcl-json/src/jsonreader.pp. Compiled by Delphi only: Lazarus builds with FPC's own unit.
  Changed, by kind:
  - range and overflow checks are off (the directives $R- and $Q- before the unit clause), as
    FPC builds its fcl-json, so that a project compiled with them gets FPC's results
    (TJSONInt64Number of 2^40 gives AsInteger 0, not ERangeError);
  - strings are Delphi's UTF-16 string (TJSONStringType = string, TJSONCharType = Char), and QWord
    is written UInt64;
  - the scanner's source is a string, so a string token needs no conversion; the default values
    of parameters are not repeated in the implementation; TryStrToQWord is TryStrToUInt64;
  - floating-point numbers are read by tyfclnum's TyFclTextToFloat (for Val);
  - arrays and objects nest at most 1000 levels (together); deeper raises EJSONParser, as the
    reader's other syntax errors do (a deliberate limit, FPC has none: the reader and the
    destructors recurse per level, as FPC's do, and a Delphi program's default stack overflows at
    depths an FPC program survives; without the cap a deep text can end the process);
  - the branches for PAS2JS and for other FPC versions are removed, and so is the include of
    fcl-json.inc (its mode switch, a define these units do not test and a warning switch are
    FPC's only).
  The original's licence applies, see the notice above (THIRD-PARTY-NOTICES.md says more). }
{ Compiled as FPC compiles its own units: without range and overflow checks, whatever the
  project sets. }
{$R-}{$Q-}
unit jsonreader;

interface

uses
  Classes, SysUtils, fpJSON, jsonscanner;
  
Type

  { TBaseJSONReader }

  TBaseJSONReader = Class(TObject)
  Private
    FScanner : TJSONScanner;
    FNesting : Integer; // arrays and objects open
    function GetO(AIndex: TJSONOption): Boolean;
    function GetOptions: TJSONOptions; inline;
    procedure SetO(AIndex: TJSONOption; AValue: Boolean);
    procedure SetOptions(AValue: TJSONOptions);
  Protected
    procedure DoError(const Msg: String);
    procedure EnterNesting;
    Procedure DoParse(AtCurrent,AllowEOF: Boolean);
    function GetNextToken: TJSONToken;
    function CurrentTokenString: string;
    function CurrentToken: TJSONToken; inline;

    Procedure KeyValue(Const AKey : TJSONStringType); virtual; abstract;
    Procedure StringValue(Const AValue : TJSONStringType);virtual; abstract;
    Procedure NullValue; virtual; abstract;
    Procedure FloatValue(Const AValue : Double); virtual; abstract;
    Procedure BooleanValue(Const AValue : Boolean); virtual; abstract;
    Procedure NumberValue(Const AValue : TJSONStringType); virtual; abstract;
    Procedure IntegerValue(Const AValue : integer); virtual; abstract;
    Procedure Int64Value(Const AValue : int64); virtual; abstract;
    Procedure QWordValue(Const AValue : UInt64); virtual; abstract;
    Procedure StartArray; virtual; abstract;
    Procedure StartObject; virtual; abstract;
    Procedure EndArray; virtual; abstract;
    Procedure EndObject; virtual; abstract;

    Procedure ParseArray;
    Procedure ParseObject;
    Procedure ParseNumber;
    Procedure DoExecute;
    Property Scanner : TJSONScanner read FScanner;
  Public
    Constructor Create(Source : TStream; AUseUTF8 : Boolean = True); overload;deprecated 'use options form instead';
    Constructor Create(Const Source : string; AUseUTF8 : Boolean = True); overload;deprecated 'use options form instead';
    constructor Create(Source: TStream; AOptions: TJSONOptions); overload;
    constructor Create(const Source: string; AOptions: TJSONOptions); overload;
    destructor Destroy();override;
    // Parsing options
    Property Options : TJSONOptions Read GetOptions Write SetOptions;
  end;

  TOnJSONBoolean = Procedure (Sender : TObject; Const AValue : Boolean) of object;
  TOnJSONFloat = Procedure (Sender : TObject; Const AValue : TJSONFloat) of object;
  TOnJSONInt64 = Procedure (Sender : TObject; Const AValue : Int64) of object;
  TOnJSONQWord = Procedure (Sender : TObject; Const AValue : UInt64) of object;
  TOnJSONInteger = Procedure (Sender : TObject; Const AValue : Integer) of object;
  TOnJSONString = Procedure (Sender : TObject; Const AValue : TJSONStringType) of Object;
  TOnJSONKey = Procedure (Sender : TObject; Const AKey : TJSONStringType) of Object;


  { TJSONEventReader }

  TJSONEventReader = Class(TBaseJSONReader)
  Private
    FOnBooleanValue: TOnJSONBoolean;
    FOnEndArray: TNotifyEvent;
    FOnEndObject: TNotifyEvent;
    FOnFloatValue: TOnJSONFloat;
    FOnInt64Value: TOnJSONInt64;
    FOnIntegerValue: TOnJSONInteger;
    FOnKeyName: TOnJSONKey;
    FOnNullValue: TNotifyEvent;
    FOnNumberValue: TOnJSONString;
    FOnQWordValue: TOnJSONQWord;
    FOnStartArray: TNotifyEvent;
    FOnStartObject: TNotifyEvent;
    FOnStringValue: TOnJSONString;
  Protected
    Procedure KeyValue(Const AKey : TJSONStringType); override;
    Procedure StringValue(Const AValue : TJSONStringType);override;
    Procedure NullValue; override;
    Procedure FloatValue(Const AValue : Double); override;
    Procedure BooleanValue(Const AValue : Boolean); override;
    Procedure NumberValue(Const AValue : TJSONStringType); override;
    Procedure IntegerValue(Const AValue : integer); override;
    Procedure Int64Value(Const AValue : int64); override;
    Procedure QWordValue(Const AValue : UInt64); override;
    Procedure StartArray; override;
    Procedure StartObject; override;
    Procedure EndArray; override;
    Procedure EndObject; override;
  Public
    Procedure Execute;
    Property OnNullValue : TNotifyEvent Read FOnNullValue Write FOnNullValue;
    Property OnBooleanValue : TOnJSONBoolean Read FOnBooleanValue Write FOnBooleanValue;
    Property OnNumberValue : TOnJSONString Read FOnNumberValue Write FOnNumberValue;
    Property OnFloatValue : TOnJSONFloat Read FOnFloatValue Write FOnFloatValue;
    Property OnIntegerValue : TOnJSONInteger Read FOnIntegerValue Write FOnIntegerValue;
    Property OnInt64Value : TOnJSONInt64 Read FOnInt64Value Write FOnInt64Value;
    Property OnQWordValue : TOnJSONQWord Read FOnQWordValue Write FOnQWordValue;
    Property OnStringValue : TOnJSONString Read FOnStringValue Write FOnStringValue;
    Property OnKeyName : TOnJSONKey Read FOnKeyName Write FOnKeyName;
    Property OnStartObject : TNotifyEvent Read FOnStartObject Write FOnStartObject;
    Property OnEndObject : TNotifyEvent Read FOnEndObject Write FOnEndObject;
    Property OnStartArray : TNotifyEvent Read FOnStartArray Write FOnStartArray;
    Property OnEndArray : TNotifyEvent Read FOnEndArray Write FOnEndArray;
  end;

  IJSONConsumer = Interface ['{60F9D640-2A69-4AAB-8EE1-0DB6DC614D27}']
    Procedure NullValue;
    Procedure BooleanValue (const AValue : Boolean);
    Procedure NumberValue (const AValue : TJSONStringType);
    Procedure FloatValue (const AValue : TJSONFloat);
    Procedure Int64Value (const AValue : Int64);
    Procedure QWordValue (const AValue : UInt64);
    Procedure IntegerValue(const AValue : Integer) ;
    Procedure StringValue(const AValue : TJSONStringType) ;
    Procedure KeyName(const AKey : TJSONStringType);
    Procedure StartObject;
    Procedure EndObject;
    Procedure StartArray;
    Procedure EndArray;
  end;

  { TJSONConsumerReader }

  TJSONConsumerReader = Class(TBaseJSONReader)
  Private
    FConsumer: IJSONConsumer;
  Protected
    Procedure KeyValue(Const AKey : TJSONStringType); override;
    Procedure StringValue(Const AValue : TJSONStringType);override;
    Procedure NullValue; override;
    Procedure FloatValue(Const AValue : Double); override;
    Procedure BooleanValue(Const AValue : Boolean); override;
    Procedure NumberValue(Const AValue : TJSONStringType); override;
    Procedure IntegerValue(Const AValue : integer); override;
    Procedure Int64Value(Const AValue : int64); override;
    Procedure QWordValue(Const AValue : UInt64); override;
    Procedure StartArray; override;
    Procedure StartObject; override;
    Procedure EndArray; override;
    Procedure EndObject; override;
  Public
    Procedure Execute;
    Property Consumer : IJSONConsumer Read FConsumer Write FConsumer;
  end;

  EJSONParser = Class(EParserError);
  
implementation

uses tyfclnum;

Resourcestring
  SErrUnexpectedEOF   = 'Unexpected EOF encountered.';
  SErrUnexpectedToken = 'Unexpected token (%s) encountered.';
  SErrExpectedColon   = 'Expected colon (:), got token "%s".';
  //SErrEmptyElement = 'Empty element encountered.';
  SErrExpectedElementName    = 'Expected element name, got token "%s"';
  SExpectedCommaorBraceClose = 'Expected comma (,) or square bracket (]), got token "%s".';
  SErrInvalidNumber          = 'Number is not an integer or real number: %s';
  SErrNoScanner = 'No scanner. No source specified ?';
  SErrorAt = 'Error at line %d, Pos %d: ';
  SErrGarbageFound = 'Expected EOF, but got %s';
  SErrTooDeep = 'Arrays and objects nested deeper than %d levels are not supported by this port';

const
  // The port's cap on nesting: the reader and the destructors recurse per level (as FPC's do), and
  // a Delphi program's default stack overflows at depths an FPC program survives.
  cMaxNesting = 1000;

{ TBaseJSONReader }


Procedure TBaseJSONReader.DoExecute;

begin
  if (FScanner=Nil) then
    DoError(SErrNoScanner);
  FNesting:=0;
  DoParse(False,True);
  if joStrict in Options then
    begin
    Repeat
       GetNextToken;
    Until CurrentToken<>tkWhiteSpace;
    If CurrentToken<>tkEOF then
      DoError(Format(SErrGarbageFound,[CurrentTokenString]));
   end;
end;

{
  Consume next token and convert to JSON data structure.
  If AtCurrent is true, the current token is used. If false,
  a token is gotten from the scanner.
  If AllowEOF is false, encountering a tkEOF will result in an exception.
}

function TBaseJSONReader.CurrentToken: TJSONToken;

begin
  Result:=FScanner.CurToken;
end;

function TBaseJSONReader.CurrentTokenString: string;

begin
  If CurrentToken in [tkString,tkIdentifier,tkNumber,tkComment] then
    Result:=FScanner.CurTokenString
  else
    Result:=TokenInfos[CurrentToken];
end;

procedure TBaseJSONReader.DoParse(AtCurrent, AllowEOF: Boolean);

var
  T : TJSONToken;
  
begin
  If not AtCurrent then
    T:=GetNextToken
  else
    T:=FScanner.CurToken;
  Case T of
    tkEof : If Not AllowEof then
              DoError(SErrUnexpectedEOF);
    tkNull  : NullValue;
    tkTrue,
    tkFalse : BooleanValue(t=tkTrue);
    tkString : StringValue(CurrentTokenString);
    tkCurlyBraceOpen :
        ParseObject;
    tkCurlyBraceClose :
        DoError(SErrUnexpectedToken);
    tkSQuaredBraceOpen :
        ParseArray;
    tkSQuaredBraceClose :
        DoError(SErrUnexpectedToken);
    tkNumber :
        ParseNumber;
    tkComma :
        DoError(SErrUnexpectedToken);
    tkIdentifier :
        DoError(SErrUnexpectedToken);
  else
    // Do nothing
  end;
end;


// Creates the correct JSON number type, based on the current token.
procedure TBaseJSONReader.ParseNumber;

Var
  I : Integer;
  I64 : Int64;
  QW  : UInt64;
  F : TJSONFloat;
  S : String;

begin
  S:=CurrentTokenString;
  NumberValue(S);
  I:=0;
  if TryStrToUInt64(S,QW) then
    begin
    if QW>UInt64(high(Int64)) then
      QWordValue(QW)
    else
      if QW>MaxInt then
      begin
        I64 := QW;
        Int64Value(I64);
      end
      else
      begin
        I:=QW;
        IntegerValue(I);
      end
    end
  else
    begin
    If TryStrToInt64(S,I64) then
      if (I64>Maxint) or (I64<-MaxInt) then
        Int64Value(I64)
      Else
        begin
        I:=I64;
        IntegerValue(I);
        end
    else
      begin
      If Not TyFclTextToFloat(S,F) then
        DoError(SErrInvalidNumber);
      FloatValue(F);
      end;
    end;
end;

function TBaseJSONReader.GetO(AIndex: TJSONOption): Boolean;
begin
  Result:=AIndex in Options;
end;

function TBaseJSONReader.GetOptions: TJSONOptions;
begin
  Result:=FScanner.Options
end;

procedure TBaseJSONReader.SetO(AIndex: TJSONOption; AValue: Boolean);
begin
  if aValue then
    FScanner.Options:=FScanner.Options+[AINdex]
  else
    FScanner.Options:=FScanner.Options-[AINdex]
end;

procedure TBaseJSONReader.SetOptions(AValue: TJSONOptions);
begin
  FScanner.Options:=AValue;
end;


// Current token is {, on exit current token is }
Procedure TBaseJSONReader.ParseObject;

Var
  T : TJSONtoken;
  LastComma : Boolean;
  S : TJSONStringType;

begin
  LastComma:=False;
  EnterNesting;
  StartObject;
  T:=GetNextToken;
  While T<>tkCurlyBraceClose do
    begin
    If (T<>tkString) and (T<>tkIdentifier) then
      DoError(SErrExpectedElementName);
    S:=CurrentTokenString;
    KeyValue(S);
    // Writeln(S);
    T:=GetNextToken;
    If (T<>tkColon) then
      DoError(SErrExpectedColon);
    DoParse(False,False);
    T:=GetNextToken;
    If Not (T in [tkComma,tkCurlyBraceClose]) then
      DoError(SExpectedCommaorBraceClose);
    If T=tkComma then
      begin
      T:=GetNextToken;
      LastComma:=(t=tkCurlyBraceClose);
      end;
    end;
  If LastComma and ((joStrict in Options) or not (joIgnoreTrailingComma in Options))  then // Test for ,} case
    DoError(SErrUnExpectedToken);
  EndObject;
  Dec(FNesting);
end;

// Current token is [, on exit current token is ]
Procedure TBaseJSONReader.ParseArray;

Var
  T : TJSONtoken;
  LastComma : Boolean;
  S : TJSONOPTions;

begin
  EnterNesting;
  StartArray;
  LastComma:=False;
  Repeat
    T:=GetNextToken;
    If (T<>tkSquaredBraceClose) then
      begin
      DoParse(True,False);
      T:=GetNextToken;
      If Not (T in [tkComma,tkSquaredBraceClose]) then
        DoError(SExpectedCommaorBraceClose);
      LastComma:=(t=TkComma);
      end;
  Until (T=tkSquaredBraceClose);
  S:=Options;
  If LastComma and ((joStrict in S) or not (joIgnoreTrailingComma in S))  then // Test for ,] case
    DoError(SErrUnExpectedToken);
  EndArray;
  Dec(FNesting);
end;

// Get next token, discarding whitespace
function TBaseJSONReader.GetNextToken: TJSONToken;

begin
  Repeat
    Result:=FScanner.FetchToken;
  Until (Not (Result in [tkComment,tkWhiteSpace]));
end;

// One more array or object open; raises beyond cMaxNesting (the port's own).
procedure TBaseJSONReader.EnterNesting;

begin
  if FNesting>=cMaxNesting then
    DoError(Format(SErrTooDeep,[cMaxNesting]));
  Inc(FNesting);
end;

procedure TBaseJSONReader.DoError(const Msg: String);

Var
  S : String;

begin
  S:=Format(Msg,[CurrentTokenString]);
  S:=Format(SErrorAt,[FScanner.CurRow,FSCanner.CurColumn])+S;
  Raise EJSONParser.Create(S);
end;

constructor TBaseJSONReader.Create(Source: TStream; AUseUTF8 : Boolean);
begin
  Inherited Create;
  FScanner:=TJSONScanner.Create(Source,[joUTF8]);
  if AUseUTF8 then
   Options:=Options + [joUTF8];
end;

constructor TBaseJSONReader.Create(const Source: string; AUseUTF8 : Boolean);
begin
  Inherited Create;
  FScanner:=TJSONScanner.Create(Source,[joUTF8]);
  if AUseUTF8 then
   Options:=Options + [joUTF8];
end;

constructor TBaseJSONReader.Create(Source: TStream; AOptions: TJSONOptions);
begin
  FScanner:=TJSONScanner.Create(Source,AOptions);
end;

constructor TBaseJSONReader.Create(const Source: string; AOptions: TJSONOptions);
begin
  FScanner:=TJSONScanner.Create(Source,AOptions);
end;

destructor TBaseJSONReader.Destroy();
begin
  FreeAndNil(FScanner);
  inherited Destroy();
end;

{ TJSONReader }

procedure TJSONEventReader.KeyValue(const AKey: TJSONStringType);
begin
  if Assigned(FOnKeyName) then
    FOnKeyName(Self,AKey);
end;

procedure TJSONEventReader.StringValue(const AValue: TJSONStringType);
begin
  if Assigned(FOnStringValue) then
    FOnStringValue(Self,AValue);
end;

procedure TJSONEventReader.NullValue;
begin
  if Assigned(FOnNullValue) then
    FOnNullValue(Self);
end;

procedure TJSONEventReader.FloatValue(const AValue: Double);
begin
  if Assigned(FOnFloatValue) then
    FOnFloatValue(Self,AValue);
end;

procedure TJSONEventReader.BooleanValue(const AValue: Boolean);
begin
  if Assigned(FOnBooleanValue) then
    FOnBooleanValue(Self,AValue);
end;

procedure TJSONEventReader.NumberValue(const AValue: TJSONStringType);
begin
  if Assigned(FOnNumberValue) then
    FOnNumberValue(Self,AValue);
end;

procedure TJSONEventReader.IntegerValue(const AValue: integer);
begin
  if Assigned(FOnIntegerValue) then
    FOnIntegerValue(Self,AValue);

end;

procedure TJSONEventReader.Int64Value(const AValue: int64);
begin
  if Assigned(FOnInt64Value) then
    FOnInt64Value(Self,AValue);

end;

procedure TJSONEventReader.QWordValue(const AValue: UInt64);
begin
  if Assigned(FOnQWordValue) then
    FOnQWordValue(Self,AValue);
end;

procedure TJSONEventReader.StartArray;
begin
  If Assigned(FOnStartArray) then
    FOnStartArray(Self);
end;

procedure TJSONEventReader.StartObject;
begin
  if Assigned(FOnStartObject) then
    FOnStartObject(Self);
end;

procedure TJSONEventReader.EndArray;
begin
  If Assigned(FOnEndArray) then
    FOnEndArray(Self);
end;

procedure TJSONEventReader.EndObject;
begin
  If Assigned(FOnEndObject) then
   FOnEndObject(Self);
end;

procedure TJSONEventReader.Execute;
begin
  DoExecute;
end;

{ TJSONConsumerReader }

procedure TJSONConsumerReader.KeyValue(const AKey: TJSONStringType);
begin
  If Assigned(FConsumer) then
    FConsumer.KeyName(Akey)
end;

procedure TJSONConsumerReader.StringValue(const AValue: TJSONStringType);
begin
  If Assigned(FConsumer) then
    FConsumer.StringValue(AValue);
end;

procedure TJSONConsumerReader.NullValue;
begin
  If Assigned(FConsumer) then
    FConsumer.NullValue;
end;

procedure TJSONConsumerReader.FloatValue(const AValue: Double);
begin
  If Assigned(FConsumer) then
    FConsumer.FloatValue(AValue);
end;

procedure TJSONConsumerReader.BooleanValue(const AValue: Boolean);
begin
  If Assigned(FConsumer) then
    FConsumer.BooleanValue(AValue);
end;

procedure TJSONConsumerReader.NumberValue(const AValue: TJSONStringType);
begin
  If Assigned(FConsumer) then
    FConsumer.NumberValue(AValue);
end;

procedure TJSONConsumerReader.IntegerValue(const AValue: integer);
begin
  If Assigned(FConsumer) then
    FConsumer.IntegerValue(AValue);
end;

procedure TJSONConsumerReader.Int64Value(const AValue: int64);
begin
  If Assigned(FConsumer) then
    FConsumer.Int64Value(AValue);
end;

procedure TJSONConsumerReader.QWordValue(const AValue: UInt64);
begin
  If Assigned(FConsumer) then
    FConsumer.QWordValue(AValue);
end;

procedure TJSONConsumerReader.StartArray;
begin
  if Assigned(FConsumer) then
    FConsumer.StartArray;
end;

procedure TJSONConsumerReader.StartObject;
begin
  if Assigned(FConsumer) then
    FConsumer.StartObject;
end;

procedure TJSONConsumerReader.EndArray;
begin
  if Assigned(FConsumer) then
    FConsumer.EndArray;
end;

procedure TJSONConsumerReader.EndObject;
begin
  if Assigned(FConsumer) then
    FConsumer.EndObject;
end;

procedure TJSONConsumerReader.Execute;
begin
  DoExecute;
end;


end.

