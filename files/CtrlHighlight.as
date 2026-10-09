// MapDecorator - the highlight probe, and nothing else.
//
// CONTROLLER, and a DISPOSABLE one. This file exists to answer a single
// question in game: does CGameEditorPluginMap::CustomSelectionCoords actually
// paint cells in the editor, and does it do it without taking the game down?
// When the answer is in, this file either grows into the real highlight or is
// deleted. It is not wired into the survey on purpose - nothing here runs
// unless the user presses the button.
//
// WHY IT EXISTS AT ALL. Writing the editor cursor does not highlight anything.
// That is measured, not assumed: the survey writes both cursors and reads them
// back, the log shows "plugin cursor now 24/15/15" and "block cursor now
// 24/15/15", and the editor showed nothing. The coordinate is written; it is
// simply not what the editor draws.
//
// WHY THIS IS NOT THE CRASH AGAIN. pluginMap.Blocks killed the game five
// times, and it lives on this same class. The difference is in Openplanet's
// own binding file, Openplanet4.json, which carries a flag the header does not
// print:
//
//     {"n":"Blocks",                "t":"MwFastBuffer<CGameCtnBlock@>", "c":1, "m":1}
//     {"n":"CustomSelectionCoords", "t":"MwFastBuffer<nat3>",                  "m":1}
//
// "c":1 is const. The buffer that faulted is const - consistent with a derived
// view computed on demand. This one is not const, so it is storage the editor
// keeps for the plugin to fill. That is an argument, not a proof, which is why
// every line below is traced.
//
// NOTHING IS DOCUMENTED. The ManiaScript reference lists CustomSelectionCoords,
// CustomSelectionRGB, ShowCustomSelection and HideCustomSelection with their
// signatures and no description at all, no example exists online or on this
// disk, and the RGB range is unstated. Whether Show must be called again after
// the coordinates change is therefore an open question this probe answers by
// trying it.

namespace Ctrl
{
	// Set once the probe has run, so the window can say whether it was tried.
	bool g_HighlightTried = false;

	// White. The range is undocumented; vec3 in this API is otherwise always
	// 0..1, and if the cell comes out black that is itself the answer.
	const vec3 c_HighlightRGB = vec3(1.0f, 1.0f, 1.0f);

	// Paints the block the survey is currently asking about.
	//
	// The buffer is never copied into a local. MwFastBuffer is a value type with
	// opAssign, so "auto b = pluginMap.CustomSelectionCoords" would very likely
	// hand back a COPY, and every Add would land in a temporary the editor never
	// reads - a silent no-op that looks exactly like a broken API. Every call
	// goes through the property, and every one is read back through it too.
	void HighlightCurrent()
	{
		Diag("hl: enter");
		if (!HasEditor()) {
			Diag("hl: no editor");
			return;
		}

		auto pluginMap = g_Editor.PluginMapType;
		if (pluginMap is null) {
			Diag("hl: PluginMapType is null");
			return;
		}

		auto block = Current();
		if (block is null) {
			Diag("hl: no current block");
			return;
		}

		g_HighlightTried = true;

		// Step 1. Read the buffer's length. This alone is what killed the game
		// on the other buffer, so it gets its own trace on both sides.
		Diag("hl 1: about to read CustomSelectionCoords.Length");
		uint before = pluginMap.CustomSelectionCoords.Length;
		Diag("hl 1: Length = " + before);

		// Step 2. Empty it, so the highlight is the current block and not the
		// whole history of blocks visited.
		if (before > 0) {
			Diag("hl 2: about to RemoveRange(0, " + before + ")");
			pluginMap.CustomSelectionCoords.RemoveRange(0, before);
			Diag("hl 2: cleared, Length = "
				+ pluginMap.CustomSelectionCoords.Length);
		} else {
			Diag("hl 2: already empty");
		}

		// Step 3. Add the one cell. The read-back is the whole point: if the
		// property handed back a copy, Length stays 0 and the API is innocent.
		Diag("hl 3: about to Add " + block.coord.x + "/" + block.coord.y
			+ "/" + block.coord.z);
		pluginMap.CustomSelectionCoords.Add(block.coord);
		Diag("hl 3: added, Length = " + pluginMap.CustomSelectionCoords.Length);

		Diag("hl 4: about to write CustomSelectionRGB");
		pluginMap.CustomSelectionRGB = c_HighlightRGB;
		Diag("hl 4: RGB written");

		Diag("hl 5: about to call ShowCustomSelection");
		pluginMap.ShowCustomSelection();
		Diag("hl 5: ShowCustomSelection returned");

		// Printed, not just traced: this line has to survive c_Diag being off,
		// because it is the one number that says whether the write took.
		print("MapDecorator highlight: asked for " + block.coord.x + "/"
			+ block.coord.y + "/" + block.coord.z + ", buffer now holds "
			+ pluginMap.CustomSelectionCoords.Length + " cell(s)");
	}

	// The way out, and it is deliberately a separate button: if the highlight
	// paints something wrong or ugly, the user needs to undo it without
	// reloading the plugin.
	void ClearHighlight()
	{
		Diag("hl: clear enter");
		if (!HasEditor()) return;

		auto pluginMap = g_Editor.PluginMapType;
		if (pluginMap is null) return;

		Diag("hl: about to call HideCustomSelection");
		pluginMap.HideCustomSelection();
		Diag("hl: HideCustomSelection returned");

		uint n = pluginMap.CustomSelectionCoords.Length;
		if (n > 0) {
			Diag("hl: about to empty the buffer");
			pluginMap.CustomSelectionCoords.RemoveRange(0, n);
			Diag("hl: emptied");
		}
		print("MapDecorator highlight: cleared");
	}
}
