{ Switches range and overflow checks off for the region that follows; used as a pair with ChecksBack.inc }
{$IFOPT R+}{$DEFINE TY_CHART_R_ON}{$R-}{$ENDIF}
{$IFOPT Q+}{$DEFINE TY_CHART_Q_ON}{$Q-}{$ENDIF}
