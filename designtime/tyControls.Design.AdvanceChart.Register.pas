unit tyControls.Design.AdvanceChart.Register;
{$mode objfpc}{$H+}
{ The chart's design-time registration: its palette entry and icons, its component editor and
  the Option property editor. Until the chart moved to its own project these calls sat in
  TyControls' tyControls.Design (the palette), tyControls.Design.CompEditors and
  tyControls.Design.PropEditors; each is made here as it was made there, and the editors
  themselves are in tyControls.Design.AdvanceChart.Editor. }
interface

uses
  Classes, LResources, PropEdits, ComponentEditors,
  tyControls.AdvanceChart, tyControls.Design.AdvanceChart.Editor;

procedure Register;

implementation

procedure Register;
begin
  // The palette icons (a 24x24 PNG plus its _150 and _200 variants, packed by
  // scripts/gen-icons.ps1). The IDE looks each up by class name, so this MUST run
  // before RegisterComponents.
  {$I tyadvancechart_icons.lrs}
  // The same palette page as TyControls' shapes and its simple chart.
  RegisterComponents('TyControls Shapes & Charts', [TTyAdvanceChart]);
  // Double-clicking the chart opens the same option dialog its property editor
  // does. One verb, one code path -- a second entry point that assembled the
  // dialog its own way is how the two drift apart.
  RegisterComponentEditor(TTyAdvanceChart, TTyAdvanceChartEditor);
  // The chart's whole API is this one string, so it gets the biggest editor in the
  // package: SynEdit, catalog completion, a browsable reference and live diagnostics.
  // On the custom class (plan D2), so a third-party chart that publishes Option gets it too.
  RegisterPropertyEditor(TypeInfo(string), TTyCustomAdvanceChart, 'Option',
    TTyChartOptionProperty);
end;

end.
