(* Section xmlx: the XML inputs of the branch's final review, measured once under FPC, dcc32 and dcc64
  and kept here so that they stay measured; printed as section xml prints them. No line of this
  section is informational.

  The inputs, in order: prolog variants (XML declarations, processing instructions and white space
  before and after the root); attribute and tag syntax; character references (zero, a surrogate,
  beyond U+10FFFF, empty, U+FFFE, leading zeros, an overflowing number, no ';'); '&' outside a
  reference; entity corner cases (markup in an entity, an element opened in an entity and closed
  outside, references to predefined and character entities from an entity, undeclared entities under
  each kind of DOCTYPE, standalone yes and no, quotes and white space in entity values); DOCTYPE forms
  (no subset, an empty one, PUBLIC without a system literal, after the root, lower case, an illegal
  public identifier); CDATA, comment and processing-instruction edges; names (prefixes, non-ASCII, a
  digit or '-' first); line breaks in each kind of node; encoding names (variants of UTF-8,
  windows-1252, UTF-16 without a byte order mark, ascii, latin1, the empty name) and declarations in a
  wrong place; UTF-16 with and without a declaration and a byte order mark; byte order marks; UTF-8
  that is invalid or not allowed (a surrogate, beyond U+10FFFF, F5, U+FFFE, control characters);
  ISO-8859-1 bytes; elements and white space; the case of names; input cut short at 20 places.
  Left out, because they differ by ruling (the values program asserts them): an ELEMENT and an
  ATTLIST declaration in the internal subset, and version="1.1". *)

const
  cXmlXSvg11 = '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" '
    + '"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">';

procedure SectionXmlX;
begin
  BeginSection('xmlx');
  XmlTextCase('<?xml-stylesheet type="text/css" href="a.css"?><svg/>');
  XmlTextCase('<?xml version="1.0"?><?xml-stylesheet href="a.css"?><svg/>');
  XmlTextCase('<?xml version=''1.0'' encoding=''utf-8''?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="UTF-8" standalone="no"?>'#10 + cXmlXSvg11 + #10
    + '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" id="L"'
    + ' x="0px" y="0px" width="10px" height="10px" viewBox="0 0 10 10" xml:space="preserve"><g id="a">'
    + '<path id="p" d="M0,0"/></g></svg>');
  XmlTextCase(' <?xml version="1.0"?><svg/>');
  XmlTextCase(#10'<?xml version="1.0"?><svg/>');
  XmlTextCase('<svg/>x');
  XmlTextCase('<svg/>'#10#10);
  XmlTextCase('<svg/><!-- c -->');
  XmlTextCase('<svg/><?pi?>');
  XmlTextCase('x<svg/>');
  XmlTextCase('<svg id = ''x''  name="y" />');
  XmlTextCase('<svg id=""/>');
  XmlTextCase('<svg></svg >');
  XmlTextCase('< svg/>');
  XmlTextCase('<svg/ >');
  XmlTextCase('<svg id="x>y"/>');
  XmlTextCase('<svg id="x<y"/>');
  XmlTextCase('<svg id="&#60;&#38;&#62;">&#38;lt;</svg>');
  XmlTextCase('<svg>&#0;</svg>');
  XmlTextCase('<svg>&#xD800;</svg>');
  XmlTextCase('<svg>&#x110000;</svg>');
  XmlTextCase('<svg>&#;</svg>');
  XmlTextCase('<svg>&#x;</svg>');
  XmlTextCase('<svg>&#xFFFE;</svg>');
  XmlTextCase('<svg>&#xFFFD;&#x10000;&#x10FFFF;&#65</svg>');
  XmlTextCase('<svg>&#00000000000000000065;&#x000000000041;</svg>');
  XmlTextCase('<svg>&#99999999999999999999;</svg>');
  XmlTextCase('<svg>A &amp B</svg>');
  XmlTextCase('<svg>A & B</svg>');
  XmlTextCase('<svg id="A & B"/>');
  XmlTextCase('<svg>&;</svg>');
  XmlTextCase('<svg>&amp ;</svg>');
  XmlTextCase('<svg>&AMP;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "<g id=''x''/>">]><svg>&e;&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "<g>">]><svg>&e;</g></svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "</svg>">]><svg>&e;');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "&#60;g/>">]><svg>&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "&#38;lt;">]><svg id="&e;">&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "&#60;">]><svg id="&e;"/>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY lt "&#38;#60;"><!ENTITY amp "&#38;#38;">]><svg id="&lt;&amp;">&lt;&amp;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY a "&b;"><!ENTITY c "x">]><svg>&c;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY a "&b;"><!ENTITY c "x">]><svg>&a;</svg>');
  XmlTextCase(cXmlXSvg11 + '<svg><!--x-->&nbsp;</svg>');
  XmlTextCase('<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "x.dtd" [<!ENTITY a "&b;">]><svg id="&a;">&a;</svg>');
  XmlTextCase('<?xml version="1.0" standalone="yes"?>' + cXmlXSvg11 + '<svg>&nbsp;</svg>');
  XmlTextCase('<?xml version="1.0" standalone="no"?>' + cXmlXSvg11 + '<svg>&nbsp;</svg>');
  XmlTextCase('<!DOCTYPE svg SYSTEM "x.dtd"><svg>&nbsp;</svg>');
  XmlTextCase('<!DOCTYPE svg SYSTEM "x.dtd" [<!ENTITY nbsp "&#160;">]><svg id="&nbsp;">&nbsp;&foo;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "100%">]><svg>&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e ''a"b''><!ENTITY   f   "a''b"  >]><svg id="&e;&f;">&e;&f;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "T&#38;T">]><svg>&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "a'#9'b'#10'c">]><svg id="&e;">&e;</svg>');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "a&#9;b&#10;c">]><svg id="&e;|&#9;|&#10;|&#13;">&e;|&#13;</svg>');
  XmlTextCase('<!DOCTYPE svg [ <!-- c --> <?pi x?> <!ENTITY e "v"> ]><svg>&e;</svg>');
  XmlTextCase('<!DOCTYPE svg><svg/>');
  XmlTextCase('<!DOCTYPE svg []><svg/>');
  XmlTextCase('<!DOCTYPE svg[]><svg/>');
  XmlTextCase('<!DOCTYPE svg PUBLIC "p"><svg/>');
  XmlTextCase('<!DOCTYPE svg PUBLIC "p" "s" [<!ENTITY a "b">] ><svg>&a;</svg>');
  XmlTextCase('<!DOCTYPE other><svg/>');
  XmlTextCase('<svg/><!DOCTYPE svg>');
  XmlTextCase('<!doctype svg><svg/>');
  XmlTextCase('<!DOCTYPE svg PUBLIC "{bad}" "s"><svg/>');
  XmlTextCase('<svg><![CDATA[a]]b]]></svg>');
  XmlTextCase('<svg><![CDATA[a]]]]></svg>');
  XmlTextCase('<![CDATA[a]]><svg/>');
  XmlTextCase('<svg>a]>b]]&gt;c]] >d</svg>');
  XmlTextCase('<svg>]]&#62;</svg>');
  XmlTextCase('<svg><!---></svg>');
  XmlTextCase('<svg><!----></svg>');
  XmlTextCase('<svg><!-- a ---></svg>');
  XmlTextCase('<svg><!-- a - b --></svg>');
  XmlTextCase('<svg><?pi?><?pi   data  ?><?p-i.x d?></svg>');
  XmlTextCase('<svg><?pi?data?></svg>');
  XmlTextCase('<svg><?pi d?>?></svg>');
  XmlTextCase('<svg><?1pi d?></svg>');
  XmlTextCase('<a:b c:d="1" xmlns="u"><e:f/></a:b>');
  XmlTextCase('<' + #$E5#$9B#$BE + ' ' + #$E5#$B1#$9E + '="' + #$E5#$80#$BC + '" id="1"/>');
  XmlTextCase('<1a/>');
  XmlTextCase('<-a/>');
  XmlTextCase('<a.b-c_d' + #$C2#$B7 + '1 id="1"/>');
  XmlTextCase('<a 1b="x"/>');
  XmlTextCase('<svg id="a'#13#10'b'#13'c'#10#10'd"><![CDATA[a'#13#10'b'#13'c]]><!--a'#13#10'b-->'
    + '<?p a'#13#10'b?></svg>');
  XmlTextCase('<?xml version="1.0" encoding="UTF8"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="utf-8"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="windows-1252"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="UTF-16"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="ascii"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding="latin1"?><svg/>');
  XmlTextCase('<?xml version="1.0" encoding=""?><svg/>');
  XmlTextCase('<?xml version="1.0" ?><svg/>');
  XmlTextCase('<?xml version = "1.0" encoding = "UTF-8" ?><svg/>');
  XmlTextCase('<?xml encoding="UTF-8"?><svg/>');
  XmlTextCase('<?xml version="1.0" standalone="yes" encoding="UTF-8"?><svg/>');
  XmlTextCase('<?xml version="1.0"encoding="UTF-8"?><svg/>');
  XmlTextCase('<?xml version="1.0" standalone="maybe"?><svg/>');
  XmlTextCase('<?XML version="1.0"?><svg/>');
  XmlTextCase('<?xml?><svg/>');
  XmlTextCase('<?xml version="1.0"?>');
  XmlTextCase('<?xml version="1.0"?><svg/><?xml version="1.0"?>');
  XmlCase(XmlUtf16Bytes('<?xml version="1.0" encoding="UTF-16"?><svg id="' + #$E5#$9B#$BD + '"/>', True));
  XmlCase(XmlUtf16Bytes('<?xml version="1.0" encoding="UTF-8"?><svg/>', True));
  XmlCase(XmlUtf16Bytes('<?xml version="1.0" encoding="UTF-16LE"?><svg/>', True));
  XmlCase(XmlUtf16Bytes('<?xml version="1.0" encoding="UTF-16BE"?><svg/>', True));
  XmlCase(XmlUtf16Bytes('<?xml version="1.0" encoding="utf-16"?><svg/>', False));
  XmlCase(JsonStrHexBytes('3C0073002F003E00'));
  XmlCase(JsonStrHexBytes('EFBBBF'));
  XmlCase(JsonStrHexBytes('EFBBBF3C732F3EEFBBBF'));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('EDA080'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('F4908080'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('F5808080'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('EFBFBE'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('EFBFBD'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('C285E280A8'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('7F'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('00'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<s>'), XmlCat(JsonStrHexBytes('0C'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<?xml version="1.0" encoding="ISO-8859-1"?><s>'),
    XmlCat(JsonStrHexBytes('80FF85'), JsonStrUtf8Bytes('</s>'))));
  XmlCase(XmlCat(JsonStrUtf8Bytes('<?xml version="1.0" encoding="ISO-8859-1"?><s a="'),
    XmlCat(JsonStrHexBytes('E9'), JsonStrUtf8Bytes('"/>'))));
  XmlTextCase('<svg><a><b><c>t</c></b></a><a/><a></a><a> </a></svg>');
  XmlTextCase('<svg>a<b/>c<b/>d</svg>');
  XmlTextCase('<svg xml:space="preserve" xml:lang="en"> <g> </g> </svg>');
  XmlTextCase('<svg><style type="text/css"><![CDATA[ .a{fill:red} ]]></style><text>x<tspan>y</tspan>z</text></svg>');
  XmlTextCase('<svg id="a"'#10#9'name="b"'#13#10'><g'#10'/></svg'#10'>');
  XmlTextCase('<svg id="1" ID="2" Id="3"/>');
  XmlTextCase('<svg><A></a></svg>');
  XmlTextCase('<svg xmlns:a="u" a:id="1" id="2"/>');
  XmlTextCase('<svg><g></g</svg>');
  XmlTextCase('<svg><g/></svg></svg>');
  XmlTextCase('<svg');
  XmlTextCase('<svg id');
  XmlTextCase('<svg id=');
  XmlTextCase('<svg id="');
  XmlTextCase('<svg><');
  XmlTextCase('<svg></');
  XmlTextCase('<svg><!');
  XmlTextCase('<svg><!-');
  XmlTextCase('<svg><![CDATA[');
  XmlTextCase('<svg><?');
  XmlTextCase('<svg>&');
  XmlTextCase('<svg>&#');
  XmlTextCase('<!DOCTYPE');
  XmlTextCase('<!DOCTYPE svg [');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY');
  XmlTextCase('<!DOCTYPE svg [<!ENTITY e "');
  XmlTextCase('<');
  XmlTextCase('<?');
  XmlTextCase('<?xml');
  XmlTextCase('   ');
  XmlTextCase('<!-- only -->');
end;
