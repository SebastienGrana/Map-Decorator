// MapDecorator - walking the map block by block so the user can label it.
//
// CONTROLLER. It moves the editor cursor, keeps track of where the survey is,
// and saves the labels. It computes no classification: the whole point of this
// file is that the classification is not computable, and has to be observed.
//
// WHY THE CURSOR. There is no way to draw on the blocks themselves: the header
// exposes no world-to-screen projection anywhere, the editor camera API offers
// only commands (move, turn, frame) and no matrix, and CSceneCamera carries
// neither location nor field of view. What it does expose is a cursor whose
// coordinate can be written. So instead of drawing over the game, the plugin
// points the game's own cursor at a block and lets the editor highlight it.
//
// The survey holds its own state rather than putting it in MapDecorator.as:
// that file owns the plugin's lifecycle, this one owns one feature, and mixing
// them is what makes a controller grow until nobody reads it.

namespace Ctrl
{
	// The blocks of the map being surveyed, in Blocks-buffer order.
	array<Model::PlacedBlock@> g_Blocks;

	// Where the survey is. Meaningless while g_Blocks is empty.
	int g_Index = 0;

	// The user's verdicts for this map.
	Model::LabelStore g_Labels;

	// The map the labels belong to. Kept so that loading a different map cannot
	// silently write its labels into the previous map's file.
	string g_MapName;

	bool g_Loaded = false;

	// Whether Next/Previous skip blocks that already carry a label. Surveying a
	// few thousand blocks is only bearable if finished work stays finished.
	bool g_SkipLabelled = true;

	// The waypoint check. Start, finish and checkpoint blocks are route by
	// definition, so the plugin labels them itself - but it shows them to the
	// user FIRST, before anything else, rather than quietly folding them in.
	// An automatism that is never looked at is an assumption, and this project
	// has already paid twice for assumptions it never put in front of an eye.
	bool g_WaypointPass = false;
	uint g_WaypointCount = 0;

	// Reads the map and loads whatever labels were saved for it before.
	void BeginSurvey()
	{
		if (!HasEditor()) {
			return;
		}

		auto pluginMap = g_Editor.PluginMapType;

		uint freeMapping = 0;
		g_Blocks = Model::ScanMap(pluginMap, freeMapping);

		g_MapName = pluginMap.MapName;

		g_Index = 0;
		g_Loaded = true;

		LoadLabels();

		g_WaypointCount = ApplyWaypointLabels();
		g_WaypointPass = g_WaypointCount > 0;
		if (g_WaypointPass) g_Index = FirstEligible();

		// The counts are printed beside the verdict on purpose: a survey that
		// says only "ready" cannot be told from a survey that read nothing.
		print("MapDecorator survey: " + g_Blocks.Length + " blocks on '"
			+ g_MapName + "', " + g_Labels.Count() + " already labelled, "
			+ freeMapping + " skipped (free mapping)");
		print("MapDecorator waypoints: " + g_WaypointCount
			+ " blocks auto-labelled Route (waypoint), shown first for checking");

		MoveCursorToCurrent();
	}

	// Labels every waypoint block the user has not already judged, and answers
	// how many. A block the user labelled by hand is left alone even when the
	// two disagree: the point of this file is that his verdict wins.
	uint ApplyWaypointLabels()
	{
		uint n = 0;
		for (uint i = 0; i < g_Blocks.Length; i++) {
			if (g_Blocks[i].waypoint == Model::c_WaypointNone) continue;
			if (g_Labels.Get(g_Blocks[i].coord) != Model::Klass::Unlabelled) continue;
			g_Labels.Set(g_Blocks[i].coord, Model::Klass::RouteWaypoint);
			n++;
		}
		if (n > 0) SaveLabels();
		return n;
	}

	// Whether the survey stops on a block. Two regimes, and the waypoint pass
	// ignores g_SkipLabelled on purpose: during that pass every block in scope
	// carries a label already, so honouring the checkbox would skip the whole
	// pass and the check would silently never happen.
	bool Eligible(uint i)
	{
		if (g_WaypointPass) return g_Blocks[i].waypoint != Model::c_WaypointNone;
		if (!g_SkipLabelled) return true;
		return g_Labels.Get(g_Blocks[i].coord) == Model::Klass::Unlabelled;
	}

	int FirstEligible()
	{
		for (uint i = 0; i < g_Blocks.Length; i++) {
			if (Eligible(i)) return int(i);
		}
		return 0;
	}

	// Ends the waypoint check and drops the survey at the first block that is
	// still to be judged. Called from the window, never automatically: only
	// the user can say he has seen enough.
	void EndWaypointPass()
	{
		g_WaypointPass = false;
		g_Index = FirstEligible();
		MoveCursorToCurrent();
	}

	bool HasSurvey()
	{
		return g_Loaded && g_Blocks.Length > 0;
	}

	Model::PlacedBlock@ Current()
	{
		if (!HasSurvey()) return null;
		if (g_Index < 0 || uint(g_Index) >= g_Blocks.Length) return null;
		return g_Blocks[g_Index];
	}

	// Points the editor cursor at the block under the survey.
	//
	// Both cursors are written on purpose. Openplanet.h exposes two: the
	// scripting API one (CGameEditorPluginCursorAPI, the sanctioned path) and
	// the block cursor the editor actually draws (CGameCursorBlock). Which of
	// the two moves the visible highlight is not documented anywhere, so the
	// first move prints both back and the log settles it rather than a guess.
	bool g_ReadbackPrinted = false;

	void MoveCursorToCurrent()
	{
		auto block = Current();
		if (block is null || !HasEditor()) {
			return;
		}

		auto pluginMap = g_Editor.PluginMapType;

		// Both writes reach into the engine; the read-back below, printed on
		// the first move, says whether they took.
		if (pluginMap.Cursor !is null) {
			pluginMap.Cursor.Coord = block.coord;
		}

		if (g_Editor.Cursor !is null) {
			g_Editor.Cursor.Coord = block.coord;
		}

		if (!g_ReadbackPrinted) {
			g_ReadbackPrinted = true;
			print("MapDecorator cursor asked for " + block.coord.x + "/"
				+ block.coord.y + "/" + block.coord.z);
			if (pluginMap.Cursor !is null) {
				print("  plugin cursor now " + pluginMap.Cursor.Coord.x + "/"
					+ pluginMap.Cursor.Coord.y + "/" + pluginMap.Cursor.Coord.z);
			}
			if (g_Editor.Cursor !is null) {
				print("  block cursor now " + g_Editor.Cursor.Coord.x + "/"
					+ g_Editor.Cursor.Coord.y + "/" + g_Editor.Cursor.Coord.z);
			}
		}
	}

	// Step through the survey. Returns without moving when there is nowhere
	// left to go, rather than wrapping: wrapping around silently makes "I have
	// seen everything" impossible to tell from "I am back at the start".
	void Step(int direction)
	{
		if (!HasSurvey()) return;

		int i = g_Index;
		for (uint guard = 0; guard < g_Blocks.Length; guard++) {
			i += direction;
			if (i < 0 || uint(i) >= g_Blocks.Length) return;

			if (Eligible(uint(i))) break;
		}
		if (i < 0 || uint(i) >= g_Blocks.Length) return;

		g_Index = i;
		MoveCursorToCurrent();
	}

	// Records a verdict and moves on, because labelling then advancing by hand
	// doubles the clicks on a job that is already thousands of blocks long.
	void LabelCurrent(Model::Klass k)
	{
		auto block = Current();
		if (block is null) return;

		g_Labels.Set(block.coord, k);
		SaveLabels();
		Step(1);
	}

	void LoadLabels()
	{
		g_Labels.Clear();
		string path = Model::LabelFileFor(g_MapName);
		if (!IO::FileExists(path)) return;

		g_Labels.FromJson(Json::FromFile(path));
	}

	// Saved on every verdict rather than on a Save button. A survey is long and
	// interruptible, and losing an hour of judgements to a forgotten click is
	// not a trade worth making for one file write.
	void SaveLabels()
	{
		if (g_MapName.Length == 0) return;
		Json::ToFile(Model::LabelFileFor(g_MapName), g_Labels.ToJson());
	}
}
