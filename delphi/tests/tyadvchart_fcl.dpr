{ The FCL transcript: what the FCL units the chart uses give for a fixed set of inputs, one line per result.
  Built and run by scripts/delphi-probe.py --fcl with FPC (FPC's own units) and with dcc32 and dcc64 (the
  ports in delphi/fcl); every compiler must print delphi/tests/expected/fcl.txt, the lines that start with
  '~ ' excepted for dcc (they are informational: the probe counts them when they differ).

  The format:
  - every input prints a line '== <section> <number>', then its result lines;
  - every string goes through Esc: its UTF-16 code units, $20..$7E except '\' as they are, any other unit
    as \uXXXX (four upper-case hexadecimal digits), and so is a blank at the start or the end of the
    string, and a result line drops the blanks at its end (the blank after a label whose value is
    empty), so that no line of the transcript starts or ends with a blank;
  - an exception prints 'raises <class name>', not its message;
  - an informational line starts with '~ ';
  - the last line is FCL TRANSCRIPT END.

  One include file per section. The sources are ASCII: a non-ASCII character is written as a contiguous
  run of UTF-8 byte escapes (bytes for FPC, one character for Delphi, which is given --codepage:65001). }
program tyadvchart_fcl;

{$IFDEF FPC}{$mode delphi}{$H+}{$ENDIF}
{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  Math,
  fpjson,
  jsonparser,
  jsonscanner,
  DOM,
  XMLRead,
  tyControls.AdvanceChart.NativeStr;

var
  GSection: string;
  GCase: Integer;
  GInfo: Boolean;

{ S as UTF-16 code units: $20..$7E except '\' as they are, any other unit as \uXXXX; a blank that is the
  first or the last unit is written \u0020 as well, so that no line depends on blanks at its ends. }
function Esc(const S: string): string;
var
  u: UnicodeString;
  i, c: Integer;
begin
  u := TyJsUnits(S);
  Result := '';
  for i := 1 to Length(u) do
  begin
    c := Ord(u[i]);
    if (c >= $20) and (c <= $7E) and (c <> Ord('\'))
      and not ((c = $20) and ((i = 1) or (i = Length(u)))) then
      Result := Result + Char(c)
    else
      Result := Result + '\u' + IntToHex(c, 4);
  end;
end;

{ One result line; informational while GInfo is set. Blanks at its end are dropped: Esc writes none, so
  they can only be the blank after a label whose value is empty ('key ' + Esc('') is 'key'). }
procedure Line(const S: string);
begin
  { An empty informational line would print '~' without its blank, and so be compared: none is empty. }
  if GInfo then
    Writeln(TrimRight('~ ' + S))
  else
    Writeln(TrimRight(S));
end;

{ The line of a raised exception. }
procedure Raised(E: Exception);
begin
  Line('raises ' + E.ClassName);
end;

procedure BeginSection(const AName: string);
begin
  GSection := AName;
  GCase := 0;
  GInfo := False;
end;

{ Starts the next input of the current section. }
procedure NextCase;
begin
  Inc(GCase);
  GInfo := False;
  Writeln('== ' + GSection + ' ' + IntToStr(GCase));
end;

{$I tyadvchart_fcl.selftest.inc}
{$I tyadvchart_fcl.json.inc}
{$I tyadvchart_fcl.jsonstr.inc}
{$I tyadvchart_fcl.jsonnum.inc}
{$I tyadvchart_fcl.xml.inc}

begin
  {$IFDEF FPC}
  SetMultiByteConversionCodePage(CP_UTF8);
  {$ENDIF}
  SectionSelfTest;
  SectionJson;
  SectionJsonStr;
  SectionJsonNum;
  SectionXml;
  Writeln('FCL TRANSCRIPT END');
end.
