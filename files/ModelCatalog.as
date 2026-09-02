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

	// True when a variant actually carries cells. A variant handle that is not
	// null can still hold an empty BlockUnitModels, and such a variant tells us
	// nothing: no cells means no clips can be read from it either.
	bool IsPopulated(CGameCtnBlockInfoVariant@ variant)
	{
		return variant !is null && variant.BlockUnitModels.Length > 0;
	}

	// The variant a block should be catalogued from: the first candidate that
	// actually has cells.
	//
	// The order below is not a preference, it is what measurement forced.
	// Openplanet.h declares VariantGround / VariantAir carrying a
	// "// Maniascript" marker, and VariantBaseGround / VariantBaseAir /
	// AdditionalVariants* without one. Reading the unmarked pair first looked
	// right - they are the fields ManiaScript cannot see, and reaching them is
	// why this plugin is in Openplanet at all. It was wrong: on the scenery
	// families VariantBaseGround is non-null but EMPTY, and preferring it took
	// the clip-less count from 1 of 551 to 154 of 551, every one of them at
	// zero cells. The marked pair is not a narrower view, it is the RESOLVED
	// one.
	//
	// So the rule is not "which field is better" - it is "which handle has
	// cells". That survives being wrong about any single field.
	CGameCtnBlockInfoVariant@ DefaultVariantOf(CGameCtnBlockInfo@ model)
	{
		if (model is null) return null;

		// Ground before air: a decoration pass puts blocks on the ground, and
		// air-only blocks (gantries, some signs) still need cataloguing.
		if (IsPopulated(model.VariantGround)) return model.VariantGround;
		if (IsPopulated(model.VariantAir)) return model.VariantAir;

		if (IsPopulated(model.VariantBaseGround)) return model.VariantBaseGround;
		if (IsPopulated(model.VariantBaseAir)) return model.VariantBaseAir;

		// Last resort, and invisible to ManiaScript: a block whose only usable
		// variant lives in these buffers is unreadable without Openplanet.
		for (uint i = 0; i < model.AdditionalVariantsGround.Length; i++) {
			if (IsPopulated(model.AdditionalVariantsGround[i])) {
				return model.AdditionalVariantsGround[i];
			}
		}
		for (uint i = 0; i < model.AdditionalVariantsAir.Length; i++) {
			if (IsPopulated(model.AdditionalVariantsAir[i])) {
				return model.AdditionalVariantsAir[i];
			}
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
