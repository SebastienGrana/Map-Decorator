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
// STATUS: lists the blocks the map holds AND builds the occupancy grid from
// that list (OccupancyPlan / BuildOccupancyPlan, below). What is still
// missing is the footprint: a block marks the one cell it is anchored in,
// not the cells its shape actually fills - see "context AI/12-empreintes.md".

namespace Model
{
	// A block placed in free mapping has no cell: the engine stores 0xFFFFFFFF
	// in its coordinates. Such a block cannot be pointed at by a cell cursor,
	// so the survey skips it - but it is counted, never dropped in silence.
	const uint c_NoCoord = 4294967295;

	// EWayPointType::None. Named rather than written as 3 at the call site:
	// this is the value that decides whether a block is auto-labelled, and a
	// bare 3 next to a coordinate is unreadable a month later.
	const int c_WaypointNone = 3;

	// One block as the map holds it. A snapshot, not a handle: the survey walks
	// this list while the user moves around the editor, and keeping engine
	// pointers alive across that is how a plugin takes the game down with it.
	class PlacedBlock
	{
		string name;
		nat3 coord;
		bool isGround;

		// The waypoint role, raw, as CGameCtnBlockInfo::EWayPointType numbers
		// it: Start=0, Finish=1, Checkpoint=2, None=3, StartFinish=4,
		// Dispenser=5 (Openplanet.h:1865). Stored as the engine's own int
		// rather than remapped: a block with no model gets c_WaypointNone, and
		// inventing a fourth value for "unknown" would put a distinction in the
		// data that nothing downstream could act on.
		int waypoint;
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
		if (pluginMap is null) {
			return blocks;
		}

		// THE MAP, NOT THE PLUGIN. pluginMap.Map (Openplanet.h:7104, marked) is
		// a handle to the real CGameCtnChallenge. Read the note at the bottom of
		// this file before ever putting pluginMap.Blocks back.
		auto map = pluginMap.Map;
		if (map is null) {
			return blocks;
		}

		// Snapshot the buffer into a local, the way BlocksItemsCounter does
		// (Objects.as:29). The previous version re-read the property on every
		// loop condition and again on every index - three engine lookups per
		// block where production does one for the whole walk.
		auto buffer = map.Blocks;
		uint count = buffer.Length;

		for (uint i = 0; i < count; i++) {
			auto block = buffer[i];
			if (block is null) {
				continue;
			}

			// Free-mapped blocks first: their Coord is meaningless, and the
			// survey addresses blocks by cell.
			uint cx = block.CoordX;
			uint cz = block.CoordZ;
			if (cx == c_NoCoord || cz == c_NoCoord) {
				freeMapping++;
				continue;
			}

			PlacedBlock placed;
			// Written as an if rather than a ternary: BlockModel.Name and a
			// string literal have no common type the compiler will pick alone.
			placed.name = "<unknown>";
			placed.waypoint = c_WaypointNone;
			// One null check for both reads: BlockModel is dereferenced once, and
			// WaypointType is a marked plain enum on the MODEL - never the pointer
			// on the block that two earlier fixes wrongly blamed.
			if (block.BlockModel !is null) {
				placed.name = block.BlockModel.Name;
				placed.waypoint = int(block.BlockModel.WaypointType);
			}

			placed.coord = block.Coord;
			placed.isGround = block.IsGround;

			blocks.InsertLast(placed);
		}

		return blocks;
	}

	// Finds the block model still standing at coord/dir/name, so the undo
	// journal can verify it is still "our" block before touching it
	// (invariant 4, 15-annulation.md). No match, of any kind, means null:
	// the caller must skip the entry rather than force the removal.
	CGameCtnBlockInfo@ FindPlacedBlockModel(CGameEditorPluginMap@ pluginMap,
		int3 coord, const string &in name, int dir)
	{
		if (pluginMap is null) return null;

		// pluginMap.Map.Blocks, never pluginMap.Blocks - the latter crashes
		// the game (see the note at the bottom of this file).
		auto map = pluginMap.Map;
		if (map is null) return null;

		auto buffer = map.Blocks;
		uint count = buffer.Length;
		for (uint i = 0; i < count; i++) {
			auto block = buffer[i];
			if (block is null) continue;
			if (int(block.Coord.x) != coord.x || int(block.Coord.y) != coord.y
				|| int(block.Coord.z) != coord.z) continue;
			if (int(block.Dir) != dir) continue;
			if (block.BlockModel is null) continue;
			if (block.BlockModel.Name != name) continue;
			return block.BlockModel;
		}
		return null;
	}

	// Which cells hold at least one placed block. Keyed the same way
	// ModelLabels keys a cell ("x/y/z"), so a later survey and this plan
	// agree on what a cell even is.
	class OccupancyPlan
	{
		private dictionary m_cells;

		void Mark(nat3 coord)
		{
			m_cells["" + coord.x + "/" + coord.y + "/" + coord.z] = true;
		}

		bool IsOccupied(nat3 coord) const
		{
			return m_cells.Exists("" + coord.x + "/" + coord.y + "/"
				+ coord.z);
		}

		uint Count() const { return m_cells.GetSize(); }
	}

	// Builds the occupancy plan from a survey ScanMap already produced.
	// Free-mapped blocks carry no coordinate (c_NoCoord) and were never
	// added to the survey, so they mark nothing here either.
	OccupancyPlan BuildOccupancyPlan(const array<PlacedBlock@> &in blocks)
	{
		OccupancyPlan plan;
		for (uint i = 0; i < blocks.Length; i++) {
			plan.Mark(blocks[i].coord);
		}
		return plan;
	}
}

// WHY map.Blocks AND NOT pluginMap.Blocks
//
// This is the note that cost five crashes on 2026-09-02. All five were the
// same death: ManiaPlanet.exe, Openplanet.dll, c0000005, fault offset
// 0x51ae3, every time on the click that starts the survey. The version that
// finally ran is the one below, and exactly one thing changed.
//
// The killer was the CONTAINER, not the field.
//
//     pluginMap.Blocks       // Openplanet.h:7261, on CGameEditorPluginMap
//     pluginMap.Map.Blocks   // Openplanet.h:1550, on CGameCtnChallenge
//
// Both are declared MwFastBuffer<CGameCtnBlock*>, so the type is not the
// difference. The owner is. CGameEditorPluginMap extends CGameManiaApp
// (7037) - it is the ManiaScript application host, and its Blocks sits in a
// family of script-side derived views (7261-7266: Blocks, BlockModels,
// TerrainBlockModels, MacroblockModels, ClassicBlocks, TerrainBlocks). Such a
// view answers .Length with a real number while its data pointer is not
// allocated for a native reader, which is precisely what was observed:
// .Length returned 1249 without complaint, and [0] faulted at a fixed
// address. CGameCtnChallenge is a plain CMwNod (1493) holding the map's own
// storage, and pluginMap.Map (7104) is a marked handle to it.
//
// HOW WE KNOW IT WAS THE INDEXING AND NOT A FIELD. Openplanet validates nod
// member reads and logs "Invalid address for member ID ..." when one fails,
// setting it to null and surviving. That warning appeared at the 22:42
// crash. It did NOT appear at the 23:50 one - the process died before any
// CGameCtnBlock member was ever read. Which is why the trace line "indexing
// survived" sat between buffer[i] and the first field read: it was the line
// that discriminated, and the line that never printed until this version.
// That trace, the Diag() instrument, was removed once the fault was named
// (MD2, 2026-10-13); the fix above is what stays.
//
// TWO EARLIER FIXES BLAMED THE WRONG THING. v0.3.2 removed
// WaypointSpecialProperty; the crash came back. The next attempt blamed the
// unmarked BlockInfo and preferred the marked BlockModel; the crash came
// back. Both were chosen on which field looked most suspicious, never proven
// by a trace. The marked/bare distinction is real but answers only one
// question - "does ManiaScript see this member?" - and it never answered the
// one that mattered here.
//
// The argument "no shipped plugin uses pluginMap.Blocks" was also used, and
// it is weak: only 2 of 9 unpacked plugins enumerate placed blocks at all, so
// that is a sample of 2, not of 9. This fix rests on the mechanism above. The
// two real precedents merely agree with it, and both snapshot the buffer into
// a local the way this function now does:
//
//     BlocksItemsCounter/Source/Libs/Objects.as:29
//     EditorHelpers/src/EditorFunction/PodiumReminder.as:185
//
// THE WAYPOINT ROLE CAME SECOND, ON PURPOSE. It is free ground truth - a
// start, checkpoint or finish is route by definition - and the safe source is
// on the model: CGameCtnBlockInfo carries "const EWayPointType WaypointType;"
// (1909), a marked plain enum rather than a pointer. It was held back until
// the fix above had proven the crash gone - 1831 blocks read, survey running -
// because a second change in the same build would have made a second crash
// unattributable. ScanMap now reads it into PlacedBlock.waypoint, through
// block.BlockModel, never through a pointer on the block itself.
