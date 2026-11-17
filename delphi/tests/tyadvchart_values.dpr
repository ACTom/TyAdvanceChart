{ Checks, under Delphi, the values of the helpers that have a branch of their own for it.
  Built and run by scripts/delphi-probe.py --values with dcc32 and dcc64; not compiled by FPC.
  Prints DELPHI VALUES OK as its last line when every check holds, else the failed check and exit code 1. }
program tyadvchart_values;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  fpjson,
  jsonparser,
  jsonscanner,
  tyControls.AdvanceChart.Catalog,
  tyControls.AdvanceChart.JsMath,
  tyControls.AdvanceChart.NativeStr,
  tyControls.AdvanceChart.Types;

procedure Check(ACond: Boolean; const AWhat: string);
begin
  if not ACond then
  begin
    Writeln('FAILED: ' + AWhat);
    Halt(1);
  end;
end;

procedure CheckSar32;
begin
  Check(TySar32(5, 2) = 1, 'TySar32(5, 2) = 1');
  Check(TySar32(-5, 2) = -2, 'TySar32(-5, 2) = -2');
  Check(TySar32(-1, 31) = -1, 'TySar32(-1, 31) = -1');
  Check(TySar32(Low(Integer), 1) = -1073741824, 'TySar32(Low(Integer), 1) = -1073741824');
  Check(TySar32(High(Integer), 31) = 0, 'TySar32(High(Integer), 31) = 0');
  Check(TySar32(-7, 0) = -7, 'TySar32(-7, 0) = -7');
end;

procedure CheckIntToDouble;
begin
  Check(TyIntToDouble(0) = 0.0, 'TyIntToDouble(0) = 0');
  Check(TyIntToDouble(1) / 3 = Double(1.0) / 3, 'TyIntToDouble(1) / 3 = 1.0 / 3');
  Check(TyIntToDouble(-360) = -360.0, 'TyIntToDouble(-360) = -360');
  Check(TyIntToDouble(High(Integer)) = 2147483647.0, 'TyIntToDouble(High(Integer)) = 2147483647');
  Check(TyIntToDouble(Int64(9007199254740993)) = 9007199254740992.0, 'TyIntToDouble(2^53 + 1) rounds to even');
  Check(TyIntToDouble(Int64(9007199254740995)) = 9007199254740996.0, 'TyIntToDouble(2^53 + 3) rounds to even');
  Check(TyIntToDouble(Low(Int64)) = -9223372036854775808.0, 'TyIntToDouble(Low(Int64)) = -2^63');
end;

procedure CheckFloorCeil64;
begin
  Check(TyFloor64(2.5) = 2, 'TyFloor64(2.5) = 2');
  Check(TyFloor64(-2.5) = -3, 'TyFloor64(-2.5) = -3');
  Check(TyFloor64(-2.0) = -2, 'TyFloor64(-2.0) = -2');
  Check(TyFloor64(4294967296.5) = 4294967296, 'TyFloor64(4294967296.5) = 4294967296');
  Check(TyCeil64(2.5) = 3, 'TyCeil64(2.5) = 3');
  Check(TyCeil64(-2.5) = -2, 'TyCeil64(-2.5) = -2');
  Check(TyCeil64(2.0) = 2, 'TyCeil64(2.0) = 2');
  Check(TyCeil64(-4294967296.5) = -4294967296, 'TyCeil64(-4294967296.5) = -4294967296');
end;

procedure CheckBoolText;
begin
  Check(TyBoolText(True, 'yes', 'no') = 'yes', 'TyBoolText(True, ''yes'', ''no'') = ''yes''');
  Check(TyBoolText(False, 'yes', 'no') = 'no', 'TyBoolText(False, ''yes'', ''no'') = ''no''');
  Check(TyBoolText(False, 'c', '') = '', 'TyBoolText(False, ''c'', '''') = ''''');
end;

{ The same checks as tests/test.advchart.nativestr.pas, in UTF-16: a BMP character is one unit, a surrogate
  pair two. }
procedure CheckNativeStr;
const
  cGuo = #$56FD;
  cEAcute = #$00E9;
  cGrin = #$D83D#$DE00;
var
  u: UnicodeString;
  n: Integer;
begin
  Check(Length(TyJsUnits('a' + cGuo + cEAcute)) = 3, 'Length(TyJsUnits(a + U+56FD + U+00E9)) = 3');
  Check(Length(TyJsUnits(cGrin)) = 2, 'Length(TyJsUnits(U+1F600)) = 2');
  Check(Length(TyJsUnits('')) = 0, 'Length(TyJsUnits('''')) = 0');
  Check(Ord(TyJsUnits(cGuo)[1]) = $56FD, 'TyJsUnits(U+56FD)[1] = $56FD');
  u := TyJsUnits(cGrin);
  Check((Ord(u[1]) = $D83D) and (Ord(u[2]) = $DE00), 'TyJsUnits(U+1F600) = $D83D $DE00');

  Check(TyFromJsUnits(TyJsUnits('')) = '', 'round trip of ''''');
  Check(TyFromJsUnits(TyJsUnits('abc')) = 'abc', 'round trip of abc');
  Check(TyFromJsUnits(TyJsUnits('a' + cGuo + cEAcute)) = 'a' + cGuo + cEAcute, 'round trip of a + U+56FD + U+00E9');
  Check(TyFromJsUnits(TyJsUnits(cGrin + 'x')) = cGrin + 'x', 'round trip of U+1F600 + x');

  Check(TyCodePointStr($41) = 'A', 'TyCodePointStr($41) = A');
  Check(TyCodePointStr($E9) = cEAcute, 'TyCodePointStr($E9) = U+00E9');
  Check(TyCodePointStr($56FD) = cGuo, 'TyCodePointStr($56FD) = U+56FD');
  Check(TyCodePointStr($1F600) = cGrin, 'TyCodePointStr($1F600) = $D83D $DE00');
  Check(TyCodePointStr($7F) = #$7F, 'TyCodePointStr($7F) = $7F');
  Check(TyCodePointStr($80) = #$0080, 'TyCodePointStr($80) = $0080');
  Check(TyCodePointStr($7FF) = #$07FF, 'TyCodePointStr($7FF) = $07FF');
  Check(TyCodePointStr($800) = #$0800, 'TyCodePointStr($800) = $0800');
  Check(TyCodePointStr($FFFF) = #$FFFF, 'TyCodePointStr($FFFF) = $FFFF');
  Check(TyCodePointStr($10000) = #$D800#$DC00, 'TyCodePointStr($10000) = $D800 $DC00');
  Check(TyCodePointStr($10FFFF) = #$DBFF#$DFFF, 'TyCodePointStr($10FFFF) = $DBFF $DFFF');

  Check(TyFirstCharLen('') = 0, 'TyFirstCharLen('''') = 0');
  Check(TyFirstCharLen('abc') = 1, 'TyFirstCharLen(abc) = 1');
  Check(TyFirstCharLen(cGuo + 'a') = Length(cGuo), 'TyFirstCharLen(U+56FD + a) = Length(U+56FD)');
  Check(TyFirstCharLen(cGrin + 'a') = Length(cGrin), 'TyFirstCharLen(U+1F600 + a) = Length(U+1F600)');
  Check(TyFirstCharLen(cGuo) = 1, 'TyFirstCharLen(U+56FD) = 1');
  Check(TyFirstCharLen(cGrin) = 2, 'TyFirstCharLen(U+1F600) = 2');
  Check(TyFirstCharLen('a' + cGuo) = 1, 'TyFirstCharLen(a + U+56FD) = 1');

  Check(TyLastCharStart('') = 0, 'TyLastCharStart('''') = 0');
  Check(TyLastCharStart('abc') = 3, 'TyLastCharStart(abc) = 3');
  Check(TyLastCharStart('a' + cGuo) = 2, 'TyLastCharStart(a + U+56FD) = 2');
  Check(TyLastCharStart('a' + cGrin) = 2, 'TyLastCharStart(a + U+1F600) = 2');
  Check(TyLastCharStart(cGuo) = 1, 'TyLastCharStart(U+56FD) = 1');
  Check(TyLastCharStart(cGrin) = 1, 'TyLastCharStart(U+1F600) = 1');
  Check(TyLastCharStart(cGuo + 'a') = 2, 'TyLastCharStart(U+56FD + a) = 2');
  Check(TyLastCharStart(cGrin + 'a') = 3, 'TyLastCharStart(U+1F600 + a) = 3');

  Check((TyCodePointAt('A', 1, n) = $41) and (n = 1), 'TyCodePointAt(A, 1) = $41, len 1');
  Check((TyCodePointAt(cEAcute, 1, n) = $E9) and (n = 1), 'TyCodePointAt(U+00E9, 1) = $E9, len 1');
  Check((TyCodePointAt(cGuo, 1, n) = $56FD) and (n = 1), 'TyCodePointAt(U+56FD, 1) = $56FD, len 1');
  Check((TyCodePointAt(cGrin, 1, n) = $1F600) and (n = 2), 'TyCodePointAt(U+1F600, 1) = $1F600, len 2');
  Check((TyCodePointAt('a' + cGuo + 'b', 2, n) = $56FD) and (n = 1), 'TyCodePointAt(a + U+56FD + b, 2) = $56FD, len 1');
  Check((TyCodePointAt('a' + cGuo + 'b', 3, n) = $62) and (n = 1), 'TyCodePointAt(a + U+56FD + b, 3) = $62, len 1');
  Check((TyCodePointAt('a' + cGrin + 'b', 2, n) = $1F600) and (n = 2), 'TyCodePointAt(a + U+1F600 + b, 2) = $1F600, len 2');
  Check((TyCodePointAt('a' + cGrin + 'b', 4, n) = $62) and (n = 1), 'TyCodePointAt(a + U+1F600 + b, 4) = $62, len 1');
  Check((TyCodePointAt('a' + #$D83D, 2, n) = $D83D) and (n = 1), 'TyCodePointAt(a + lone high surrogate at the end, 2) = $D83D, len 1');
  Check((TyCodePointAt(#$D83D + 'a', 1, n) = $D83D) and (n = 1), 'TyCodePointAt(high surrogate + a, 1) = $D83D, len 1');
  Check((TyCodePointAt(#$DE00, 1, n) = $DE00) and (n = 1), 'TyCodePointAt(lone low surrogate, 1) = $DE00, len 1');
  Check((TyCodePointAt(cGrin, 2, n) = $DE00) and (n = 1), 'TyCodePointAt(U+1F600, 2) = $DE00, len 1');

  Check(TyCharStartAt('abc', 3, 1) = 3, 'TyCharStartAt(abc, 3, 1) = 3');
  Check(TyCharStartAt('a' + cGuo, 2, 1) = 2, 'TyCharStartAt(a + U+56FD, 2, 1) = 2');
  Check(TyCharStartAt('a' + cGrin, 3, 1) = 2, 'TyCharStartAt(a + U+1F600, 3, 1) = 2');
  Check(TyCharStartAt('a' + cGrin, 2, 1) = 2, 'TyCharStartAt(a + U+1F600, 2, 1) = 2');
  Check(TyCharStartAt(cGrin, 2, 1) = 1, 'TyCharStartAt(U+1F600, 2, 1) = 1');
  Check(TyCharStartAt(cGrin, 2, 0) = 1, 'TyCharStartAt(U+1F600, 2, 0) = 1');
  Check(TyCharStartAt(cGrin, 2, 2) = 2, 'TyCharStartAt(U+1F600, 2, 2) = 2 (the floor holds)');
  Check(TyCharStartAt(#$DE00, 1, 0) = 1, 'TyCharStartAt(lone low surrogate, 1, 0) = 1');
  Check(TyCharStartAt('a' + #$DE00, 2, 1) = 2, 'TyCharStartAt(a + lone low surrogate, 2, 1) = 2');

  { Unpaired surrogates: Delphi's branches keep them as they are. }
  Check(TyLastCharStart('a' + #$DE00) = 2, 'TyLastCharStart(a + lone low surrogate) = 2');
  Check(TyFirstCharLen(#$D83D + 'a') = 1, 'TyFirstCharLen(lone high surrogate + a) = 1');
  Check(TyCodePointStr($D800) = #$D800, 'TyCodePointStr($D800) = $D800');
  { FPC's TyFromJsUnits drops an unpaired surrogate (UTF8Encode's behaviour); Delphi's keeps it. }
  u := 'a' + #$D83D + 'b';
  Check(TyFromJsUnits(u) = 'a' + #$D83D + 'b', 'TyFromJsUnits(a + lone high surrogate + b) keeps it');
end;

{ With --codepage:65001 a contiguous run of byte escapes in a chart unit is one UTF-8 sequence, one
  character under Delphi: Catalog's TyOptStr[387] is written ''''#$E2#$96#$B6'''', a quoted U+25B6.
  The index moves when the catalog is generated again; find the entry by that literal. }
procedure CheckByteEscapeRun;
const
  cAt = 387;
begin
  Check(Length(TyOptStr[cAt]) = 3, 'Length(TyOptStr[387]) = 3 (quote, U+25B6, quote)');
  Check((TyOptStr[cAt][1] = '''') and (TyOptStr[cAt][3] = ''''), 'TyOptStr[387] is quoted');
  Check(Ord(TyOptStr[cAt][2]) = $25B6, 'TyOptStr[387][2] = $25B6');
end;

{ delphi/fcl's fpjson keeps member names of any length (FPC's own keeps 255 bytes of them; the FCL
  transcript shows it only as informational lines), for objects built with Add and read by the parser. }
procedure CheckJsonLongKeys;
var
  o: TJSONObject;
  d: TJSONData;
  k300, ka, kb: string;
begin
  k300 := StringOfChar('k', 300);
  ka := StringOfChar('k', 279) + 'a' + StringOfChar('k', 20);
  kb := StringOfChar('k', 279) + 'b' + StringOfChar('k', 20);
  o := TJSONObject.Create;
  try
    o.Add(k300, 1);
    Check(o.Find(k300) <> nil, 'JSON: a key of 300 characters is found');
    Check(Length(o.Names[0]) = 300, 'JSON: Length(Names[0]) = 300');
  finally
    o.Free;
  end;
  o := TJSONObject.Create;
  try
    o.Add(ka, 1);
    o.Add(kb, 2);
    Check(o.Count = 2, 'JSON: two keys that differ at the 280th character are two members');
    Check((o.Find(ka) <> nil) and (o.Find(ka).AsInteger = 1), 'JSON: the first of them has the value 1');
    Check((o.Find(kb) <> nil) and (o.Find(kb).AsInteger = 2), 'JSON: the second of them has the value 2');
  finally
    o.Free;
  end;
  { The same, for objects read by the parser. }
  d := GetJSON('{"' + k300 + '":1}');
  try
    Check(TJSONObject(d).Find(k300) <> nil, 'JSON, parsed: a key of 300 characters is found');
    Check(Length(TJSONObject(d).Names[0]) = 300, 'JSON, parsed: Length(Names[0]) = 300');
  finally
    d.Free;
  end;
  d := GetJSON('{"' + ka + '":1,"' + kb + '":2}');
  try
    o := TJSONObject(d);
    Check(o.Count = 2, 'JSON, parsed: two keys that differ at the 280th character are two members');
    Check((o.Find(ka) <> nil) and (o.Find(ka).AsInteger = 1), 'JSON, parsed: the first of them has the value 1');
    Check((o.Find(kb) <> nil) and (o.Find(kb).AsInteger = 2), 'JSON, parsed: the second of them has the value 2');
  finally
    d.Free;
  end;
end;

{ The code units of S in hexadecimal, for the messages. }
function UnitsHex(const S: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    Result := Result + ' $' + IntToHex(Ord(S[i]), 4);
end;

{ Each \u escape is one code unit, in order, in the scanner and in JSONStringToString: the inputs of the
  FCL transcript's jsonstr 14-20, informational there because FPC 3.2.2 drops unpaired surrogates and
  pairs a pending escape with the next one. Also \u0000 (FPC's drops it) and DumpJSON of a kept
  unpaired surrogate. }
procedure CheckJsonEscapes;
const
  cInputs: array[0..6] of string = (
    '\ud83d', '\ude00', '\ud83dx', '\u00f1\ud83d\ude00', '\u4e2d\ud83d\ude00', '\u4e2d\u6587\ud83d\ude00',
    '\u0041\u56fd\u00e9');
  cUnits: array[0..6] of string = (
    #$D83D, #$DE00, #$D83D'x', #$00F1#$D83D#$DE00, #$4E2D#$D83D#$DE00, #$4E2D#$6587#$D83D#$DE00,
    'A'#$56FD#$00E9);
var
  i: Integer;
  d: TJSONData;
  s: string;
  st: TBytesStream;
begin
  for i := Low(cInputs) to High(cInputs) do
  begin
    d := GetJSON('"' + cInputs[i] + '"');
    try
      s := d.AsString;
    finally
      d.Free;
    end;
    Check(s = cUnits[i], 'JSON: "' + cInputs[i] + '" reads as' + UnitsHex(cUnits[i]) + ', got' + UnitsHex(s));
    s := JSONStringToString(cInputs[i]);
    Check(s = cUnits[i], 'JSON: JSONStringToString(' + cInputs[i] + ') =' + UnitsHex(cUnits[i]) + ', got' + UnitsHex(s));
  end;
  Check(Length(JSONStringToString('\u0000')) = 1, 'JSON: Length(JSONStringToString(\u0000)) = 1');
  Check(JSONStringToString('a\u0000b') = 'a'#0'b', 'JSON: JSONStringToString(a\u0000b) = a #0 b');
  { DumpJSON writes a kept unpaired surrogate as the replacement character's UTF-8 bytes. }
  d := TJSONString.Create('a' + #$D83D);
  st := TBytesStream.Create;
  try
    d.DumpJSON(st);
    Check((st.Size = 6) and (st.Bytes[0] = $22) and (st.Bytes[1] = $61) and (st.Bytes[2] = $EF)
      and (st.Bytes[3] = $BF) and (st.Bytes[4] = $BD) and (st.Bytes[5] = $22),
      'JSON: DumpJSON of a + lone $D83D writes 22 61 EF BF BD 22');
  finally
    st.Free;
    d.Free;
  end;
end;

{ A stream with invalid UTF-8 parses: an invalid sequence reads as U+FFFD (FPC's keeps the bytes). }
procedure CheckJsonInvalidBytes;
const
  cBytes1: array[0..4] of Byte = ($22, $41, $FF, $42, $22);
  cBytes2: array[0..4] of Byte = ($22, $41, $E5, $9B, $22);
var
  b: TBytes;
  st: TBytesStream;
  p: TJSONParser;
  d: TJSONData;
  s: string;
  k: Integer;
begin
  for k := 1 to 2 do
  begin
    SetLength(b, 5);
    if k = 1 then
      Move(cBytes1[0], b[0], 5)
    else
      Move(cBytes2[0], b[0], 5);
    st := TBytesStream.Create(b);
    try
      p := TJSONParser.Create(st, [joUTF8]);
      try
        d := p.Parse;
      finally
        p.Free;
      end;
    finally
      st.Free;
    end;
    try
      Check(d.JSONType = jtString, 'JSON: invalid UTF-8 in a stream still gives a string');
      s := d.AsString;
    finally
      d.Free;
    end;
    if k = 1 then
      Check(s = 'A'#$FFFD'B', 'JSON: the bytes 22 41 FF 42 22 read as $0041 $FFFD $0042, got' + UnitsHex(s))
    else
      Check(s = 'A'#$FFFD, 'JSON: the bytes 22 41 E5 9B 22 read as $0041 $FFFD (the quote survives), got' + UnitsHex(s));
  end;
end;

{ delphi/fcl's JSON units keep strings as UTF-16: an escaped surrogate pair is the two code units, a
  non-ASCII character needs no escape, and a stream of UTF-8 bytes reads as the same text. }
procedure CheckJsonStrings;
const
  cText = '{"' + #$540D + '":"caf' + #$00E9 + ' ' + #$56FD + #$D83D#$DE00 + '","a":[' + '"\u00f1"]}';
var
  d, ds: TJSONData;
  s: string;
  st: TBytesStream;
  p: TJSONParser;
begin
  d := GetJSON('"\ud83d\ude00"');
  try
    s := d.AsString;
    Check(Length(s) = 2, 'JSON: "\ud83d\ude00" reads as a string of length 2');
    Check((Ord(s[1]) = $D83D) and (Ord(s[2]) = $DE00), 'JSON: "\ud83d\ude00" reads as $D83D $DE00');
  finally
    d.Free;
  end;
  s := 'a' + #$56FD + 'b';
  Check(StringToJSONString(s) = s, 'JSON: StringToJSONString(a + U+56FD + b) gives it back as it is');
  d := GetJSON(cText);
  try
    st := TBytesStream.Create(TEncoding.UTF8.GetBytes(cText));
    try
      p := TJSONParser.Create(st, [joUTF8]);
      try
        ds := p.Parse;
      finally
        p.Free;
      end;
    finally
      st.Free;
    end;
    try
      Check(ds.AsJSON = d.AsJSON, 'JSON: read from a stream of UTF-8 bytes, the tree is the one read from the string');
      Check(TJSONObject(ds).Names[0] = #$540D, 'JSON: read from a stream of UTF-8 bytes, the name is U+540D');
      Check(TJSONObject(ds).Items[0].AsString = TJSONObject(d).Items[0].AsString,
        'JSON: read from a stream of UTF-8 bytes, the string is the one read from the string');
      Check(TJSONObject(ds).Items[0].AsString = 'caf' + #$00E9 + ' ' + #$56FD + #$D83D#$DE00,
        'JSON: read from a stream of UTF-8 bytes, the string is caf + U+00E9 + blank + U+56FD + U+1F600');
    finally
      ds.Free;
    end;
  finally
    d.Free;
  end;
end;

{ As FPC's, a JSON string that Val cannot read is read again with the locale's format settings. The
  decimal separator is set here, so the check does not depend on the machine's locale. }
procedure CheckJsonStringLocaleFloat;
var
  sep: Char;
  s: TJSONString;
begin
  sep := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    s := TJSONString.Create('1,5');
    try
      Check(s.AsFloat = 1.5, 'JSON: with the decimal separator '','', the string 1,5 reads as 1.5');
    finally
      s.Free;
    end;
    s := TJSONString.Create('1.5');
    try
      Check(s.AsFloat = 1.5, 'JSON: with the decimal separator '','', the string 1.5 still reads as 1.5');
    finally
      s.Free;
    end;
  finally
    FormatSettings.DecimalSeparator := sep;
  end;
end;

begin
  CheckSar32;
  CheckIntToDouble;
  CheckFloorCeil64;
  CheckBoolText;
  CheckNativeStr;
  CheckByteEscapeRun;
  CheckJsonLongKeys;
  CheckJsonStrings;
  CheckJsonEscapes;
  CheckJsonInvalidBytes;
  CheckJsonStringLocaleFloat;
  Writeln('DELPHI VALUES OK');
end.
