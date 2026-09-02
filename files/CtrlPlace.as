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
// STATUS: declaration only.

namespace Ctrl
{
}
