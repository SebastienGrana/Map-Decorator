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
// STATUS: BuildPlan wires the Ready/Placed lifecycle. It always returns an
// empty plan - the free-space packing strategy itself is still unwritten
// (13-strategies.md).

namespace Model
{
	// One block the plan proposes to place. Carries its own map coordinates
	// and family name so the View can list it without recomputing anything.
	class PlacementEntry
	{
		string name;
		string family;
		int x, y, z;

		// ECardinalDirections as an int: placing and undoing both need it,
		// and BuildPlan has no packing strategy yet to decide it, so it
		// fills every entry with 0 (North) until one exists.
		int dir;
	}

	// One "N skipped - reason" line. Candidates rejected for the same stated
	// cause are grouped under a single count rather than one line each.
	class SkipReason
	{
		uint count;
		string reason;
	}

	// What BuildPlan proposes: what to place, and why some candidates were
	// left out. Pure data - Ctrl::Place is the only file allowed to turn a
	// Plan into blocks on the map.
	class Plan
	{
		array<PlacementEntry@> placements;
		array<SkipReason@> skipped;
	}

	// Decides what to place and where. Returns an empty plan for now: only
	// the path from a click to a Ready plan is being wired here, not the
	// strategy that would fill it in.
	Plan BuildPlan()
	{
		Plan plan;
		return plan;
	}
}
