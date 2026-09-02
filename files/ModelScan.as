// MapDecorator - read the map the player already built.
//
// MODEL. It reads the map and returns a picture of it; it writes nothing.
//
// This file has no counterpart in TrackGen, and it is the whole difference
// between the two plugins: TrackGen starts from an empty map and owns what it
// writes, while this one inherits a finished map and may only use the space the
// track left over.
//
// One trap paid for in TrackGen still applies: an empty cell is NOT null.
// GetBlock returns StadiumGrass on empty ground, so occupancy must be judged on
// the picture this file builds, not by asking the map cell by cell. Reading the
// Blocks buffer, as below, sidesteps that entirely: it lists what was actually
// placed, and says nothing about cells nobody touched.
//
// STATUS: lists the blocks the map holds. The occupancy grid is not built yet.

namespace Model
{
	// One block as the map holds it. A snapshot, not a handle: the survey walks
	// this list while the user moves around the editor, and keeping engine
	// pointers alive across that is how a plugin takes the game down with it.
	class PlacedBlock
	{
		string name;
		nat3 coord;
		bool isGround;

		// NO WAYPOINT FLAG HERE, and it is not an oversight.
		//
		// CGameCtnBlock.WaypointSpecialProperty would say whether a block is a
		// start, checkpoint or finish - the one role the game declares itself,
		// and so the obvious ground truth to check a classification against.
		// Reading it CRASHED THE GAME: Openplanet logged "Invalid address for
		// member ID 03057010 ... Setting it to null" and the process went down
		// on the next frame.
		//
		// That field carries no "// Maniascript" marker in Openplanet.h, and
		// the same evening an unmarked field (VariantBaseGround) had already
		// proved to be a trap. Unmarked means present in the dump, not safe to
		// touch. A waypoint source has to be found elsewhere before this comes
		// back.
	}

	// Every block placed on the map.
	//
	// Blocks, not BlockModels: the palette says what COULD be placed, this says
	// what IS. The decoration question is about a specific map, so it is this
	// buffer that matters.
	array<PlacedBlock@> ScanMap(CGameEditorPluginMap@ pluginMap)
	{
		array<PlacedBlock@> blocks;
		if (pluginMap is null) return blocks;

		for (uint i = 0; i < pluginMap.Blocks.Length; i++) {
			auto block = pluginMap.Blocks[i];
			if (block is null) continue;

			PlacedBlock placed;
			// Written as an if rather than a ternary: BlockInfo.Name and a string
			// literal have no common type the compiler will pick on its own.
			placed.name = "<unknown>";
			if (block.BlockInfo !is null) placed.name = block.BlockInfo.Name;
			placed.coord = nat3(block.CoordX, block.CoordY, block.CoordZ);
			placed.isGround = block.IsGround;

			blocks.InsertLast(placed);
		}
		return blocks;
	}
}
