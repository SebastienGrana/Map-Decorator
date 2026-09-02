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
	// A block placed in free mapping has no cell: the engine stores 0xFFFFFFFF
	// in its coordinates. Such a block cannot be pointed at by a cell cursor,
	// so the survey skips it - but it is counted, never dropped in silence.
	const uint c_NoCoord = 4294967295;

	// One block as the map holds it. A snapshot, not a handle: the survey walks
	// this list while the user moves around the editor, and keeping engine
	// pointers alive across that is how a plugin takes the game down with it.
	class PlacedBlock
	{
		string name;
		nat3 coord;
		bool isGround;

		// NO WAYPOINT FLAG HERE YET, and it is not an oversight. See the note
		// at the bottom of this file: the field that would give it took the
		// game down, and its safe replacement has not been tried in game.
	}

	// Every block placed on the map.
	//
	// Blocks, not BlockModels: the palette says what COULD be placed, this says
	// what IS. The decoration question is about a specific map, so it is this
	// buffer that matters.
	//
	// freeMapping receives the number of blocks skipped for having no cell.
	array<PlacedBlock@> ScanMap(CGameEditorPluginMap@ pluginMap, uint &out freeMapping)
	{
		array<PlacedBlock@> blocks;
		freeMapping = 0;
		if (pluginMap is null) return blocks;

		for (uint i = 0; i < pluginMap.Blocks.Length; i++) {
			auto block = pluginMap.Blocks[i];
			if (block is null) continue;

			// Free-mapped blocks first: their Coord is meaningless, and the
			// survey addresses blocks by cell.
			if (block.CoordX == c_NoCoord || block.CoordZ == c_NoCoord) {
				freeMapping++;
				continue;
			}

			PlacedBlock placed;
			// Written as an if rather than a ternary: BlockModel.Name and a
			// string literal have no common type the compiler will pick alone.
			placed.name = "<unknown>";
			if (block.BlockModel !is null) placed.name = block.BlockModel.Name;
			placed.coord = block.Coord;
			placed.isGround = block.IsGround;

			blocks.InsertLast(placed);
		}
		return blocks;
	}
}

// WHY BlockModel AND Coord, AND NOT BlockInfo AND CoordX/Y/Z
//
// CGameCtnBlock carries each of these twice. Openplanet.h marks one of each
// pair "// Maniascript" and leaves the other bare:
//
//     CGameCtnBlockInfo* const BlockInfo;                  <- bare
//     CGameCtnBlockInfo* const BlockModel;   // Maniascript
//     uint CoordX; uint CoordY; uint CoordZ;               <- bare
//     const nat3 Coord;                      // Maniascript
//
// Reading the bare BlockInfo CRASHED THE GAME, twice. Openplanet logged
// "Invalid address for member ID 03057010. This is likely a Nadeo bug! Setting
// it to null!" and the process went down; 03057000 is CGameCtnBlock's class id
// and 0x10 lands on BlockInfo. The log holds no MapDecorator line between the
// load and the warning, which places the death inside this function, before
// its caller's print - and BlockInfo was the only pointer it dereferenced.
//
// The first attempt at this fix blamed WaypointSpecialProperty, removed it, and
// the warning came back unchanged in the next build. That is the whole reason
// this note exists: the second fix was chosen on evidence rather than on which
// field looked most suspicious.
//
// Proof by example, which is the standard this project now holds itself to
// before dereferencing an unmarked pointer: BlockModel appears five times in
// installed plugins (EditorHelpers, BlocksItemsCounter) reading .Name, .IdName
// and .PodiumInfo. BlockInfo appears once, on a custom-block path only.
//
// The waypoint role is still wanted - a start, checkpoint or finish is route by
// definition, and free ground truth. The safe source is on the MODEL, not the
// block: CGameCtnBlockInfo carries "const EWayPointType WaypointType;" with the
// // Maniascript marker, a plain enum rather than a pointer. It is deliberately
// NOT read in this build: this build exists to prove the crash is gone, and
// adding a second change would make a second crash unattributable.
