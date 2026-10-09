// MapDecorator - what the user says each block really is.
//
// MODEL. It holds the labels and puts them on disk; it decides nothing and
// judges nothing. The judgement is the user's, this file only remembers it.
//
// WHY THIS EXISTS. Two independent measurements agree that nothing about a
// block tells you whether it is decoration: every block in the palette carries
// clips (551 of 551), and the same block names appear both on and off the
// driven route. So the classification cannot be derived from the block - it can
// only be fitted, and a fit needs ground truth.
//
// This file is that ground truth. The user walks the map, says "this one is
// route, that one is support, that one is decoration", and the labels are
// written where the offline tools in Cairn-VlpLib can read them back and check any
// proposed rule against a human verdict.
//
// The file is JSON keyed by cell, not by index: a block's position in the
// Blocks buffer changes the moment the map is edited, while its coordinate is
// what the user actually pointed at.

namespace Model
{
	// What a block is, in the user's eyes.
	//
	// Three classes and not two, because the binary route/decoration split was
	// losing the middle: pillars under a road, borders, the base a track sits
	// on. They serve the race without being driven on, and lumping them into
	// decoration would let a decoration pass overwrite the track's own support.
	enum Klass
	{
		Unlabelled = 0,
		Route      = 1,  // the player drives through this
		Support    = 2,  // carries or frames the race, but is not driven on
		Decor      = 3,  // could be removed and the race would be unchanged

		// Route, but derived by the plugin from the block's waypoint role rather
		// than judged by the user. Far from the other values on purpose: this
		// file is the ground truth a rule gets fitted against, so a label the
		// code produced must never be indistinguishable from a human verdict -
		// that would fit the rule against itself. The offline tools can fold it
		// into Route or drop it, and the choice stays theirs because the JSON
		// still says which is which.
		RouteWaypoint = 101
	}

	string KlassName(Klass k)
	{
		if (k == Klass::Route)   return "Route";
		if (k == Klass::RouteWaypoint) return "Route (waypoint)";
		if (k == Klass::Support) return "Support";
		if (k == Klass::Decor)   return "Decor";
		return "unlabelled";
	}

	// The three-way count behind the Map tab's bar, once the track is guessed
	// or measured. Filled with zero until a detection path actually exists -
	// a bar drawn from invented numbers would be a lie the window tells
	// before the plugin has done any work.
	class Split
	{
		uint route;
		uint support;
		uint decor;
	}

	// Labels for one map, keyed by "x/y/z".
	//
	// A dictionary rather than an array parallel to the scan: the user labels
	// over several sittings, and a map edited in between would silently shift
	// every index. The coordinate is what was pointed at, so the coordinate is
	// the key.
	class LabelStore
	{
		private dictionary m_byCell;

		string KeyOf(nat3 coord) const
		{
			return "" + coord.x + "/" + coord.y + "/" + coord.z;
		}

		void Set(nat3 coord, Klass k)
		{
			string key = KeyOf(coord);
			if (k == Klass::Unlabelled) {
				m_byCell.Delete(key);
				return;
			}
			m_byCell[key] = int(k);
		}

		Klass Get(nat3 coord) const
		{
			string key = KeyOf(coord);
			if (!m_byCell.Exists(key)) return Klass::Unlabelled;
			int stored;
			m_byCell.Get(key, stored);
			return Klass(stored);
		}

		uint Count() const { return m_byCell.GetSize(); }

		void Clear() { m_byCell.DeleteAll(); }

		// How many of each class, for the window. Counted on demand rather than
		// kept as running totals: a total that drifts out of step with the
		// dictionary would be a lie told confidently, and this is cheap.
		uint CountOf(Klass k) const
		{
			uint n = 0;
			auto keys = m_byCell.GetKeys();
			for (uint i = 0; i < keys.Length; i++) {
				int stored;
				m_byCell.Get(keys[i], stored);
				if (Klass(stored) == k) n++;
			}
			return n;
		}

		Json::Value@ ToJson() const
		{
			auto json = Json::Object();
			auto keys = m_byCell.GetKeys();
			for (uint i = 0; i < keys.Length; i++) {
				int stored;
				m_byCell.Get(keys[i], stored);
				json[keys[i]] = stored;
			}
			return json;
		}

		void FromJson(const Json::Value@ json)
		{
			Clear();
			if (json is null || json.GetType() != Json::Type::Object) return;

			auto keys = json.GetKeys();
			for (uint i = 0; i < keys.Length; i++) {
				m_byCell[keys[i]] = int(json[keys[i]]);
			}
		}
	}

	// One file per map, so labelling a second map cannot overwrite the first.
	// Spaces and punctuation in map names would make an unusable filename, so
	// anything outside a safe set becomes '_'.
	string LabelFileFor(const string &in mapName)
	{
		string safe;
		for (uint i = 0; i < uint(mapName.Length); i++) {
			string c = mapName.SubStr(i, 1);
			bool ok = (c >= "0" && c <= "9") || (c >= "A" && c <= "Z")
				|| (c >= "a" && c <= "z") || c == "-" || c == "_";
			safe += ok ? c : "_";
		}
		if (safe.Length == 0) safe = "unnamed";
		return IO::FromStorageFolder("labels_" + safe + ".json");
	}
}
