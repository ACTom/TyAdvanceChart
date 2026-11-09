<#
  Rebuild docs/gallery/advchart: screenshots of the AdvChart example, in English, light and
  dark, one per page of its page control -- and docs/images/advchart.png, the README's picture.

  Neither the example nor the packages are touched. The example is copied to
  .gallery-build/advchart/ (git-ignored, at the same depth as examples/advchart/ so its
  relative paths still resolve), its program gets one more unit -- tyGalleryCapture.pas, which
  takes the pictures and closes the program -- and the copy is built and run.

  The capture unit is TyControls' tools/gallery/tyGalleryCapture.pas. It is taken from the
  TyControls checkout named by -TyControls, else by TY_CORE_DIR (the checkout the tests read
  too), else from a ty-controls or TyControls folder next to this repository.

  The window opens on the desktop while this runs (a few seconds); leave the mouse alone.
  Windows only.

  Usage, from the repo root:
    powershell -File scripts/make-gallery.ps1
    powershell -File scripts/make-gallery.ps1 -BuildOnly            # build the copy, no window
    powershell -File scripts/make-gallery.ps1 -NoBuild              # re-shoot, no rebuild

  -Pcp <dir>         a Lazarus config directory for lazbuild (--pcp) in which the tycontrols and
                     tyadvancechart packages are already compiled; lazbuild then skips the
                     dependencies. Without it lazbuild uses your normal Lazarus configuration.
  -Lazbuild <exe>    lazbuild.exe, when it is not on PATH or at C:\lazarus.
  -TyControls <dir>  the TyControls checkout that holds tools/gallery/tyGalleryCapture.pas.
#>
param(
  [string]$Pcp = '',
  [string]$Lazbuild = '',
  [string]$TyControls = '',
  [switch]$NoBuild,
  [switch]$BuildOnly,
  [int]$Timeout = 180
)
$ErrorActionPreference = 'Stop'
$root    = Split-Path $PSScriptRoot -Parent
$name    = 'advchart'
$example = Join-Path $root "examples\$name"
$stage   = Join-Path $root '.gallery-build'
$out     = Join-Path $root "docs\gallery\$name"
$utf8    = New-Object System.Text.UTF8Encoding($false)

# The README's picture: a copy of a gallery picture under docs/images, so a README without the
# gallery still has it. Refreshed on every run.
$readmePicks = [ordered]@{
  'advchart.png' = 'main-light.png'
}

function Resolve-Capture {
  if ($TyControls -ne '') { $dirs = @($TyControls) }
  elseif ($env:TY_CORE_DIR) { $dirs = @($env:TY_CORE_DIR) }
  else { $dirs = @('ty-controls', 'TyControls' | ForEach-Object { Join-Path (Split-Path $root -Parent) $_ }) }
  foreach ($d in $dirs) {
    $f = Join-Path $d 'tools\gallery\tyGalleryCapture.pas'
    if (Test-Path $f) { return $f }
  }
  throw "tools\gallery\tyGalleryCapture.pas is not in $($dirs -join ' or '): pass -TyControls <TyControls checkout> or set TY_CORE_DIR"
}

function Resolve-Lazbuild {
  if ($Lazbuild -ne '') { return $Lazbuild }
  $cmd = Get-Command lazbuild -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  if (Test-Path 'C:\lazarus\lazbuild.exe') { return 'C:\lazarus\lazbuild.exe' }
  throw 'lazbuild not found: pass -Lazbuild <path to lazbuild.exe>'
}

# Copy, add the capture unit, build. Returns the exe, or $null.
function Build-Copy($lb, $capture) {
  $dst = Join-Path $stage $name
  robocopy $example $dst /MIR /XD lib backup /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { Write-Warning "${name}: copy failed"; return $null }
  Copy-Item $capture $dst -Force
  $lpi = Get-ChildItem $dst -Filter *.lpi | Select-Object -First 1
  $lpr = Join-Path $dst ($lpi.BaseName + '.lpr')
  $text = [IO.File]::ReadAllText($lpr)
  if ($text -notmatch 'tyGalleryCapture') {
    $re = [regex]'(?i)\bInterfaces\s*,'
    if (-not $re.IsMatch($text)) { Write-Warning "${name}: no 'Interfaces,' in the program's uses"; return $null }
    [IO.File]::WriteAllText($lpr, $re.Replace($text, 'Interfaces, tyGalleryCapture,', 1), $utf8)
  }
  $lbArgs = @()
  if ($Pcp -ne '') { $lbArgs += "--pcp=$Pcp"; $lbArgs += '--skip-dependencies' }
  $lbArgs += '-B'; $lbArgs += $lpi.FullName
  $log = Join-Path $dst 'gallery-build.log'
  & $lb @lbArgs *> $log
  if ($LASTEXITCODE -ne 0) { Write-Warning "${name}: build failed, see $log"; return $null }
  return Find-Exe $dst
}

function Find-Exe($dir) {
  $exe = Get-ChildItem $dir -Recurse -Filter *.exe -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  return $exe
}

function Shoot($exe) {
  if (Test-Path $out) { Remove-Item $out -Recurse -Force }
  New-Item -ItemType Directory $out | Out-Null
  $env:TY_GALLERY_DIR = $out
  # the capture unit's other switches (TyControls' skin wall, page picks, steps before the first
  # picture) are not used for this example
  $env:TY_GALLERY_SKINS = ''
  $env:TY_GALLERY_PAGES = ''
  $env:TY_GALLERY_BEFORE = ''
  try {
    $p = Start-Process $exe.FullName -ArgumentList '--lang=en' -WorkingDirectory $exe.DirectoryName -PassThru
    if (-not $p.WaitForExit($Timeout * 1000)) {
      Stop-Process -Id $p.Id -Force
      Write-Warning "${name}: still running after $Timeout s, stopped"
    }
  } finally {
    Remove-Item Env:TY_GALLERY_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:TY_GALLERY_SKINS -ErrorAction SilentlyContinue
    Remove-Item Env:TY_GALLERY_BEFORE -ErrorAction SilentlyContinue
    Remove-Item Env:TY_GALLERY_PAGES -ErrorAction SilentlyContinue
  }
  $shots = @(Get-ChildItem $out -Filter *.png).Count
  # the log stays with the build copy, out of docs/
  $log = Join-Path (Join-Path $stage $name) 'capture.log'
  if (Test-Path (Join-Path $out 'capture.log')) { Move-Item (Join-Path $out 'capture.log') $log -Force }
  $bad = @()
  if (Test-Path $log) { $bad = @(Select-String -Path $log -Pattern 'FAILED|no Dark|BitBlt failed' | ForEach-Object { $_.Line }) }
  "{0,-22} {1,3} picture(s){2}" -f $name, $shots, $(if ($bad.Count) { '  ! ' + ($bad -join ' | ') } else { '' })
}

function Update-ReadmeImages {
  $dst = Join-Path $root 'docs\images'
  New-Item -ItemType Directory -Force $dst | Out-Null
  foreach ($k in $readmePicks.Keys) {
    $src = Join-Path $out $readmePicks[$k]
    if (Test-Path $src) { Copy-Item $src (Join-Path $dst $k) -Force }
    else { Write-Warning "README picture ${k}: $($readmePicks[$k]) is not in the gallery (a page renamed?)" }
  }
  "README pictures: $($readmePicks.Count) in docs\images"
}

# ---- run ------------------------------------------------------------------------------------

New-Item -ItemType Directory -Force $stage | Out-Null
if ($NoBuild) { $exe = Find-Exe (Join-Path $stage $name) }
else { $exe = Build-Copy (Resolve-Lazbuild) (Resolve-Capture) }
if ($null -eq $exe) { throw "${name}: nothing to run" }
if ($BuildOnly) { "{0,-22} built" -f $name; return }
Shoot $exe
Update-ReadmeImages
