(* Section jsonx: the JSON inputs of the branch's final review, measured once under FPC, dcc32 and dcc64
  and kept here so that they stay measured. No line of this section is informational.

  The inputs by group (numbers of '== jsonx N'):
    -  1-14    characters whose low byte is an ASCII delimiter (U+4E0A, U+4E00, U+9500, U+0122, U+010A,
               U+015C, U+012F, U+011F, U+0108, U+0120, U+017D, U+0141) inside strings, outside them,
               after numbers and in comments; StringToJSONString and JSONStringToString of them
    -  15-62   number literals: lenient forms, integer classification at every boundary (Integer,
               Int64, QWord), invalid forms; printed as the number type and the integer, or the
               Double's 64 bits
    -  63-103  lenient and invalid syntax read by GetJSON
    -  104-132 TJSONParser with joComments and joIgnoreTrailingComma (comments in every place), with
               joStrict, and with no options
    -  133     one tree: FindPath and GetPath of 27 paths, FormatJSON with each option, the
               enumerators, CompressedJSON, UnquotedMemberNames, StrictEscaping, out-of-range and
               missing-member operations on objects and arrays, a rebuilt object, its member table
               grown to 100 and 50 of them deleted
    -  134     TJSONObject.Create and TJSONArray.Create with arrays of const (odd count, a number as
               a name, an empty name, a duplicate, a pointer, a class)
    -  135-141 TJSONString's AsInteger, AsInt64, AsFloat (the 64 bits) and AsBoolean of the plain shapes
               '12', ' 12', '12 ', '1.5', '$1F', '0x1F' and the empty string, where the port's
               conversions (the RTL's) and FPC's (Val) agree; fpjson's header names the shapes where
               they do not
  Left out, because they differ by ruling or by design (the review measured them): the float bits of
  123456789012345678901234567890 and 1E400 (float text, the numeric plan's; jsonnum pins them),
  '"<U+1F600>\ud83d"' (an unpaired surrogate, jsonstr 14-16), JSONStringToString of 'a\' + U+015C
  (jsonstr 33), TJSONString's conversions of other shapes ('%101', '&17', '2147483648', a leading tab,
  a trailing line feed, 'e5', 'Nan'). *)

const
  { U+4E0A U+4E00 U+9500 U+0122 U+010A U+015C U+012F U+011F U+0108 U+0120 U+017D U+0141 }
  cJsonXUp = #$E4#$B8#$8A;
  cJsonXOne = #$E4#$B8#$80;
  cJsonXXiao = #$E9#$94#$80;
  cJsonXG = #$C4#$A2;
  cJsonXC = #$C4#$8A;
  cJsonXS = #$C5#$9C;
  cJsonXI = #$C4#$AF;
  cJsonXGb = #$C4#$9F;
  cJsonXCc = #$C4#$88;
  cJsonXGd = #$C4#$A0;
  cJsonXZ = #$C5#$BD;
  cJsonXL = #$C5#$81;
  { U+00E9 }
  cJsonXEAcute = #$C3#$A9;

{ TJSONParser.Create(AText, AOptions).Parse: the tree and AsJSON, 'nil', or the exception. }
procedure JsonXParserCase(const AText: string; AOptions: TJSONOptions);
var
  p: TJSONParser;
  d: TJSONData;
begin
  NextCase;
  Line('input ' + Esc(AText));
  d := nil;
  p := TJSONParser.Create(AText, AOptions);
  try
    try
      d := p.Parse;
    except
      on E: Exception do
      begin
        Raised(E);
        Exit;
      end;
    end;
    if d = nil then
      Line('nil')
    else
    begin
      JsonDump(d);
      Line('asjson ' + Esc(d.AsJSON));
    end;
  finally
    d.Free;
    p.Free;
  end;
end;

{ A number literal read by GetJSON: its number type and value (a float as its 64 bits). }
procedure JsonXNumCase(const AText: string);
var
  d: TJSONData;
  i64: Int64;
  f: Double;
begin
  NextCase;
  Line('input ' + Esc(AText));
  try
    d := GetJSON(AText);
  except
    on E: Exception do
    begin
      Raised(E);
      Exit;
    end;
  end;
  try
    if d = nil then
    begin
      Line('nil');
      Exit;
    end;
    if d.JSONType <> jtNumber then
    begin
      Line('not a number');
      JsonDump(d);
      Exit;
    end;
    case TJSONNumber(d).NumberType of
      ntInteger: Line('int ' + IntToStr(d.AsInteger));
      ntInt64: Line('int64 ' + IntToStr(d.AsInt64));
      ntQWord: Line('qword ' + UIntToStr(d.AsQWord));
    else
      begin
        f := d.AsFloat;
        Move(f, i64, 8);
        Line('float ' + IntToHex(i64, 16));
      end;
    end;
  finally
    d.Free;
  end;
end;

procedure JsonXPathCase(D: TJSONData; const APath: string);
var
  r: TJSONData;
begin
  try
    r := D.FindPath(APath);
    Line('findpath ' + Esc(APath) + ' -> ' + JsonDataText(r));
  except
    on E: Exception do Line('findpath ' + Esc(APath) + ' raises ' + E.ClassName);
  end;
  try
    r := D.GetPath(APath);
    Line('getpath ' + Esc(APath) + ' -> ' + JsonDataText(r));
  except
    on E: Exception do Line('getpath ' + Esc(APath) + ' raises ' + E.ClassName);
  end;
end;

procedure JsonXFormatCase(D: TJSONData; const AWhat: string; AOptions: TFormatOptions; AIndent: Integer);
begin
  Line('format ' + AWhat);
  JsonFormatLines(D.FormatJSON(AOptions, AIndent));
end;

procedure JsonXEnumCase(D: TJSONData);
var
  e: TJSONEnum;
begin
  for e in D do
    Line('enum key ' + Esc(e.Key) + ' num ' + IntToStr(e.KeyNum) + ' value ' + JsonDataText(e.Value));
end;

{ Group 133: one tree and the operations on it. }
procedure JsonXOpsCase;
var
  d, r: TJSONData;
  o: TJSONObject;
  a: TJSONArray;
  i: Integer;
  s: string;
begin
  NextCase;
  { through a string variable: FPC would convert a constant argument of GetJSON at compile time }
  s := '{"a":{"b":[1,{"c":"x"},[2,3]],"' + cJsonXUp + '":[5]},"":7,"a.b":8,"n":null}';
  d := GetJSON(s);
  try
    JsonXPathCase(d, 'a.b[1].c');
    JsonXPathCase(d, 'a.b[2][1]');
    JsonXPathCase(d, '');
    JsonXPathCase(d, '.a');
    JsonXPathCase(d, 'a..b');
    JsonXPathCase(d, 'a[');
    JsonXPathCase(d, 'a.b[x]');
    JsonXPathCase(d, 'a.b[-1]');
    JsonXPathCase(d, 'a.b[99]');
    JsonXPathCase(d, 'a.z');
    JsonXPathCase(d, 'a.' + cJsonXUp + '[0]');
    JsonXPathCase(d, 'a.b[1]');
    JsonXPathCase(d, 'a.b.[1]');
    JsonXPathCase(d, 'a.b[1]c');
    JsonXPathCase(d, 'n.x');
    JsonXPathCase(d, 'a.b[0].x');
    JsonXPathCase(d, 'a.b[ 1 ]');
    JsonXPathCase(d, 'A');
    JsonXPathCase(d, 'a.b[1].c.');
    JsonXPathCase(d, 'a.b[]');
    JsonXPathCase(d, '[0]');
    JsonXPathCase(d, 'a.b[1');
    JsonXPathCase(d, 'a.b[1e0]');
    JsonXPathCase(d, 'a.b[$1]');
    JsonXPathCase(d, 'a.b[0x1]');
    JsonXPathCase(d, 'a.b[+1]');
    JsonXPathCase(d, 'a.b[ 1]');
    JsonXFormatCase(d, 'default', DefaultFormat, DefaultIndentSize);
    JsonXFormatCase(d, 'singlelinearray', [foSingleLineArray], 2);
    JsonXFormatCase(d, 'singlelineobject', [foSingleLineObject], 2);
    JsonXFormatCase(d, 'donotquote', [foDoNotQuoteMembers], 2);
    JsonXFormatCase(d, 'tabchar', [foUseTabchar], 1);
    JsonXFormatCase(d, 'skipws', [foSkipWhiteSpace], 2);
    JsonXFormatCase(d, 'skipws leading', [foSkipWhiteSpace, foSkipWhiteSpaceOnlyLeading], 2);
    JsonXFormatCase(d, 'all single skip', [foSingleLineArray, foSingleLineObject, foSkipWhiteSpace], 0);
    JsonXFormatCase(d, 'indent 0', [], 0);
    JsonXEnumCase(d);
    JsonXEnumCase(TJSONObject(d).Objects['a'].Arrays['b']);
    JsonXEnumCase(TJSONObject(d).Find('n'));
    Line('count of null ' + IntToStr(TJSONObject(d).Find('n').Count));
    try
      r := TJSONObject(d).Find('n').Items[0];
      Line('items[0] of null ' + JsonDataText(r));
    except
      on E: Exception do Raised(E);
    end;
    TJSONData.CompressedJSON := True;
    Line('compressed ' + Esc(d.AsJSON));
    TJSONData.CompressedJSON := False;
    TJSONObject.UnquotedMemberNames := True;
    Line('unquoted ' + Esc(d.AsJSON));
    TJSONObject.UnquotedMemberNames := False;
    TJSONString.StrictEscaping := True;
    r := TJSONString.Create('a/b');
    Line('strictescaping ' + Esc(r.AsJSON));
    r.Free;
    TJSONString.StrictEscaping := False;
    o := TJSONObject(d);
    try o.Add('a', 1); Line('add dup ok'); except on E: Exception do Raised(E); end;
    try r := o.Elements['zz']; Line('elements missing ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try o.Delete(99); Line('delete 99 ok'); except on E: Exception do Raised(E); end;
    try o.Delete(-1); Line('delete -1 ok'); except on E: Exception do Raised(E); end;
    try Line('names[-1] ' + Esc(o.Names[-1])); except on E: Exception do Raised(E); end;
    try Line('names[99] ' + Esc(o.Names[99])); except on E: Exception do Raised(E); end;
    try r := o.Items[99]; Line('items[99] ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try r := o.Extract('zz'); Line('extract missing ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try r := o.Extract(99); Line('extract 99 ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try o.Delete('zz'); Line('delete missing name ok'); except on E: Exception do Raised(E); end;
    Line('indexofname ci ' + IntToStr(o.IndexOfName('A.B', True)) + ' ' + IntToStr(o.IndexOfName('A.B', False))
      + ' ' + IntToStr(o.IndexOfName('N', True)));
    try
      Line('get int default ' + IntToStr(o.Get('zz', 5)) + ' ' + IntToStr(o.Get('', 5)) + ' '
        + IntToStr(o.Get('n', 5)));
    except
      on E: Exception do Raised(E);
    end;
    try
      Line('get str default ' + Esc(o.Get('zz', 'dflt')) + ' ' + Esc(o.Get('a.b', 'dflt')));
    except
      on E: Exception do Raised(E);
    end;
    try Line('integers[a] ' + IntToStr(o.Integers['a'])); except on E: Exception do Raised(E); end;
    try Line('strings[a.b] ' + Esc(o.Strings['a.b'])); except on E: Exception do Raised(E); end;
    try Line('strings[n] ' + Esc(o.Strings['n'])); except on E: Exception do Raised(E); end;
    try Line('arrays[n] ' + JsonDataText(o.Arrays['n'])); except on E: Exception do Raised(E); end;
    try
      Line('nulls ' + BoolToStr(o.Nulls['n'], True) + ' ' + BoolToStr(o.Nulls['a'], True));
    except
      on E: Exception do Raised(E);
    end;
    a := o.Objects['a'].Arrays['b'];
    try a.Delete(99); Line('arr delete 99 ok'); except on E: Exception do Raised(E); end;
    try r := a.Items[99]; Line('arr items[99] ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try r := a.Items[-1]; Line('arr items[-1] ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try a.Insert(99, 5); Line('arr insert 99 ok'); except on E: Exception do Raised(E); end;
    try a.Exchange(0, 99); Line('arr exchange 99 ok'); except on E: Exception do Raised(E); end;
    try a.Move(0, 99); Line('arr move 99 ok'); except on E: Exception do Raised(E); end;
    try r := a.Extract(99); Line('arr extract 99 ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try r := a.Extract(d); Line('arr extract foreign ' + JsonDataText(r)); except on E: Exception do Raised(E); end;
    try a.Remove(d); Line('arr remove foreign ok'); except on E: Exception do Raised(E); end;
    try Line('arr indexof foreign ' + IntToStr(a.IndexOf(d))); except on E: Exception do Raised(E); end;
    try Line('arr strings[0] ' + Esc(a.Strings[0])); except on E: Exception do Raised(E); end;
    try Line('arr integers[1] ' + IntToStr(a.Integers[1])); except on E: Exception do Raised(E); end;
    try Line('arr objects[0] ' + JsonDataText(a.Objects[0])); except on E: Exception do Raised(E); end;
    a.Add('s');
    a.Add(Int64(5000000000));
    a.Add(True);
    a.Add;
    a.Add(TJSONArray.Create);
    a.Insert(0);
    a.Insert(1, 'i');
    a.Insert(2, TJSONObject.Create);
    a.Exchange(0, 1);
    a.Move(0, 3);
    Line('after ops ' + Esc(d.AsJSON));
    o.Clear;
    Line('after clear ' + Esc(d.AsJSON) + ' ' + IntToStr(o.Count));
    o.Add('x', 1);
    o.Add('y', 'v');
    o.Add('z');
    o.Add('w', TJSONArray.Create([1, 'ab', 'c', True, nil]));
    o.Add('big', Int64(5000000000));
    o.Add('b', False);
    o.Delete(1);
    o.Add('y', 2);
    o.Integers['x'] := 9;
    o.Strings['new'] := 'n';
    o.Booleans['b'] := True;
    o.Nulls['z'] := True;
    o.Arrays['arr'] := TJSONArray.Create;
    o.Objects['obj'] := TJSONObject.Create(['k', 'v', 'k2', 5]);
    Line('after rebuild ' + Esc(d.AsJSON));
    for i := 0 to o.Count - 1 do
      Line('name ' + IntToStr(i) + ' ' + Esc(o.Names[i]) + ' idx ' + IntToStr(o.IndexOfName(o.Names[i])));
    for i := 1 to 100 do
      o.Add('k' + IntToStr(i), i);
    for i := 1 to 50 do
      o.Delete('k' + IntToStr(i * 2));
    s := '';
    for i := 0 to o.Count - 1 do
      if o.IndexOfName(o.Names[i]) <> i then
        s := s + ' ' + IntToStr(i);
    Line('after grow/delete count ' + IntToStr(o.Count) + ' bad' + s + ' k99 ' + JsonDataText(o.Find('k99'))
      + ' k98 ' + JsonDataText(o.Find('k98')));
  finally
    d.Free;
  end;
end;

{ Group 134: constructors with arrays of const. }
procedure JsonXCreateCase;
var
  o: TJSONObject;
  a: TJSONArray;
begin
  NextCase;
  try
    o := TJSONObject.Create(['a', 1, 'bc', 'x', 'd', 'y', 'e', True, 'f', nil, 'g', Int64(5000000000), 'h',
      TJSONArray.Create]);
    Line('create ' + Esc(o.AsJSON));
    o.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    o := TJSONObject.Create(['a']);
    Line('create odd ' + Esc(o.AsJSON));
    o.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    o := TJSONObject.Create([1, 2]);
    Line('create int name ' + Esc(o.AsJSON));
    o.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    o := TJSONObject.Create(['', 2]);
    Line('create empty name ' + Esc(o.AsJSON));
    o.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    o := TJSONObject.Create(['a', 1, 'a', 2]);
    Line('create dup ' + Esc(o.AsJSON));
    o.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    a := TJSONArray.Create(['a', 'bc', 1, True, nil, 3000000000, cJsonXUp, cJsonXUp + cJsonXOne]);
    Line('create array ' + Esc(a.AsJSON));
    a.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    a := TJSONArray.Create([Pointer(@GCase)]);
    Line('create array ptr ' + Esc(a.AsJSON));
    a.Free;
  except
    on E: Exception do Raised(E);
  end;
  try
    a := TJSONArray.Create([TObject(nil), TStringList]);
    Line('create array class ' + Esc(a.AsJSON));
    a.Free;
  except
    on E: Exception do Raised(E);
  end;
end;

{ Group 135-141: a TJSONString's conversions. }
procedure JsonXStrConvCase(const AValue: string);
var
  s: TJSONString;
  f: Double;
  i64: Int64;
begin
  NextCase;
  Line('value ' + Esc(AValue));
  s := TJSONString.Create(AValue);
  try
    try Line('asinteger ' + IntToStr(s.AsInteger)); except on E: Exception do Raised(E); end;
    try Line('asint64 ' + IntToStr(s.AsInt64)); except on E: Exception do Raised(E); end;
    try
      f := s.AsFloat;
      Move(f, i64, 8);
      Line('asfloat ' + IntToHex(i64, 16));
    except
      on E: Exception do Raised(E);
    end;
    try
      if s.AsBoolean then
        Line('asboolean true')
      else
        Line('asboolean false');
    except
      on E: Exception do Raised(E);
    end;
  finally
    s.Free;
  end;
end;

procedure SectionJsonX;
const
  cCommentOpts: TJSONOptions = [joUTF8, joComments, joIgnoreTrailingComma];
  cStrictOpts: TJSONOptions = [joUTF8, joStrict];
begin
  BeginSection('jsonx');
  { 1-14: characters whose low byte is an ASCII delimiter }
  JsonCase('{"' + cJsonXUp + '":"' + cJsonXOne + cJsonXXiao + '","' + cJsonXG + '":"' + cJsonXC + cJsonXS + cJsonXI
    + cJsonXGb + cJsonXCc + cJsonXGd + cJsonXZ + cJsonXL + '"}');
  JsonCase('[' + cJsonXUp + ']');
  JsonCase('[1' + cJsonXUp + ']');
  JsonCase('[1' + cJsonXC + ']');
  JsonCase('[1' + cJsonXGd + ']');
  JsonCase('[1' + cJsonXZ + ']');
  JsonCase('[true' + cJsonXL + ']');
  JsonCase('[1,' + cJsonXGd + '2]');
  JsonCase('{"a' + cJsonXC + 'b":1}');
  JsonXParserCase('/* ' + cJsonXUp + cJsonXC + cJsonXOne + ' */ [1]', cCommentOpts);
  JsonXParserCase('// ' + cJsonXOne + cJsonXC + ' [2]'#10'[1]', cCommentOpts);
  JsonXParserCase('["' + cJsonXOne + '",' + cJsonXXiao + ']', cCommentOpts);
  NextCase;
  JsonStrToJson(cJsonXUp + cJsonXOne + cJsonXXiao + cJsonXG + cJsonXC + cJsonXS + cJsonXI + cJsonXGb + cJsonXCc
    + cJsonXGd + cJsonXZ + cJsonXL + '/"\'#127#$C2#$80#$E2#$80#$A8);
  NextCase;
  JsonStrFromJson('"' + cJsonXUp + '\n' + cJsonXS + '\\' + cJsonXG + '\"' + cJsonXOne + '"');
  JsonStrFromJson('"\u12"');
  JsonStrFromJson('"\u"');
  JsonStrFromJson('"\"');
  JsonStrFromJson('"\x41"');
  JsonStrFromJson('"\/\b\f"');
  JsonStrFromJson('"' + cJsonXEAcute + cJsonXUp + cJsonXUp + '"');
  { 15-62: number literals }
  JsonXNumCase('.5');
  JsonXNumCase('-.5');
  JsonXNumCase('5.e3');
  JsonXNumCase('1.e+2');
  JsonXNumCase('-0');
  JsonXNumCase('007');
  JsonXNumCase('0007.5');
  JsonXNumCase('00');
  JsonXNumCase('1E5');
  JsonXNumCase('1e+5');
  JsonXNumCase('1e-5');
  JsonXNumCase('18446744073709551616');
  JsonXNumCase('184467440737095516150');
  JsonXNumCase('-9223372036854775808');
  JsonXNumCase('-9223372036854775809');
  JsonXNumCase('2147483648');
  JsonXNumCase('-2147483647');
  JsonXNumCase('-2147483648');
  JsonXNumCase('1.0');
  JsonXNumCase('-');
  JsonXNumCase('+1');
  JsonXNumCase('1e');
  JsonXNumCase('1e+');
  JsonXNumCase('0x10');
  JsonXNumCase('1.');
  JsonXNumCase('-.');
  JsonXNumCase('.');
  JsonXNumCase('1.5.2');
  JsonXNumCase('1e5e2');
  JsonXNumCase('- 1');
  JsonXNumCase('1_000');
  JsonXNumCase('01');
  JsonXNumCase('-01');
  JsonXNumCase('0.0');
  JsonXNumCase('-0.0e0');
  JsonXNumCase('NaN');
  JsonXNumCase('Infinity');
  JsonXNumCase('-Infinity');
  JsonXNumCase('4294967295');
  JsonXNumCase('4294967296');
  JsonXNumCase('9223372036854775807');
  JsonXNumCase('09223372036854775808');
  JsonXNumCase('000000000000000000000000001');
  JsonXNumCase('99999999999999999999');
  JsonXNumCase('1e2');
  JsonXNumCase('100e-2');
  JsonXNumCase(' 12 ');
  JsonXNumCase(#9'12'#13#10);
  { 63-103: lenient and invalid syntax }
  JsonCase('{a:1}');
  JsonCase('{a b:1}');
  JsonCase('[tRuE,NULL,False]');
  JsonCase('[truex]');
  JsonCase('[nul]');
  JsonCase('{''a'':''b''}');
  JsonCase('[1,,2]');
  JsonCase('[,]');
  JsonCase('{,}');
  JsonCase('{"a":1,,}');
  JsonCase('[1,]');
  JsonCase('{"a":1,}');
  JsonCase('"a" "b"');
  JsonCase('1 2');
  JsonCase(' ');
  JsonCase('[1]//c');
  JsonCase('"a'#9'b"');
  JsonCase('''a\''b''');
  JsonCase('"\a"');
  JsonCase('"\U0041"');
  JsonCase(#$EF#$BB#$BF'[1]');
  JsonCase('[1]'#0'[2]');
  JsonCase('{"a":1 "b":2}');
  JsonCase('{"a" 1}');
  JsonCase('{1:2}');
  JsonCase('{"a":}');
  JsonCase('[}');
  JsonCase('{]');
  JsonCase('{"a":[1,{"b":2}]');
  JsonCase('nulll');
  JsonCase('True');
  JsonCase('[true false]');
  JsonCase('{"a":1}{"b":2}');
  JsonCase('[1]]');
  JsonCase('{"a":{"a":{"a":{"a":[[[[{"a":null}]]]]}}}}');
  JsonCase('undefined');
  JsonCase('{"a":undefined}');
  JsonCase('[-]');
  JsonCase('[+1]');
  JsonCase('[.5]');
  JsonCase('{"__proto__":1,"constructor":2}');
  { 104-132: parser options }
  JsonXParserCase('{a:1,''b'':2,}', cCommentOpts);
  JsonXParserCase('[1,2,,]', cCommentOpts);
  JsonXParserCase('[,]', cCommentOpts);
  JsonXParserCase('{,}', cCommentOpts);
  JsonXParserCase('/**/[1]', cCommentOpts);
  JsonXParserCase('/*', cCommentOpts);
  JsonXParserCase('/*/', cCommentOpts);
  JsonXParserCase('[1] /* a */ /* b */', cCommentOpts);
  JsonXParserCase('{"a":/*c*/1}', cCommentOpts);
  JsonXParserCase('{/*c*/"a":1}', cCommentOpts);
  JsonXParserCase('[/*c*/]', cCommentOpts);
  JsonXParserCase('[1/*c*/,2]', cCommentOpts);
  JsonXParserCase('{"a"/*c*/:1}', cCommentOpts);
  JsonXParserCase('[1] // x', cCommentOpts);
  JsonXParserCase('// only', cCommentOpts);
  JsonXParserCase('/* a'#13#10' b */[1]', cCommentOpts);
  JsonXParserCase('[1] /* a', cCommentOpts);
  JsonXParserCase('{a:1}', cStrictOpts);
  JsonXParserCase('{''a'':1}', cStrictOpts);
  JsonXParserCase('[01]', cStrictOpts);
  JsonXParserCase('[.5]', cStrictOpts);
  JsonXParserCase('[1.]', cStrictOpts);
  JsonXParserCase('["a'#9'b"]', cStrictOpts);
  JsonXParserCase('[TRUE]', cStrictOpts);
  JsonXParserCase('[1,]', cStrictOpts);
  JsonXParserCase('[1]//c', cStrictOpts);
  JsonXParserCase('', cStrictOpts);
  JsonXParserCase('[1]', []);
  JsonXParserCase('{"' + cJsonXUp + '":"' + cJsonXUp + '"}', []);
  { 133-134 }
  JsonXOpsCase;
  JsonXCreateCase;
  { 135-141 }
  JsonXStrConvCase('12');
  JsonXStrConvCase(' 12');
  JsonXStrConvCase('12 ');
  JsonXStrConvCase('1.5');
  JsonXStrConvCase('$1F');
  JsonXStrConvCase('0x1F');
  JsonXStrConvCase('');
end;
