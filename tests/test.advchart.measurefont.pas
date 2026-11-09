{ Copied from TyControls tests/test.dpi.measurefont.pas at 77860b40. }
unit test.advchart.measurefont;
{ A control's size is a function of its own PPI, never of the SCREEN's.   (TyControls #2)

  A caption used to be MEASURED with a font sized in points, which an LCL TFont turns into pixels
  with its own PixelsPerInch -- the screen's, for a fresh font -- so everything sized from a
  measurement carried the screen's PPI twice. TyControls' TTyMeasureFontDpiTest holds every
  control on its palette to two sweeps, and TTyAdvanceChart was on that palette until it moved
  here; the same two run over this repository's registrations:

    TestNoRegisteredControlSizesItselfFromTheScreen  the same PPI reached from two screens gives
                                                     the same size, floor and preferred size;
    TestEveryRegisteredControlScalesItsSizeWithThePPI  a form at 192 PPI gives twice the box of
                                                     its 96-PPI twin.

  The screen is simulated through ScreenInfo, the variable TFont.Create reads, and nothing else is
  faked: each control is born under the simulated screen on a 96-PPI design form and LCL's own
  pass takes the form to the PPI. Copied from the core: the harness (SetUp, TearDown,
  SimulateScreen, SeedContent, FactsOf and its helpers) and the two sweeps; the rest of that
  suite is about the core's painter and its captioned controls, and stays there. The core's
  second anti-vacuity floor (at least 100 pairs with a floor or a preferred size) is about its
  captioned controls and does not carry over to a population of one: the chart's size, floor
  and preferred size are compared whatever they are. }
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, Math, Controls, Forms, Graphics, LCLType, TypInfo,
  fpcunit, testregistry,
  test.designregistry, test.advchart.version,
  tyControls.Types, tyControls.Painter, tyControls.Controller, tyControls.BuiltinThemes,
  tyControls.Base;

type
  { What a control says about its own size. }
  TSizeFacts = record
    W, H, MinW, MinH, PrefW, PrefH: Integer;
    { Which sides the PARENT decides. }
    Align: TAlign;
  end;

  { How the control came to be on its form:
      bwDesigned   read from a form file: LCL puts every font back at the design PPI when the
                   read completes (TCustomForm.Loaded, FixDesignFontsPPIWithChildren);
      bwCodeBuilt  created by code: nothing repairs the font. }
  TBirth = (bwDesigned, bwCodeBuilt);

  TAdvChartMeasureFontDpiTest = class(TTestCase)
  private
    FSaveX, FSaveY: Integer;
    FSaveFontSize: Integer;
    FSaveFontName: string;
    FCtl: TTyStyleController;
    procedure SimulateScreen(APPI: Integer);
    function FactsOf(ACls: TControlClass; AScreen, APPI: Integer; ABirth: TBirth;
      out AFacts: TSizeFacts; out AError: string): Boolean;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNoRegisteredControlSizesItselfFromTheScreen;
    procedure TestEveryRegisteredControlScalesItsSizeWithThePPI;
  end;

implementation

const
  CCaption = 'Sample Ag';

{ ===== harness ============================================================== }

procedure TAdvChartMeasureFontDpiTest.SetUp;
begin
  inherited SetUp;
  FSaveX := ScreenInfo.PixelsPerInchX;
  FSaveY := ScreenInfo.PixelsPerInchY;
  { Applying a theme rewrites TyFallbackFontSize from --font-size-base; put both fallbacks
    back afterwards so this suite cannot change what a later one measures. }
  FSaveFontSize := TyFallbackFontSize;
  FSaveFontName := TyFallbackFontName;
  TyRegisterBuiltinThemes;
  FCtl := TTyStyleController.Create(nil);
  FCtl.ThemeName := 'default';
end;

procedure TAdvChartMeasureFontDpiTest.TearDown;
begin
  FreeAndNil(FCtl);
  ScreenInfo.PixelsPerInchX := FSaveX;
  ScreenInfo.PixelsPerInchY := FSaveY;
  Screen.UpdateScreen;
  TyFallbackFontSize := FSaveFontSize;
  TyFallbackFontName := FSaveFontName;
  { Nothing measured under a simulated screen may outlive the simulation. }
  TyInvalidateTextMeasureCache;
  inherited TearDown;
end;

procedure TAdvChartMeasureFontDpiTest.SimulateScreen(APPI: Integer);
begin
  ScreenInfo.PixelsPerInchX := APPI;
  ScreenInfo.PixelsPerInchY := APPI;
  Screen.UpdateScreen;
  { The measurement memo is keyed on the control PPI and not on the screen, so without this the
    second screen would be answered from the first one's entries. }
  TyInvalidateTextMeasureCache;
end;

{ Give a freshly built control something to measure, through RTTI so that the sweep needs no
  per-class knowledge: a caption, and two entries in whichever string list it publishes. }
procedure SeedContent(AControl: TControl);
const
  CLists: array[0..2] of string = ('Items', 'Tabs', 'Lines');
var
  pi: PPropInfo;
  o: TObject;
  i: Integer;
begin
  pi := GetPropInfo(AControl, 'Caption');
  if (pi <> nil) and (pi^.SetProc <> nil)
     and (pi^.PropType^.Kind in [tkSString, tkLString, tkAString]) then
    try
      SetStrProp(AControl, pi, CCaption);
    except
      { a control that vetoes this caption keeps the one it has }
    end;
  for i := 0 to High(CLists) do
  begin
    pi := GetPropInfo(AControl, CLists[i]);
    if (pi = nil) or (pi^.PropType^.Kind <> tkClass) then Continue;
    o := GetObjectProp(AControl, pi);
    if not (o is TStrings) then Continue;
    try
      TStrings(o).Add('First Ag');
      TStrings(o).Add('Second entry');
    except
      { a list that refuses free-form entries stays as it was }
    end;
  end;
end;

function TAdvChartMeasureFontDpiTest.FactsOf(ACls: TControlClass; AScreen, APPI: Integer;
  ABirth: TBirth; out AFacts: TSizeFacts; out AError: string): Boolean;
{ ONE CONTROL, THE WAY IT REALLY GETS TO A HiDPI SCREEN: the form is put in its 96-PPI design
  space, the control is born under the simulated screen and parented, and then LCL's own pass
  takes the form to APPI. }
var
  frm: TForm;
  c: TControl;
begin
  Result := False;
  AError := '';
  AFacts := Default(TSizeFacts);
  frm := nil;
  SimulateScreen(AScreen);
  try
    try
      frm := TForm.CreateNew(nil);
      { What TCustomDesignControl.Create does in a scaled application. }
      frm.Font.PixelsPerInch := 96;
      { An explicit size on the FORM: left unset, LCL's pass writes one worked out against
        Screen.PixelsPerInch, which cannot be simulated. }
      frm.Font.Size := 9;
      frm.SetBounds(40, 40, 1200, 900);
      c := ACls.Create(frm);
      if c is TTyCustomControl then
        TTyCustomControl(c).Controller := FCtl
      else if c is TTyGraphicControl then
        TTyGraphicControl(c).Controller := FCtl;
      c.Parent := frm;
      SeedContent(c);
      if ABirth = bwDesigned then
        frm.FixDesignFontsPPIWithChildren(96);
      if APPI <> 96 then
        frm.AutoAdjustLayout(lapAutoAdjustForDPI, 96, APPI,
          frm.Width, MulDiv(frm.Width, APPI, 96));
      c.InvalidatePreferredSize;
      AFacts.Align := c.Align;
      AFacts.MinW := c.Constraints.MinWidth;
      AFacts.MinH := c.Constraints.MinHeight;
      AFacts.W := Max(c.Width, AFacts.MinW);
      AFacts.H := Max(c.Height, AFacts.MinH);
      c.GetPreferredSize(AFacts.PrefW, AFacts.PrefH, True, False);
      Result := True;
    except
      on E: Exception do
        AError := E.ClassName + ': ' + E.Message;
    end;
  finally
    FreeAndNil(frm);
  end;
end;

function FactsText(const F: TSizeFacts): string;
begin
  Result := Format('size %dx%d, floor %dx%d, preferred %dx%d',
    [F.W, F.H, F.MinW, F.MinH, F.PrefW, F.PrefH]);
end;

function SameFacts(const A, B: TSizeFacts): Boolean;
begin
  Result := (A.W = B.W) and (A.H = B.H) and (A.MinW = B.MinW) and (A.MinH = B.MinH)
    and (A.PrefW = B.PrefW) and (A.PrefH = B.PrefH);
end;

function BirthText(ABirth: TBirth): string;
begin
  if ABirth = bwDesigned then Result := 'designed' else Result := 'code-built';
end;

{ ===== the sweeps ============================================================ }

procedure TAdvChartMeasureFontDpiTest.TestNoRegisteredControlSizesItselfFromTheScreen;
{ Each control makes the journey to the SAME PPI on two different screens, and has to come out
  the same size with the same floor both times. Two pairs: a form shown at 168 PPI on a 96 and
  on a 168 desktop, and a plain 96-PPI form on a 72 against a real 96. }
var
  names, differ, unbuilt: TStringList;
  i, swept: Integer;
  cls: TPersistentClass;
  a, b: TSizeFacts;
  err: string;
  birth: TBirth;

  procedure Pair(AScreenA, AScreenB, APPI: Integer);
  begin
    if not FactsOf(TControlClass(cls), AScreenA, APPI, birth, a, err) then
    begin
      if unbuilt.IndexOf(names[i] + ' -- ' + err) < 0 then
        unbuilt.Add(names[i] + ' -- ' + err);
      Exit;
    end;
    if not FactsOf(TControlClass(cls), AScreenB, APPI, birth, b, err) then
    begin
      if unbuilt.IndexOf(names[i] + ' -- ' + err) < 0 then
        unbuilt.Add(names[i] + ' -- ' + err);
      Exit;
    end;
    if not SameFacts(a, b) then
      differ.Add(Format('%s (%s) at %d PPI: on a %d-PPI screen %s; on a %d-PPI screen %s',
        [names[i], BirthText(birth), APPI, AScreenA, FactsText(a), AScreenB, FactsText(b)]));
  end;

begin
  names := TStringList.Create;
  differ := TStringList.Create;
  unbuilt := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    AssertTrue('the design-registry parser found the palette entry',
      names.IndexOf('TTyAdvanceChart') >= 0);
    swept := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if cls = nil then Continue;
      if not cls.InheritsFrom(TControl) then Continue;
      if cls.InheritsFrom(TCustomForm) then Continue;
      Inc(swept);
      for birth := Low(TBirth) to High(TBirth) do
      begin
        Pair(96, 168, 168);
        Pair(72, 96, 96);
      end;
    end;
    AssertTrue(Format('the sweep must cover the registrations, and it covered %d classes',
      [swept]), swept >= 1);
    AssertEquals('controls that could not be built for the sweep (each one is a control'
      + ' this guard does NOT cover):' + LineEnding + unbuilt.Text, 0, unbuilt.Count);
    AssertEquals('controls whose size depends on the SCREEN''s PPI and not only on their'
      + ' own:' + LineEnding + differ.Text, 0, differ.Count);
  finally
    unbuilt.Free;
    differ.Free;
    names.Free;
  end;
end;

procedure TAdvChartMeasureFontDpiTest.TestEveryRegisteredControlScalesItsSizeWithThePPI;
{ A form shown at 192 PPI on a 192-PPI desktop has to give every control twice the box, and
  twice the floor, of its 96-PPI twin. The tolerance catches a size out by a row height or a
  whole font, not by a pixel. }
var
  names, bad, unbuilt: TStringList;
  i, swept: Integer;
  cls: TPersistentClass;
  lo, hi: TSizeFacts;
  err: string;
  birth: TBirth;

  procedure Scales(const AWhat: string; ALo, AHi: Integer);
  var
    want, tol: Integer;
  begin
    if (ALo <= 0) and (AHi <= 0) then Exit;
    want := 2 * ALo;
    tol := Max(4, want div 10);
    if Abs(AHi - want) > tol then
      bad.Add(Format('%s (%s) %s: %d at 96 PPI, so about %d at 192 PPI, but it is %d',
        [names[i], BirthText(birth), AWhat, ALo, want, AHi]));
  end;

begin
  names := TStringList.Create;
  bad := TStringList.Create;
  unbuilt := TStringList.Create;
  try
    CollectRegisteredClassNames(names);
    swept := 0;
    for i := 0 to names.Count - 1 do
    begin
      cls := GetClass(names[i]);
      if cls = nil then Continue;
      if not cls.InheritsFrom(TControl) then Continue;
      if cls.InheritsFrom(TCustomForm) then Continue;
      Inc(swept);
      for birth := Low(TBirth) to High(TBirth) do
      begin
        if not FactsOf(TControlClass(cls), 96, 96, birth, lo, err) then
        begin
          unbuilt.Add(names[i] + ' -- ' + err);
          Continue;
        end;
        if not FactsOf(TControlClass(cls), 192, 192, birth, hi, err) then
        begin
          unbuilt.Add(names[i] + ' -- ' + err);
          Continue;
        end;
        if not (lo.Align in [alTop, alBottom, alClient]) then
        begin
          Scales('width', lo.W, hi.W);
          Scales('width floor', lo.MinW, hi.MinW);
          Scales('preferred width', lo.PrefW, hi.PrefW);
        end;
        if not (lo.Align in [alLeft, alRight, alClient]) then
        begin
          Scales('height', lo.H, hi.H);
          Scales('height floor', lo.MinH, hi.MinH);
          Scales('preferred height', lo.PrefH, hi.PrefH);
        end;
      end;
    end;
    AssertTrue(Format('the sweep must cover the registrations, and it covered %d classes',
      [swept]), swept >= 1);
    AssertEquals('controls that could not be built for the sweep:' + LineEnding
      + unbuilt.Text, 0, unbuilt.Count);
    AssertEquals('controls whose size does not follow their PPI:' + LineEnding + bad.Text,
      0, bad.Count);
  finally
    unbuilt.Free;
    bad.Free;
    names.Free;
  end;
end;

initialization
  RegisterTest(TAdvChartMeasureFontDpiTest);
end.
