// MapDecorator - a disposable instrument, not a feature.
//
// WHY THIS FILE EXISTS. The game died three times on 2026-09-02, always at
// Openplanet.dll+0x51ae3 (access violation), an offset that appears nowhere in
// the previous 45 days of Windows crash reports. The second death was
// attributable: the last line of the log was MapDecorator's own "Invalid
// address for member ID 03057010" warning, one second before the process went.
// The third was not: the log said "MapDecorator 0.3.4 loaded" and then nothing
// at all, for six seconds, until the game was gone.
//
// A survey that says nothing on its way down cannot be told from a survey that
// was never asked to run. That is the entire problem, and reading the source
// again does not solve it: every field the scan touches has since been checked
// against Openplanet.h and against real usage in installed plugins, and they
// all come back clean. The fault is somewhere the source does not show.
//
// So each step now writes the VALUE it just read, before attempting the next
// read. Whatever the last line in the log turns out to be, it names the step
// that killed the process - or, if it is still "loaded", it clears the survey
// completely and the search moves elsewhere.
//
// DELETE THIS FILE, and every Diag() call with it, once the fault is named. It
// is an instrument with a date on it, not part of the design.

// Flip to false to silence the instrument without removing the calls.
const bool c_Diag = true;

// Lines kept for the Debug tab's Log panel, oldest first. Capped so a long
// session cannot grow this without bound - the game log stays the full
// record, this buffer is only what fits on screen.
const uint c_LogCap = 200;
array<string> g_LogLines;

// Whether Diag()'s per-block trace lines also land in the panel. Off by
// default: those lines fire once per block scanned and would drown the
// startup/scan lines the Log fold exists to show. They always reach the game
// log regardless, through Diag()'s own print().
bool g_Verbose = false;

// Appends one line to the capped buffer, dropping the oldest when full.
void AddLogLine(const string &in line)
{
	g_LogLines.InsertLast(line);
	if (g_LogLines.Length > c_LogCap) {
		g_LogLines.RemoveAt(0);
	}
}

// The one place that both feeds the Debug tab's Log panel and writes to the
// game log, so the two never drift apart. Everything outside this file that
// used to call print() directly should call this instead.
void Log(const string &in line)
{
	AddLogLine(line);
	print(line);
}

// Deliberately one line per step and one value per line. A trace that batches
// its output loses exactly the part that matters: the last step before the
// crash is the one that never gets flushed.
void Diag(const string &in step)
{
	if (!c_Diag) return;
	string line = "[dg] " + step;
	print(line);
	if (g_Verbose) AddLogLine(line);
}
