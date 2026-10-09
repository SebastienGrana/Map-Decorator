// MapDecorator - the only file that writes to the map.
//
// CONTROLLER. Everything else reads or calculates; writing is concentrated here
// so that "what can damage the player's map" is one small file.
//
// Undo has to be a first-class concern from the start, which it never was in
// TrackGen: here the map belongs to somebody else. The editor offers
// PlaceBlock_NoDestruction, which refuses rather than overwrites - that is the
// default this file should use, with plain PlaceBlock reserved for a case the
// user explicitly asked for.
//
// STATUS: PlacePlan writes, called from the Decorate tab's Place button
// (RenderPlaceButton, ViewUI.as), and UndoPass reverses it from the "Undo this
// pass" button. Both run for real, but Model::BuildPlan still returns an empty
// plan, so in practice no block is written yet.

namespace Ctrl
{
	// Resolves a placement's model name back into the engine handle
	// PlaceBlock_NoDestruction needs. ModelCatalog's BlockEntry deliberately
	// keeps no such handle (a scan is a snapshot, not a set of live pointers),
	// so this is the one place, right before writing, that looks one up.
	CGameCtnBlockInfo@ ModelNamed(CGameEditorPluginMap@ pluginMap, const string &in name)
	{
		for (uint i = 0; i < pluginMap.BlockModels.Length; i++) {
			auto model = pluginMap.BlockModels[i];
			if (model !is null && model.Name == name) return model;
		}
		return null;
	}

	// Turns a Ready plan into blocks on the map. The only function in this
	// file that writes - see the file header. Walks g_Plan.placements and
	// calls PlaceBlock_NoDestruction, which refuses rather than overwrites;
	// only a placement it accepts is recorded to g_PlacedLog, so Undo (U4)
	// never tries to remove something that was never written. Reports the
	// tally through Log() rather than returning it - the Debug tab's Log
	// panel and the game log are both fed from there.
	void PlacePlan()
	{
		g_PlacedLog.Resize(0);
		if (!HasEditor()) return;

		auto pluginMap = g_Editor.PluginMapType;
		uint refused = 0;

		for (uint i = 0; i < g_Plan.placements.Length; i++) {
			auto entry = g_Plan.placements[i];
			auto model = ModelNamed(pluginMap, entry.name);
			if (model is null) {
				refused++;
				continue;
			}

			auto dir = CGameEditorPluginMap::ECardinalDirections(entry.dir);
			bool ok = pluginMap.PlaceBlock_NoDestruction(
				model, int3(entry.x, entry.y, entry.z), dir);

			if (ok) g_PlacedLog.InsertLast(entry);
			else refused++;
		}

		Log("" + g_PlacedLog.Length + " placed, " + refused + " refused");
	}

	// Reverses the last PlacePlan, newest entry first. For each entry it asks
	// Model::FindPlacedBlockModel whether the block is still there; a miss, or
	// a RemoveBlockSafe that comes back false, counts as "left in place" and
	// is logged with its coordinate - no retry, no plain RemoveBlock. The
	// journal is cleared at the end regardless: what could not be removed now
	// will not be removed later.
	void UndoPass()
	{
		if (!HasEditor()) return;

		auto pluginMap = g_Editor.PluginMapType;
		uint left = 0;

		for (int i = int(g_PlacedLog.Length) - 1; i >= 0; i--) {
			auto entry = g_PlacedLog[i];
			auto coord = int3(entry.x, entry.y, entry.z);
			auto model = Model::FindPlacedBlockModel(pluginMap, coord, entry.name, entry.dir);

			if (model is null) {
				left++;
				Log("left in place (not found) at " + coord.x + "/" + coord.y
					+ "/" + coord.z + ": " + entry.name);
				continue;
			}

			auto dir = CGameEditorPluginMap::ECardinalDirections(entry.dir);
			if (!pluginMap.RemoveBlockSafe(model, coord, dir)) {
				left++;
				Log("left in place (refused) at " + coord.x + "/" + coord.y
					+ "/" + coord.z + ": " + entry.name);
			}
		}

		g_PlacedLog.Resize(0);
		Log(left == 0 ? "undo: all placements removed" : "" + left + " left in place");
	}
}
