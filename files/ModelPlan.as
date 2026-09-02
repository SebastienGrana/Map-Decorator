// MapDecorator - decide what goes where, without touching the map.
//
// MODEL, deliberately. It decides, which sounds like a Controller job, but it
// never touches the map and holds no state: give it an occupancy picture and a
// palette, it returns a list of placements. That makes it pure, testable and
// replayable - a plan that paints itself into a corner is thrown away and
// redrawn rather than undone.
//
// Ctrl::Place is the only file allowed to turn a plan into blocks.
//
// STATUS: declaration only.

namespace Model
{
}
