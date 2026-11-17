(* Section json: the structure of fpjson's trees (objects, arrays, strings, booleans, null, integers; no
  floating-point numbers here). Every text input is read with GetJSON, then
  - the tree: 'object N' and per member 'key <name>' and the value, 'array N' and the elements,
    'string <text>', 'true' / 'false', 'null', 'int N' / 'int64 N' / 'qword N' by NumberType;
  - 'asjson <AsJSON>', then 'formatjson' and one '| <line>' per line of FormatJSON;
  - for every object of the tree (depth first, a parent before its members), on clones: Find of its first
    name and of a missing one, IndexOfName, Names[0], whether a Clone gives the same AsJSON, Count and
    Names[0] after Delete(0), Extract by name and by index.

  The inputs by group of the plan (numbers of '== json N'):
    1  1-6     {}, [], null, true, "x", 0
    2  7       nested object and array
    3  8       member order z, a, m
    4  9       non-ASCII keys
    5  10      empty key, a key of one blank, a key with an escaped quote
    6  11      a duplicate key
    7  12-13   a key of 300 characters, two keys that differ at the 280th character (informational:
               FPC's member names are short strings; the same number of lines, whatever the outcome)
    8  14-21   integers at the bounds of Integer, Int64, QWord; -0; 007
    9  22-29   invalid inputs
    10 30-31   TJSONParser with the options of the chart's Option unit
    11 32      200 nested arrays
    12 33-35   trees built by code: TJSONObject.Create(array of const), Add, Remove; TJSONArray's Insert,
               Move, Remove, Extract, Delete and Sort; an object's members replaced through Elements[],
               Strings[] and Integers[], Get with a default, FindPath, Delete(name), Clear *)

{ 'nil', or the value as AsJSON. }
function JsonDataText(D: TJSONData): string;
begin
  if D = nil then
    Result := 'nil'
  else
    Result := Esc(D.AsJSON);
end;

procedure JsonDump(D: TJSONData);
var
  i: Integer;
begin
  case D.JSONType of
    jtObject:
      begin
        Line('object ' + IntToStr(D.Count));
        for i := 0 to D.Count - 1 do
        begin
          Line('key ' + Esc(TJSONObject(D).Names[i]));
          JsonDump(D.Items[i]);
        end;
      end;
    jtArray:
      begin
        Line('array ' + IntToStr(D.Count));
        for i := 0 to D.Count - 1 do
          JsonDump(D.Items[i]);
      end;
    jtString:
      Line('string ' + Esc(D.AsString));
    jtBoolean:
      if D.AsBoolean then
        Line('true')
      else
        Line('false');
    jtNull:
      Line('null');
    jtNumber:
      case TJSONNumber(D).NumberType of
        ntInteger: Line('int ' + IntToStr(D.AsInteger));
        ntInt64: Line('int64 ' + IntToStr(D.AsInt64));
        ntQWord: Line('qword ' + UIntToStr(D.AsQWord));
      else
        Line('float ' + Esc(D.AsJSON));
      end;
  else
    Line('unknown');
  end;
end;

procedure JsonFormatLines(const S: string);
var
  rest: string;
  p: Integer;
begin
  Line('formatjson');
  rest := S;
  repeat
    p := Pos(sLineBreak, rest);
    if p = 0 then
    begin
      Line('| ' + Esc(rest));
      Break;
    end;
    Line('| ' + Esc(Copy(rest, 1, p - 1)));
    Delete(rest, 1, p + Length(sLineBreak) - 1);
  until False;
end;

procedure JsonCheckObject(O: TJSONObject);
const
  cMissing = 'no such key';
var
  c: TJSONObject;
  x: TJSONData;
  first, last: string;
begin
  Line('checks object ' + IntToStr(O.Count));
  if O.Count > 0 then
  begin
    first := O.Names[0];
    Line('find first ' + JsonDataText(O.Find(first)));
    Line('indexofname first ' + IntToStr(O.IndexOfName(first)));
    last := O.Names[O.Count - 1];
    Line('indexofname last ' + IntToStr(O.IndexOfName(last)));
  end;
  Line('find missing ' + JsonDataText(O.Find(cMissing)));
  Line('indexofname missing ' + IntToStr(O.IndexOfName(cMissing)));
  try
    Line('names[0] ' + Esc(O.Names[0]));
  except
    on E: Exception do Raised(E);
  end;
  c := O.Clone as TJSONObject;
  try
    if c.AsJSON = O.AsJSON then
      Line('clone same')
    else
      Line('clone differs ' + Esc(c.AsJSON));
    try
      c.Delete(0);
      Line('delete(0) count ' + IntToStr(c.Count));
    except
      on E: Exception do Raised(E);
    end;
    try
      Line('delete(0) names[0] ' + Esc(c.Names[0]));
    except
      on E: Exception do Raised(E);
    end;
  finally
    c.Free;
  end;
  c := O.Clone as TJSONObject;
  try
    if c.Count > 0 then
    begin
      last := c.Names[c.Count - 1];
      x := c.Extract(last);
      Line('extract last ' + JsonDataText(x) + ' count ' + IntToStr(c.Count));
      x.Free;
    end;
    x := c.Extract(cMissing);
    Line('extract missing ' + JsonDataText(x));
    try
      x := c.Extract(0);
      Line('extract(0) ' + JsonDataText(x) + ' count ' + IntToStr(c.Count) + ' ' + Esc(c.AsJSON));
      x.Free;
    except
      on E: Exception do Raised(E);
    end;
  finally
    c.Free;
  end;
end;

procedure JsonCheckObjects(D: TJSONData);
var
  i: Integer;
begin
  if D.JSONType = jtObject then
    JsonCheckObject(TJSONObject(D));
  if D.JSONType in [jtObject, jtArray] then
    for i := 0 to D.Count - 1 do
      JsonCheckObjects(D.Items[i]);
end;

{ Everything the section prints about one tree. }
procedure JsonTree(D: TJSONData);
begin
  if D = nil then
  begin
    Line('nil');
    Exit;
  end;
  JsonDump(D);
  Line('asjson ' + Esc(D.AsJSON));
  JsonFormatLines(D.FormatJSON);
  JsonCheckObjects(D);
end;

procedure JsonText(const AText: string);
var
  d: TJSONData;
begin
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
    JsonTree(d);
  finally
    d.Free;
  end;
end;

procedure JsonCase(const AText: string);
begin
  NextCase;
  JsonText(AText);
end;

procedure JsonParserCase(const AText: string);
var
  p: TJSONParser;
  d: TJSONData;
begin
  NextCase;
  Line('input ' + Esc(AText));
  d := nil;
  p := TJSONParser.Create(AText, [joUTF8, joComments, joIgnoreTrailingComma]);
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
    JsonTree(d);
  finally
    d.Free;
    p.Free;
  end;
end;

{ Group 7: one object with the member AKey1 = 1, and AKey2 = 2 unless AKey2 is ''. Informational, and
  always the same seven lines, so that the lines after it stay in step whatever FPC and Delphi make of it. }
procedure JsonLongKeysCase(const AKey1, AKey2: string);
var
  text, lens: string;
  d: TJSONData;
  i: Integer;
begin
  NextCase;
  GInfo := True;
  text := '{"' + AKey1 + '":1';
  if AKey2 <> '' then
    text := text + ',"' + AKey2 + '":2';
  text := text + '}';
  Line('input ' + Esc(text));
  try
    d := GetJSON(text);
  except
    on E: Exception do
    begin
      Raised(E);
      Line('count -');
      Line('name lengths -');
      Line('find key 1 -');
      Line('find key 2 -');
      Line('asjson -');
      Exit;
    end;
  end;
  try
    Line('parsed');
    Line('count ' + IntToStr(d.Count));
    lens := '';
    for i := 0 to d.Count - 1 do
      lens := lens + ' ' + IntToStr(Length(TJSONObject(d).Names[i]));
    Line('name lengths' + lens);
    Line('find key 1 ' + JsonDataText(TJSONObject(d).Find(AKey1)));
    Line('find key 2 ' + JsonDataText(TJSONObject(d).Find(AKey2)));
    Line('asjson ' + Esc(d.AsJSON));
  finally
    d.Free;
  end;
end;

{ Orders strings by their first character only, so that the order of ties shows. }
function JsonCompareFirstChar(Item1, Item2: Pointer): Integer;
begin
  Result := Ord(TJSONData(Item1).AsString[1]) - Ord(TJSONData(Item2).AsString[1]);
end;

procedure JsonBuiltObject;
var
  o: TJSONObject;
begin
  NextCase;
  Line('input TJSONObject.Create([a, 1, b, x]), Add, Remove');
  o := TJSONObject.Create(['a', 1, 'b', 'x']);
  try
    JsonDump(o);
    o.Add('c', TJSONArray.Create([1, 'two', True]));
    o.Add('d', True);
    o.Add('e', 'str');
    o.Add('f', Int64(5000000000));
    o.Add('n');
    Line('add count ' + IntToStr(o.Count));
    try
      o.Add('a', 5);
    except
      on E: Exception do Raised(E);
    end;
    Line('after duplicate count ' + IntToStr(o.Count));
    o.Remove(o.Find('b'));
    Line('remove b count ' + IntToStr(o.Count));
    JsonTree(o);
  finally
    o.Free;
  end;
end;

procedure JsonBuiltArray;
var
  a: TJSONArray;
  x: TJSONData;
begin
  NextCase;
  Line('input TJSONArray: Insert, Add, Move, Remove, Extract, Delete, Sort');
  a := TJSONArray.Create(['b1', 'a1', 'b2', 'a2', 'a3', 'b3', 'c1']);
  try
    JsonDump(a);
    a.Insert(0, 'z0');
    a.Insert(2, 'y0');
    a.Add('x0');
    Line('insert ' + Esc(a.AsJSON));
    a.Move(0, 3);
    Line('move(0, 3) ' + Esc(a.AsJSON));
    a.Move(5, 1);
    Line('move(5, 1) ' + Esc(a.AsJSON));
    a.Remove(a.Items[1]);
    Line('remove items[1] ' + Esc(a.AsJSON));
    x := a.Extract(0);
    Line('extract(0) ' + JsonDataText(x) + ' ' + Esc(a.AsJSON));
    x.Free;
    x := a.Extract(a.Items[a.Count - 1]);
    Line('extract(last item) ' + JsonDataText(x) + ' ' + Esc(a.AsJSON));
    x.Free;
    a.Delete(0);
    Line('delete(0) ' + Esc(a.AsJSON));
    a.Sort(JsonCompareFirstChar);
    Line('sort ' + Esc(a.AsJSON));
    a.Add('a9');
    a.Add('b9');
    a.Insert(0, 'b0');
    a.Insert(0, 'a0');
    a.Sort(JsonCompareFirstChar);
    Line('sort again ' + Esc(a.AsJSON));
    JsonTree(a);
  finally
    a.Free;
  end;
end;

{ The object's member table owns the values: setting a member through Elements[], Strings[] or Integers[]
  frees the value it had, Delete and Clear free theirs; Get with a default; FindPath. }
procedure JsonBuiltObjectMembers;
var
  o: TJSONObject;
  defText: TJSONStringType;
  defInt: Integer;
begin
  NextCase;
  Line('input TJSONObject: Elements[], Strings[], Integers[], Get, FindPath, Delete(name), Clear');
  o := TJSONObject(GetJSON('{"a":[1,2],"b":"x","c":{"d":true},"p":{"b":[10,20,30]}}'));
  try
    JsonDump(o);
    o.Elements['a'] := TJSONString.Create('was an array');
    Line('elements[a] ' + Esc(o.AsJSON));
    o.Strings['c'] := 'was an object';
    Line('strings[c] ' + Esc(o.AsJSON));
    o.Integers['b'] := 7;
    Line('integers[b] ' + Esc(o.AsJSON));
    o.Integers['n'] := 8;
    Line('integers[n] ' + Esc(o.AsJSON));
    JsonDump(o);
    defInt := -1;
    defText := 'none';
    Line('get b ' + IntToStr(o.Get('b', defInt)));
    Line('get missing ' + IntToStr(o.Get('missing', defInt)));
    Line('get a ' + Esc(o.Get('a', defText)));
    Line('get missing ' + Esc(o.Get('missing', defText)));
    Line('findpath p.b[1] ' + JsonDataText(o.FindPath('p.b[1]')));
    Line('findpath p ' + JsonDataText(o.FindPath('p')));
    Line('findpath p.b[3] ' + JsonDataText(o.FindPath('p.b[3]')));
    Line('findpath p.x.y ' + JsonDataText(o.FindPath('p.x.y')));
    o.Delete('c');
    Line('delete(c) ' + IntToStr(o.Count) + ' ' + Esc(o.AsJSON));
    o.Delete('missing');
    Line('delete(missing) ' + IntToStr(o.Count));
    o.Clear;
    Line('clear ' + IntToStr(o.Count) + ' ' + Esc(o.AsJSON));
    o.Add('e', 1);
    JsonTree(o);
  finally
    o.Free;
  end;
end;

procedure SectionJson;
begin
  BeginSection('json');
  { 1 }
  JsonCase('{}');
  JsonCase('[]');
  JsonCase('null');
  JsonCase('true');
  JsonCase('"x"');
  JsonCase('0');
  { 2 }
  JsonCase('{"a":1,"b":[1,2,{"c":null}],"d":{"e":"f"}}');
  { 3 }
  JsonCase('{"z":1,"a":2,"m":3}');
  { 4 }
  JsonCase('{"'#$E9#$94#$80#$E9#$87#$8F'":[5,20],"'#$E5#$90#$8D#$E7#$A7#$B0'":"'#$E8#$A1#$AC#$E8#$A1#$AB'"}');
  { 5 }
  JsonCase('{"":1," ":2,"a\"b":3}');
  { 6 }
  JsonCase('{"a":1,"a":2}');
  { 7: informational }
  JsonLongKeysCase(StringOfChar('k', 300), '');
  JsonLongKeysCase(StringOfChar('k', 279) + 'a' + StringOfChar('k', 20),
    StringOfChar('k', 279) + 'b' + StringOfChar('k', 20));
  { 8 }
  JsonCase('2147483647');
  JsonCase('2147483648');
  JsonCase('-2147483649');
  JsonCase('9223372036854775807');
  JsonCase('9223372036854775808');
  JsonCase('18446744073709551615');
  JsonCase('-0');
  JsonCase('007');
  { 9 }
  JsonCase('{');
  JsonCase('[1,]');
  JsonCase('{"a"}');
  JsonCase('{''a'':1}');
  JsonCase('tru');
  JsonCase('');
  JsonCase('{"a":1}x');
  JsonCase('[1 2]');
  { 10 }
  JsonParserCase('[1,2,] // c');
  JsonParserCase('{"a":1,/* c */"b":2,}');
  { 11 }
  JsonCase(StringOfChar('[', 200) + StringOfChar(']', 200));
  { 12 }
  JsonBuiltObject;
  JsonBuiltArray;
  JsonBuiltObjectMembers;
end;
