(* Section xml: DOM and XMLRead. Every input is a run of bytes in a TBytesStream, parsed with the options
  the chart's map reader sets (PreserveWhitespace True, Namespaces False, ExpandEntities True, Validate
  False). The tree is printed depth first from the document node, one line per node:
  '<depth> <NodeType> <Esc(NodeName)> <Esc(NodeValue)>'; an element is followed by '@<name>=<Esc(value)>'
  for every name of cXmlAttrNames that GetAttributeNode finds, then by 'text <Esc(TextContent)>'. A parse
  that raises prints 'raises <class name>'. No line of this section is informational.

  The inputs by group of the plan (numbers of '== xml N'):
    1  1       a small SVG
    2  2       line breaks and indentation between elements (white-space text nodes)
    3  3       comments, processing instructions, a CDATA section, the XML declaration
    4  4       the five predefined entities and character references (decimal, hexadecimal, beyond the
               BMP), in text and in an attribute value
    5  5       tab, line break and runs of blanks in attribute values; single quotes; ten attributes
    6  6       a DOCTYPE with internal entities, used in attributes and text
    7  7       a DOCTYPE with an external identifier and no internal subset
    8  8-11    Chinese text and attribute values: UTF-8, UTF-8 with a byte order mark, UTF-16 LE and UTF-16
               BE with byte order marks
    9  12      encoding="ISO-8859-1" and a byte $E9
    10 13      CRLF line breaks (LF in text nodes and attribute values)
    11 14      prefixed element and attribute names (Namespaces False: the names as written)
    12 15-21   invalid: an unclosed tag, a mismatched end tag, two root elements, an unquoted attribute
               value, an undeclared entity, empty input, encoding="GBK"
    -  22-25   what FPC does with: encoding="US-ASCII", a lone continuation byte, an overlong UTF-8
               sequence, a truncated UTF-8 sequence at the end
    -  26-38   what FPC does with: an entity whose text holds elements, a CDATA section and a
               comment; an entity referring to another; a recursive entity; an entity with '<' in an
               attribute; a repeated attribute; attributes without white space between them; ']]>' in
               text; '--' in a comment; a processing instruction named XML; &#X41; (upper-case X); a
               reference to U+0001; a raw U+0001; a second DOCTYPE
    13 39-41   the three SVG files of examples/advchart/maps (read relative to delphi/tests, the working
               directory the probe gives): the number of element and of text nodes, the FNV-1a (32 bits)
               of all the node lines (each followed by a line feed), and the first 40 node lines *)

const
  cXmlAttrNames: array[0..18] of string = (
    'id', 'name', 'd', 'points', 'transform', 'style', 'class', 'fill', 'stroke', 'x', 'y', 'width',
    'height', 'viewBox', 'cx', 'cy', 'r', 'xlink:href', 'xmlns');
  cXmlMapFiles: array[0..2] of string = (
    'Beef_cuts_France.svg', 'Map_of_Iceland.svg', 'Sicily_prehellenic_topographic_map.svg');
  cXmlMapDir = '..' + PathDelim + '..' + PathDelim + 'examples' + PathDelim + 'advchart' + PathDelim
    + 'maps' + PathDelim;
  { "<U+4E2D U+6587>" and "<U+56FD>" }
  cXmlZhText = #$E4#$B8#$AD#$E6#$96#$87;
  cXmlZhId = #$E5#$9B#$BD;
  cXmlZhDoc = '<svg><text id="' + cXmlZhId + '" class="a ' + cXmlZhText + '">' + cXmlZhText
    + '</text></svg>';

function XmlCat(const A, B: TBytes): TBytes;
begin
  SetLength(Result, Length(A) + Length(B));
  if Length(A) > 0 then
    Move(A[0], Result[0], Length(A));
  if Length(B) > 0 then
    Move(B[0], Result[Length(A)], Length(B));
end;

{ S as UTF-16 code units, two bytes each, after a byte order mark; little-endian when ALittle is set. }
function XmlUtf16Bytes(const S: string; ALittle: Boolean): TBytes;
var
  u: UnicodeString;
  i, c: Integer;
begin
  u := TyJsUnits(S);
  SetLength(Result, 2 * Length(u) + 2);
  for i := 0 to Length(u) do
  begin
    if i = 0 then
      c := $FEFF
    else
      c := Ord(u[i]);
    if ALittle then
    begin
      Result[2 * i] := c and $FF;
      Result[2 * i + 1] := c shr 8;
    end
    else
    begin
      Result[2 * i] := c shr 8;
      Result[2 * i + 1] := c and $FF;
    end;
  end;
end;

{ Parses ABytes with the chart's options; ADoc is nil when it raised (then AError is the class name). }
function XmlParse(const ABytes: TBytes; out ADoc: TXMLDocument; out AError: string): Boolean;
var
  parser: TDOMParser;
  src: TXMLInputSource;
  st: TBytesStream;
begin
  ADoc := nil;
  AError := '';
  parser := TDOMParser.Create;
  st := TBytesStream.Create(ABytes);
  src := nil;
  try
    parser.Options.PreserveWhitespace := True;
    parser.Options.Namespaces := False;
    parser.Options.ExpandEntities := True;
    parser.Options.Validate := False;
    src := TXMLInputSource.Create(st);
    try
      parser.Parse(src, ADoc);
    except
      on E: Exception do
      begin
        AError := E.ClassName;
        FreeAndNil(ADoc);
      end;
    end;
  finally
    src.Free;
    st.Free;
    parser.Free;
  end;
  Result := ADoc <> nil;
end;

{ The lines of ANode and of its descendants, depth first, added to AOut. }
procedure XmlNodeLines(ANode: TDOMNode; ADepth: Integer; AOut: TStrings; var AElements, ATexts: Integer);
var
  i: Integer;
  a, c: TDOMNode;
begin
  AOut.Add(IntToStr(ADepth) + ' ' + IntToStr(ANode.NodeType) + ' ' + Esc(ANode.NodeName) + ' '
    + Esc(ANode.NodeValue));
  if ANode.NodeType = TEXT_NODE then
    Inc(ATexts);
  if ANode is TDOMElement then
  begin
    Inc(AElements);
    for i := 0 to High(cXmlAttrNames) do
    begin
      a := TDOMElement(ANode).GetAttributeNode(TyJsUnits(cXmlAttrNames[i]));
      if a <> nil then
        AOut.Add('@' + cXmlAttrNames[i] + '=' + Esc(a.NodeValue));
    end;
    AOut.Add('text ' + Esc(ANode.TextContent));
  end;
  c := ANode.FirstChild;
  while c <> nil do
  begin
    XmlNodeLines(c, ADepth + 1, AOut, AElements, ATexts);
    c := c.NextSibling;
  end;
end;

{ The FNV-1a hash (32 bits) of the lines of AList, each followed by a line feed, in hexadecimal. }
function XmlFnv(AList: TStrings): string;
var
  h: Int64;
  i, k: Integer;
  s: string;
begin
  h := $811C9DC5;
  for i := 0 to AList.Count - 1 do
  begin
    s := AList[i] + #10;
    for k := 1 to Length(s) do
      h := ((h xor Ord(s[k])) * 16777619) and $FFFFFFFF;
  end;
  Result := IntToHex(h, 8);
end;

{ One input: every node line, or the exception. }
procedure XmlCase(const ABytes: TBytes);
var
  doc: TXMLDocument;
  err: string;
  lines: TStringList;
  i, ne, nt: Integer;
begin
  NextCase;
  if not XmlParse(ABytes, doc, err) then
  begin
    Line('raises ' + err);
    Exit;
  end;
  lines := TStringList.Create;
  try
    ne := 0;
    nt := 0;
    XmlNodeLines(doc, 0, lines, ne, nt);
    for i := 0 to lines.Count - 1 do
      Line(lines[i]);
  finally
    lines.Free;
    doc.Free;
  end;
end;

procedure XmlTextCase(const AText: string);
begin
  XmlCase(JsonStrUtf8Bytes(AText));
end;

{ One of the map files: the counts, the hash and the first 40 lines. }
procedure XmlFileCase(const AName: string);
var
  fs: TFileStream;
  b: TBytes;
  doc: TXMLDocument;
  err: string;
  lines: TStringList;
  i, ne, nt: Integer;
begin
  NextCase;
  Line('file ' + AName);
  fs := TFileStream.Create(cXmlMapDir + AName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(b, fs.Size);
    if Length(b) > 0 then
      fs.ReadBuffer(b[0], Length(b));
  finally
    fs.Free;
  end;
  Line('bytes ' + IntToStr(Length(b)));
  if not XmlParse(b, doc, err) then
  begin
    Line('raises ' + err);
    Exit;
  end;
  lines := TStringList.Create;
  try
    ne := 0;
    nt := 0;
    XmlNodeLines(doc, 0, lines, ne, nt);
    Line('elements ' + IntToStr(ne));
    Line('texts ' + IntToStr(nt));
    Line('lines ' + IntToStr(lines.Count));
    Line('fnv ' + XmlFnv(lines));
    for i := 0 to lines.Count - 1 do
    begin
      if i >= 40 then
        Break;
      Line(lines[i]);
    end;
  finally
    lines.Free;
    doc.Free;
  end;
end;

procedure SectionXml;
var
  i: Integer;
begin
  BeginSection('xml');
  { group 1 }
  XmlTextCase('<svg><g id="a"><path d="M0 0L1 1"/></g></svg>');
  { group 2 }
  XmlTextCase('<svg>'#10'  <g id="a">'#10#9'<path d="M0 0"/>'#10'  </g>'#10'  <text> a  b </text>'#10
    + '</svg>'#10);
  { group 3 }
  XmlTextCase('<?xml version="1.0" encoding="UTF-8" standalone="no"?>'#10'<!-- top -->'#10
    + '<?pi-top some data?>'#10'<svg><!-- in svg --><?app x="1"?><text>t<![CDATA[a<b]]>u</text>'
    + '<![CDATA[]]></svg>'#10'<!-- after -->'#10);
  { group 4 }
  XmlTextCase('<svg><text id="&lt;&gt;&amp;&apos;&quot;|&#65;&#x42;&#x1f600;|&#20013;">'
    + '&lt;&gt;&amp;&apos;&quot;|&#65;&#x42;&#x1F600;|&#20013;</text></svg>');
  { group 5 }
  XmlTextCase('<svg id="a'#9'b" name="c'#10'd" d="M0  0   L1 1" points='' 1,2  3,4 '''
    + ' transform=''rotate(1)'' style=''fill:"red"'' class="x&#9;y&#10;z" fill="red" stroke="blue"'
    + ' x="1"/>');
  { group 6 }
  XmlTextCase('<!DOCTYPE svg [<!ENTITY ns "http://x"><!ENTITY t "T&amp;T">]>'
    + '<svg xmlns="&ns;"><text id="&t;" class="a&ns;b">a&t;b&ns;</text></svg>');
  { group 7 }
  XmlTextCase('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" '
    + '"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">'#10'<svg width="1"/>');
  { group 8 }
  XmlTextCase(cXmlZhDoc);
  XmlCase(XmlCat(JsonStrHexBytes('EFBBBF'), JsonStrUtf8Bytes(cXmlZhDoc)));
  XmlCase(XmlUtf16Bytes(cXmlZhDoc, True));
  XmlCase(XmlUtf16Bytes(cXmlZhDoc, False));
  { group 9 }
  XmlCase(XmlCat(XmlCat(JsonStrUtf8Bytes('<?xml version="1.0" encoding="ISO-8859-1"?><svg id="a'),
    JsonStrHexBytes('E9')), XmlCat(JsonStrUtf8Bytes('"><text>'), XmlCat(JsonStrHexBytes('E9'),
    JsonStrUtf8Bytes('</text></svg>')))));
  { group 10 }
  XmlTextCase('<svg>'#13#10'<text d="1'#13#10'2">a'#13#10'b'#13'c</text>'#13#10'</svg>'#13#10);
  { group 11 }
  XmlTextCase('<svg xmlns:xlink="http://www.w3.org/1999/xlink"><use xlink:href="#a"/>'
    + '<xlink:a xlink:href="#b"/></svg>');
  { group 12 }
  XmlTextCase('<svg>');
  XmlTextCase('<svg></g>');
  XmlTextCase('<a/><b/>');
  XmlTextCase('<svg id=a/>');
  XmlTextCase('<svg>&foo;</svg>');
  XmlTextCase('');
  XmlTextCase('<?xml version="1.0" encoding="GBK"?><svg/>');
  { what FPC does with these }
  XmlTextCase('<?xml version="1.0" encoding="US-ASCII"?><svg/>');
  XmlCase(XmlCat(JsonStrUtf8Bytes('<svg>'), XmlCat(JsonStrHexBytes('80'), JsonStrUtf8Bytes('</svg>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<svg>'), XmlCat(JsonStrHexBytes('C0AF'), JsonStrUtf8Bytes('</svg>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<svg/>'), JsonStrHexBytes('E4B8')));
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "x<g id=''i''>y<![CDATA[z]]><!--c-->w</g>v">]><svg>a&e;b</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY a "1&b;2"><!ENTITY b "B&#9;"><!ENTITY a "dup">]>'
    + '<svg id="&a;">&a;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY a "x&a;">]><svg>&a;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY a "x&lt;y"><!ENTITY b "<">]><svg id="&a;" name="&b;"/>');
  XmlTextCase('<svg id="1" id="2"/>');
  XmlTextCase('<svg id="1"name="2"/>');
  XmlTextCase('<svg>a]]>b</svg>');
  XmlTextCase('<svg><!-- a -- b --></svg>');
  XmlTextCase('<svg><?XML a?></svg>');
  XmlTextCase('<svg>&#X41;</svg>');
  XmlTextCase('<svg>&#1;</svg>');
  XmlTextCase('<svg>'#1'</svg>');
  XmlTextCase('<!DOCTYPE a><!DOCTYPE b><svg/>');
  { group 13 }
  for i := 0 to High(cXmlMapFiles) do
    XmlFileCase(cXmlMapFiles[i]);
end;
