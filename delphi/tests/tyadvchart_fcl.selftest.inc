{ Section selftest: Esc itself, on a\b, U+56FD, U+1F600 (a surrogate pair) and a tab. }

procedure SectionSelfTest;
begin
  BeginSection('selftest');
  NextCase;
  Line(Esc('a\b'));
  NextCase;
  Line(Esc(#$E5#$9B#$BD));
  NextCase;
  Line(Esc(#$F0#$9F#$98#$80));
  NextCase;
  Line(Esc(#9));
end;
