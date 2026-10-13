// MapDecorator - the plugin's own log, fed to both the game log and the Debug
// tab's Log panel.
//
// CONTROLLER. Kept at global scope, like the entry points in MapDecorator.as,
// so every layer that reports a step calls Log() without a namespace.
//
// It used to share a file with Diag(), the crash instrument of 2026-09-02.
// That instrument is gone (MD2, 2026-10-13); this half was never part of it:
// it is the journal the user reads, not a trace with a date on it.

// Lines kept for the Debug tab's Log panel, oldest first. Capped so a long
// session cannot grow this without bound - the game log stays the full
// record, this buffer is only what fits on screen.
const uint c_LogCap = 200;
array<string> g_LogLines;

// Appends one line to the capped buffer, dropping the oldest when full.
void AddLogLine(const string &in line)
{
	g_LogLines.InsertLast(line);
	if (g_LogLines.Length > c_LogCap) {
		g_LogLines.RemoveAt(0);
	}
}

// The one place that both feeds the Debug tab's Log panel and writes to the
// game log, so the two never drift apart. Everything that used to call
// print() directly should call this instead.
void Log(const string &in line)
{
	AddLogLine(line);
	print(line);
}
