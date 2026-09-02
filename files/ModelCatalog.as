// MapDecorator - what the editor palette declares about each scenery block.
//
// MODEL. It reads the palette and returns what it found; it changes nothing.
//
// A block model carries variants, a variant carries one unit model per cell the
// block covers, and each unit carries clips - the faces it connects through.
// TrackGen established that reading on the road families; this file aims it at
// the scenery ones.
//
// Openplanet is what makes this worth doing here rather than in ManiaScript.
// Two members that decide this plugin's design are NOT exposed to ManiaScript
// (checked in Openplanet.h: they carry no "// Maniascript" marker, while the
// members TrackGen already uses do):
//
//   - CGameCtnBlockUnitInfo::TopClipDir / BottomClipDir, typed as a NAMED enum
//     (North / East / South / West). Which clip slot means which face was left
//     uncalibrated in TrackGen because ManiaScript simply cannot see this;
//   - CGameCtnBlockInfo::AdditionalVariantsGround / AdditionalVariantsAir.
//     Picking the right variant of a scenery block is this plugin's daily job.
//
// The questions to answer, in order:
//   1. Which families exist outside the road ones, and how big is each?
//   2. Do scenery blocks carry clips at all? A tree or a grandstand may join
//      nothing, in which case placement is governed by footprint and free space
//      alone, and the whole clip machinery is irrelevant here.
//   3. Declared box versus actually connected cells. TrackGen learnt the two
//      differ; scenery, being bigger and more irregular, will differ more.
//
// Question 2 comes first: its answer decides whether this plugin's core is a
// clip matcher or a free-space packer. Nothing else should be designed until it
// has been measured in game.
//
// STATUS: declaration only.

namespace Model
{
}
