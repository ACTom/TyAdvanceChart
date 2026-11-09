# Packs the chart's palette icons, designtime/icons/TTyAdvanceChart*.png, into
# designtime/tyadvancechart_icons.lrs, which tyControls.Design.AdvanceChart.Register includes
# before it registers the component. Same tool and same resource names as TyControls'
# scripts/gen-icons.ps1: lazres, one PNG resource per file, named after the file.
#
# The PNGs are committed. They were rendered by TyControls' tools/genicons before the chart
# moved out; this script only packs them.
#
#   powershell -File scripts/gen-icons.ps1 [-LazRes <path to lazres.exe>]
param([string]$LazRes = 'C:\lazarus\tools\lazres.exe')
$ErrorActionPreference = 'Stop'
$root  = Split-Path $PSScriptRoot -Parent
$icons = Join-Path $root 'designtime/icons'
$lrs   = Join-Path $root 'designtime/tyadvancechart_icons.lrs'

$classes = @('TTyAdvanceChart')
# base = 100% (24px), _150 = 150% (36px), _200 = 200% (48px). The IDE picks the variant
# matching the display scaling, so palette icons stay crisp instead of upscaling 24px.
$suffixes = @('', '_150', '_200')

# Drift guard: every class registered with RegisterComponents in designtime/*.pas has an
# icon here, and every icon here belongs to a registered class.
Write-Host '== checking icon set vs RegisterComponents =='
$designPas = @(Get-ChildItem -Path (Join-Path $root 'designtime') -Filter '*.pas' -File | Sort-Object Name)
if ($designPas.Count -eq 0) { throw "no design-time source found under $(Join-Path $root 'designtime')" }
# Read as real UTF-8: PS 5.1 `Get-Content -Raw` decodes via the ANSI codepage.
$design = ($designPas | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
$groups = [regex]::Matches($design, "RegisterComponents\s*\(\s*'[^']*'\s*,\s*\[(?<list>[^\]]+)\]")
if ($groups.Count -eq 0) { throw "could not find any RegisterComponents('...', [...]) in $($designPas.Name -join ', ')" }
$registered = @($groups | ForEach-Object {
  [regex]::Matches($_.Groups['list'].Value, 'TTy\w+') | ForEach-Object { $_.Value }
}) | Sort-Object -Unique
$missingIcon = @($registered | Where-Object { $_ -notin $classes })
$extraIcon   = @($classes    | Where-Object { $_ -notin $registered })
if ($missingIcon.Count -or $extraIcon.Count) {
  throw ("icon set out of sync with RegisterComponents." +
         " registered-but-no-icon: [$($missingIcon -join ', ')];" +
         " icon-but-not-registered: [$($extraIcon -join ', ')].")
}
Write-Host "  OK: $($registered.Count) registered component(s) all have icons"

Write-Host '== packing .lrs (3 sizes per class for HiDPI) =='
$pairs = New-Object System.Collections.Generic.List[string]
foreach ($c in $classes) {
  foreach ($sfx in $suffixes) {
    $name = "$c$sfx"
    $png = Join-Path $icons "$name.png"
    if (-not (Test-Path $png)) { throw "missing PNG: $png" }
    $pairs.Add(('{0}={1}' -f $png, $name))
  }
}
& $LazRes $lrs @pairs
if ($LASTEXITCODE -ne 0) { throw 'lazres failed' }
Write-Host "Packed $($pairs.Count) icon resources ($($classes.Count) class(es) x $($suffixes.Count) sizes) into $lrs"
