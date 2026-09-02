// MapDecorator - the plugin window, and nothing else.
//
// VIEW. It draws and it reads; it never decides. No block is placed from this
// file and no map is read by it: a widget records what the user asked for, and
// the Controller acts on it.
//
// Kept apart because the window is the file that changes most often and whose
// changes matter least - editing a label should not mean opening the
// decorator's logic.
//
// STATUS: declaration only - an empty window that proves the plugin loads.

namespace View
{
	void RenderWindow()
	{
		if (UI::Begin("MapDecorator " + c_Version, g_WindowVisible)) {
			if (!HasEditor()) {
				UI::TextDisabled("Open a map in the editor to use MapDecorator.");
			} else {
				UI::TextDisabled("Declaration only - nothing implemented yet.");
			}
		}
		UI::End();
	}
}
