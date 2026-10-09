// MapDecorator - persisted plugin settings.
//
// Every [Setting]-annotated global below is written and reloaded by Openplanet
// itself on plugin load/unload - that annotation is what makes a value survive
// a reload (F3), and nothing else in this file needs to write to disk.
//
// STATUS: none of these settings is read by Model::BuildPlan yet - the
// free-space strategy that would consume them does not exist (13-strategies.md).
// They still have to be real, editable, persisted settings today, so the
// window (RenderSettingsTab) keeps every field enabled and says so next to it.

// ---- Visible settings ------------------------------------------------------

[Setting name="Safety margin around the track" description="Cells kept clear on every side of the route before decor may be placed."]
int g_SettingMarginCells = 1;

[Setting name="Keep clear of checkpoints" description="Cells kept clear around every checkpoint, start and finish block."]
int g_SettingCheckpointClearCells = 2;

[Setting name="Never place on Support blocks" description="Keeps decor off blocks labelled Support, even where they leave free space."]
bool g_SettingNeverOnSupport = true;

[Setting name="Always save an undo point" description="Default for the undo checkbox a pass offers before it places anything."]
bool g_SettingAlwaysSaveUndo = true;

[Setting name="Ask before placing more than 500 blocks" description="Asks for confirmation before a pass that would place more than 500 blocks."]
bool g_SettingAskBeyond500 = true;

// ---- Advanced settings ------------------------------------------------------

[Setting name="Random seed" description="Seed for every random choice a pass makes - rotation, density sampling, anything non-deterministic."]
int g_SettingRandomSeed = 20260903;

[Setting name="Max blocks per pass" description="Upper bound on how many blocks a single pass will place."]
int g_SettingMaxBlocksPerPass = 400;

[Setting name="Farthest ring from the track" description="How many 32 m rings out from the track a pass will still consider for decor."]
int g_SettingFarthestRing = 16;

[Setting name="Drive sampling rate" description="How many frames between two positions sampled while driving the track live. 1 means every frame."]
int g_SettingSampleEveryNFrames = 1;

[Setting name="Infer Support from blocks under the route" description="Labels a block Support automatically when it sits directly under a Route block, instead of asking."]
bool g_SettingInferSupport = true;

[Setting name="Random rotation" description="Rotates each placed block to a random one of its four facings instead of always the same one."]
bool g_SettingRandomRotation = true;

[Setting name="Allow placement in the air" description="Lets decor be placed on cells with nothing underneath, instead of only on ground cells."]
bool g_SettingAllowAirPlacement = false;

// ---- Defaults, for Reset to defaults ---------------------------------------

const int c_DefaultMarginCells = 1;
const int c_DefaultCheckpointClearCells = 2;
const bool c_DefaultNeverOnSupport = true;
const bool c_DefaultAlwaysSaveUndo = true;
const bool c_DefaultAskBeyond500 = true;
const int c_DefaultRandomSeed = 20260903;
const int c_DefaultMaxBlocksPerPass = 400;
const int c_DefaultFarthestRing = 16;
const int c_DefaultSampleEveryNFrames = 1;
const bool c_DefaultInferSupport = true;
const bool c_DefaultRandomRotation = true;
const bool c_DefaultAllowAirPlacement = false;

// The only way to reset settings. Called from the Settings tab's button -
// resetting is a user decision, never something that runs on its own.
void ResetSettingsToDefaults()
{
	g_SettingMarginCells = c_DefaultMarginCells;
	g_SettingCheckpointClearCells = c_DefaultCheckpointClearCells;
	g_SettingNeverOnSupport = c_DefaultNeverOnSupport;
	g_SettingAlwaysSaveUndo = c_DefaultAlwaysSaveUndo;
	g_SettingAskBeyond500 = c_DefaultAskBeyond500;
	g_SettingRandomSeed = c_DefaultRandomSeed;
	g_SettingMaxBlocksPerPass = c_DefaultMaxBlocksPerPass;
	g_SettingFarthestRing = c_DefaultFarthestRing;
	g_SettingSampleEveryNFrames = c_DefaultSampleEveryNFrames;
	g_SettingInferSupport = c_DefaultInferSupport;
	g_SettingRandomRotation = c_DefaultRandomRotation;
	g_SettingAllowAirPlacement = c_DefaultAllowAirPlacement;
}
