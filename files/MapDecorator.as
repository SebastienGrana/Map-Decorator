// MapDecorator - scenery pass over a map somebody else already built.
//
// CONTROLLER. This file owns the state, drives the frame loop, and is the only
// place that decides when something happens. It calculates nothing itself: it
// asks the Model namespace for values and hands them to the View.
//
// It is a SEPARATE deliverable from TrackGen and shares no code with it. What
// it borrows is method - TrackGen proved the editor palette declares each
// block's footprint and its clips, and that reading is what this plugin needs,
// aimed at the scenery families instead of the road ones.
//
// The one hard difference from TrackGen, and the reason this is not a setting
// inside it: TrackGen owns an empty map and writes a track onto it, while
// MapDecorator inherits a finished map it did not write, must not damage it,
// and only has the space the track left over. Reading comes before writing
// here, which is why Model::Scan exists and has no counterpart in TrackGen.
//
// STATUS: reads the palette and reports what joins nothing. Nothing is placed.

// Shown in the window title so a screenshot always says which build is loaded.
const string c_Version = "0.5.0";

// Whether the plugin window is open. A plain global rather than a local of
// Main(), because RenderMenu() toggles it from outside the frame loop.
bool g_WindowVisible = false;

// How sure the plugin is about which blocks on this map are route, support or
// decor. Guessed and Measured both come from a source of truth outside this
// enum - the point here is only how far the window can trust that source.
enum TrackKnowledge { Unknown, Guessed, Measured }

// Where the current decoration plan stands: nothing computed yet, a plan
// ready to place, or already placed on the map.
enum PlanState { None, Ready, Placed }

// The only source of truth for how much the plugin knows about this map.
// Changed only through SetTrackKnowledge(), because that is what keeps
// g_PlanState and g_PlaceArmed from ever describing a plan for a map the
// plugin no longer trusts.
TrackKnowledge g_TrackKnowledge = TrackKnowledge::Unknown;

// The route/support/decor counts shown on the Map tab once the track is
// guessed or measured. Stays zero until a detection path fills it in - see
// Model::Split.
Model::Split g_Split;

// The only source of truth for the decoration plan's lifecycle. Changed only
// through SetTrackKnowledge() and ResetPlan().
PlanState g_PlanState = PlanState::None;

// Whether the Place action is armed, i.e. the next click actually writes to
// the map. A separate flag from g_PlanState rather than a third PlanState
// value, because arming is a per-visit confirmation, not a stage of the plan.
bool g_PlaceArmed = false;

// Whether Preview is waiting on the Guessed confirm/cancel choice, i.e. the
// click on Preview has not yet been confirmed into an actual BuildPlan call.
bool g_PreviewArmed = false;

// The only way to change what the plugin knows about the map. Resets the plan
// and disarms Place and Preview, because a plan and an armed action both
// describe a map this knowledge no longer matches.
void SetTrackKnowledge(TrackKnowledge k)
{
	g_TrackKnowledge = k;
	g_PlanState = PlanState::None;
	g_PlaceArmed = false;
	g_PreviewArmed = false;
}

// The only way to clear the decoration plan without touching what the plugin
// knows about the map.
void ResetPlan()
{
	g_PlanState = PlanState::None;
	g_PlaceArmed = false;
	g_PreviewArmed = false;
}

// The only way to disarm the Place action without discarding the plan itself.
void Disarm()
{
	g_PlaceArmed = false;
	g_PreviewArmed = false;
}

// Where the decor goes: away from the track, or hugging it. Fill is the
// measured default - only 7.4 % of placed scenery on real maps sits within
// 32 m of the driven line (cairn, 2026-09-14: 497 maps with a run >= 300 m,
// 576 817 objects). Provisional: the ghost reader truncates maps wider than
// 32 cells (26.2 % of objects), and on_route still counts trackside scenery
// as "on route" until cairn's role column lands (cairn P6).
enum DecorStrategy { Fill, Border }
DecorStrategy g_DecorStrategy = DecorStrategy::Fill;

// One checkbox per decor family offered in the Decorate tab, in the order the
// window draws them. Trees, Rocks and Buildings start checked; Fences and
// Inflatables start unchecked - matches the mockup's default selection.
enum DecorFamily { Trees, Rocks, Buildings, Fences, Inflatables }
array<bool> g_FamilyEnabled = {true, true, true, false, false};

// How much decor to place: 1 = Low, 2 = Medium, 3 = High.
int g_Density = 2;

// Minimum distance kept from the track, in 32 m steps from 1 to 8.
int g_MinDistSteps = 2;

// Every setter below touches a decoration setting, so every one of them
// disarms Place: a plan computed under the old settings must not be placed
// under the new ones without being looked at again.
void SetDecorStrategy(DecorStrategy s)
{
	g_DecorStrategy = s;
	Disarm();
}

void ToggleFamily(DecorFamily f)
{
	g_FamilyEnabled[f] = !g_FamilyEnabled[f];
	Disarm();
}

void SetDensity(int d)
{
	g_Density = d;
	Disarm();
}

void SetMinDistSteps(int d)
{
	g_MinDistSteps = d;
	Disarm();
}

// The last plan Preview built. Empty until PreviewPlan() runs, and only ever
// replaced wholesale - nothing mutates it in place.
Model::Plan g_Plan;

// Placements Ctrl::PlacePlan actually wrote to the map, in the order it wrote
// them. Undo (U4) is only allowed to remove what is recorded here - a
// placement PlaceBlock_NoDestruction refused was never written to the map.
// Replaced wholesale by each PlacePlan call, like g_Plan.
array<Model::PlacementEntry@> g_PlacedLog;

// Whether the pending Place would drop an undo point first. Checked by
// default, matching the mockup.
bool g_SaveUndoFirst = true;

// Builds a fresh decoration plan and makes it Ready. Called only from the
// Preview button - like ScanPalette, a plan is a decision, never recomputed
// on its own. Disarms Place: a plan just rebuilt has not been looked at yet.
void PreviewPlan()
{
	if (!HasEditor()) return;

	g_Plan = Model::BuildPlan();
	g_PlanState = PlanState::Ready;
	Disarm();
}

// What the Preview button does. On a Guessed route, previewing itself asks
// once: the first click only arms the confirm/cancel choice, since the route
// under it is not trusted - the second click (RequestPreview again while
// armed, i.e. Confirm) is what actually builds the plan. On any other track
// knowledge there is nothing to confirm, so it builds right away.
void RequestPreview()
{
	if (g_TrackKnowledge == TrackKnowledge::Guessed && !g_PreviewArmed) {
		g_PreviewArmed = true;
		return;
	}
	PreviewPlan();
}

// Cancels a Preview waiting on Guessed's confirm/cancel choice, without
// building a plan.
void CancelPreview()
{
	g_PreviewArmed = false;
}

// Toggles whether Place would drop an undo point first. Disarms like every
// other setting: an armed Place agreed to a specific choice here, and that
// choice just changed.
void SetSaveUndoFirst(bool v)
{
	g_SaveUndoFirst = v;
	Disarm();
}

// The editor this plugin is attached to, or null when the user is not in the
// map editor. Refreshed every frame on purpose: the editor object is destroyed
// when the user leaves it, and holding on to a stale handle is how a plugin
// takes the game down with it.
CGameCtnEditorFree@ g_Editor = null;

// What the Map tab's header shows about the loaded map. Blank/zero fields
// until ReadMap() has run once - the header must never show a number nobody
// has actually read.
class MapSummary
{
	string name;
	string environment;
	string author;
	uint blockCount;
	uint cellsOccupied;
}

MapSummary g_MapSummary;
bool g_HasReadMap = false;

// Time::Now, in milliseconds since the game started, at the last ReadMap().
// Used only to show how stale the header is - never to decide anything.
uint64 g_MapReadAtMs = 0;

// Reads the currently loaded map into g_MapSummary. Called only from the Map
// tab's "Read this map again" button - like ScanPalette, reading is a user
// decision, never redone silently every frame. Writes nothing to the map.
void ReadMap()
{
	if (!HasEditor()) return;

	auto pluginMap = g_Editor.PluginMapType;
	uint freeMapping;
	auto blocks = Model::ScanMap(pluginMap, freeMapping);
	auto plan = Model::BuildOccupancyPlan(blocks);

	auto map = pluginMap is null ? null : pluginMap.Map;
	g_MapSummary.name = map is null ? "" : string(map.MapName);
	g_MapSummary.environment = map is null ? "" : map.CollectionName;
	g_MapSummary.author = map is null ? "" : string(map.AuthorNickName);
	g_MapSummary.blockCount = blocks.Length + freeMapping;
	g_MapSummary.cellsOccupied = plan.Count();

	g_HasReadMap = true;
	g_MapReadAtMs = Time::Now;

	// Logged as well as shown, so the numbers on screen can be checked
	// against the log on a real map.
	Log("MapDecorator read map '" + g_MapSummary.name + "': "
		+ g_MapSummary.environment + " . author " + g_MapSummary.author
		+ " . " + g_MapSummary.blockCount + " blocks . "
		+ g_MapSummary.cellsOccupied + " cells used");
}

// Whether a drive sampling session is currently running. Armed by
// StartDriveSessionDetected(), read every frame by Update() to decide
// whether to sample - cleared only by ending the session.
bool g_DriveSessionActive = false;

// Which drive is running: a free test drive that never stops itself, or a
// validation run that stops at the finish line. Read every frame by Update()
// to know whether IsTesting or IsValidating marks this session's end.
enum DriveKind { Testing, Validating }
DriveKind g_DriveKind = DriveKind::Testing;

// What the running session is and why, kept only to show in the Debug tab -
// a wrong reading here would otherwise be silent until the session never
// ends on its own.
string g_DriveDecisionLabel = "";

// Cells the running drive session has sampled so far. Replaced wholesale by
// StartDriveSessionDetected(), like g_Plan is by PreviewPlan().
Model::TrackCells g_TrackCells;

// Update() calls since the session started, compared against
// g_SettingSampleEveryNFrames to decide whether the current frame samples.
uint g_DriveFrameCounter = 0;

// Whether the running flag (IsTesting or IsValidating, whichever g_DriveKind
// points at) has read true at least once since the session was armed. Both
// flags can take a frame or two to actually read true, so Update() must not
// read the pre-start "false" as the session already having ended - see
// StartDriveSessionDetected(), which sets this true immediately instead,
// since by construction the run is already under way when it is called.
bool g_DriveSessionSeenRunning = false;

// The map's ValidationStatus, refreshed every frame by Update() so the Map
// tab can show a live reading of whether this map has a finish and has
// already been validated - the View never reads game API directly
// (03-architecture.md), it only reads this.
CGameEditorPluginMapMapType::EValidationStatus g_ValidationStatus
	= CGameEditorPluginMapMapType::EValidationStatus::NotValidable;

// What the map said about its own validation run when the running session
// started, as ValidationRunFingerprint() writes it. Compared at close to
// tell a real finish from an Escape cancel.
string g_ValidationFingerprintAtStart = "";

// What the map says about its own validation run: the author time it
// declares, and the race time of the ghost the editor keeps as the run that
// validated it. A validation that actually reaches the finish rewrites both;
// one abandoned with Escape leaves them untouched.
//
// This is the only signal measured to work on a map that was already
// Validated before the run: ValidationStatus stays Validated either way, and
// so do ValidationEndRequested / ValidationEndNoConfirm /
// IsSwitchedToPlayground - all four read identically after an Escape cancel
// (measured in game 2026-09-05, log at 00:39:54).
string ValidationRunFingerprint()
{
	if (!HasEditor()) return "no-editor";

	auto map = g_Editor.PluginMapType.Map;
	if (map is null) return "no-map";

	string ghostTime = "none";
	auto params = map.ChallengeParameters;
	if (params !is null && params.RaceValidateGhost !is null) {
		ghostTime = "" + params.RaceValidateGhost.RaceTime;
	}

	return "authorTime=" + map.TMObjective_AuthorTime
		+ " ghostTime=" + ghostTime;
}

// R6 probe (piste 1): does this plugin ever reach a populated
// CTmRaceInterfaceManialinkScripHandler once a drive session is running?
// Openplanet.h documents ValidationGhost_GetPosition/IsVisible on that type
// for Manialink scripts, not editor plugins, and the only field pointing to
// it (CGameCtnNetwork.PlaygroundInterfaceScriptHandler) carries no
// "// Maniascript" tag either way - settled here, in game, not from the
// header alone. Remove once R6 is decided.
void LogManialinkHandlerReachability(const string &in when)
{
	auto network = GetApp().Network;
	if (network is null) {
		Log("MapDecorator R6 probe (" + when + "): Network is null");
		return;
	}

	auto handler = cast<CTmRaceInterfaceManialinkScripHandler>(
		network.PlaygroundInterfaceScriptHandler);
	if (handler is null) {
		Log("MapDecorator R6 probe (" + when + "): PlaygroundInterfaceScriptHandler"
			+ " is null or not a race handler");
		return;
	}

	Log("MapDecorator R6 probe (" + when + "): handler reached,"
		+ " ValidationGhost_IsVisible=" + handler.ValidationGhost_IsVisible());
}

// Turns an EValidationStatus into the word shown in the log and the Debug
// tab - the game gives no string form of its own.
string ValidationStatusLabel(CGameEditorPluginMapMapType::EValidationStatus s)
{
	if (s == CGameEditorPluginMapMapType::EValidationStatus::Validable) return "Validable";
	if (s == CGameEditorPluginMapMapType::EValidationStatus::Validated) return "Validated";
	return "NotValidable";
}

// Arms the sampling session for a drive this plugin did not start itself -
// the only way a session starts: launching Validate() plus
// RequestEnterPlayground() ourselves reproduced a native game error
// ("Race::StartValidation() ... Must be called before loadmap") on the very
// click that called them, confirmed in game on 2026-09-04. So neither the
// free test drive nor the validation run is ever launched from this plugin
// any more - both are only ever picked up passively, by Update() noticing
// IsTesting or IsValidating already true because the user tested or
// validated from the game's own menu.
void StartDriveSessionDetected(DriveKind kind)
{
	g_DriveKind = kind;
	g_ValidationFingerprintAtStart = ValidationRunFingerprint();
	LogManialinkHandlerReachability("session start");

	g_DriveDecisionLabel = "ValidationStatus=" + ValidationStatusLabel(g_ValidationStatus)
		+ " -> " + (kind == DriveKind::Validating ? "Validate()" : "TestMapFromStart()")
		+ " detected from the game's own menu";
	Log("MapDecorator drive session auto-detected: " + g_DriveDecisionLabel);

	g_TrackCells = Model::TrackCells();
	g_DriveFrameCounter = 0;
	g_DriveSessionActive = true;
	g_DriveSessionSeenRunning = true;
}

// Samples every controlled player's position into g_TrackCells, once every
// g_SettingSampleEveryNFrames frames. Called from Update() only while a
// drive session is active.
void SampleDriveSession()
{
	g_DriveFrameCounter++;
	if (g_DriveFrameCounter % g_SettingSampleEveryNFrames != 0) return;

	auto playground = GetApp().CurrentPlayground;
	if (playground is null) return;

	for (uint i = 0; i < playground.GameTerminals.Length; i++) {
		auto player = cast<CTrackManiaPlayer>(
			playground.GameTerminals[i].ControlledPlayer);
		if (player is null) continue;

		g_TrackCells.MarkPosition(player.Position);
	}
}

// Ends the running drive session and turns its samples into the plugin's
// track knowledge. Called from the "Stop and use this run" button (always
// offered as an escape hatch), and from Update() once a Testing session's
// IsTesting drops back to false, or a Validating session's IsValidating
// drops back to false while ValidationStatus shows the run actually reached
// the finish (see Update() - a Validating session that stopped without
// that stops at CancelDriveSession() instead).
void EndDriveSession()
{
	g_DriveSessionActive = false;
	LogManialinkHandlerReachability("session end");
	g_Split.route = g_TrackCells.Count();
	SetTrackKnowledge(TrackKnowledge::Measured);

	Log("MapDecorator drive session closed: " + g_Split.route + " cells");
}

// Ends a Validating session that stopped without reaching the finish -
// Escape canceling a validation, not a completed run. Discards the samples
// instead of confirming them: TrackKnowledge stays whatever it was before
// this session (reported in game 2026-09-05, a false "Measured" without
// ever crossing the line).
void CancelDriveSession()
{
	g_DriveSessionActive = false;

	Log("MapDecorator drive session cancelled: " + g_TrackCells.Count()
		+ " cells discarded (validation ended without reaching Validated)");
}

// The last palette scan. Empty until the user asks for one.
//
// Held here rather than recomputed per frame because a scan walks every block
// model in the palette - cheap once, wasteful sixty times a second. It is a
// snapshot: it does not follow the palette if the editor changes environment,
// which is why the View says when it was taken.
array<Model::BlockEntry@> g_Palette;
bool g_HasScanned = false;

// The subset of g_Palette that declares no clip at all. Filtered once, at scan
// time, rather than by the View every frame: the View displays, it does not
// compute.
array<Model::BlockEntry@> g_Unconnectable;

// Openplanet entry point, called once when the plugin loads.
void Main()
{
	Log("MapDecorator " + c_Version + " loaded");
}

// Called every frame. Kept to the single job of refreshing the editor handle;
// anything that decides or calculates belongs in the Model namespace.
void Update(float dt)
{
	@g_Editor = cast<CGameCtnEditorFree>(GetApp().Editor);

	if (HasEditor()) {
		g_ValidationStatus = g_Editor.PluginMapType.ValidationStatus;
	}

	if (!g_DriveSessionActive && HasEditor()) {
		auto pm = g_Editor.PluginMapType;
		if (pm.IsValidating) {
			StartDriveSessionDetected(DriveKind::Validating);
		} else if (pm.IsTesting) {
			StartDriveSessionDetected(DriveKind::Testing);
		}
	}

	if (g_DriveSessionActive) {
		SampleDriveSession();

		if (HasEditor()) {
			auto pm = g_Editor.PluginMapType;
			bool running = g_DriveKind == DriveKind::Validating
				? pm.IsValidating
				: pm.IsTesting;
			if (running) {
				g_DriveSessionSeenRunning = true;
			} else if (g_DriveSessionSeenRunning) {
				// A Testing session has no finish to reach - any way it stops
				// (Escape, "Back to editor") is a completed run. A Validating
				// session only counts as one if the map now carries a
				// different validation run than it did when the session
				// started: Escape answers "Retour à l'éditeur ?" and abandons,
				// which leaves the map's own validation run untouched.
				string fingerprintAtEnd = ValidationRunFingerprint();
				bool reachedFinish = g_DriveKind == DriveKind::Testing
					|| fingerprintAtEnd != g_ValidationFingerprintAtStart;
				// The raw fingerprints stay beside the verdict on purpose: a
				// verdict without them cannot be diagnosed when it is wrong,
				// and this one has already been wrong twice.
				Log("MapDecorator drive stopped: kind=" + (g_DriveKind == DriveKind::Validating ? "Validating" : "Testing")
					+ " ValidationStatus=" + ValidationStatusLabel(pm.ValidationStatus)
					+ " | at start: " + g_ValidationFingerprintAtStart
					+ " | at end: " + fingerprintAtEnd
					+ " -> " + (reachedFinish ? "confirmed" : "cancelled (Escape)"));
				if (reachedFinish) EndDriveSession();
				else CancelDriveSession();
			}
		}
	}
}

// Called every frame to draw the plugin's own windows.
void RenderInterface()
{
	if (!g_WindowVisible) return;
	View::RenderWindow();
}

// Puts the plugin in Openplanet's menu, so the window can be reopened after
// the user closes it.
void RenderMenu()
{
	if (UI::MenuItem("MapDecorator", "", g_WindowVisible)) {
		g_WindowVisible = !g_WindowVisible;
	}
}

// True when there is a live editor to work on. Every action must ask this
// first: the handle is null everywhere outside the map editor.
bool HasEditor()
{
	return g_Editor !is null && g_Editor.PluginMapType !is null;
}

// Reads the palette into g_Palette. Called from the View's button, because a
// scan is a user decision - it is never run on its own.
void ScanPalette()
{
	if (!HasEditor()) return;

	g_Palette = Model::ScanPalette(g_Editor.PluginMapType);
	g_Unconnectable = Model::UnconnectableOf(g_Palette);
	g_HasScanned = true;

	// Logged as well as shown, so the raw counts survive in the log even when
	// the window is closed or the numbers look wrong.
	Log("MapDecorator scanned " + g_Palette.Length + " block models, "
		+ g_Unconnectable.Length + " of them declare no clip");

	// Each clip-less block is named with its cell count, because the count
	// alone cannot be trusted. A block with neither a ground nor an air variant
	// yields a null variant, hence zero clips AND zero cells - it looks like a
	// block that joins nothing while really being a block we failed to read.
	// Printing cells separates the two: 0 cells means artefact, not scenery.
	for (uint i = 0; i < g_Unconnectable.Length; i++) {
		auto entry = g_Unconnectable[i];
		Log("  no clip: " + entry.name + "  (" + entry.cells + " cells, page "
			+ entry.page + ")");
	}
}
