{ Copied from TyControls tests/test.paletteicons.pas at 77860b40. }
unit test.advchart.paletteicons;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry, LResources, test.designregistry;

type
  { Palette-icon guard.

    THE CONTRACT. designtime/tyControls.Design.AdvanceChart.Register.pas includes
    tyadvancechart_icons.lrs and then calls RegisterComponents; the IDE looks each palette
    button's image up BY CLASS NAME. A class with no resource of that name gets a blank button --
    no error, no warning, just a hole in the palette. Every palette class therefore needs three
    resources (100% / 150% / 200%).

    TyControls' TPaletteIconTest holds its palette to that, and TTyAdvanceChart's three icons
    were in its tycontrols_icons.lrs until the chart moved here (Task 11 packed them into
    designtime/tyadvancechart_icons.lrs). The population is the registrations test.designregistry
    parses out of this repository's designtime/, in both directions:
      * forward -- every parsed palette class has its three PNG resources;
      * backward -- every TTy* icon resource belongs to a parsed palette class.
    TyControls' third test (icon-less registrations have no icon) has nothing to hold here: this
    repository makes no RegisterNoIcon or RegisterDesignerBaseClass call. }
  TAdvChartPaletteIconTest = class(TTestCase)
  published
    procedure TestEveryPaletteClassHasItsIconResources;
    procedure TestNoOrphanIconResources;
  end;

implementation

const
  { HiDPI variants: '' = 100% (24px), '_150' = 150% (36px), '_200' = 200% (48px). }
  Suffixes: array[0..2] of string = ('', '_150', '_200');
  { Only the TTy* resources are this test's business -- the LResources list is global and
    anything else linked into the runner may add to it. }
  CPrefix = 'TTy';
  CRegen = ' -- add designtime/icons/<class>{,_150,_200}.png and re-run scripts/gen-icons.ps1';

procedure TAdvChartPaletteIconTest.TestEveryPaletteClassHasItsIconResources;
var
  classes, bad: TStringList;
  i, j: Integer;
  nm: string;
  res: TLResource;
begin
  classes := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectPaletteClassNames(classes);
    AssertTrue('the parse of designtime/ found the palette entry',
      classes.IndexOf('TTyAdvanceChart') >= 0);
    for i := 0 to classes.Count - 1 do
      for j := 0 to High(Suffixes) do
      begin
        nm := classes[i] + Suffixes[j];
        res := LazarusResources.Find(nm);
        if res = nil then
          bad.Add(nm + ': no icon resource -- the IDE would show a blank palette button' + CRegen)
        else if res.ValueType <> 'PNG' then
          bad.Add(nm + ': icon resource is ' + res.ValueType + ', expected PNG');
      end;
    AssertEquals('classes registered with RegisterComponents whose palette icon is missing from'
      + ' designtime/tyadvancechart_icons.lrs:' + LineEnding + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    classes.Free;
  end;
end;

{ The backward direction. Every icon must answer to a palette registration; an orphan means
  either the .lrs still carries a renamed or withdrawn class (regenerate) or the parse has
  stopped seeing a registration that is still there. }
procedure TAdvChartPaletteIconTest.TestNoOrphanIconResources;
var
  palette, bad: TStringList;
  i, j, icons: Integer;
  nm, base: string;
begin
  palette := TStringList.Create;
  bad := TStringList.Create;
  try
    CollectPaletteClassNames(palette);
    icons := 0;
    for i := 0 to LazarusResources.Count - 1 do
    begin
      nm := LazarusResources.Items[i].Name;
      if not AnsiStartsStr(CPrefix, nm) then Continue;
      Inc(icons);
      { strip the HiDPI suffix, if any; an UNKNOWN suffix must not be stripped -- it is itself a
        finding (the IDE would never look that name up) }
      base := nm;
      for j := 0 to High(Suffixes) do
        if (Suffixes[j] <> '') and AnsiEndsStr(Suffixes[j], nm) then
        begin
          base := Copy(nm, 1, Length(nm) - Length(Suffixes[j]));
          Break;
        end;
      if palette.IndexOf(base) < 0 then
        bad.Add(nm + ': icon resource with no RegisterComponents entry for ' + base);
    end;
    AssertTrue('anti-vacuity: the icons were linked in (' + IntToStr(icons) + ')', icons >= 3);
    AssertEquals('orphan palette icons in designtime/tyadvancechart_icons.lrs:' + LineEnding
      + bad.Text, 0, bad.Count);
  finally
    bad.Free;
    palette.Free;
  end;
end;

initialization
  {$I ../designtime/tyadvancechart_icons.lrs}
  RegisterTest(TAdvChartPaletteIconTest);
end.
