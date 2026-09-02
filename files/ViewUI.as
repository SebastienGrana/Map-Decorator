// MapDecorator - the plugin window, and nothing else.
//
// VIEW. It draws and it reads; it never decides and never computes. No block is
// placed from this file and no map is read by it: a widget asks a Controller to
// do something, and the Controller does it.
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
			} else if (UI::BeginTabBar("modes")) {
				if (UI::BeginTabItem("Survey")) {
					RenderSurvey();
					UI::EndTabItem();
				}
				if (UI::BeginTabItem("Palette")) {
					RenderScanButton();
					UI::Separator();
					RenderResult();
					UI::EndTabItem();
				}
				UI::EndTabBar();
			}
		}
		UI::End();
	}

	// ---- Survey: the user labels the map block by block ----------------

	void RenderSurvey()
	{
		if (!Ctrl::HasSurvey()) {
			UI::TextWrapped("Walk the map block by block and say what each one"
				" really is. The editor cursor moves to the block being asked"
				" about.");
			if (UI::Button("Read this map")) {
				Ctrl::BeginSurvey();
			}
			return;
		}

		RenderSurveyProgress();
		UI::Separator();
		RenderCurrentBlock();
		UI::Separator();
		RenderLabelButtons();
	}

	void RenderSurveyProgress()
	{
		uint total = Ctrl::g_Blocks.Length;
		uint done = Ctrl::g_Labels.Count();

		UI::Text("" + done + " of " + total + " blocks labelled");
		UI::TextDisabled("  route " + Ctrl::g_Labels.CountOf(Model::Klass::Route)
			+ "   support " + Ctrl::g_Labels.CountOf(Model::Klass::Support)
			+ "   decor " + Ctrl::g_Labels.CountOf(Model::Klass::Decor));

		Ctrl::g_SkipLabelled = UI::Checkbox("Skip blocks already labelled",
			Ctrl::g_SkipLabelled);
	}

	void RenderCurrentBlock()
	{
		auto block = Ctrl::Current();
		if (block is null) {
			UI::TextDisabled("Nothing left to visit in this direction.");
			return;
		}

		UI::Text(block.name);
		UI::TextDisabled("  cell " + block.coord.x + " / " + block.coord.y
			+ " / " + block.coord.z + (block.isGround ? "   ground" : "   air"));

		// A waypoint is on the route by definition, so saying so removes the
		// one case where the user might have to guess.
		if (block.isWaypoint) {
			UI::Text("\$fc0this block is a waypoint - it is on the route by definition");
		}

		auto current = Ctrl::g_Labels.Get(block.coord);
		if (current != Model::Klass::Unlabelled) {
			UI::TextDisabled("  already labelled: " + Model::KlassName(current));
		}
	}

	void RenderLabelButtons()
	{
		if (UI::Button("Route")) {
			Ctrl::LabelCurrent(Model::Klass::Route);
		}
		UI::SameLine();
		if (UI::Button("Support")) {
			Ctrl::LabelCurrent(Model::Klass::Support);
		}
		UI::SameLine();
		if (UI::Button("Decor")) {
			Ctrl::LabelCurrent(Model::Klass::Decor);
		}

		if (UI::Button("< Previous")) {
			Ctrl::Step(-1);
		}
		UI::SameLine();
		if (UI::Button("Skip >")) {
			Ctrl::Step(1);
		}

		UI::TextDisabled("Labels are saved to disk on every verdict.");
	}

	// ---- Palette: what the block models declare ------------------------

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
