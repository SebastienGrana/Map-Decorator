// MapDecorator - what the editor palette declares about each block.
//
// MODEL. It reads the palette and returns what it found; it changes nothing.
//
// A block model carries variants, a variant carries one unit model per cell the
// block covers, and each unit carries clips - the faces it connects through.
// TrackGen established that reading on the road families; this file aims it at
// the whole palette, to find out what scenery is made of.
//
// FIRST QUESTION THIS ANSWERS: do scenery blocks carry clips at all? A tree or
// a grandstand may join nothing, in which case placement is governed by
// footprint and free space alone, and the entire clip machinery is irrelevant
// to this plugin. The answer decides whether the core is a clip matcher or a
// free-space packer, so it is measured before anything else is designed.
//
// Openplanet is what makes this worth doing here rather than in ManiaScript:
// TopClipDir / BottomClipDir and AdditionalVariants* are not exposed to
// ManiaScript (see "context AI/02-plateforme.md").

namespace Model
{
	// One palette entry, reduced to what the question needs. Deliberately not a
	// handle to the block model: a scan is a snapshot to be sorted and counted,
	// and keeping engine pointers around invites use after the editor closes.
	class BlockEntry
	{
		string name;
		string page;    // palette page - the only grouping the game itself offers
		uint cells;     // unit models, i.e. cells the block really occupies
		uint clips;     // clip slots declared across all those cells

		// A block that declares no clip anywhere joins nothing. It is placed by
		// footprint alone - which is the definition of decoration, as opposed to
		// a piece of track that has to meet its neighbours.
		//
		// A plain method rather than a property accessor: AngelScript needs the
		// "property" keyword for those, and a name that reads as a question is
		// no worse.
		bool IsConnectable() const { return clips > 0; }
	}

	// The variant a block is placed as by default. Ground first because that is
	// what a decoration pass puts on the map; air-only blocks (gantries, some
	// signs) still have to be catalogued, hence the fallbacks.
	//
	// VariantBase* rather than Variant*: Openplanet.h declares both, but
	// VariantGround / VariantAir carry the "// Maniascript" marker - they are
	// the narrower view ManiaScript is given. Reading through them was costing
	// us blocks: StadiumRoadDirtMultiLap came back with a null variant, hence
	// zero cells and zero clips, and so counted as a block joining nothing -
	// which for a road block is plainly false.
	//
	// AdditionalVariants* is the last resort and is the whole reason this
	// plugin is in Openplanet at all: ManiaScript cannot see those buffers.
	// A block whose only variants live there is invisible to the narrow view.
	CGameCtnBlockInfoVariant@ DefaultVariantOf(CGameCtnBlockInfo@ model)
	{
		if (model is null) return null;

		if (model.VariantBaseGround !is null) return model.VariantBaseGround;
		if (model.VariantBaseAir !is null) return model.VariantBaseAir;

		if (model.AdditionalVariantsGround.Length > 0) {
			return model.AdditionalVariantsGround[0];
		}
		if (model.AdditionalVariantsAir.Length > 0) {
			return model.AdditionalVariantsAir[0];
		}
		return null;
	}

	// Clip slots declared across every cell of a variant.
	//
	// Summed rather than per-cell on purpose: the question at this stage is
	// "does this block connect at all", and one clip anywhere is enough to
	// answer yes. Which cell and which face carries it is a later question -
	// see "context AI/11-clips-et-faces.md".
	uint ClipCountOf(CGameCtnBlockInfoVariant@ variant)
	{
		if (variant is null) return 0;

		uint total = 0;
		for (uint cell = 0; cell < variant.BlockUnitModels.Length; cell++) {
			auto unit = variant.BlockUnitModels[cell];
			if (unit !is null) total += unit.Clips.Length;
		}
		return total;
	}

	// Every block model the editor palette holds, reduced to BlockEntry.
	//
	// The palette is the authority, not a corpus of saved maps: a corpus only
	// shows what somebody happened to use.
	//
	// Terrain models are left out. They are a separate buffer
	// (TerrainBlockModels) with their own placement rules, and mixing them in
	// would blur the very count this scan exists to produce.
	array<BlockEntry@> ScanPalette(CGameEditorPluginMap@ pluginMap)
	{
		array<BlockEntry@> entries;
		if (pluginMap is null) return entries;

		for (uint i = 0; i < pluginMap.BlockModels.Length; i++) {
			auto model = pluginMap.BlockModels[i];
			if (model is null) continue;

			auto variant = DefaultVariantOf(model);

			BlockEntry entry;
			entry.name  = model.Name;
			entry.page  = model.PageName;
			entry.cells = (variant !is null) ? variant.BlockUnitModels.Length : 0;
			entry.clips = ClipCountOf(variant);

			entries.InsertLast(entry);
		}
		return entries;
	}

	// The blocks that join nothing - the candidates for decoration.
	array<BlockEntry@> UnconnectableOf(const array<BlockEntry@> &in entries)
	{
		array<BlockEntry@> result;
		for (uint i = 0; i < entries.Length; i++) {
			if (!entries[i].IsConnectable()) result.InsertLast(entries[i]);
		}
		return result;
	}
}
