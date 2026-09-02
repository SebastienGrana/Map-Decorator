// MapDecorator - the plugin window, and nothing else.
//
// VIEW. It draws and it reads; it never decides and never computes. No block is
// placed from this file and no map is read by it: a widget asks the Controller
// to do something, and the Controller does it.
//
// Kept apart because the window is the file that changes most often and whose
// changes matter least - editing a label should not mean opening the
// decorator's logic.

namespace View
{
	// Height of the scrolling list, in pixels. Tall enough to read a few dozen
	// names without hiding the summary above it.
	const float c_ListHeight = 320.0f;

	void RenderWindow()
	{
		if (UI::Begin("MapDecorator " + c_Version, g_WindowVisible)) {
			if (!HasEditor()) {
				UI::TextDisabled("Open a map in the editor to use MapDecorator.");
			} else {
				RenderScanButton();
				UI::Separator();
				RenderResult();
			}
		}
		UI::End();
	}

	void RenderScanButton()
	{
		if (UI::Button("Scan palette")) {
			ScanPalette();
		}
	}

	void RenderResult()
	{
		if (!g_HasScanned) {
			UI::TextDisabled("Scan the palette to see which blocks join nothing.");
			return;
		}

		RenderSummary();
		RenderUnconnectableList();
	}

	// The raw counts, shown before the list. A verdict without its counts
	// cannot be checked, and this scan exists precisely to be checked.
	void RenderSummary()
	{
		uint total = g_Palette.Length;
		uint unconnectable = g_Unconnectable.Length;

		// Every concatenation starts with a string: AngelScript resolves
		// "text" + number, not number + "text".
		UI::Text("" + total + " block models in the palette");
		UI::Text("" + unconnectable + " declare no clip - they join nothing");
		UI::Text("" + (total - unconnectable) + " declare at least one clip");
	}

	void RenderUnconnectableList()
	{
		UI::BeginChild("unconnectable", vec2(0, c_ListHeight));

		for (uint i = 0; i < g_Unconnectable.Length; i++) {
			auto entry = g_Unconnectable[i];
			UI::Text(entry.name);
			UI::SameLine();
			UI::TextDisabled("  " + entry.cells + " cells   " + entry.page);
		}

		UI::EndChild();
	}
}
