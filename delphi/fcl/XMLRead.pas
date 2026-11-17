{ A stand-in for Free Pascal's fcl-xml XMLRead unit, for Delphi: the parser the chart's map reader
  (tyControls.AdvanceChart.GeoSvg) calls, under FPC's names. Compiled by Delphi only: Lazarus builds with
  FPC's own unit. New code of the TyAdvanceChart project (FPC's xmlread and xmltextreader are far larger),
  one pass over the decoded text; its results are checked node by node against FPC's by the 'xml'
  section of delphi/tests/tyadvchart_fcl.dpr.

  Only the option set the chart uses is implemented: PreserveWhitespace True, Namespaces False,
  ExpandEntities True, Validate False. Parse raises EXMLReadError for any other value (FPC's defaults,
  all False, included).

  As FPC's TDOMParser.Parse, Parse creates ADoc first and leaves it assigned when it raises: the caller
  frees it (GeoSvg's TyGsParseDocument does). The stream is read from its position to its end.

  What it reads, as FPC's reader does:
  - the bytes: UTF-16 when they start with a byte order mark (either byte order), otherwise UTF-8 with or
    without a byte order mark, or ISO-8859-1 (and FPC's aliases of it: ISO_8859-1, latin1, iso-ir-100,
    l1, IBM819, CP819, csISOLatin1, ISO8859-1) when the XML declaration names it. An encoding name in the
    declaration must be UTF-8 or one of those (UTF-16, unicode, or the order of the mark, after a UTF-16
    byte order mark); any other, US-ASCII included, raises, as in FPC 3.2.2, whose reader knows no other
    encoding without an extra decoder unit. An invalid UTF-8 sequence raises (FPC's decoder rejects it);
    a sequence cut short by the end of the bytes is dropped, and so is an odd last byte of UTF-16, as
    FPC's decoders do;
  - a character below U+0020 other than tab, line feed and carriage return, and U+FFFE and U+FFFF,
    raise anywhere; CR LF and a lone CR become LF;
  - the XML declaration (version 1.0; encoding; standalone yes or no); comments and processing
    instructions (target 'xml' in any case is refused) before, in and after the root element; one
    DOCTYPE before the root, with an optional external identifier, which is never read, and an optional
    internal subset of internal general entity declarations, comments and processing instructions;
  - elements and attributes with their names as written (a prefix is part of the name); a repeated
    attribute raises; an attribute value has tab, line feed and carriage return replaced by a blank and
    nothing else normalised (there are no attribute types);
  - text, kept as it is, white space included (white space outside the root element makes no node); text
    next to a reference is one text node with it; ']]>' in text raises; CDATA sections, empty ones
    included, are CDATA nodes;
  - references: the five predefined entities, character references (&#N; and &#xH;, 'x' lower case,
    to a character XML allows), and the internal entities of the DOCTYPE, expanded (their replacement
    text is read as content or attribute text in place; an entity that refers to itself raises; an
    entity's elements must close inside it).
  What it rejects with EXMLReadError although FPC may read it:
  - an XML declaration with a version other than 1.0;
  - in the internal subset: parameter entities and references to them, external entities, ELEMENT,
    ATTLIST and NOTATION declarations (FPC would apply their defaults and types);
  - a reference to an undeclared entity even in a document whose DOCTYPE has an external identifier
    (FPC, which does not read the external subset either, then only reports it when validating).
  Names follow the XML 1.0 (fifth edition) name characters, with every UTF-16 surrogate allowed; FPC's
  tables may differ for some names outside ASCII. Error messages are this unit's own (and say where, as a
  character offset in the decoded text or in an entity's replacement text). }
unit XMLRead;

interface

uses
  SysUtils, Classes, DOM;

type
  EXMLReadError = class(Exception);

  TDOMParseOptions = class
  private
    FPreserveWhitespace: Boolean;
    FNamespaces: Boolean;
    FExpandEntities: Boolean;
    FValidate: Boolean;
  public
    property PreserveWhitespace: Boolean read FPreserveWhitespace write FPreserveWhitespace;
    property Namespaces: Boolean read FNamespaces write FNamespaces;
    property ExpandEntities: Boolean read FExpandEntities write FExpandEntities;
    property Validate: Boolean read FValidate write FValidate;
  end;

  TXMLInputSource = class
  private
    FStream: TStream;
  public
    { AStream is read when the source is parsed; it is not owned. }
    constructor Create(AStream: TStream);
  end;

  TDOMParser = class
  private
    FOptions: TDOMParseOptions;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Parse(ASrc: TXMLInputSource; out ADoc: TXMLDocument);
    property Options: TDOMParseOptions read FOptions;
  end;

implementation

type
  { One run of characters being read: the document, or the replacement text of an entity. }
  TXmlSource = record
    S: UnicodeString;
    P: Integer;      // the next character, from 1
    Len: Integer;
  end;

  TXmlEntity = record
    Name: UnicodeString;
    Text: UnicodeString;
    Active: Boolean; // being expanded
  end;

  TXmlReader = class
  private
    FDoc: TXMLDocument;
    FEntities: array of TXmlEntity;
    procedure Fail(const AMsg: string; const ASrc: TXmlSource);
    function AtEnd(const ASrc: TXmlSource): Boolean;
    function Peek(const ASrc: TXmlSource): WideChar;
    function StartsWith(const ASrc: TXmlSource; const AText: UnicodeString): Boolean;
    function Accept(var ASrc: TXmlSource; const AText: UnicodeString): Boolean;
    procedure Expect(var ASrc: TXmlSource; const AText: UnicodeString);
    function SkipSpaces(var ASrc: TXmlSource): Boolean;
    procedure NeedSpaces(var ASrc: TXmlSource);
    function ReadName(var ASrc: TXmlSource): UnicodeString;
    function ReadCharRef(var ASrc: TXmlSource): UnicodeString;
    function FindEntity(const AName: UnicodeString; const ASrc: TXmlSource): Integer;
    function ReadQuoted(var ASrc: TXmlSource): UnicodeString;
    procedure ReadAttChars(var ASrc: TXmlSource; AQuote: WideChar; var AOut: UnicodeString);
    function ReadAttValue(var ASrc: TXmlSource): UnicodeString;
    procedure ReadComment(var ASrc: TXmlSource; AParent: TDOMNode);
    procedure ReadPI(var ASrc: TXmlSource; AParent: TDOMNode);
    procedure ReadCData(var ASrc: TXmlSource; AParent: TDOMNode);
    procedure ReadEntityDecl(var ASrc: TXmlSource);
    procedure ReadDoctype(var ASrc: TXmlSource);
    procedure ReadElement(var ASrc: TXmlSource; AParent: TDOMNode);
    procedure ReadContent(var ASrc: TXmlSource; AParent: TDOMNode; const AEndName: UnicodeString;
      AInEntity: Boolean; var APending: UnicodeString);
    function ReadXmlDecl(var ASrc: TXmlSource): UnicodeString;
    procedure ReadDocument(var ASrc: TXmlSource);
  public
    procedure Run(const ABytes: TBytes; ADoc: TXMLDocument);
  end;

function MakeSource(const AText: UnicodeString): TXmlSource;
begin
  Result.S := AText;
  Result.P := 1;
  Result.Len := Length(AText);
end;

function IsXmlSpace(C: WideChar): Boolean;
begin
  Result := (C = ' ') or (C = #9) or (C = #10) or (C = #13);
end;

function IsNameStart(C: WideChar): Boolean;
begin
  case Ord(C) of
    Ord(':'), Ord('A')..Ord('Z'), Ord('_'), Ord('a')..Ord('z'), $C0..$D6, $D8..$F6, $F8..$2FF,
    $370..$37D, $37F..$1FFF, $200C..$200D, $2070..$218F, $2C00..$2FEF, $3001..$DFFF, $F900..$FDCF,
    $FDF0..$FFFD:
      Result := True;
  else
    Result := False;
  end;
end;

function IsNameChar(C: WideChar): Boolean;
begin
  case Ord(C) of
    Ord('-'), Ord('.'), Ord('0')..Ord('9'), $B7, $300..$36F, $203F..$2040:
      Result := True;
  else
    Result := IsNameStart(C);
  end;
end;

{ ---- bytes to text ---- }

procedure DecodeFail(const AMsg: string);
begin
  raise EXMLReadError.Create(AMsg);
end;

{ The bytes AFrom..ATo-1 as UTF-8, as FPC's Decode_UTF8: an invalid sequence raises, a sequence cut short
  by ATo is dropped. }
function DecodeUtf8(const B: TBytes; AFrom, ATo: Integer): UnicodeString;
const
  cMax: array[1..4] of Cardinal = ($7F, $7FF, $FFFF, $1FFFFF);
var
  i, n, bc, j: Integer;
  v: Cardinal;
begin
  SetLength(Result, ATo - AFrom);
  n := 0;
  i := AFrom;
  while i < ATo do
  begin
    v := B[i];
    if v < $80 then
      bc := 1
    else if v < $C2 then
    begin
      DecodeFail('Invalid character in input stream (byte offset ' + IntToStr(i) + ')');
      bc := 0;
    end
    else if v <= $DF then
      bc := 2
    else if v <= $EF then
      bc := 3
    else if v <= $F7 then
      bc := 4
    else
    begin
      DecodeFail('Invalid character in input stream (byte offset ' + IntToStr(i) + ')');
      bc := 0;
    end;
    if ATo - i < bc then
      Break;
    for j := 1 to bc - 1 do
      if (B[i + j] >= $80) and (B[i + j] <= $BF) then
        v := (v shl 6) or (B[i + j] and $3F)
      else
        DecodeFail('Invalid character in input stream (byte offset ' + IntToStr(i) + ')');
    v := v and cMax[bc];
    if (bc > 1) and (v <= cMax[bc - 1]) then
      DecodeFail('Invalid character in input stream (byte offset ' + IntToStr(i) + ')');
    case v of
      0..$D7FF, $E000..$FFFF:
        begin
          Inc(n);
          Result[n] := WideChar(v);
        end;
      $10000..$10FFFF:
        begin
          Inc(n);
          Result[n] := WideChar($D7C0 + (v shr 10));
          Inc(n);
          Result[n] := WideChar($DC00 xor (v and $3FF));
        end;
    else
      DecodeFail('Invalid character in input stream (byte offset ' + IntToStr(i) + ')');
    end;
    Inc(i, bc);
  end;
  SetLength(Result, n);
end;

function DecodeLatin1(const B: TBytes; AFrom, ATo: Integer): UnicodeString;
var
  i: Integer;
begin
  SetLength(Result, ATo - AFrom);
  for i := AFrom to ATo - 1 do
    Result[i - AFrom + 1] := WideChar(B[i]);
end;

{ The bytes from AFrom on as UTF-16 of that byte order; an odd last byte is dropped. }
function DecodeUtf16(const B: TBytes; AFrom: Integer; ABigEndian: Boolean): UnicodeString;
var
  i: Integer;
begin
  SetLength(Result, (Length(B) - AFrom) div 2);
  for i := 1 to Length(Result) do
    if ABigEndian then
      Result[i] := WideChar((B[AFrom + 2 * i - 2] shl 8) or B[AFrom + 2 * i - 1])
    else
      Result[i] := WideChar(B[AFrom + 2 * i - 2] or (B[AFrom + 2 * i - 1] shl 8));
end;

{ Raises on a character XML does not allow; CR LF and CR become LF. }
function CheckAndNormalize(const AText: UnicodeString): UnicodeString;
var
  i, n: Integer;
  c: WideChar;
begin
  SetLength(Result, Length(AText));
  n := 0;
  i := 1;
  while i <= Length(AText) do
  begin
    c := AText[i];
    if ((Ord(c) < $20) and (c <> #9) and (c <> #10) and (c <> #13)) or (Ord(c) >= $FFFE) then
      DecodeFail('Invalid character (U+' + IntToHex(Ord(c), 4) + ')');
    if c = #13 then
    begin
      c := #10;
      if (i < Length(AText)) and (AText[i + 1] = #10) then
        Inc(i);
    end;
    Inc(n);
    Result[n] := c;
    Inc(i);
  end;
  SetLength(Result, n);
end;

function IsLatin1Name(const AEncoding: string): Boolean;
begin
  Result := SameText(AEncoding, 'ISO-8859-1') or SameText(AEncoding, 'ISO_8859-1')
    or SameText(AEncoding, 'latin1') or SameText(AEncoding, 'iso-ir-100') or SameText(AEncoding, 'l1')
    or SameText(AEncoding, 'IBM819') or SameText(AEncoding, 'CP819')
    or SameText(AEncoding, 'csISOLatin1') or SameText(AEncoding, 'ISO8859-1');
end;

{ ---- TXmlReader ---- }

procedure TXmlReader.Fail(const AMsg: string; const ASrc: TXmlSource);
begin
  raise EXMLReadError.Create(AMsg + ' (at character ' + IntToStr(ASrc.P) + ')');
end;

function TXmlReader.AtEnd(const ASrc: TXmlSource): Boolean;
begin
  Result := ASrc.P > ASrc.Len;
end;

function TXmlReader.Peek(const ASrc: TXmlSource): WideChar;
begin
  if ASrc.P <= ASrc.Len then
    Result := ASrc.S[ASrc.P]
  else
    Result := #0;
end;

function TXmlReader.StartsWith(const ASrc: TXmlSource; const AText: UnicodeString): Boolean;
var
  i: Integer;
begin
  Result := ASrc.P + Length(AText) - 1 <= ASrc.Len;
  if Result then
    for i := 1 to Length(AText) do
      if ASrc.S[ASrc.P + i - 1] <> AText[i] then
      begin
        Result := False;
        Exit;
      end;
end;

function TXmlReader.Accept(var ASrc: TXmlSource; const AText: UnicodeString): Boolean;
begin
  Result := StartsWith(ASrc, AText);
  if Result then
    Inc(ASrc.P, Length(AText));
end;

procedure TXmlReader.Expect(var ASrc: TXmlSource; const AText: UnicodeString);
begin
  if not Accept(ASrc, AText) then
    Fail('Expected "' + AText + '"', ASrc);
end;

function TXmlReader.SkipSpaces(var ASrc: TXmlSource): Boolean;
begin
  Result := False;
  while (ASrc.P <= ASrc.Len) and IsXmlSpace(ASrc.S[ASrc.P]) do
  begin
    Inc(ASrc.P);
    Result := True;
  end;
end;

procedure TXmlReader.NeedSpaces(var ASrc: TXmlSource);
begin
  if not SkipSpaces(ASrc) then
    Fail('Expected white space', ASrc);
end;

function TXmlReader.ReadName(var ASrc: TXmlSource): UnicodeString;
var
  start: Integer;
begin
  start := ASrc.P;
  if AtEnd(ASrc) or not IsNameStart(ASrc.S[ASrc.P]) then
    Fail('Name expected', ASrc);
  Inc(ASrc.P);
  while (ASrc.P <= ASrc.Len) and IsNameChar(ASrc.S[ASrc.P]) do
    Inc(ASrc.P);
  Result := Copy(ASrc.S, start, ASrc.P - start);
end;

{ After '&#': the character of a character reference, as FPC's ParseRef reads it. }
function TXmlReader.ReadCharRef(var ASrc: TXmlSource): UnicodeString;
var
  code: Cardinal;
  c: WideChar;
begin
  Result := '';
  code := 0;
  if Accept(ASrc, 'x') then
    repeat
      c := Peek(ASrc);
      case c of
        '0'..'9': code := code * 16 + Cardinal(Ord(c) - Ord('0'));
        'a'..'f': code := code * 16 + Cardinal(Ord(c) - Ord('a') + 10);
        'A'..'F': code := code * 16 + Cardinal(Ord(c) - Ord('A') + 10);
      else
        Break;
      end;
      Inc(ASrc.P);
    until code > $10FFFF
  else
    repeat
      c := Peek(ASrc);
      case c of
        '0'..'9': code := code * 10 + Cardinal(Ord(c) - Ord('0'));
      else
        Break;
      end;
      Inc(ASrc.P);
    until code > $10FFFF;
  case code of
    $09, $0A, $0D, $20..$D7FF, $E000..$FFFD:
      Result := WideChar(code);
    $10000..$10FFFF:
      Result := WideChar($D7C0 + (code shr 10)) + WideChar($DC00 xor (code and $3FF));
  else
    Fail('Invalid character reference', ASrc);
  end;
  Expect(ASrc, ';');
end;

{ The predefined entity AName as its character, '' when it is not one. }
function Predefined(const AName: UnicodeString): UnicodeString;
begin
  if AName = 'lt' then
    Result := '<'
  else if AName = 'gt' then
    Result := '>'
  else if AName = 'amp' then
    Result := '&'
  else if AName = 'apos' then
    Result := ''''
  else if AName = 'quot' then
    Result := '"'
  else
    Result := '';
end;

{ The index of the declared entity AName, ready to be expanded; raises when there is none or when it
  is being expanded already. }
function TXmlReader.FindEntity(const AName: UnicodeString; const ASrc: TXmlSource): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FEntities) do
    if FEntities[i].Name = AName then
    begin
      if FEntities[i].Active then
        Fail('Entity ''' + AName + ''' recursively references itself', ASrc);
      Result := i;
      Exit;
    end;
  Fail('Reference to undefined entity ''' + AName + '''', ASrc);
  Result := -1;
end;

{ A quoted literal, without references: a system or public identifier. }
function TXmlReader.ReadQuoted(var ASrc: TXmlSource): UnicodeString;
var
  q: WideChar;
  start: Integer;
begin
  q := Peek(ASrc);
  if (q <> '"') and (q <> '''') then
    Fail('Expected a quoted literal', ASrc);
  Inc(ASrc.P);
  start := ASrc.P;
  while (ASrc.P <= ASrc.Len) and (ASrc.S[ASrc.P] <> q) do
    Inc(ASrc.P);
  if AtEnd(ASrc) then
    Fail('Literal has no closing quote', ASrc);
  Result := Copy(ASrc.S, start, ASrc.P - start);
  Inc(ASrc.P);
end;

{ The characters of an attribute value up to the quote AQuote (#0: to the end of an entity's text). }
procedure TXmlReader.ReadAttChars(var ASrc: TXmlSource; AQuote: WideChar; var AOut: UnicodeString);
var
  start, k: Integer;
  c: WideChar;
  name, pre: UnicodeString;
  sub: TXmlSource;
begin
  repeat
    start := ASrc.P;
    while (ASrc.P <= ASrc.Len) do
    begin
      c := ASrc.S[ASrc.P];
      if (c = AQuote) or (c = '<') or (c = '&') or (c = #9) or (c = #10) or (c = #13) then
        Break;
      Inc(ASrc.P);
    end;
    AOut := AOut + Copy(ASrc.S, start, ASrc.P - start);
    if AtEnd(ASrc) then
    begin
      if AQuote <> #0 then
        Fail('Literal has no closing quote', ASrc);
      Exit;
    end;
    c := ASrc.S[ASrc.P];
    if c = AQuote then
    begin
      Inc(ASrc.P);
      Exit;
    end;
    if c = '<' then
      Fail('Character ''<'' is not allowed in attribute value', ASrc);
    Inc(ASrc.P);
    if c <> '&' then
      AOut := AOut + ' '
    else if Accept(ASrc, '#') then
      AOut := AOut + ReadCharRef(ASrc)
    else
    begin
      name := ReadName(ASrc);
      Expect(ASrc, ';');
      pre := Predefined(name);
      if pre <> '' then
        AOut := AOut + pre
      else
      begin
        k := FindEntity(name, ASrc);
        FEntities[k].Active := True;
        sub := MakeSource(FEntities[k].Text);
        ReadAttChars(sub, #0, AOut);
        FEntities[k].Active := False;
      end;
    end;
  until False;
end;

function TXmlReader.ReadAttValue(var ASrc: TXmlSource): UnicodeString;
var
  q: WideChar;
begin
  q := Peek(ASrc);
  if (q <> '"') and (q <> '''') then
    Fail('Expected a quoted attribute value', ASrc);
  Inc(ASrc.P);
  Result := '';
  ReadAttChars(ASrc, q, Result);
end;

{ After nothing: '<!--' ... '-->'; a node under AParent unless AParent is nil. }
procedure TXmlReader.ReadComment(var ASrc: TXmlSource; AParent: TDOMNode);
var
  start: Integer;
begin
  Expect(ASrc, '<!--');
  start := ASrc.P;
  while not StartsWith(ASrc, '--') do
  begin
    if AtEnd(ASrc) then
      Fail('Unterminated comment', ASrc);
    Inc(ASrc.P);
  end;
  if not StartsWith(ASrc, '-->') then
    Fail('Comment contains ''--''', ASrc);
  if AParent <> nil then
    AParent.AppendChild(FDoc.CreateComment(Copy(ASrc.S, start, ASrc.P - start)));
  Inc(ASrc.P, 3);
end;

{ '<?' target data '?>'; a node under AParent unless AParent is nil. }
procedure TXmlReader.ReadPI(var ASrc: TXmlSource; AParent: TDOMNode);
var
  target: UnicodeString;
  start: Integer;
  data: UnicodeString;
begin
  Expect(ASrc, '<?');
  target := ReadName(ASrc);
  if SameText(target, 'xml') then
    Fail('Processing instruction target ''xml'' is reserved', ASrc);
  data := '';
  if not Accept(ASrc, '?>') then
  begin
    NeedSpaces(ASrc);
    start := ASrc.P;
    while not StartsWith(ASrc, '?>') do
    begin
      if AtEnd(ASrc) then
        Fail('Unterminated processing instruction', ASrc);
      Inc(ASrc.P);
    end;
    data := Copy(ASrc.S, start, ASrc.P - start);
    Inc(ASrc.P, 2);
  end;
  if AParent <> nil then
    AParent.AppendChild(FDoc.CreateProcessingInstruction(target, data));
end;

procedure TXmlReader.ReadCData(var ASrc: TXmlSource; AParent: TDOMNode);
var
  start: Integer;
begin
  Expect(ASrc, '<![CDATA[');
  start := ASrc.P;
  while not StartsWith(ASrc, ']]>') do
  begin
    if AtEnd(ASrc) then
      Fail('Unterminated CDATA section', ASrc);
    Inc(ASrc.P);
  end;
  AParent.AppendChild(FDoc.CreateCDATASection(Copy(ASrc.S, start, ASrc.P - start)));
  Inc(ASrc.P, 3);
end;

{ '<!ENTITY' name "value" '>': an internal general entity. Character references in the value are
  replaced, entity references are kept for when the entity is used; the first declaration of a name
  counts. }
procedure TXmlReader.ReadEntityDecl(var ASrc: TXmlSource);
var
  name, value: UnicodeString;
  q, c: WideChar;
  start, n, i: Integer;
begin
  Expect(ASrc, '<!ENTITY');
  NeedSpaces(ASrc);
  if Peek(ASrc) = '%' then
    Fail('Parameter entities are not supported by this XMLRead', ASrc);
  name := ReadName(ASrc);
  NeedSpaces(ASrc);
  q := Peek(ASrc);
  if (q <> '"') and (q <> '''') then
  begin
    if StartsWith(ASrc, 'SYSTEM') or StartsWith(ASrc, 'PUBLIC') then
      Fail('External entities are not supported by this XMLRead', ASrc);
    Fail('Expected an entity value', ASrc);
  end;
  Inc(ASrc.P);
  value := '';
  repeat
    start := ASrc.P;
    while (ASrc.P <= ASrc.Len) and (ASrc.S[ASrc.P] <> q) and (ASrc.S[ASrc.P] <> '&')
      and (ASrc.S[ASrc.P] <> '%') do
      Inc(ASrc.P);
    value := value + Copy(ASrc.S, start, ASrc.P - start);
    if AtEnd(ASrc) then
      Fail('Literal has no closing quote', ASrc);
    c := ASrc.S[ASrc.P];
    Inc(ASrc.P);
    if c = q then
      Break;
    if c = '%' then
      Fail('Parameter entity references are not allowed here', ASrc);
    if Accept(ASrc, '#') then
      value := value + ReadCharRef(ASrc)
    else
    begin
      value := value + '&' + ReadName(ASrc) + ';';
      Expect(ASrc, ';');
    end;
  until False;
  SkipSpaces(ASrc);
  Expect(ASrc, '>');
  { a carriage return from a character reference is a line end when the text is read }
  value := CheckAndNormalize(value);
  for i := 0 to High(FEntities) do
    if FEntities[i].Name = name then
      Exit;
  n := Length(FEntities);
  SetLength(FEntities, n + 1);
  FEntities[n].Name := name;
  FEntities[n].Text := value;
  FEntities[n].Active := False;
end;

procedure TXmlReader.ReadDoctype(var ASrc: TXmlSource);
var
  name, pubid: UnicodeString;
  i: Integer;
begin
  Expect(ASrc, '<!DOCTYPE');
  NeedSpaces(ASrc);
  name := ReadName(ASrc);
  if SkipSpaces(ASrc) then
  begin
    if Accept(ASrc, 'PUBLIC') then
    begin
      NeedSpaces(ASrc);
      pubid := ReadQuoted(ASrc);
      for i := 1 to Length(pubid) do
        if not CharInSet(pubid[i], [' ', #13, #10, 'a'..'z', 'A'..'Z', '0'..'9', '-', '''', '(', ')',
          '+', ',', '.', '/', ':', '=', '?', ';', '!', '*', '#', '@', '$', '_', '%']) then
          Fail('Illegal public identifier', ASrc);
      NeedSpaces(ASrc);
      ReadQuoted(ASrc);
      SkipSpaces(ASrc);
    end
    else if Accept(ASrc, 'SYSTEM') then
    begin
      NeedSpaces(ASrc);
      ReadQuoted(ASrc);
      SkipSpaces(ASrc);
    end;
  end;
  if Accept(ASrc, '[') then
  begin
    repeat
      SkipSpaces(ASrc);
      if AtEnd(ASrc) then
        Fail('Unterminated internal subset', ASrc);
      if Accept(ASrc, ']') then
        Break;
      if StartsWith(ASrc, '<!ENTITY') then
        ReadEntityDecl(ASrc)
      else if StartsWith(ASrc, '<!--') then
        ReadComment(ASrc, nil)
      else if StartsWith(ASrc, '<?') then
        ReadPI(ASrc, nil)
      else if Peek(ASrc) = '%' then
        Fail('Parameter entity references are not supported by this XMLRead', ASrc)
      else if StartsWith(ASrc, '<!ELEMENT') or StartsWith(ASrc, '<!ATTLIST')
        or StartsWith(ASrc, '<!NOTATION') then
        Fail('ELEMENT, ATTLIST and NOTATION declarations are not supported by this XMLRead', ASrc)
      else
        Fail('Illegal character in internal subset', ASrc);
    until False;
    SkipSpaces(ASrc);
  end;
  Expect(ASrc, '>');
  FDoc.AppendChild(FDoc.CreateDocumentTypeNode(name));
end;

{ After '<' and a name start: the element, its attributes and its content. }
procedure TXmlReader.ReadElement(var ASrc: TXmlSource; AParent: TDOMNode);
var
  el: TDOMElement;
  name, aname, pending: UnicodeString;
  sp: Boolean;
begin
  Expect(ASrc, '<');
  name := ReadName(ASrc);
  el := FDoc.CreateElement(name);
  AParent.AppendChild(el);
  repeat
    sp := SkipSpaces(ASrc);
    if Accept(ASrc, '/>') then
      Exit;
    if Accept(ASrc, '>') then
      Break;
    if not sp then
      Fail('Expected white space, ''>'' or ''/>''', ASrc);
    aname := ReadName(ASrc);
    if el.GetAttributeNode(aname) <> nil then
      Fail('Duplicate attribute ''' + aname + '''', ASrc);
    SkipSpaces(ASrc);
    Expect(ASrc, '=');
    SkipSpaces(ASrc);
    el.SetAttribute(aname, ReadAttValue(ASrc));
  until False;
  pending := '';
  ReadContent(ASrc, el, name, False, pending);
end;

{ Content under AParent up to the end tag of AEndName or, in an entity's text (AInEntity), to its end.
  APending is the text not yet made a node: an entity's text joins the text around it. }
procedure TXmlReader.ReadContent(var ASrc: TXmlSource; AParent: TDOMNode;
  const AEndName: UnicodeString; AInEntity: Boolean; var APending: UnicodeString);

  procedure Flush;
  begin
    if APending <> '' then
    begin
      AParent.AppendChild(FDoc.CreateTextNode(APending));
      APending := '';
    end;
  end;

var
  start, k, n: Integer;
  c: WideChar;
  name, pre: UnicodeString;
  sub: TXmlSource;
begin
  repeat
    start := ASrc.P;
    while (ASrc.P <= ASrc.Len) do
    begin
      c := ASrc.S[ASrc.P];
      if (c = '<') or (c = '&') or (c = '>') then
        Break;
      Inc(ASrc.P);
    end;
    APending := APending + Copy(ASrc.S, start, ASrc.P - start);
    if AtEnd(ASrc) then
    begin
      if not AInEntity then
        Fail('End-tag is missing for ''' + AEndName + '''', ASrc);
      Exit;
    end;
    c := ASrc.S[ASrc.P];
    if c = '>' then
    begin
      n := Length(APending);
      if (n >= 2) and (APending[n - 1] = ']') and (APending[n] = ']') then
        Fail('Literal '']]>'' is not allowed in text', ASrc);
      APending := APending + '>';
      Inc(ASrc.P);
    end
    else if c = '&' then
    begin
      Inc(ASrc.P);
      if Accept(ASrc, '#') then
        APending := APending + ReadCharRef(ASrc)
      else
      begin
        name := ReadName(ASrc);
        Expect(ASrc, ';');
        pre := Predefined(name);
        if pre <> '' then
          APending := APending + pre
        else
        begin
          k := FindEntity(name, ASrc);
          FEntities[k].Active := True;
          sub := MakeSource(FEntities[k].Text);
          ReadContent(sub, AParent, '', True, APending);
          FEntities[k].Active := False;
        end;
      end;
    end
    else if StartsWith(ASrc, '</') then
    begin
      if AInEntity then
        Fail('End-tag inside an entity that did not start the element', ASrc);
      Flush;
      Inc(ASrc.P, 2);
      name := ReadName(ASrc);
      if name <> AEndName then
        Fail('End-tag ''' + name + ''' does not match ''' + AEndName + '''', ASrc);
      SkipSpaces(ASrc);
      Expect(ASrc, '>');
      Exit;
    end
    else if StartsWith(ASrc, '<!--') then
    begin
      Flush;
      ReadComment(ASrc, AParent);
    end
    else if StartsWith(ASrc, '<![CDATA[') then
    begin
      Flush;
      ReadCData(ASrc, AParent);
    end
    else if StartsWith(ASrc, '<?') then
    begin
      Flush;
      ReadPI(ASrc, AParent);
    end
    else
    begin
      Flush;
      if StartsWith(ASrc, '<!') then
        Fail('Markup declaration not allowed here', ASrc);
      ReadElement(ASrc, AParent);
    end;
  until False;
end;

{ '<?xml' ... '?>': checks it; returns the encoding name, '' when there is none. }
function TXmlReader.ReadXmlDecl(var ASrc: TXmlSource): UnicodeString;
var
  q: WideChar;
  sp: Boolean;
  start: Integer;
  v: UnicodeString;
begin
  Result := '';
  Expect(ASrc, '<?xml');
  NeedSpaces(ASrc);
  Expect(ASrc, 'version');
  SkipSpaces(ASrc);
  Expect(ASrc, '=');
  SkipSpaces(ASrc);
  v := ReadQuoted(ASrc);
  if v <> '1.0' then
    Fail('XML version ''' + v + ''' is not supported by this XMLRead', ASrc);
  sp := SkipSpaces(ASrc);
  if StartsWith(ASrc, 'encoding') then
  begin
    if not sp then
      Fail('Expected white space', ASrc);
    Inc(ASrc.P, Length('encoding'));
    SkipSpaces(ASrc);
    Expect(ASrc, '=');
    SkipSpaces(ASrc);
    q := Peek(ASrc);
    if (q <> '"') and (q <> '''') then
      Fail('Expected a quoted encoding name', ASrc);
    Inc(ASrc.P);
    start := ASrc.P;
    while (ASrc.P <= ASrc.Len) and (ASrc.P - start < 30) and (CharInSet(ASrc.S[ASrc.P], ['A'..'Z', 'a'..'z'])
      or ((ASrc.P > start) and CharInSet(ASrc.S[ASrc.P], ['0'..'9', '.', '-', '_']))) do
      Inc(ASrc.P);
    Result := Copy(ASrc.S, start, ASrc.P - start);
    if Peek(ASrc) <> q then
      Fail('Illegal encoding name', ASrc);
    Inc(ASrc.P);
    sp := SkipSpaces(ASrc);
  end;
  if StartsWith(ASrc, 'standalone') then
  begin
    if not sp then
      Fail('Expected white space', ASrc);
    Inc(ASrc.P, Length('standalone'));
    SkipSpaces(ASrc);
    Expect(ASrc, '=');
    SkipSpaces(ASrc);
    v := ReadQuoted(ASrc);
    if (v <> 'yes') and (v <> 'no') then
      Fail('Only "yes" or "no" are permitted as values of "standalone"', ASrc);
    SkipSpaces(ASrc);
  end;
  Expect(ASrc, '?>');
end;

{ The prolog, the root element and what follows it. }
procedure TXmlReader.ReadDocument(var ASrc: TXmlSource);
var
  hasRoot, hasDoctype: Boolean;
begin
  hasRoot := False;
  hasDoctype := False;
  repeat
    SkipSpaces(ASrc);
    if AtEnd(ASrc) then
      Break;
    if StartsWith(ASrc, '<?') then
      ReadPI(ASrc, FDoc)
    else if StartsWith(ASrc, '<!--') then
      ReadComment(ASrc, FDoc)
    else if StartsWith(ASrc, '<!DOCTYPE') then
    begin
      if hasDoctype or hasRoot then
        Fail('DOCTYPE is not allowed here', ASrc);
      ReadDoctype(ASrc);
      hasDoctype := True;
    end
    else if (Peek(ASrc) = '<') and (ASrc.P < ASrc.Len) and IsNameStart(ASrc.S[ASrc.P + 1]) then
    begin
      if hasRoot then
        Fail('Only one top-level element allowed', ASrc);
      ReadElement(ASrc, FDoc);
      hasRoot := True;
    end
    else
      Fail('Illegal at document level', ASrc);
  until False;
  if not hasRoot then
    Fail('Root element is missing', ASrc);
end;

procedure TXmlReader.Run(const ABytes: TBytes; ADoc: TXMLDocument);
var
  n, declEnd, i: Integer;
  fixed, enc: string;
  text: UnicodeString;
  src: TXmlSource;
  latin1: Boolean;
begin
  FDoc := ADoc;
  n := Length(ABytes);
  fixed := '';
  declEnd := n;
  if (n >= 2) and (ABytes[0] = $FE) and (ABytes[1] = $FF) then
  begin
    fixed := 'UTF-16BE';
    text := DecodeUtf16(ABytes, 0, True);
  end
  else if (n >= 2) and (ABytes[0] = $FF) and (ABytes[1] = $FE) then
  begin
    fixed := 'UTF-16LE';
    text := DecodeUtf16(ABytes, 0, False);
  end
  else
  begin
    { the XML declaration is read as UTF-8; the encoding it names applies after it }
    i := 0;
    if (n >= 3) and (ABytes[0] = $EF) and (ABytes[1] = $BB) and (ABytes[2] = $BF) then
      i := 3;
    if (n - i >= 5) and (ABytes[i] = Ord('<')) and (ABytes[i + 1] = Ord('?')) and (ABytes[i + 2] = Ord('x'))
      and (ABytes[i + 3] = Ord('m')) and (ABytes[i + 4] = Ord('l')) then
    begin
      Inc(i, 5);
      while (i + 1 < n) and not ((ABytes[i] = Ord('?')) and (ABytes[i + 1] = Ord('>'))) do
        Inc(i);
      if i + 1 < n then
        declEnd := i + 2;
    end;
    text := DecodeUtf8(ABytes, 0, declEnd);
  end;
  text := CheckAndNormalize(text);
  if (text <> '') and (text[1] = #$FEFF) then
    Delete(text, 1, 1);
  src := MakeSource(text);
  enc := '';
  if StartsWith(src, '<?xml') then
    enc := ReadXmlDecl(src);
  latin1 := False;
  if fixed <> '' then
  begin
    if (enc <> '') and not (SameText(enc, fixed) or SameText(enc, 'UTF-16') or SameText(enc, 'unicode')) then
      Fail('Encoding ''' + enc + ''' is not supported', src);
  end
  else if (enc <> '') and not SameText(enc, 'UTF-8') then
  begin
    if not IsLatin1Name(enc) then
      Fail('Encoding ''' + enc + ''' is not supported', src);
    latin1 := True;
  end;
  if declEnd < n then
  begin
    if latin1 then
      text := DecodeLatin1(ABytes, declEnd, n)
    else
      text := DecodeUtf8(ABytes, declEnd, n);
    src.S := src.S + CheckAndNormalize(text);
    src.Len := Length(src.S);
  end;
  ReadDocument(src);
end;

{ TXMLInputSource }

constructor TXMLInputSource.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
end;

{ TDOMParser }

constructor TDOMParser.Create;
begin
  inherited Create;
  FOptions := TDOMParseOptions.Create;
end;

destructor TDOMParser.Destroy;
begin
  FOptions.Free;
  inherited Destroy;
end;

procedure TDOMParser.Parse(ASrc: TXMLInputSource; out ADoc: TXMLDocument);
var
  bytes: TBytes;
  reader: TXmlReader;
  n: Int64;
begin
  ADoc := TXMLDocument.Create;
  if not (FOptions.PreserveWhitespace and not FOptions.Namespaces and FOptions.ExpandEntities
    and not FOptions.Validate) then
    raise EXMLReadError.Create('This XMLRead implements only PreserveWhitespace = True, '
      + 'Namespaces = False, ExpandEntities = True, Validate = False');
  n := ASrc.FStream.Size - ASrc.FStream.Position;
  SetLength(bytes, n);
  if n > 0 then
    ASrc.FStream.ReadBuffer(bytes[0], n);
  reader := TXmlReader.Create;
  try
    reader.Run(bytes, ADoc);
  finally
    reader.Free;
  end;
end;

end.
