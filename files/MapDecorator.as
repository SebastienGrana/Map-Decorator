// MapDecorator - scenery pass over a map somebody else already built.
//
// CONTROLLER. This file owns the state, drives the frame loop, and is the only
// place that decides when something happens. It calculates nothing itself: it
// asks the Model namespace for values and hands them to the View.
//
// It is a SEPARATE deliverable from TrackGen and shares no code with it. What
// it borrows is method - TrackGen proved the editor palette declares each
// block's footprint and its clips, and that reading is what this plugin needs,
// aimed at the scenery families instead of the road ones.
//
// The one hard difference from TrackGen, and the reason this is not a setting
// inside it: TrackGen owns an empty map and writes a track onto it, while
// MapDecorator inherits a finished map it did not write, must not damage it,
// and only has the space the track left over. Reading comes before writing
// here, which is why Model::Scan exists and has no counterpart in TrackGen.
//
// STATUS: reads the palette and reports what joins nothing. Nothing is placed.

// Shown in the window title so a screenshot always says which build is loaded.
const string c_Version = "0.3.0";

// Whether the plugin window is open. A plain global rather than a local of
// Main(), because RenderMenu() toggles it from outside the frame loop.
bool g_WindowVisible = false;

// The editor this plugin is attached to, or null when the user is not in the
// map editor. Refreshed every frame on purpose: the editor object is destroyed
// when the user leaves it, and holding on to a stale handle is how a plugin
// takes the game down with it.
CGameCtnEditorFree@ g_Editor = null;

// The last palette scan. Empty until the user asks for one.
//
// Held here rather than recomputed per frame because a scan walks every block
// model in the palette - cheap once, wasteful sixty times a second. It is a
// snapshot: it does not follow the palette if the editor changes environment,
// which is why the View says when it was taken.
array<Model::BlockEntry@> g_Palette;
bool g_HasScanned = false;

// The subset of g_Palette that declares no clip at all. Filtered once, at scan
// time, rather than by the View every frame: the View displays, it does not
// compute.
array<Model::BlockEntry@> g_Unconnectable;

// Openplanet entry point, called once when the plugin loads.
void Main()
{
	print("MapDecorator " + c_Version + " loaded");
}

// Called every frame. Kept to the single job of refreshing the editor handle;
// anything that decides or calculates belongs in the Model namespace.
void Update(float dt)
{
	@g_Editor = cast<CGameCtnEditorFree>(GetApp().Editor);
}

// Called every frame to draw the plugin's own windows.
void RenderInterface()
{
	if (!g_WindowVisible) return;
	View::RenderWindow();
}

// Puts the plugin in Openplanet's menu, so the window can be reopened after
// the user closes it.
void RenderMenu()
{
	if (UI::MenuItem("MapDecorator", "", g_WindowVisible)) {
		g_WindowVisible = !g_WindowVisible;
	}
}

// True when there is a live editor to work on. Every action must ask this
// first: the handle is null everywhere outside the map editor.
bool HasEditor()
{
	return g_Editor !is null && g_Editor.PluginMapType !is null;
}

// Reads the palette into g_Palette. Called from the View's button, because a
// scan is a user decision - it is never run on its own.
void ScanPalette()
{
	if (!HasEditor()) return;

	g_Palette = Model::ScanPalette(g_Editor.PluginMapType);
	g_Unconnectable = Model::UnconnectableOf(g_Palette);
	g_HasScanned = true;

	// Printed as well as shown, so the raw counts survive in the log even when
	// the window is closed or the numbers look wrong.
	print("MapDecorator scanned " + g_Palette.Length + " block models, "
		+ g_Unconnectable.Length + " of them declare no clip");

	// Each clip-less block is named with its cell count, because the count
	// alone cannot be trusted. A block with neither a ground nor an air variant
	// yields a null variant, hence zero clips AND zero cells - it looks like a
	// block that joins nothing while really being a block we failed to read.
	// Printing cells separates the two: 0 cells means artefact, not scenery.
	for (uint i = 0; i < g_Unconnectable.Length; i++) {
		auto entry = g_Unconnectable[i];
		print("  no clip: " + entry.name + "  (" + entry.cells + " cells, page "
			+ entry.page + ")");
	}
}
