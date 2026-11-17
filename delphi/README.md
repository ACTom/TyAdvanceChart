# delphi/

Work in progress: what a Delphi build of `TTyAdvanceChart` needs besides `source/`, and the programs that
check it. The chart cannot be used from Delphi yet: the control unit and five others (Render, Images,
DirtyRect, ToolboxDlg, KeyNav) need the LCL or BGRABitmap, and seven units are still missing (see the
last section). Lazarus never sees this folder: it is on none of the packages' or projects' search paths,
and a Lazarus build uses FPC's own units.

## fcl/

Delphi-only units under the names of the Free Pascal units the chart's sources use, so that the same
`uses` clauses compile with both compilers. Each unit's header says what it is and how it differs.

- `fpjson`, `jsonscanner`, `jsonreader`, `jsonparser`: ports of Free Pascal 3.2.2's fcl-json
  (`packages/fcl-json/src/`), under its licence (see `THIRD-PARTY-NOTICES.md`).
- `DOM`, `XMLRead`: a small reader of this project's own with fcl-xml's names, for the part the map
  reader (`Geo`, `GeoSvg`) uses; it builds a read-only tree. Not a port of FPC's code.
- `dynlibs`: FPC's `LoadLibrary`, `GetProcedureAddress` and `UnloadLibrary` over `Winapi.Windows`
  (`Data` reaches kernel32's time zone routines through it). Windows only.
- `tyfclnum`: every conversion between floating-point numbers and text that the JSON ports make; for now
  Delphi's RTL with invariant format settings.
- `tyfclutf8`: every conversion of bytes read from a stream into a string in the JSON ports.

## Known differences from FPC

- JSON object member names are not cut at 255 bytes. FPC keeps them as `ShortString`s: a longer name is
  cut, and two names that differ only after byte 255 are a duplicate, which raises.
- Each `\uXXXX` escape is one UTF-16 code unit, appended as it is: a valid surrogate pair stays a pair, an
  unpaired surrogate is kept, `\u0000` is kept as `#0`. FPC 3.2.2 damages a valid pair that follows an odd
  number of escapes, drops unpaired surrogates and drops `\u0000`.
- Bytes read from a stream are decoded as UTF-8, and an invalid sequence becomes U+FFFD; nothing raises.
  FPC keeps the raw bytes in its string.
- `DumpJSON` writes UTF-8, as FPC's does; an unpaired surrogate the port kept comes out as the encoder's
  replacement character (`EF BF BD`), while `AsJSON` keeps the unit.
- Conversions between floating-point numbers and text may differ in the last digits and in a few edge
  cases; whether to match FPC digit for digit is not decided yet. Examples from the transcript: dcc64
  writes 0.1 as `1.0000000000000000E-001` where FPC writes `1.0000000000000001E-001` (40 inputs differ in
  this way under dcc64, 4 under dcc32; both write -0.0 without its sign); dcc32 raises `EJSONParser` on
  `1e999` and `-1e999`, which FPC and dcc64 read as +Inf and -Inf; dcc64 reads `1.7976931348623157e308`
  one bit lower than FPC. In all, 57 informational lines of the transcript differ under dcc32 and 124
  under dcc64, the cases of the items above included.
- Two quirks of FPC's lists on the JSON array side are not copied: setting `TJSONArray.Items[i]` to the
  object already there frees it in FPC; `Move(i, i)` with `i` out of range raises in FPC.
- `XMLRead` implements only the option set the chart uses (PreserveWhitespace and ExpandEntities on,
  Namespaces and Validate off) and raises `EXMLReadError` for any other. It also raises, where FPC reads
  on, for an XML 1.1 declaration; in an internal subset, for parameter entities, external entity
  declarations and ELEMENT, ATTLIST and NOTATION declarations (only internal general entity declarations,
  comments and processing instructions are read); and for elements nested deeper than 4096 levels. Its
  error messages are its own.
- `TTyHashList` (`source/tyControls.AdvanceChart.HashList.pas`, FPC's `TFPHashList` under FPC) is keyed
  by `string` under Delphi, so its names are not cut at 255 bytes.

## tests/

- `tyadvchart_fcl.dpr` and its `.inc` files: the transcript. It prints one line per result for a fixed
  set of JSON and XML inputs, and is built with FPC (FPC's own units) and with dcc32 and dcc64 (the
  ports). Every compiler must print `expected/fcl.txt`, except that for dcc a line starting with `~ ` is
  informational: a difference there is counted, not failed.
- `tyadvchart_values.dpr`: Delphi only. Assertions on what the transcript cannot show: the Delphi branches
  of chart helpers, the JSON ports' strings and escapes, the XML reader's limits, `TTyHashList`,
  `dynlibs`. It prints `DELPHI VALUES OK` as its last line.
- `expected/fcl.txt`: FPC's output of the transcript.

## Running

From the repository root, on Windows with Delphi's `dcc32`/`dcc64` and FPC 3.2.2 (Lazarus's):

```
python -B scripts/delphi-probe.py --fcl      # the transcript with FPC, dcc32 and dcc64
python -B scripts/delphi-probe.py --values   # the values program with dcc32 and dcc64
python -B scripts/delphi-probe.py            # the units that need only the RTL
```

`--bin` and `--fpc` point at other installations. After changing the transcript program, regenerate
`expected/fcl.txt` with `python -B scripts/delphi-probe.py --fcl --write-expected` (it runs FPC only and
writes its output), then review the diff before committing it.

## Still missing

`python -B scripts/delphi-probe.py --standins DIR --all` compiles every unit under `source/` except the
six above (110 units) with both compilers. Seven units it needs have no Delphi implementation yet:
`Graphics`, `tyControls.Painter`, `tyControls.FontUnits`, `tyControls.SubPixel`, `tyControls.StrConsts`,
`tyControls.Css.AddOns` and `tyControls.Css.Catalog`. `DIR` is a folder of compile-only placeholders for
them, kept outside the repository: they compile, but are wrong at run time.
