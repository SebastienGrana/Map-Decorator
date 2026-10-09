// MapDecorator - convert a world position into the track's cell grid.
//
// MODEL. Pure data and pure functions: no CGameCtn*, no call into the game
// anywhere in this file. This is the only place that knows the cell
// conversion constants (cell size 32 in X/Z, 8 in Y, +8 vertical offset) -
// R2 calls WorldToCell rather than recopying them.

namespace Model
{
	const float c_CellSizeXZ = 32.0f;
	const float c_CellSizeY = 8.0f;
	const int c_CellOffsetY = 8;

	// Converts a world-space position (as read from CTrackManiaPlayer.Position)
	// into the cell it falls in, using the same grid the editor's blocks sit
	// on.
	nat3 WorldToCell(vec3 pos)
	{
		return nat3(
			uint(pos.x / c_CellSizeXZ),
			uint(pos.y / c_CellSizeY) + c_CellOffsetY,
			uint(pos.z / c_CellSizeXZ)
		);
	}

	// Which cells the track has been seen occupying. Keyed the same way
	// Model::OccupancyPlan keys a cell ("x/y/z" in ModelScan.as), so this plan
	// and the block survey agree on what a cell even is.
	class TrackCells
	{
		private dictionary m_cells;

		// Split so a session can show both counts side by side
		// (feedback_print-sample-beside-verdict) rather than only the total:
		// a total alone cannot say whether interpolation did anything.
		private uint m_rawCellCount = 0;
		private uint m_interpolatedCellCount = 0;

		private vec3 m_lastPos;
		private bool m_hasLast = false;

		private void MarkCell(nat3 coord, bool interpolated)
		{
			string key = "" + coord.x + "/" + coord.y + "/" + coord.z;
			if (m_cells.Exists(key)) return;

			m_cells[key] = true;
			if (interpolated) m_interpolatedCellCount++;
			else m_rawCellCount++;
		}

		// Marks the cell a raw sample falls in. When the previous sample is
		// far enough away that a straight line between them would cross
		// cells this one alone does not cover - a fast car outruns a fixed
		// sampling rate - the crossed cells are filled in too.
		void MarkPosition(vec3 pos)
		{
			if (m_hasLast) FillBetween(m_lastPos, pos);

			MarkCell(WorldToCell(pos), false);
			m_lastPos = pos;
			m_hasLast = true;
		}

		// Walks the straight line from the previous sample to this one and
		// marks every cell it crosses, one step per cell size so no cell in
		// between is skipped.
		private void FillBetween(vec3 fromPos, vec3 toPos)
		{
			float dist = (toPos - fromPos).Length();
			if (dist <= c_CellSizeXZ) return;

			uint steps = uint(Math::Ceil(dist / c_CellSizeXZ));
			for (uint i = 1; i < steps; i++) {
				float t = float(i) / float(steps);
				MarkCell(WorldToCell(fromPos + (toPos - fromPos) * t), true);
			}
		}

		bool IsOccupied(nat3 coord) const
		{
			return m_cells.Exists("" + coord.x + "/" + coord.y + "/"
				+ coord.z);
		}

		uint Count() const { return m_cells.GetSize(); }
		uint RawCount() const { return m_rawCellCount; }
		uint InterpolatedCount() const { return m_interpolatedCellCount; }
	}
}
