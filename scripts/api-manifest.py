#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Record the chart control's public interface and check it against the recorded list.

    python scripts/api-manifest.py --write      rewrite scripts/api-manifest.txt
    python scripts/api-manifest.py --check      take it now, compare, print the diff and exit 1 if it differs
    python scripts/api-manifest.py --selftest   run the extraction on a small embedded class

WHAT IT READS
-------------
The `public` and `published` sections of TTyCustomAdvanceChart and TTyAdvanceChart in
source/tyControls.AdvanceChart.pas, and the `RequiredPkgs` of tyadvancechart.lpk. Each member
(method, constructor, destructor, property, field) is one line with its directives
(`overload; virtual;`), comments dropped, whitespace squeezed to one space, and the type aliases
FPC treats as one type normalised (QWord -> UInt64 ...), so renaming an alias in the sources
does not change the list. The lines of a section are sorted.

WHAT IT IS FOR
--------------
The syntax rewrite must not change the public interface on Lazarus; every task of it ends with
`--check`. A line that changes is a change to the interface, or a spelling the rewrite must not
touch: look at the diff, do not --write it away.
"""
import difflib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'source', 'tyControls.AdvanceChart.pas')
LPK = os.path.join(ROOT, 'tyadvancechart.lpk')
MANIFEST = os.path.join(ROOT, 'scripts', 'api-manifest.txt')

CLASSES = ('TTyCustomAdvanceChart', 'TTyAdvanceChart')
SECTIONS = ('public', 'published')

ALIASES = {
    'qword': 'UInt64', 'pqword': 'PUInt64', 'ptrint': 'NativeInt', 'ptruint': 'NativeUInt',
    'sizeint': 'NativeInt', 'longword': 'Cardinal', 'longint': 'Integer',
}
ALIAS_RE = re.compile(r'\b(' + '|'.join(ALIASES) + r')\b', re.IGNORECASE)

VISIBILITY_RE = re.compile(r'^(?:strict\s+)?(private|protected|public|published)\b', re.IGNORECASE)
MEMBER_RE = re.compile(
    r'^(?:(?:class\s+)?(?:procedure|function)|constructor|destructor|property)\b'
    r'|^[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*\s*:(?!=)', re.IGNORECASE)
# what may follow a member as a `;`-terminated piece of its own
DIRECTIVE_RE = re.compile(
    r'^(?:overload|virtual|abstract|override|reintroduce|inline|static|dynamic|final|deprecated|'
    r'platform|experimental|cdecl|stdcall|register|safecall|pascal|default|message|dispid|'
    r'stored|nodefault|index|read|write|implements|external|varargs|unsafe)\b', re.IGNORECASE)


def strip_comments(src):
    """Blank out { } (nesting), (* *) and // comments, keeping string literals."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "'":
            j = i + 1
            while j < n and src[j] != "'":
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
        elif c == '{':
            depth, j = 1, i + 1
            while j < n and depth:
                if src[j] == '{':
                    depth += 1
                elif src[j] == '}':
                    depth -= 1
                j += 1
            out.append(' ')
            i = j
        elif src.startswith('(*', i):
            j = src.find('*)', i + 2)
            j = n if j < 0 else j + 2
            out.append(' ')
            i = j
        elif src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def class_body(text, name):
    """The text between `name = class(...)` and its closing `end;` (comment-free input)."""
    m = re.search(r'\b' + re.escape(name) + r'\s*=\s*class\s*\(', text, re.IGNORECASE)
    if not m:
        raise SystemExit('class %s not found' % name)
    i, n, depth = m.end(), len(text), 1
    while i < n and depth:               # skip the ancestor list
        depth += {'(': 1, ')': -1}.get(text[i], 0)
        i += 1
    start, nest = i, 0
    tok = re.compile(r"'[^']*'|\b(record|object|end)\b", re.IGNORECASE)
    for t in tok.finditer(text, start):
        w = (t.group(1) or '').lower()
        if w in ('record', 'object'):
            nest += 1
        elif w == 'end':
            if nest == 0:
                return text[start:t.start()]
            nest -= 1
    raise SystemExit('class %s has no end' % name)


def split_pieces(body):
    """Split at `;` outside strings, parentheses, brackets and records."""
    pieces, cur, depth, i, n = [], [], 0, 0, len(body)
    word = re.compile(r'[A-Za-z_]\w*')
    while i < n:
        c = body[i]
        if c == "'":
            j = body.find("'", i + 1)
            j = n - 1 if j < 0 else j
            cur.append(body[i:j + 1])
            i = j + 1
        elif c in '([':
            depth += 1
            cur.append(c)
            i += 1
        elif c in ')]':
            depth -= 1
            cur.append(c)
            i += 1
        elif c.isalpha() or c == '_':
            w = word.match(body, i).group(0)
            if w.lower() in ('record', 'object'):
                depth += 1
            elif w.lower() == 'end':
                depth -= 1
            cur.append(w)
            i += len(w)
        elif c == ';' and depth == 0:
            pieces.append(''.join(cur))
            cur = []
            i += 1
        else:
            cur.append(c)
            i += 1
    if ''.join(cur).strip():
        pieces.append(''.join(cur))
    return pieces


def normalise(s):
    s = re.sub(r'\s+', ' ', s).strip()
    return ALIAS_RE.sub(lambda m: ALIASES[m.group(1).lower()], s)


def members(text, name):
    """{section: [member line, ...]} of the public and published sections of class `name`."""
    result = dict((s, []) for s in SECTIONS)
    section, last = None, None
    for piece in split_pieces(class_body(strip_comments(text), name)):
        piece = piece.strip()
        m = VISIBILITY_RE.match(piece)
        if m:
            section, last = m.group(1).lower(), None
            piece = piece[m.end():].strip()
        if not piece:
            continue
        if MEMBER_RE.match(piece):
            if section in result:
                result[section].append([piece])
                last = result[section][-1]
            else:
                last = None
        elif DIRECTIVE_RE.match(piece):
            if last is not None:
                last.append(piece)
        elif section in result:
            raise SystemExit('%s %s: cannot place "%s"' % (name, section, normalise(piece)[:80]))
    return dict((s, sorted(normalise('; '.join(p) + ';') for p in lst)) for s, lst in result.items())


def requires(lpk_text):
    m = re.search(r'<RequiredPkgs>(.*?)</RequiredPkgs>', lpk_text, re.DOTALL)
    return re.findall(r'<PackageName\s+Value="([^"]*)"', m.group(1)) if m else []


def lines_of(src_text, lpk_text):
    lines = ['requires: ' + p for p in requires(lpk_text)]
    counts = ['requires: %d' % len(lines)]
    for cls in CLASSES:
        found = members(src_text, cls)
        for sec in SECTIONS:
            lines += ['%s %s: %s' % (cls, sec, x) for x in found[sec]]
            counts.append('%s %s: %d' % (cls, sec, len(found[sec])))
    return lines, counts


def read(path):
    with open(path, 'rb') as f:
        return f.read().decode('utf-8').replace('\r\n', '\n')


def current():
    return lines_of(read(SRC), read(LPK))


SELFTEST_SRC = """
unit u;
interface
type
  TTyDemo = class(TObject)
  private
    FHidden: QWord;
    procedure Hide(A: Integer);
  public
    { a comment; with a semicolon }
    constructor Create(AOwner: TComponent); override;
    function Sum(const A: QWord;
      B: PtrInt): Integer; overload; // trailing
    FPlain, FOther: LongInt;
  published
    property Count: LongWord read FCount
      write SetCount default 0;
  end;
"""


def selftest():
    found = members(SELFTEST_SRC, 'TTyDemo')
    assert len(found['public']) == 3, found
    assert len(found['published']) == 1, found
    assert not any('Hide' in x or 'FHidden' in x for s in SECTIONS for x in found[s]), found
    assert 'function Sum(const A: UInt64; B: NativeInt): Integer; overload;' in found['public'], found
    assert 'FPlain, FOther: Integer;' in found['public'], found
    assert 'constructor Create(AOwner: TComponent); override;' in found['public'], found
    assert found['published'] == ['property Count: Cardinal read FCount write SetCount default 0;'], found
    assert not any('QWord' in x for x in found['public']), found
    print('selftest ok')


def main(argv):
    if len(argv) != 2 or argv[1] not in ('--write', '--check', '--selftest'):
        print(__doc__)
        return 2
    if argv[1] == '--selftest':
        selftest()
        return 0
    lines, counts = current()
    if argv[1] == '--write':
        with open(MANIFEST, 'wb') as f:
            f.write(('\n'.join(lines) + '\n').encode('utf-8'))
        print('wrote %s (%d lines)' % (os.path.relpath(MANIFEST, ROOT), len(lines)))
        print('\n'.join(counts))
        return 0
    recorded = read(MANIFEST).split('\n')
    if recorded and recorded[-1] == '':
        recorded.pop()
    if recorded == lines:
        print('api manifest ok')
        print('\n'.join(counts))
        return 0
    for d in difflib.unified_diff(recorded, lines, 'recorded', 'current', lineterm='', n=0):
        print(d)
    print('api manifest differs: %d recorded, %d now' % (len(recorded), len(lines)))
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))
