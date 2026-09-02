// MapDecorator - read the map the player already built.
//
// MODEL. It reads the map and returns a picture of it; it writes nothing.
//
// This file has no counterpart in TrackGen, and it is the whole difference
// between the two plugins: TrackGen starts from an empty map and owns what it
// writes, while this one inherits a finished map and may only use the space the
// track left over.
//
// What it has to produce before anything can be placed:
//   - the occupied cells: where the track and the existing scenery already
//     stand, i.e. everywhere this plugin must not write;
//   - the free cells, per height level;
//   - the border: free cells adjacent to the track, which is where decoration
//     actually reads from the driver's seat.
//
// One trap paid for in TrackGen still applies: an empty cell is NOT null.
// GetBlock returns StadiumGrass on empty ground, so occupancy must be judged on
// the picture this file builds, not by asking the map cell by cell.
//
// STATUS: declaration only.

namespace Model
{
}
