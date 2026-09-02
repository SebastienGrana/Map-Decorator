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
// STATUS: declaration only. The plugin loads, finds the editor and shows an
// empty window; nothing reads the map and nothing is placed.

// Shown in the window title so a screenshot always says which build is loaded.
const string c_Version = "0.1.0";

// Whether the plugin window is open. A plain global rather than a local of
// Main(), because RenderMenu() toggles it from outside the frame loop.
bool g_WindowVisible = false;

// The editor this plugin is attached to, or null when the user is not in the
// map editor. Refreshed every frame on purpose: the editor object is destroyed
// when the user leaves it, and holding on to a stale handle is how a plugin
// takes the game down with it.
CGameCtnEditorFree@ g_Editor = null;

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
