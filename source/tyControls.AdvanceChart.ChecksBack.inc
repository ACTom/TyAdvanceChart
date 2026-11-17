{ Restores the range and overflow checks that ChecksOff.inc switched off; used as a pair with ChecksOff.inc }
{$IFDEF TY_CHART_R_ON}{$UNDEF TY_CHART_R_ON}{$R+}{$ENDIF}
{$IFDEF TY_CHART_Q_ON}{$UNDEF TY_CHART_Q_ON}{$Q+}{$ENDIF}
