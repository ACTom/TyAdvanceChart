# delphi/

Work in progress: what a Delphi build of `TTyAdvanceChart` needs besides `source/`, and the programs that
check it. The chart cannot be used from Delphi yet: the control unit and five others (Render, Images,
DirtyRect, ToolboxDlg, KeyNav) need the LCL or BGRABitmap, and seven units are still missing (see the
last section). Lazarus never sees this folder: it is on none of the packages' or projects' search paths,
and a Lazarus build uses FPC's own units.

## fcl/

Delphi-only units: under the names of the Free Pascal units the chart's sources use, so that the same
`uses` clauses compile with both compilers, and two helper units of this project's own that the JSON
ports use. Each unit's header says what it is and how it differs from FPC's.

- `fpjson`, `jsonscanner`, `jsonreader`, `jsonparser`: ports of Free Pascal 3.2.2's fcl-json
  (`packages/fcl-json/src/`), under its licence (`COPYING.FPC` here; see `THIRD-PARTY-NOTICES.md`).
- `DOM`, `XMLRead`: a small reader of this project's own with fcl-xml's names, for the part the map
  reader (`Geo`, `GeoSvg`) uses; it builds a read-only tree. Not a port of FPC's code.
- `dynlibs`: FPC's `LoadLibrary`, `GetProcedureAddress` and `UnloadLibrary` over `Winapi.Windows`
  (`Data` reaches kernel32's time zone routines through it). Windows only.
- `tyfclnum` (this project's own, no FPC unit of that name): every conversion between floating-point
  numbers and text that the JSON ports make; for now Delphi's RTL with invariant format settings.
- `tyfclutf8` (this project's own, no FPC unit of that name): every conversion of bytes read from a
  stream into a string in the JSON ports.

## Known differences from FPC

- JSON object member names are not cut at 255 bytes. FPC keeps them as `ShortString`s: a longer name is
  cut, and two names that differ only after byte 255 are a duplicate, which raises.
- Each `\uXXXX` escape is one UTF-16 code unit, appended as it is: a valid surrogate pair stays a pair, an
  unpaired surrogate is kept, `\u0000` is kept as `#0`. FPC 3.2.2 damages a valid pair that follows an odd
  number of escapes, drops unpaired surrogates and drops `\u0000`.
- `JSONStringToString` drops the character after an unknown escape, as FPC's drops an ASCII one
  (`a\qb` gives `ab`); a non-ASCII character goes as a whole, where FPC's drops only its first UTF-8
  byte and leaves the rest as invalid bytes.
- The options `joUTF8` and `UseUTF8` change nothing: the ports' strings are UTF-16 whatever they say.
- Bytes read from a stream are decoded as UTF-8, and an invalid sequence becomes U+FFFD; nothing raises.
  FPC keeps the raw bytes in its string.
- `DumpJSON` writes UTF-8, as FPC's does; an unpaired surrogate the port kept comes out as the encoder's
  replacement character (`EF BF BD`), while `AsJSON` keeps the unit.
- A `TJSONString`'s `AsInteger`, `AsInt64`, `AsQWord`, `AsFloat` and `AsBoolean` use Delphi's
  conversions where FPC's are built on `Val`. The plain shapes agree (`12`, ` 12`, `12 `, `1.5`, `$1F`,
  `0x1F`, the empty string; the transcript compares them); others do not: FPC reads `%101` as 5 and `&17`
  as 15, wraps `2147483648` to an Integer, accepts a leading tab and a trailing line feed, reads `e5` as
  0, and raises for `Nan` as a Boolean, where the port raises `EConvertError` (and reads `Nan` as True).
- Floating-point numbers and text do not yet convert as in FPC; matching FPC digit for digit is the
  subject of a later plan. Measured on this branch with Delphi 13: under dcc64 a Double does not always
  survive `AsJSON` followed by `GetJSON` (87,410 of 199,957 pseudo-random doubles changed, and 4 of 48
  number literals of the gallery and the transcript; for example `8.3` is written
  `8.3000000000000013E+000` and reads back one unit in the last place off); under dcc32 and FPC none did.
  Out-of-range literals (`1e309`, `2e308`, `1e400`, `-1e400`, `1.8e308`, `1e4000`, ...) raise
  `EJSONParser` under both Delphi compilers, where FPC reads them as +Inf or -Inf; `1e999` and `-1e999`
  are the ones dcc64 reads as +Inf and -Inf (dcc32 raises for them too). Both Delphi compilers write `-0.0` without its sign. The transcript shows
  these on its informational lines, and pins what each compiler prints there (see `tests/` below).
- Two quirks of FPC's lists on the JSON array side are not copied: setting `TJSONArray.Items[i]` to the
  object already there frees it in FPC; `Move(i, i)` with `i` out of range raises in FPC.
- Deliberate limits, where FPC has none, each raising the unit's own exception instead of overflowing the
  stack (the readers and the destructors recurse per level, and a Delphi program's default stack
  overflows at depths FPC survives): JSON arrays and objects nest at most 1000 levels (`EJSONParser`);
  XML elements at most 4096 levels and XML entity references at most 64 levels (`EXMLReadError`).
- The four JSON ports are compiled without range and overflow checks (`{$R-}{$Q-}`), as FPC builds its
  fcl-json, whatever the project sets: with them on, `TJSONInt64Number` of 2^40 gives `AsInteger` 0 as
  in FPC, not `ERangeError`.
- `XMLRead` implements only the option set the chart uses (PreserveWhitespace and ExpandEntities on,
  Namespaces and Validate off) and raises `EXMLReadError` for any other. It also raises, where FPC reads
  on, for an XML 1.1 declaration; in an internal subset, for parameter entities, external entity
  declarations and ELEMENT, ATTLIST and NOTATION declarations (only internal general entity declarations,
  comments and processing instructions are read); and beyond the limits above. FPC applies the defaults
  of an internal-subset `<!ATTLIST>` (measured: `<!ATTLIST svg id CDATA "dflt">` gives the root
  `id="dflt"`); the stand-in rejects such a declaration, a known candidate for later. Its name-character
  tables follow XML 1.0 (fifth edition) and may differ from FPC's for some names outside ASCII. Its
  error messages are its own.
- `TTyHashList` (`source/tyControls.AdvanceChart.HashList.pas`, FPC's `TFPHashList` under FPC) is keyed
  by `string` under Delphi, so its names are not cut at 255 bytes.

## tests/

- `tyadvchart_fcl.dpr` and its `.inc` files: the transcript. It prints one line per result for a fixed
  set of JSON and XML inputs, and is built with FPC (FPC's own units) and with dcc32 and dcc64 (the
  ports). Every compiler must print `expected/fcl.txt`, except that for dcc a line starting with `~ ` is
  informational: the informational lines a compiler prints differently are pinned, and must be exactly
  those of `expected/fcl.dcc32.txt` or `expected/fcl.dcc64.txt` (line number, tab, the line it prints).
  A line that starts to differ, stops differing or differs otherwise fails the run.
- `tyadvchart_values.dpr`: Delphi only. Assertions on what the transcript cannot show: the Delphi branches
  of chart helpers, the JSON ports' strings, escapes and limits, the XML reader's limits and entity
  expansion, `TTyHashList`, `dynlibs`. It prints `DELPHI VALUES OK` as its last line.
- `expected/fcl.txt`: FPC's output of the transcript; `expected/fcl.dcc32.txt` and `fcl.dcc64.txt`: the
  informational lines each Delphi compiler prints differently.

## Running

From the repository root, on Windows with Delphi's `dcc32`/`dcc64` and FPC 3.2.2 (Lazarus's):

```
python -B scripts/delphi-probe.py --fcl      # the transcript with FPC, dcc32 and dcc64
python -B scripts/delphi-probe.py --values   # the units that need only the RTL, then the values program
python -B scripts/delphi-probe.py            # the units that need only the RTL
```

`--bin` and `--fpc` point at other installations. After changing the transcript program, regenerate the
expected files with `python -B scripts/delphi-probe.py --fcl --write-expected` (it runs all three
compilers and writes `expected/fcl.txt` and the two pinned files, or nothing when a compared line of
dcc32 or dcc64 differs from FPC's), then review the diff before committing it.

## Still missing

`python -B scripts/delphi-probe.py --standins DIR --all` compiles every unit under `source/` except the
six above (110 units) with both compilers. Seven units it needs have no Delphi implementation yet:
`Graphics`, `tyControls.Painter`, `tyControls.FontUnits`, `tyControls.SubPixel`, `tyControls.StrConsts`,
`tyControls.Css.AddOns` and `tyControls.Css.Catalog`. `DIR` is a folder of compile-only placeholders for
them, kept outside the repository: they compile, but are wrong at run time.
