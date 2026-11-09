unit test.advchart.themedump;
{$mode objfpc}{$H+}

{ Test support, not a suite: a deterministic JSON dump of what every built-in theme, in both
  modes, resolves for the chart. Two things go in:
    - each token the chart's own tycss defines (its --advchart-* tokens), read with
      ResolveToken;
    - each typeKey it names (its TyAdvChart* keys), resolved with no style class under no state
      and under each pseudo-state, every field of the result written as text.
  The two lists are TyAdvChartThemeVocabulary: TyCssVocabularyOf over TyAdvChartCss, the text
  tyControls.AdvanceChart.Theme registers, by the rules scripts/gen-tycss-catalog.ps1 uses
  (ascending by byte value). When the chart was split out of the core they gave exactly the
  lists themes/light.tycss carried for it: 10 tokens and 87 typeKeys.

  The text is the same on every run and on every machine: names and keys are sorted ordinally,
  floats use a fixed format, and a path under the checkout is written relative to it. A
  baseline taken before the split and the dump taken after it can be compared as they are. }

interface

uses
  tyControls.Css.AddOns;

// The dump as JSON. One object keyed '<theme>|<light|dark>', each holding 'tokens' (token name to
// value) and 'typeKeys' (typeKey to one text line per state).
function TyAdvChartThemeDump: string;

// The tokens and typeKeys the dump covers: the vocabulary of the chart's own tycss.
function TyAdvChartThemeVocabulary: TTyCssVocabulary;

implementation

uses
  Classes, SysUtils, tyControls.Types, tyControls.StyleModel, tyControls.Controller,
  tyControls.ThemeRegistry, tyControls.BuiltinThemes, tyControls.AdvanceChart.Theme;

const
  cStateNames: array[0..5] of string =
    ('normal', 'hover', 'active', 'focused', 'disabled', 'selected');

var
  GFS: TFormatSettings;

function JsonStr(const S: string): string;
var
  i: Integer;
  c: Char;
begin
  Result := '"';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    case c of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #9:  Result := Result + '\t';
    else
      if c < ' ' then
        Result := Result + '\u' + IntToHex(Ord(c), 4)
      else
        Result := Result + c;
    end;
  end;
  Result := Result + '"';
end;

function Flt(V: Double): string;
begin
  Result := FormatFloat('0.######', V, GFS);
  if Result = '-0' then Result := '0';
end;

function Clr(C: TTyColor): string;
begin
  Result := '#' + IntToHex(Cardinal(C), 8);
end;

{ A path the style carries, with the checkout's own location taken out so it reads the same
  wherever the tree is. }
function PathText(const P: string): string;
var
  root: string;
begin
  Result := P;
  if Result = '' then Exit;
  root := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim);
  if (root <> '') and (Pos(root, Result) = 1) then
    Result := '<root>' + PathDelim + Copy(Result, Length(root) + 1, MaxInt);
  Result := StringReplace(Result, '\', '/', [rfReplaceAll]);
end;

function FillText(const F: TTyFill): string;
var
  i: Integer;
begin
  Result := Format('kind=%d color=%s from=%s to=%s angle=%s slice=%d,%d,%d,%d repeat=%d mode=%d ' +
    'blur=%d glassblur=%d glasstint=%s img=%s stops=[',
    [Ord(F.Kind), Clr(F.Color), Clr(F.GradFrom), Clr(F.GradTo), Flt(F.GradAngleDeg),
     F.SliceInsets.Left, F.SliceInsets.Top, F.SliceInsets.Right, F.SliceInsets.Bottom,
     Ord(F.SliceRepeat), Ord(F.ImageMode), F.Blur, F.GlassBlur, Clr(F.GlassTint),
     PathText(F.ImagePath)]);
  for i := 0 to High(F.GradStops) do
  begin
    if i > 0 then Result := Result + ',';
    Result := Result + Clr(F.GradStops[i].Color) + '@' + Flt(F.GradStops[i].Pos);
  end;
  Result := Result + ']';
end;

function StyleText(const S: TTyStyleSet): string;
var
  p: TTyProp;
  present: string;
begin
  present := '';
  for p := Low(TTyProp) to High(TTyProp) do
    if p in S.Present then
      present := present + IntToStr(Ord(p)) + ',';
  Result := Format('present=[%s] bg={%s} bgUnderTitle=%d windowShadow=%d text=%s border=%s ' +
    'bw=%d bstyle=%d rstyle=%d br=%d radius=%d,%d,%d,%d pad=%d,%d,%d,%d font=%s fsize=%d ' +
    'fweight=%d opacity=%s shadow=%s,%d,%d,%d outline=%s,%d,%d',
    [present, FillText(S.Background), Ord(S.BackgroundUnderTitlebar), Ord(S.WindowShadow),
     Clr(S.TextColor), Clr(S.BorderColor), S.BorderWidth, Ord(S.BorderStyle),
     Ord(S.RenderStyle), S.BorderRadius, S.Radius.TL, S.Radius.TR, S.Radius.BR, S.Radius.BL,
     S.Padding.Left, S.Padding.Top, S.Padding.Right, S.Padding.Bottom, S.FontName,
     S.FontSize, S.FontWeight, Flt(S.Opacity), Clr(S.ShadowColor), S.ShadowBlur,
     S.ShadowOffset.X, S.ShadowOffset.Y, Clr(S.OutlineColor), S.OutlineWidth,
     S.OutlineOffset]);
end;

function StatesOf(AIndex: Integer): TTyStateSet;
begin
  Result := [];
  case AIndex of
    1: Result := [tysHover];
    2: Result := [tysActive];
    3: Result := [tysFocused];
    4: Result := [tysDisabled];
    5: Result := [tysSelected];
  end;
end;

function SortedNames: TStringList;
var
  names: TStringArray;
  i, j: Integer;
  t: string;
begin
  names := TyBuiltinThemeNames;
  Result := TStringList.Create;
  for i := 0 to High(names) do
    Result.Add(names[i]);
  // ordinal order, so the text does not depend on the locale
  for i := 0 to Result.Count - 2 do
    for j := i + 1 to Result.Count - 1 do
      if CompareStr(Result[j], Result[i]) < 0 then
      begin
        t := Result[i]; Result[i] := Result[j]; Result[j] := t;
      end;
end;

function TyAdvChartThemeVocabulary: TTyCssVocabulary;
begin
  Result := TyCssVocabularyOf(TyAdvChartCss);
end;

function TyAdvChartThemeDump: string;
var
  c: TTyStyleController;
  names: TStringList;
  sb: TStringBuilder;
  i, m, k, s: Integer;
  mode, line: string;
  firstEntry: Boolean;
  v: TTyCssVocabulary;
begin
  v := TyAdvChartThemeVocabulary;
  TyRegisterBuiltinThemes;
  GFS := DefaultFormatSettings;
  GFS.DecimalSeparator := '.';
  sb := TStringBuilder.Create;
  names := SortedNames;
  c := TTyStyleController.Create(nil);
  try
    sb.Append('{').Append(#10);
    firstEntry := True;
    for i := 0 to names.Count - 1 do
      for m := 0 to 1 do
      begin
        if m = 0 then mode := 'light' else mode := 'dark';
        c.ThemeName := names[i];
        c.Mode := mode;
        if not firstEntry then sb.Append(',').Append(#10);
        firstEntry := False;
        sb.Append(JsonStr(names[i] + '|' + mode)).Append(': {').Append(#10);
        sb.Append('  "tokens": {').Append(#10);
        for k := 0 to High(v.Tokens) do
        begin
          sb.Append('    ').Append(JsonStr(v.Tokens[k])).Append(': ')
            .Append(JsonStr(c.Model.ResolveToken(v.Tokens[k])));
          if k < High(v.Tokens) then sb.Append(',');
          sb.Append(#10);
        end;
        sb.Append('  },').Append(#10);
        sb.Append('  "typeKeys": {').Append(#10);
        for k := 0 to High(v.TypeKeys) do
        begin
          line := '';
          for s := 0 to High(cStateNames) do
          begin
            if s > 0 then line := line + #10;
            line := line + cStateNames[s] + ': ' +
              StyleText(c.Model.ResolveStyle(v.TypeKeys[k], '', StatesOf(s)));
          end;
          sb.Append('    ').Append(JsonStr(v.TypeKeys[k])).Append(': ').Append(JsonStr(line));
          if k < High(v.TypeKeys) then sb.Append(',');
          sb.Append(#10);
        end;
        sb.Append('  }').Append(#10).Append('}');
      end;
    sb.Append(#10).Append('}').Append(#10);
    Result := sb.ToString;
  finally
    c.Free;
    names.Free;
    sb.Free;
  end;
end;

end.
