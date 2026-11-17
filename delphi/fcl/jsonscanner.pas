{
    This file is part of the Free Component Library

    JSON source lexical scanner
    Copyright (c) 2007 by Michael Van Canneyt michael@freepascal.org

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}
{ Ported for Delphi by the TyAdvanceChart project from Free Pascal 3.2.2,
  packages/fcl-json/src/jsonscanner.pp. Compiled by Delphi only: Lazarus builds with FPC's own unit.
  Changed, by kind:
  - range and overflow checks are off (the directives $R- and $Q- before the unit clause), as
    FPC builds its fcl-json, so that a project compiled with them gets FPC's results
    (TJSONInt64Number of 2^40 gives AsInteger 0, not ERangeError);
  - the source is Delphi's UTF-16 string and the scanner walks it with PChar, not PAnsiChar (Move
    counts SizeOf(Char)); a stream is read as UTF-8 by tyfclutf8's TyFclUtf8Decode (a byte order
    mark is skipped under joBOMCheck, as FPC's does, and is otherwise read as a character, which
    the scanner rejects as FPC's does its first byte); FPC keeps the raw bytes in its byte
    string, the port has UTF-16 strings and replaces an invalid sequence by U+FFFD (a deliberate
    difference: it never raises on invalid bytes); \u escapes: each escape is one code unit,
    appended as it is (a valid pair stays a pair, an unpaired surrogate is kept, \u0000 is a #0
    where FPC's drops it; MaybeAppendUnicode and u1 are kept only to stay line-comparable with
    FPC's, u1 is never non-zero), and joUTF8 and UseUTF8 change
    nothing; FPC 3.2.2 pairs a pending escape with the next one and encodes the two to UTF-8, so
    it damages a valid pair that follows an odd number of escapes and drops unpaired surrogates
    (a deliberate difference: the port does not copy that defect); the property Strict is written
    &Strict, and Strict and UseUTF8 are not marked deprecated (Delphi has no hint directives on
    properties);
    the default values of parameters are not repeated in the implementation;
  - the switch to mode objfpc is gone (FPC's only).
  The original's licence applies, see the notice above (THIRD-PARTY-NOTICES.md says more). }
{$h+}
{ $INLINE ON}

{ Compiled as FPC compiles its own units: without range and overflow checks, whatever the
  project sets. }
{$R-}{$Q-}
unit jsonscanner;

interface

uses SysUtils, Classes;

resourcestring
  SErrInvalidCharacter = 'Invalid character at line %d, pos %d: ''%s''';
  SUnterminatedComment = 'Unterminated comment at line %d, pos %d: ''%s''';
  SErrOpenString = 'string exceeds end of line %d';

type

  TJSONToken = (
    tkEOF,
    tkWhitespace,
    tkString,
    tkNumber,
    tkTrue,
    tkFalse,
    tkNull,
    // Simple (one-character) tokens
    tkComma,                 // ','
    tkColon,                 // ':'
    tkCurlyBraceOpen,        // '{'
    tkCurlyBraceClose,       // '}'
    tkSquaredBraceOpen,       // '['
    tkSquaredBraceClose,      // ']'
    tkIdentifier,            // Any Javascript identifier
    tkComment,
    tkUnknown
    );

  EScannerError = class(EParserError);

  TJSONOption = (joUTF8,joStrict,joComments,joIgnoreTrailingComma,joIgnoreDuplicates,joBOMCheck);
  TJSONOptions = set of TJSONOption;

Const
  DefaultOptions = [joUTF8];

Type

  { TJSONScanner }

  TJSONScanner = class
  private
    FSource: string;
    FCurPos : PChar; // Position inside total string
    FCurRow: Integer;
    FCurToken: TJSONToken;
    FCurTokenString: string;
    FCurLine: PChar;
    FTokenStr:  PChar; // position inside FCurLine
    FEOL : PChar; // EOL
    FOptions : TJSONOptions;
    function GetCurColumn: Integer; inline;
    function GetCurLine: string;
    function GetO(AIndex: TJSONOption): Boolean;
    procedure SetO(AIndex: TJSONOption; AValue: Boolean);
  protected
    procedure Error(const Msg: string);overload;
    procedure Error(const Msg: string;  Const Args: array of const);overload;
//    function DoFetchToken: TJSONToken; inline;
  public
    constructor Create(Source : TStream; AUseUTF8 : Boolean = True); overload; deprecated 'use options form instead';
    constructor Create(Source: TStream; AOptions: TJSONOptions); overload;
    constructor Create(const aSource : string; AUseUTF8 : Boolean = True); overload; deprecated  'use options form instead';
    constructor Create(const aSource: string; AOptions: TJSONOptions); overload;

    function FetchToken: TJSONToken;

    property CurLine: string read GetCurLine;
    property CurRow: Integer read FCurRow;
    property CurColumn: Integer read GetCurColumn;

    property CurToken: TJSONToken read FCurToken;
    property CurTokenString: string read FCurTokenString;
    // Use strict JSON: " for strings, object members are strings, not identifiers
    Property &Strict : Boolean Index joStrict Read GetO Write SetO ;
    // if set to TRUE, then strings will be converted to UTF8 ansistrings, not system codepage ansistrings.
    Property UseUTF8 : Boolean index joUTF8 Read GetO Write SetO;
    // Parsing options
    Property Options : TJSONOptions Read FOptions Write FOptions;
  end;

const
  TokenInfos: array[TJSONToken] of string = (
    'EOF',
    'Whitespace',
    'String',
    'Number',
    'True',
    'False',
    'Null',
    ',',
    ':',
    '{',
    '}',
    '[',
    ']',
    'identifier',
    'comment',
    ''
  );


implementation

uses tyfclutf8;

constructor TJSONScanner.Create(Source : TStream; AUseUTF8 : Boolean);

Var
  O : TJSONOptions;

begin
  O:=DefaultOptions;
  if AUseUTF8 then
    Include(O,joUTF8)
  else
    Exclude(O,joUTF8);
  Create(Source,O);
end;

constructor TJSONScanner.Create(Source: TStream; AOptions: TJSONOptions);

  procedure SkipStreamBOM;
  Var
    OldPos : integer;
    Header : array[0..3] of byte;
  begin
    OldPos := Source.Position;
    FillChar(Header, SizeOf(Header), 0);
    if Source.Read(Header, 3) = 3 then
      if (Header[0]=$EF) and (Header[1]=$BB) and (Header[2]=$BF) then
        exit;
    Source.Position := OldPos;
  end;


Var
  S : string;
  B : TBytes;

begin
  if (joBOMCheck in aOptions) then
    SkipStreamBom;
  B:=nil;
  SetLength(B,Source.Size-Source.Position);
  if Length(B)>0 then
    Source.ReadBuffer(B[0],Length(B));
  S:=TyFclUtf8Decode(B);
  Create(S,AOptions)
end;

constructor TJSONScanner.Create(const aSource : string; AUseUTF8 : Boolean);
Var
  O : TJSONOptions;

begin
  O:=DefaultOptions;
  if AUseUTF8 then
    Include(O,joUTF8)
  else
    Exclude(O,joUTF8);
  Create(aSource,O);
end;

constructor TJSONScanner.Create(const aSource: string; AOptions: TJSONOptions);
begin
  FSource:=aSource;
  FCurPos:=PChar(FSource);
  if FCurPos<>Nil then
    FCurRow:=1;
  FOptions:=AOptions;
end;

function TJSONScanner.GetCurColumn: Integer;
begin
  Result := FTokenStr - FCurLine;
end;


procedure TJSONScanner.Error(const Msg: string);
begin
  raise EScannerError.Create(Msg);
end;

procedure TJSONScanner.Error(const Msg: string; const Args: array of const);
begin
  raise EScannerError.CreateFmt(Msg, Args);
end;

function TJSONScanner.FetchToken: TJSONToken;

(*
  procedure dumpcurrent;

  begin
  Writeln('Start of line : ',FCurLine);
  Writeln('Cur pos : ',FCurPos);
  Writeln('Start of token : ',FTokenstr);
  Writeln('End of line : ',FTokenstr);
  end;
*)
  function FetchLine: Boolean;


  begin
    Result:=(FCurPos<>Nil) and (FCurPos^<>#0);
    if Result then
      begin
      FCurLine:=FCurPos;
      FTokenStr:=FCurPos;
      While Not (FCurPos^ in [#0,#10,#13]) do
        Inc(FCurPos);
      FEOL:=FCurPos;
      If (FCurPos^<>#0) then
//      While (FCurPos^<>#0) and (FCurPos^ in [#10,#13]) do
        begin
        if (FCurPos^=#13) and (FCurPos[1]=#10) then
          Inc(FCurPos); // Skip CR-LF
        Inc(FCurPos); // To start of next line
        Inc(FCurRow); // Increase line index
        end;
//      Len:=FEOL-FTokenStr;
//      FTokenStr:=FCurPos;
      end
    else             
      begin
      FCurLine:=Nil;
      FTokenStr:=nil;
      end;
  end;

var
  TokenStart: PChar;
  it : TJSONToken;
  I : Integer;
  OldLength, SectionLength,  tstart,tcol, u1,u2: Integer;
  C , c2: char;
  S : String;
  Line : String;
  IsStar,EOC: Boolean;

  // Kept to stay line-comparable with FPC; u1 is never non-zero here.
  Procedure MaybeAppendUnicode;

  Var
    u : String;

  begin
  // if there is a leftover \u, append
  if (u1<>0) then
    begin
    U:=WideChar(u1); // whatever joUTF8 says
    FCurTokenString:=FCurTokenString+U;
    OldLength:=Length(FCurTokenString);
    u1:=0;
    end;
  end;


begin
  if (FTokenStr = nil) or (FTokenStr=FEOL) then
    begin
    if not FetchLine then
      begin
      Result := tkEOF;
      FCurToken := Result;
      exit;
      end;
    end;
  FCurTokenString := '';
  case FTokenStr^ of
    #0:         // Empty line
      begin
      FetchLine;
      Result := tkWhitespace;
      end;
    #9, ' ', #10, #13:
      begin
      Result := tkWhitespace;
      repeat
        if FTokenStr = FEOL then
          begin
          if not FetchLine then
            begin
            FCurToken := Result;
            exit;
            end
          end
        else
          Inc(FTokenStr);
      until not (FTokenStr[0] in [#9, ' ']);
      end;
    '"','''':
      begin
        C:=FTokenStr^;
        If (C='''') and (joStrict in Options) then
          Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
        Inc(FTokenStr);
        TokenStart := FTokenStr;
        OldLength := 0;
        FCurTokenString := '';
        u1:=0;
        while not (FTokenStr^ in [#0,C]) do
          begin
          if (FTokenStr^='\') then
            begin
            // Save length
            SectionLength := FTokenStr - TokenStart;
            Inc(FTokenStr);
            // Read escaped token
            Case FTokenStr^ of
              '"' : S:='"';
              '''' : S:='''';
              't' : S:=#9;
              'b' : S:=#8;
              'n' : S:=#10;
              'r' : S:=#13;
              'f' : S:=#12;
              '\' : S:='\';
              '/' : S:='/';
              'u' : begin
                    u2:=0;
                    For I:=1 to 4 do
                      begin
                      Inc(FTokenStr);
                      c2:=FTokenStr^;
                      Case c2 of
                        '0'..'9': u2:=u2*16+ord(c2)-ord('0');
                        'A'..'F': u2:=u2*16+ord(c2)-ord('A')+10;
                        'a'..'f': u2:=u2*16+ord(c2)-ord('a')+10;
                      else
                        Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
                      end;
                      end;
                    // Each escape is one code unit (u1 stays 0), whatever joUTF8 says: FPC's
                    // pairs a pending escape with the next one, whatever they are.
                    S:=WideChar(u2);
                    end;
              #0  : Error(SErrOpenString,[FCurRow]);
            else
              Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
            end;
            I:=Length(S);
            if (SectionLength+I>0) then
              begin
              // FPC's: if length=1, it was not \uXX, but u1 can be nonzero and is appended first
              // (example: \u00f8\"). Here a \uXX is length 1 too, and u1 is always 0.
              if (I=1) and (u1<>0) then
                MaybeAppendUnicode;
              SetLength(FCurTokenString, OldLength + SectionLength+i);
              if SectionLength > 0 then
                Move(TokenStart^, FCurTokenString[OldLength + 1], SectionLength*SizeOf(Char));
              if I>0 then
                Move(S[1],FCurTokenString[OldLength + SectionLength+1],i*SizeOf(Char));
              Inc(OldLength, SectionLength+I);
              end;
            // Next char
            TokenStart := FTokenStr+1;
            end
          else if u1<>0 then
            MaybeAppendUnicode;
          if FTokenStr^ < #$20 then
            if FTokenStr^ = #0 then Error(SErrOpenString,[FCurRow])
            else if joStrict in Options then Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
          Inc(FTokenStr);
          end;
        if FTokenStr^ = #0 then
          Error(SErrOpenString,[FCurRow]);
        if u1<>0 then
          MaybeAppendUnicode;
        SectionLength := FTokenStr - TokenStart;
        SetLength(FCurTokenString, OldLength + SectionLength);
        if SectionLength > 0 then
          Move(TokenStart^, FCurTokenString[OldLength + 1], SectionLength*SizeOf(Char));
        Inc(FTokenStr);
        Result := tkString;
      end;
    ',':
      begin
        Inc(FTokenStr);
        Result := tkComma;
      end;
    '0'..'9','.','-':
      begin
        TokenStart := FTokenStr;
        if FTokenStr^ = '-' then inc(FTokenStr);
        case FTokenStr^ of
          '1'..'9': Inc(FTokenStr);
          '0': begin
            Inc(FTokenStr);
            if (joStrict in Options) and (FTokenStr^ in ['0'..'9']) then
              Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
          end;
          '.': if joStrict in Options then
                 Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
          else
            Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
        end;
        while true do
        begin
          case FTokenStr^ of
            '0'..'9': inc(FTokenStr);
            '.':
              begin
                case FTokenStr[1] of
                  '0'..'9': Inc(FTokenStr, 2);
                  'e', 'E': begin
                    if joStrict in Options then
                      Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
                    Inc(FTokenStr);
                  end;
                  else Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
                end;
                while FTokenStr^ in ['0'..'9'] do
                  inc(FTokenStr);
                break;
              end;
          else
            break;
          end;
        end;
        if FTokenStr^ in ['e', 'E'] then begin
          Inc(FTokenStr);
          if FTokenStr^ in ['-','+']  then
            Inc(FTokenStr);
          if not (FTokenStr^ in ['0'..'9']) then
            Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
          repeat
            Inc(FTokenStr);
          until not (FTokenStr^ in ['0'..'9']);
        end;
        if {(FTokenStr<>FEOL) and }not (FTokenStr^ in [#13,#10,#0,'}',']',',',#9,' ']) then
          Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
        SectionLength := FTokenStr - TokenStart;
        FCurTokenString:='';
        SetString(FCurTokenString, TokenStart, SectionLength);
        If (FCurTokenString[1]='.') then
          FCurTokenString:='0'+FCurTokenString;
        Result := tkNumber;
      end;
    ':':
      begin
        Inc(FTokenStr);
        Result := tkColon;
      end;
    '{':
      begin
        Inc(FTokenStr);
        Result := tkCurlyBraceOpen;
      end;
    '}':
      begin
        Inc(FTokenStr);
        Result := tkCurlyBraceClose;
      end;  
    '[':
      begin
        Inc(FTokenStr);
        Result := tkSquaredBraceOpen;
      end;
    ']':
      begin
        Inc(FTokenStr);
        Result := tkSquaredBraceClose;
      end;
    '/' :
      begin
      if Not (joComments in Options) then
        Error(SErrInvalidCharacter, [CurRow,CurCOlumn,FTokenStr[0]]);
      TokenStart:=FTokenStr;
      Inc(FTokenStr);
      Case FTokenStr^ of
        '/' : begin
              FCurTokenString:='';
              Inc(FTokenStr);
              TokenStart:=FTokenStr;
              SectionLength := PChar(FEOL)-TokenStart;
              SetString(FCurTokenString, TokenStart, SectionLength);
              FetchLine;
              end;
        '*' :
          begin
          IsStar:=False;
          Inc(FTokenStr);
          TokenStart:=FTokenStr;
          Repeat
            While (FTokenStr=FEOL) do
              begin
              SectionLength := (FTokenStr - TokenStart);
              Line:='';
              SetString(Line, TokenStart, SectionLength);
              FCurtokenString:=FCurtokenString+Line+sLineBreak;
              if not fetchLine then
                Error(SUnterminatedComment, [CurRow,CurCOlumn,FTokenStr[0]]);
              TokenStart:=FTokenStr;
              end;
            IsStar:=FTokenStr^='*';
            Inc(FTokenStr);
            EOC:=(isStar and (FTokenStr^='/'));
          Until EOC;
          if EOC then
            begin
            SectionLength := (FTokenStr - TokenStart-1);
            Line:='';
            SetString(Line, TokenStart, SectionLength);
            FCurtokenString:=FCurtokenString+Line;
            Inc(FTokenStr);
            end;
          end;
      else
        Error(SErrInvalidCharacter, [CurRow,CurCOlumn,FTokenStr[0]]);
      end;
      Result:=tkComment;
      end;
    'a'..'z','A'..'Z','_':
      begin
        tstart:=CurRow;
        Tcol:=CurColumn;
        TokenStart := FTokenStr;
        Result:=tkIdentifier;
        case TokenStart^ of
          't': if (TokenStart[1] = 'r') and (TokenStart[2] = 'u') and (TokenStart[3] = 'e') then
            Result:=tkTrue;
          'f': if (TokenStart[1] = 'a') and (TokenStart[2] = 'l') and (TokenStart[3] = 's') and (TokenStart[4] = 'e') then
            Result:=tkFalse;
          'n': if (TokenStart[1] = 'u') and (TokenStart[2] = 'l') and (TokenStart[3] = 'l') then
            Result:=tkNull;
        end;
        if result <> tkIdentifier then inc(FTokenStr, length(TokenInfos[result]) - 1);
        repeat
          Inc(FTokenStr);
        until not (FTokenStr^ in ['A'..'Z', 'a'..'z', '0'..'9', '_']);
        SectionLength := FTokenStr - TokenStart;
        FCurTokenString:='';
        SetString(FCurTokenString, TokenStart, SectionLength);
        if (result = tkIdentifier) or (SectionLength <> length(TokenInfos[result])) then begin
          if (joStrict in Options) then
            Error(SErrInvalidCharacter, [tStart,tcol,TokenStart[0]]);
          for it := tkTrue to tkNull do
            if CompareText(CurTokenString, TokenInfos[it]) = 0 then
              begin
              Result := it;
              FCurToken := Result;
              exit;
              end;
        end;
      end;
  else
    Error(SErrInvalidCharacter, [CurRow,CurColumn,FTokenStr[0]]);
  end;
  FCurToken := Result;
end;

{function TJSONScanner.FetchToken: TJSONToken;

begin
  Result:=DoFetchToken;
end;}

function TJSONScanner.GetCurLine: string;
begin
  Result:='';
  if FCurLine<>Nil then
    begin
    SetLength(Result,FEOL-FCurLine);
    if Length(Result)>0 then
      Move(FCurLine^,Result[1],Length(Result)*SizeOf(Char));
    end;
end;

function TJSONScanner.GetO(AIndex: TJSONOption): Boolean;
begin
  Result:=AIndex in FOptions;
end;

procedure TJSONScanner.SetO(AIndex: TJSONOption; AValue: Boolean);
begin
  If AValue then
    Include(Foptions,AIndex)
  else
    Exclude(Foptions,AIndex)
end;

end.
