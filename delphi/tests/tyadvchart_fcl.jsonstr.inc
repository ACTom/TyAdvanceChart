(* Section jsonstr: JSON strings. A text input is read with GetJSON and printed as in section json (the
  tree, 'asjson', 'formatjson'); then, when it was read, 'tojson' and 'tojson strict' are
  StringToJSONString of its value with Strict False and True, and in every case 'fromjson' is
  JSONStringToString of the text between its quotes.

  The inputs by group of the plan (numbers of '== jsonstr N'):
    1  1       the escapes \" \\ \/ \b \f \n \r \t
    2  2-4     \u escapes (case 2 without 'fromjson': FPC's JSONStringToString damages it, see
               group 7b); a surrogate pair written \u..\u..; a four-byte character written directly
    3  5       Chinese and accented letters written directly
    4  6       U+0001, U+001F, U+007F, U+0080, U+2028 through StringToJSONString
    5  7-9     the empty string, a string of one quote, a string of 5000 units
    6  10-13   invalid: \x, \u with two digits, no closing quote, a line break in the string
    7  14-16   unpaired surrogates (informational: FPC's strings are UTF-8, which cannot hold them, and
               its UTF8Encode drops them; the port keeps them; always the same seven lines)
    7b 17-20   valid text that FPC 3.2.2 damages (informational, the same seven lines): FPC's scanner
               keeps a \u escape pending and encodes it together with the NEXT escape, whatever that
               is, so a valid pair that follows an odd number of escapes is split and its halves
               dropped (\u00f1 + pair, \u4e2d + pair: the emoji is lost); after an even number
               (\u4e2d\u6587 + pair) the pair survives, but FPC 3.2.2 turns the U+6587 into '?'.
               FPC's JSONStringToString also appends a pending escape a second time (\u00f1 + pair
               gives U+00F1 twice and no emoji; \u4e2d\u6587 + pair gives U+4E2D twice;
               \u0041\u56fd\u00e9 gives AA..). This is FPC's defect; the port appends every escape
               as its one code unit.
    8  21-26   read from a stream of UTF-8 bytes: TJSONParser.Create(TStream, ...) with and without joUTF8,
               with a byte order mark (with and without joBOMCheck), GetJSON(TStream), and GetJSON(TStream)
               with no stream parser handler (FPC's reads the stream and returns nil)
    9  27      GetJSON(text, False)
    -  28      the bytes TJSONData.DumpJSON writes for a tree with non-ASCII names and strings *)

const
  { group 3: "<U+4E2D U+6587> caf<U+00E9> <U+00F1>" }
  cJsonStrText3 = '"'#$E4#$B8#$AD#$E6#$96#$87' caf'#$C3#$A9' '#$C3#$B1'"';
  cJsonStrBom = #$EF#$BB#$BF;

{ The UTF-8 bytes of S: under FPC the string's own bytes, under Delphi its encoding. }
function JsonStrUtf8Bytes(const S: string): TBytes;
begin
  {$IFDEF FPC}
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
  {$ELSE}
  Result := TEncoding.UTF8.GetBytes(S);
  {$ENDIF}
end;

function JsonStrHex(const B: TBytes): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Length(B) - 1 do
    Result := Result + IntToHex(B[i], 2);
end;

{ A new memory stream that holds ABytes, at position 0. }
function JsonStrStream(const ABytes: TBytes): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  if Length(ABytes) > 0 then
    Result.WriteBuffer(ABytes[0], Length(ABytes));
  Result.Position := 0;
end;

{ The text between the quotes of a JSON string: one leading and one trailing quote dropped. }
function JsonStrInner(const AText: string): string;
begin
  Result := AText;
  if (Result <> '') and (Result[1] = '"') then
    Delete(Result, 1, 1);
  if (Result <> '') and (Result[Length(Result)] = '"') then
    Delete(Result, Length(Result), 1);
end;

procedure JsonStrFromJson(const AText: string);
begin
  try
    Line('fromjson ' + Esc(JSONStringToString(JsonStrInner(AText))));
  except
    on E: Exception do Raised(E);
  end;
end;

procedure JsonStrToJson(const AValue: string);
begin
  Line('tojson ' + Esc(StringToJSONString(AValue, False)));
  Line('tojson strict ' + Esc(StringToJSONString(AValue, True)));
end;

{ The tree, then tojson when the value is a string. }
procedure JsonStrTree(D: TJSONData);
begin
  JsonTree(D);
  if (D <> nil) and (D.JSONType = jtString) then
    JsonStrToJson(D.AsString);
end;

procedure JsonStrCaseEx(const AText: string; AFromJson: Boolean);
var
  d: TJSONData;
begin
  NextCase;
  Line('input ' + Esc(AText));
  try
    d := GetJSON(AText);
    try
      JsonStrTree(d);
    finally
      d.Free;
    end;
  except
    on E: Exception do Raised(E);
  end;
  if AFromJson then
    JsonStrFromJson(AText);
end;

procedure JsonStrCase(const AText: string);
begin
  JsonStrCaseEx(AText, True);
end;

{ Group 4: the characters one by one, then all of them, through StringToJSONString and back. }
procedure JsonStrControlCase;
const
  cChars: array[0..4] of string = (#$01, #$1F, #$7F, #$C2#$80, #$E2#$80#$A8);
var
  s, all: string;
  i: Integer;
  d: TJSONData;
begin
  NextCase;
  Line('input U+0001, U+001F, U+007F, U+0080, U+2028');
  all := '';
  for i := Low(cChars) to High(cChars) do
  begin
    s := 'a' + cChars[i] + 'b';
    Line('value ' + Esc(s));
    JsonStrToJson(s);
    all := all + s;
  end;
  Line('value ' + Esc(all));
  JsonStrToJson(all);
  d := TJSONString.Create(all);
  try
    Line('asjson ' + Esc(d.AsJSON));
  finally
    d.Free;
  end;
  d := GetJSON('"' + StringToJSONString(all) + '"');
  try
    if d.AsString = all then
      Line('read back same')
    else
      Line('read back differs ' + Esc(d.AsString));
  finally
    d.Free;
  end;
end;

{ Group 5: a string of 5000 UTF-16 units, 1250 times a, b, a quote and U+56FD (three bytes in UTF-8). }
procedure JsonStrLongCase;
var
  value, text: string;
  i: Integer;
  d: TJSONData;
begin
  NextCase;
  Line('input 1250 times a, b, \", U+56FD');
  value := '';
  text := '';
  for i := 1 to 1250 do
  begin
    value := value + 'ab"'#$E5#$9B#$BD;
    text := text + 'ab\"'#$E5#$9B#$BD;
  end;
  text := '"' + text + '"';
  Line('units ' + IntToStr(Length(TyJsUnits(value))));
  d := GetJSON(text);
  try
    Line('units read ' + IntToStr(Length(TyJsUnits(d.AsString))));
    if d.AsString = value then
      Line('value same')
    else
      Line('value differs');
    if d.AsJSON = text then
      Line('asjson same')
    else
      Line('asjson differs');
  finally
    d.Free;
  end;
  if StringToJSONString(value) = JsonStrInner(text) then
    Line('tojson same')
  else
    Line('tojson differs');
  if JSONStringToString(JsonStrInner(text)) = value then
    Line('fromjson same')
  else
    Line('fromjson differs');
end;

{ Groups 7 and 7b: informational, and always the same seven lines. }
procedure JsonStrInfoCase(const AText: string);
var
  d: TJSONData;
begin
  NextCase;
  GInfo := True;
  Line('input ' + Esc(AText));
  d := nil;
  try
    try
      d := GetJSON(AText);
      Line('parsed');
    except
      on E: Exception do Raised(E);
    end;
    if d = nil then
    begin
      Line('value -');
      Line('asjson -');
      Line('tojson -');
      Line('tojson strict -');
    end
    else
    begin
      Line('value ' + Esc(d.AsString));
      Line('asjson ' + Esc(d.AsJSON));
      JsonStrToJson(d.AsString);
    end;
  finally
    d.Free;
  end;
  JsonStrFromJson(AText);
end;

{ Group 8: TJSONParser.Create(TStream, AOptions) on the UTF-8 bytes of AText, after ABefore. }
procedure JsonStrStreamCase(const AWhat, ABefore, AText: string; AOptions: TJSONOptions);
var
  st: TMemoryStream;
  p: TJSONParser;
  d: TJSONData;
begin
  NextCase;
  Line('input ' + AWhat + ' ' + Esc(AText));
  st := JsonStrStream(JsonStrUtf8Bytes(ABefore + AText));
  try
    Line('bytes ' + IntToStr(st.Size));
    d := nil;
    p := TJSONParser.Create(st, AOptions);
    try
      try
        d := p.Parse;
        JsonStrTree(d);
      except
        on E: Exception do Raised(E);
      end;
    finally
      d.Free;
      p.Free;
    end;
  finally
    st.Free;
  end;
end;

{ Group 8: GetJSON(TStream); with ANoHandler, while the stream parser handler is unset. }
procedure JsonStrGetJsonStreamCase(const AText: string; ANoHandler: Boolean);
var
  st: TMemoryStream;
  d: TJSONData;
  old: TJSONParserHandler;
begin
  NextCase;
  if ANoHandler then
    Line('input GetJSON(TStream), no stream parser handler ' + Esc(AText))
  else
    Line('input GetJSON(TStream) ' + Esc(AText));
  st := JsonStrStream(JsonStrUtf8Bytes(AText));
  try
    old := nil;
    if ANoHandler then
      old := SetJSONParserHandler(nil);
    try
      d := nil;
      try
        try
          d := GetJSON(st);
          JsonStrTree(d);
        except
          on E: Exception do Raised(E);
        end;
      finally
        d.Free;
      end;
    finally
      if ANoHandler then
        SetJSONParserHandler(old);
    end;
    Line('position ' + IntToStr(st.Position));
  finally
    st.Free;
  end;
end;

{ Group 9 }
procedure JsonStrNoUtf8Case(const AText: string);
var
  d: TJSONData;
begin
  NextCase;
  Line('input GetJSON(text, False) ' + Esc(AText));
  try
    d := GetJSON(AText, False);
    try
      JsonStrTree(d);
    finally
      d.Free;
    end;
  except
    on E: Exception do Raised(E);
  end;
end;

{ DumpJSON writes UTF-8: the same bytes under FPC and Delphi. }
procedure JsonStrDumpCase(const AText: string);
var
  d: TJSONData;
  st: TMemoryStream;
  b: TBytes;
begin
  NextCase;
  Line('input DumpJSON ' + Esc(AText));
  d := GetJSON(AText);
  try
    st := TMemoryStream.Create;
    try
      d.DumpJSON(st);
      Line('bytes ' + IntToStr(st.Size));
      SetLength(b, st.Size);
      if st.Size > 0 then
        Move(st.Memory^, b[0], st.Size);
      Line('hex ' + JsonStrHex(b));
    finally
      st.Free;
    end;
  finally
    d.Free;
  end;
end;

procedure SectionJsonStr;
begin
  BeginSection('jsonstr');
  { 1 }
  JsonStrCase('"\" \\ \/ \b \f \n \r \t"');
  { 2 }
  JsonStrCaseEx('"\u0041\u56fd\u00e9"', False);
  JsonStrCase('"\ud83d\ude00"');
  JsonStrCase('"'#$F0#$9F#$98#$80'"');
  { 3 }
  JsonStrCase(cJsonStrText3);
  { 4 }
  JsonStrControlCase;
  { 5 }
  JsonStrCase('""');
  JsonStrCase('"\""');
  JsonStrLongCase;
  { 6 }
  JsonStrCase('"\x"');
  JsonStrCase('"\u12"');
  JsonStrCase('"abc');
  JsonStrCase('"a'#10'b"');
  { 7: informational }
  JsonStrInfoCase('"\ud83d"');
  JsonStrInfoCase('"\ude00"');
  JsonStrInfoCase('"\ud83dx"');
  { 7b: informational, FPC's defect }
  JsonStrInfoCase('"\u00f1\ud83d\ude00"');
  JsonStrInfoCase('"\u4e2d\ud83d\ude00"');
  JsonStrInfoCase('"\u4e2d\u6587\ud83d\ude00"');
  JsonStrInfoCase('"\u0041\u56fd\u00e9"');
  { 8 }
  JsonStrStreamCase('TJSONParser(TStream, [joUTF8])', '', cJsonStrText3, [joUTF8]);
  JsonStrStreamCase('TJSONParser(TStream, [])', '', cJsonStrText3, []);
  JsonStrStreamCase('TJSONParser(TStream, [joUTF8]) after a BOM', cJsonStrBom, cJsonStrText3, [joUTF8]);
  JsonStrStreamCase('TJSONParser(TStream, [joUTF8, joBOMCheck]) after a BOM', cJsonStrBom, cJsonStrText3,
    [joUTF8, joBOMCheck]);
  JsonStrGetJsonStreamCase(cJsonStrText3, False);
  JsonStrGetJsonStreamCase(cJsonStrText3, True);
  { 9 }
  JsonStrNoUtf8Case(cJsonStrText3);
  { DumpJSON }
  JsonStrDumpCase('{"'#$E5#$90#$8D'":["caf'#$C3#$A9'",1,"\u00f1x\ud83d\ude00"],"a\"b":{"'#$E2#$80#$A8'":null}}');
end;
