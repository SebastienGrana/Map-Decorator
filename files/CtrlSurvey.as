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

	// Reads the map and loads whatever labels were saved for it before.
	void BeginSurvey()
	{
		if (!HasEditor()) return;

		auto pluginMap = g_Editor.PluginMapType;
		g_Blocks = Model::ScanMap(pluginMap);
		g_MapName = pluginMap.MapName;
		g_Index = 0;
		g_Loaded = true;

		LoadLabels();

		print("MapDecorator survey: " + g_Blocks.Length + " blocks on '"
			+ g_MapName + "', " + g_Labels.Count() + " already labelled");

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
		if (block is null || !HasEditor()) return;

		auto pluginMap = g_Editor.PluginMapType;

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

			if (!g_SkipLabelled) break;
			if (g_Labels.Get(g_Blocks[i].coord) == Model::Klass::Unlabelled) break;
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
