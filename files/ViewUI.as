// MapDecorator - the plugin window, and nothing else.
//
// VIEW. It draws and it reads; it never decides and never computes. No block is
// placed from this file and no map is read by it: a widget asks a Controller to
// do something, and the Controller does it.
//
// Kept apart because the window is the file that changes most often and whose
// changes matter least - editing a label should not mean opening the
// decorator's logic.

namespace View
{
	// Height of the scrolling list, in pixels. Tall enough to read a few dozen
	// names without hiding the summary above it.
	const float c_ListHeight = 320.0f;

	// Which tab was active last frame. Compared against on every frame so a
	// tab switch can be told apart from simply redrawing the same tab -
	// Disarm() must fire once on the switch, not sixty times a second.
	string g_ActiveTab = "";

	// Disarms Place the first frame a tab becomes active. Placing is a
	// per-tab decision: leaving the tab that armed it must not leave a stale
	// armed action waiting behind on another tab.
	void NoteActiveTab(const string &in name)
	{
		if (g_ActiveTab == name) return;
		g_ActiveTab = name;
		Disarm();
	}

	void RenderWindow()
	{
		if (UI::Begin("MapDecorator " + c_Version, g_WindowVisible)) {
			RenderStrip();
			if (!HasEditor()) {
				UI::TextDisabled("Open a map in the editor to use MapDecorator.");
			} else {
				// BeginTabBar returns void in this Openplanet build, so it is a
				// statement; only BeginTabItem answers whether to draw.
				UI::BeginTabBar("modes");
				if (UI::BeginTabItem("Map")) {
					NoteActiveTab("Map");
					RenderMapTab();
					UI::EndTabItem();
				}
				if (UI::BeginTabItem("Decorate")) {
					NoteActiveTab("Decorate");
					RenderDecorateTab();
					UI::EndTabItem();
				}
				if (UI::BeginTabItem("Settings")) {
					NoteActiveTab("Settings");
					RenderSettingsTab();
					UI::EndTabItem();
				}
				if (UI::BeginTabItem("Debug")) {
					NoteActiveTab("Debug");
					RenderDebugTab();
					UI::EndTabItem();
				}
				UI::EndTabBar();
			}
		}
		UI::End();
	}

	// Three-way color a pill can take. Yellow sits between gray and green for
	// the track pill, whose Guessed state must never read as trustworthy as
	// Measured.
	enum PillColor { Gray, Yellow, Green }

	// The status strip: map / track / plan, recomputed from MapDecorator.as's
	// own state every frame. No pill variable exists and nothing "updates"
	// this strip - it simply reads what is already true.
	void RenderStrip()
	{
		bool mapRead = g_HasReadMap;
		RenderPill(mapRead ? PillColor::Green : PillColor::Gray,
			mapRead ? "Map read" : "No map");

		UI::SameLine();
		PillColor trackColor = PillColor::Gray;
		string trackLabel = "Track unknown";
		if (g_TrackKnowledge == TrackKnowledge::Guessed) {
			trackColor = PillColor::Yellow;
			trackLabel = "Track guessed";
		} else if (g_TrackKnowledge == TrackKnowledge::Measured) {
			trackColor = PillColor::Green;
			trackLabel = "Track measured";
		}
		RenderPill(trackColor, trackLabel);

		UI::SameLine();
		if (g_PlanState == PlanState::None) {
			RenderPill(PillColor::Gray, "No plan");
		} else if (g_PlanState == PlanState::Ready) {
			RenderPill(PillColor::Green, "Plan ready");
		} else {
			RenderPill(PillColor::Green, "Plan placed");
		}
	}

	void RenderPill(PillColor color, const string &in label)
	{
		vec4 c = vec4(0.55f, 0.55f, 0.55f, 1.0f);
		if (color == PillColor::Green) c = vec4(0.30f, 0.80f, 0.30f, 1.0f);
		else if (color == PillColor::Yellow) c = vec4(0.85f, 0.75f, 0.15f, 1.0f);

		UI::PushStyleColor(UI::Col::Text, c);
		UI::Text(label);
		UI::PopStyleColor();
	}

	// Very visible reading of g_ValidationStatus (MapDecorator.as, refreshed
	// every frame from the game) - the only cue left, now that no button
	// launches a validation from this window, telling the user whether
	// driving to the finish from the game's own menu would actually validate
	// this map.
	void RenderValidationStatusPill()
	{
		if (g_ValidationStatus == CGameEditorPluginMapMapType::EValidationStatus::Validated) {
			RenderPill(PillColor::Green, "Map validated");
		} else if (g_ValidationStatus == CGameEditorPluginMapMapType::EValidationStatus::Validable) {
			RenderPill(PillColor::Yellow, "Has a finish - not yet validated");
		} else {
			RenderPill(PillColor::Gray, "No finish line on this map");
		}
	}

	// How long ago a Time::Now millisecond timestamp was, for the "read N s
	// ago" line - display only, decides nothing.
	string TimeSinceLabel(uint64 sinceMs)
	{
		uint64 seconds = (Time::Now - sinceMs) / 1000;
		if (seconds < 60) return "" + seconds + " s";
		return "" + (seconds / 60) + " min";
	}

	// ---- Map tab: what this map is, and how well the track is known ----

	void RenderMapTab()
	{
		// Name, environment, author, block count and cells occupied all
		// come from the loaded map, through ReadMap(). Nothing is shown
		// before the first read - a blank header is honest, a guessed
		// one is not.
		if (g_HasReadMap) {
			UI::Text(g_MapSummary.name);
			UI::TextDisabled(g_MapSummary.environment + " . author "
				+ g_MapSummary.author + " . " + g_MapSummary.blockCount
				+ " blocks . " + g_MapSummary.cellsOccupied
				+ " cells used");
		}

		if (UI::Button("Read this map again")) {
			ReadMap();
		}
		if (g_HasReadMap) {
			UI::SameLine();
			UI::TextDisabled("read " + TimeSinceLabel(g_MapReadAtMs)
				+ " ago");
		}

		UI::Separator();

		if (g_TrackKnowledge == TrackKnowledge::Unknown) {
			RenderTrackUnknown();
		} else if (g_TrackKnowledge == TrackKnowledge::Guessed) {
			RenderTrackKnown(true);
		} else if (g_TrackKnowledge == TrackKnowledge::Measured) {
			RenderTrackKnown(false);
		}
	}

	// Shown while the plugin has no idea which blocks are road. Offers the
	// three ways to find out, all disabled for now: none of them is written
	// yet, and each says so instead of pretending to work.
	void RenderTrackUnknown()
	{
		UI::TextWrapped("MapDecorator does not know where the track is.");
		UI::TextWrapped("Nothing about a block says whether it is road or"
			" scenery - measured twice, on 551 palette models and 3511"
			" placed blocks. The track has to come from somewhere else.");

		UI::Separator();
		UI::TextDisabled("Three ways to find it");

		RenderValidationStatusPill();
		UI::SameLine();
		UI::TextDisabled("exact");
		if (g_DriveSessionActive) {
			UI::TextWrapped("One clean run. MapDecorator watches where the"
				" car goes, 60 samples a second.");
			if (UI::Button("Stop and use this run")) EndDriveSession();
			UI::SameLine();
			UI::TextDisabled("Session running - see Debug for the live"
				" count.");
		} else if (g_ValidationStatus == CGameEditorPluginMapMapType::EValidationStatus::Validated) {
			UI::PushStyleColor(UI::Col::Text, vec4(0.85f, 0.75f, 0.15f, 1.0f));
			UI::TextWrapped("This map is already validated, but MapDecorator"
				" has not measured its track yet.");
			UI::PopStyleColor();
			UI::TextWrapped("Re-validating from the game's own menu would"
				" work, but re-drives a track that already has a recorded"
				" run. \"Import a validation run\" below is meant for this"
				" case exactly.");
		} else {
			UI::TextWrapped("Test or validate the map from the game's own"
				" menu - MapDecorator watches where the car goes the moment"
				" either one starts, 60 samples a second. No button here any"
				" more: launching a validation from this window crashed the"
				" game on the very click (measured 2026-09-04).");
		}

		RenderTrackPathButton("Import a validation run", "exact",
			"Reads the ghost the editor wrote when this map was validated."
			" No driving needed.",
			"MapDecorator cannot read the ghost yet.");

		RenderTrackPathButton("Guess it", "approximate",
			"Follows the start, the checkpoints and the finish the map"
			" declares. A guess, never a measurement.",
			"The guess is not written yet.");
	}

	// One of the three grayed-out paths to learn the track: a disabled
	// button with its tag, the sentence explaining what it would do, and the
	// gray line saying why it cannot be used yet.
	void RenderTrackPathButton(const string &in label, const string &in tag,
		const string &in why, const string &in reason)
	{
		UI::BeginDisabled();
		UI::Button(label);
		UI::EndDisabled();
		UI::SameLine();
		UI::TextDisabled(tag);
		UI::TextWrapped(why);
		UI::TextDisabled(reason);
	}

	// Shown once the track is guessed or measured: the same three-part bar
	// and its numeric legend either way, since g_Split reads zero until a
	// detection path is wired in. Guessed additionally gets the yellow
	// warning, so a guess never reads as trustworthy as a measurement.
	void RenderTrackKnown(bool guessed)
	{
		if (guessed) {
			UI::PushStyleColor(UI::Col::Text, vec4(0.85f, 0.75f, 0.15f, 1.0f));
			UI::TextWrapped("This route was guessed, not driven.");
			UI::PopStyleColor();
			UI::TextWrapped("Traced through the declared waypoints. Jumps,"
				" shortcuts and anything off the straight line between"
				" checkpoints are missed - MapDecorator may take road for"
				" scenery.");
			UI::Separator();
		}

		RenderSplitBar();

		UI::TextDisabled("Wrong run, or want to try another source?");
		if (UI::Button("Reset")) SetTrackKnowledge(TrackKnowledge::Unknown);
	}

	// The route / support / decor bar and its legend, read from g_Split.
	// Three ProgressBar widgets side by side rather than one bar with
	// three colored fills, because Openplanet's UI has no multi-segment
	// bar primitive. Colored green for Measured, yellow for Guessed - a
	// ProgressBar's fill is UI::Col::PlotHistogram, not Text, so RenderPill's
	// color push doesn't reach it on its own.
	void RenderSplitBar()
	{
		uint total = g_Split.route + g_Split.support + g_Split.decor;
		float fRoute = total > 0 ? float(g_Split.route) / float(total) : 0.0f;
		float fSupport = total > 0 ? float(g_Split.support) / float(total) : 0.0f;
		float fDecor = total > 0 ? float(g_Split.decor) / float(total) : 0.0f;

		vec4 fill = vec4(0.30f, 0.80f, 0.30f, 1.0f);
		if (g_TrackKnowledge == TrackKnowledge::Guessed) {
			fill = vec4(0.85f, 0.75f, 0.15f, 1.0f);
		}

		UI::PushStyleColor(UI::Col::PlotHistogram, fill);
		UI::ProgressBar(fRoute, vec2(-1, 0), "");
		UI::SameLine();
		UI::ProgressBar(fSupport, vec2(-1, 0), "");
		UI::SameLine();
		UI::ProgressBar(fDecor, vec2(-1, 0), "");
		UI::PopStyleColor();

		UI::Text("" + g_Split.route + " Route");
		UI::SameLine();
		UI::Text("" + g_Split.support + " Support");
		UI::SameLine();
		UI::Text("" + g_Split.decor + " Decor");
	}

	// ---- Decorate: the strategy and its settings ------------------------

	// Blocked until the track is known at all - placing decor without
	// knowing what is road risks burying the track under trees. Guessed
	// still lets the choice through, with a warning up top.
	void RenderDecorateTab()
	{
		if (g_TrackKnowledge == TrackKnowledge::Unknown) {
			RenderDecorateBlocked();
		} else {
			RenderDecorateChoice();
		}
	}

	void RenderDecorateBlocked()
	{
		UI::TextWrapped("Find the track first.");
		UI::TextWrapped("Without it, MapDecorator cannot tell road from"
			" scenery - and would bury the track under trees.");
		if (UI::Button("Go to Map")) {
			// T1's tabs are driven by BeginTabItem, not by a variable this
			// button could set - switching tab programmatically is left for
			// whichever task wires that control.
		}
	}

	void RenderDecorateChoice()
	{
		if (g_TrackKnowledge == TrackKnowledge::Guessed) {
			UI::PushStyleColor(UI::Col::Text, vec4(0.85f, 0.75f, 0.15f, 1.0f));
			UI::TextWrapped("Working from a guessed route.");
			UI::PopStyleColor();
			UI::TextWrapped("Placing now may drop scenery onto road the guess"
				" did not see. Placing is allowed, and asks twice.");
			UI::Separator();
		}

		RenderStrategyChoice();
		UI::Separator();
		RenderFamilyChips();
		UI::Separator();
		RenderDecorateSliders();

		UI::Separator();
		RenderPreviewRow();

		if (g_PlanState == PlanState::Ready) {
			UI::Separator();
			RenderPlanReady();
		} else if (g_PlanState == PlanState::Placed) {
			UI::Separator();
			RenderPlanPlaced();
		}
	}

	// The Preview button. On a Guessed route, a first click grays Preview
	// and opens Confirm/Cancel next to it rather than building the plan
	// right away - Confirm builds it, Cancel drops the request and leaves
	// Preview as if nothing had been clicked.
	void RenderPreviewRow()
	{
		if (g_TrackKnowledge == TrackKnowledge::Guessed && g_PreviewArmed) {
			UI::BeginDisabled();
			UI::Button("Preview");
			UI::EndDisabled();

			UI::SameLine();
			if (UI::Button("Confirm")) {
				RequestPreview();
			}
			UI::SameLine();
			if (UI::Button("Cancel")) {
				CancelPreview();
			}
			UI::SameLine();
			UI::PushStyleColor(UI::Col::Text, vec4(0.85f, 0.75f, 0.15f, 1.0f));
			UI::Text("This map's route was never validated - it's a guess.");
			UI::PopStyleColor();
			return;
		}

		if (UI::Button("Preview")) {
			RequestPreview();
		}
	}

	// The plan Preview just built: the headline count, one warning line per
	// skip reason, the scrolling list of what it would place, the undo
	// checkbox and the pose button.
	void RenderPlanReady()
	{
		UI::Text("" + g_Plan.placements.Length + " blocks proposed");

		UI::PushStyleColor(UI::Col::Text, vec4(0.85f, 0.75f, 0.15f, 1.0f));
		for (uint i = 0; i < g_Plan.skipped.Length; i++) {
			auto skip = g_Plan.skipped[i];
			UI::TextWrapped("" + skip.count + " skipped — " + skip.reason);
		}
		UI::PopStyleColor();

		UI::BeginChild("plan_list", vec2(0, c_ListHeight));
		for (uint i = 0; i < g_Plan.placements.Length; i++) {
			auto entry = g_Plan.placements[i];
			UI::Text(entry.name);
			UI::SameLine();
			UI::TextDisabled("  cell " + entry.x + " / " + entry.y + " / "
				+ entry.z + " · " + entry.family);
		}
		UI::EndChild();

		bool saveUndo = UI::Checkbox("Save an undo point first", g_SaveUndoFirst);
		if (saveUndo != g_SaveUndoFirst) SetSaveUndoFirst(saveUndo);

		RenderPlaceButton();
	}

	// The pose button. One rule governs it now that undo exists: the first
	// click while Guessed only arms and writes nothing to the map, so it
	// needs no confirmation beyond that; every other case places for real.
	void RenderPlaceButton()
	{
		bool guessedUnarmed = g_TrackKnowledge == TrackKnowledge::Guessed
			&& !g_PlaceArmed;

		if (guessedUnarmed) {
			if (UI::Button("Place these " + g_Plan.placements.Length
					+ " blocks")) {
				g_PlaceArmed = true;
			}
			return;
		}

		string label = g_TrackKnowledge == TrackKnowledge::Guessed
			// Armed: the next click really would place, so from here on the
			// same block as Measured applies.
			? "The route is a guess — click again to place"
			: "Place these " + g_Plan.placements.Length + " blocks";

		if (UI::Button(label)) {
			Ctrl::PlacePlan();
			g_PlanState = PlanState::Placed;
		}
	}

	// The after-pose panel (PlanState::Placed). "Undo this pass" stays
	// grayed with its reason once the journal it would undo is empty -
	// either because UndoPass already ran, or because PlacePlan wrote
	// nothing. "Another pass" always works: it just clears the journal and
	// starts over.
	void RenderPlanPlaced()
	{
		UI::TextWrapped("" + g_PlacedLog.Length + " blocks placed.");

		if (g_PlacedLog.Length == 0) {
			vec4 muted = vec4(0.3f, 0.3f, 0.3f, 1.0f);
			UI::PushStyleColor(UI::Col::Button, muted);
			UI::PushStyleColor(UI::Col::ButtonHovered, muted);
			UI::PushStyleColor(UI::Col::ButtonActive, muted);
			UI::Button("Undo this pass");
			UI::PopStyleColor(3);
			UI::TextDisabled("Nothing to undo - the journal is empty.");
		} else if (UI::Button("Undo this pass")) {
			Ctrl::UndoPass();
			g_PlanState = PlanState::Ready;
		}

		UI::SameLine();
		if (UI::Button("Another pass")) {
			g_PlacedLog.Resize(0);
			ResetPlan();
		}
	}

	// The two ways to spend the free space, each with its own explanation -
	// a radio button decides nothing by itself without the sentence next to
	// it saying what it means.
	void RenderStrategyChoice()
	{
		UI::TextDisabled("Where the decor goes");

		if (UI::RadioButton("Fill the background",
				g_DecorStrategy == DecorStrategy::Fill)) {
			SetDecorStrategy(DecorStrategy::Fill);
		}
		UI::TextWrapped("Populate the empty space away from the track. 90.7 %"
			" of what real authors place sits beyond 32 m - measured on 280"
			" maps, 217 155 objects.");

		if (UI::RadioButton("Line the track",
				g_DecorStrategy == DecorStrategy::Border)) {
			SetDecorStrategy(DecorStrategy::Border);
		}
		UI::TextWrapped("Hug the driven line. Only 9.3 % of measured scenery"
			" lives there.");
	}

	// One checkbox per family, on a single line like the mockup's row of
	// chips - UI::Checkbox already returns the post-click value, so each one
	// only needs to notice when it flipped.
	void RenderFamilyChips()
	{
		UI::TextDisabled("What to place with");

		RenderFamilyChip("Trees", DecorFamily::Trees);
		UI::SameLine();
		RenderFamilyChip("Rocks", DecorFamily::Rocks);
		UI::SameLine();
		RenderFamilyChip("Buildings", DecorFamily::Buildings);
		UI::SameLine();
		RenderFamilyChip("Fences", DecorFamily::Fences);
		UI::SameLine();
		RenderFamilyChip("Inflatables", DecorFamily::Inflatables);

		if (g_HasScanned) {
			// No block model has been sorted into a decor family yet - that
			// matching is 10-familles-decor.md's job, still unwritten. Zero
			// is the honest count until it exists, never a guessed one.
			uint matches = 0;
			UI::TextDisabled("" + matches + " of " + g_Palette.Length
				+ " palette models match. Full list in Debug -> Palette.");
		}
	}

	void RenderFamilyChip(const string &in label, DecorFamily f)
	{
		bool checked = UI::Checkbox(label, g_FamilyEnabled[f]);
		if (checked != g_FamilyEnabled[f]) {
			ToggleFamily(f);
		}
	}

	// The two sliders. Each shows the game unit AngelScript alone cannot
	// read from a plain SliderInt - Low/Medium/High for density, and metres
	// for the distance step - as a separate label next to the widget.
	void RenderDecorateSliders()
	{
		int density = UI::SliderInt("How much", g_Density, 1, 3);
		if (density != g_Density) SetDensity(density);
		UI::SameLine();
		UI::Text(DensityLabel(g_Density));

		int minDist = UI::SliderInt("Keep this far from the track",
			g_MinDistSteps, 1, 8);
		if (minDist != g_MinDistSteps) SetMinDistSteps(minDist);
		UI::SameLine();
		UI::Text("" + g_MinDistSteps + " . " + (g_MinDistSteps * 32) + " m");
	}

	string DensityLabel(int d)
	{
		if (d <= 1) return "Low";
		if (d >= 3) return "High";
		return "Medium";
	}

	// ---- Settings: persisted preferences, none of them read yet --------

	// Reason shown next to every setting below: true for all twelve until
	// Model::BuildPlan grows a strategy that actually consumes them.
	const string c_SettingUnusedReason
		= "not read yet - no strategy uses this";

	void RenderSettingsTab()
	{
		UI::TextDisabled("Kept between passes and between sessions.");

		g_SettingMarginCells = RenderIntSetting(
			"Safety margin around the track", g_SettingMarginCells,
			" cell(s)");
		g_SettingCheckpointClearCells = RenderIntSetting(
			"Keep clear of checkpoints", g_SettingCheckpointClearCells,
			" cell(s)");
		g_SettingNeverOnSupport = RenderBoolSetting(
			"Never place on Support blocks", g_SettingNeverOnSupport);
		g_SettingAlwaysSaveUndo = RenderBoolSetting(
			"Always save an undo point", g_SettingAlwaysSaveUndo);
		g_SettingAskBeyond500 = RenderBoolSetting(
			"Ask before placing more than 500 blocks",
			g_SettingAskBeyond500);

		UI::Separator();
		if (UI::CollapsingHeader("Advanced")) {
			g_SettingRandomSeed = RenderIntSetting("Random seed",
				g_SettingRandomSeed, "");
			g_SettingMaxBlocksPerPass = RenderIntSetting(
				"Max blocks per pass", g_SettingMaxBlocksPerPass, "");
			RenderFarthestRingSetting();
			RenderSampleRateSetting();
			g_SettingInferSupport = RenderBoolSetting(
				"Infer Support from blocks under the route",
				g_SettingInferSupport);
			g_SettingRandomRotation = RenderBoolSetting("Random rotation",
				g_SettingRandomRotation);
			g_SettingAllowAirPlacement = RenderBoolSetting(
				"Allow placement in the air", g_SettingAllowAirPlacement);
		}

		UI::Separator();
		if (UI::Button("Reset to defaults")) {
			ResetSettingsToDefaults();
		}
	}

	// One integer field plus its unit suffix, e.g. "1 cell(s)". Stays fully
	// editable - only the reason line below says nothing reads it yet, the
	// same way RenderPlaceButton grays a control that still has to work.
	// Returns the value to store, AngelScript primitives taking &in only.
	int RenderIntSetting(const string &in label, int value,
		const string &in unit)
	{
		int v = UI::InputInt(label, value);
		if (unit.Length > 0) {
			UI::SameLine();
			UI::Text(unit);
		}
		UI::TextDisabled("  " + c_SettingUnusedReason);
		return v;
	}

	bool RenderBoolSetting(const string &in label, bool value)
	{
		bool v = UI::Checkbox(label, value);
		UI::TextDisabled("  " + c_SettingUnusedReason);
		return v;
	}

	// The farthest-ring field needs its own row: the mockup pairs the ring
	// count with the metres it works out to, like RenderDecorateSliders does
	// for g_MinDistSteps.
	void RenderFarthestRingSetting()
	{
		int v = UI::InputInt("Farthest ring from the track",
			g_SettingFarthestRing);
		if (v != g_SettingFarthestRing) g_SettingFarthestRing = v;
		UI::SameLine();
		UI::Text("" + g_SettingFarthestRing + " . "
			+ (g_SettingFarthestRing * 32) + " m");
		UI::TextDisabled("  " + c_SettingUnusedReason);
	}

	// Drive sampling rate: stored as frames between samples, shown as "every
	// frame" for 1 - the only value with no honest count to display yet -
	// and "every N frames" otherwise.
	void RenderSampleRateSetting()
	{
		int v = UI::InputInt("Drive sampling rate",
			g_SettingSampleEveryNFrames);
		if (v < 1) v = 1;
		if (v != g_SettingSampleEveryNFrames) g_SettingSampleEveryNFrames = v;
		UI::SameLine();
		UI::Text(g_SettingSampleEveryNFrames <= 1
			? "every frame" : "every " + g_SettingSampleEveryNFrames
				+ " frames");
		UI::TextDisabled("  " + c_SettingUnusedReason);
	}

	// ---- Survey: the user labels the map block by block ----------------

	void RenderSurvey()
	{
		if (!Ctrl::HasSurvey()) {
			UI::TextWrapped("Walk the map block by block and say what each one"
				" really is. The editor cursor moves to the block being asked"
				" about.");
			if (UI::Button("Read this map")) {
				Ctrl::BeginSurvey();
			}
			return;
		}

		RenderSurveyProgress();
		if (Ctrl::g_WaypointPass) {
			UI::Separator();
			RenderWaypointPass();
		}
		UI::Separator();
		RenderCurrentBlock();
		UI::Separator();
		RenderLabelButtons();
	}

	// The waypoint check, shown before anything can be labelled by hand. It
	// says how many blocks the plugin decided on its own and offers the only
	// two answers that matter: they are right, or this one is not.
	void RenderWaypointPass()
	{
		UI::TextWrapped("" + Ctrl::g_WaypointCount + " blocks were labelled"
			" Route by the plugin because the block model declares a start,"
			" finish or checkpoint. Walk them with Skip and check the cursor"
			" lands where you expect. Any label you give overrides the plugin.");
		if (UI::Button("Waypoints look right - carry on")) {
			Ctrl::EndWaypointPass();
		}
	}

	void RenderSurveyProgress()
	{
		uint total = Ctrl::g_Blocks.Length;
		uint done = Ctrl::g_Labels.Count();

		UI::Text("" + done + " of " + total + " blocks labelled");
		UI::TextDisabled("  route " + Ctrl::g_Labels.CountOf(Model::Klass::Route)
			+ "   support " + Ctrl::g_Labels.CountOf(Model::Klass::Support)
			+ "   decor " + Ctrl::g_Labels.CountOf(Model::Klass::Decor)
			+ "   waypoint "
			+ Ctrl::g_Labels.CountOf(Model::Klass::RouteWaypoint));

		Ctrl::g_SkipLabelled = UI::Checkbox("Skip blocks already labelled",
			Ctrl::g_SkipLabelled);
	}

	void RenderCurrentBlock()
	{
		auto block = Ctrl::Current();
		if (block is null) {
			UI::TextDisabled("Nothing left to visit in this direction.");
			return;
		}

		UI::Text(block.name);
		UI::TextDisabled("  cell " + block.coord.x + " / " + block.coord.y
			+ " / " + block.coord.z + (block.isGround ? "   ground" : "   air"));
		if (block.waypoint != Model::c_WaypointNone) {
			UI::TextDisabled("  waypoint: " + WaypointName(block.waypoint));
		}

		auto current = Ctrl::g_Labels.Get(block.coord);
		if (current != Model::Klass::Unlabelled) {
			UI::TextDisabled("  already labelled: " + Model::KlassName(current));
		}
	}

	// EWayPointType, spelled out. The number is what the engine gives and what
	// the JSON would carry, but a window that says "waypoint: 2" tells the
	// user nothing he can check.
	string WaypointName(int t)
	{
		if (t == 0) return "start";
		if (t == 1) return "finish";
		if (t == 2) return "checkpoint";
		if (t == 4) return "start/finish";
		if (t == 5) return "dispenser";
		return "none";
	}

	void RenderLabelButtons()
	{
		if (UI::Button("Route")) {
			Ctrl::LabelCurrent(Model::Klass::Route);
		}
		UI::SameLine();
		if (UI::Button("Support")) {
			Ctrl::LabelCurrent(Model::Klass::Support);
		}
		UI::SameLine();
		if (UI::Button("Decor")) {
			Ctrl::LabelCurrent(Model::Klass::Decor);
		}

		if (UI::Button("< Previous")) {
			Ctrl::Step(-1);
		}
		UI::SameLine();
		if (UI::Button("Skip >")) {
			Ctrl::Step(1);
		}

		UI::TextDisabled("Labels are saved to disk on every verdict.");
	}

	// The highlight probe. Kept visibly apart from the labelling buttons and
	// labelled as an experiment, because it is one: nothing in this project has
	// ever written into CustomSelectionCoords, and the user is the one who
	// decides whether to risk the click.
	void RenderHighlightProbe()
	{
		UI::TextDisabled("Experiment - highlight");
		if (UI::Button("Highlight this block")) {
			Ctrl::HighlightCurrent();
		}
		UI::SameLine();
		if (UI::Button("Clear highlight")) {
			Ctrl::ClearHighlight();
		}
	}

	// ---- Palette: what the block models declare ------------------------

	void RenderScanButton()
	{
		if (UI::Button("Scan palette")) {
			ScanPalette();
		}
	}

	void RenderResult()
	{
		if (!g_HasScanned) {
			UI::TextDisabled("Scan the palette to see which blocks join nothing.");
			return;
		}

		RenderSummary();
		RenderUnconnectableList();
	}

	// The raw counts, shown before the list. A verdict without its counts
	// cannot be checked, and this scan exists precisely to be checked.
	void RenderSummary()
	{
		uint total = g_Palette.Length;
		uint unconnectable = g_Unconnectable.Length;

		// Every concatenation starts with a string: AngelScript resolves
		// "text" + number, not number + "text".
		UI::Text("" + total + " block models in the palette");
		UI::Text("" + unconnectable + " declare no clip - they join nothing");
		UI::Text("" + (total - unconnectable) + " declare at least one clip");
	}

	void RenderUnconnectableList()
	{
		UI::BeginChild("unconnectable", vec2(0, c_ListHeight));

		for (uint i = 0; i < g_Unconnectable.Length; i++) {
			auto entry = g_Unconnectable[i];
			UI::Text(entry.name);
			UI::SameLine();
			UI::TextDisabled("  " + entry.cells + " cells   " + entry.page);
		}

		UI::EndChild();
	}

	// ---- Log: the startup/scan lines, kept next to the game log ---------

	void RenderLog()
	{
		bool verbose = UI::Checkbox("Verbose", g_Verbose);
		if (verbose != g_Verbose) g_Verbose = verbose;

		UI::BeginChild("log_lines", vec2(0, c_ListHeight));
		for (uint i = 0; i < g_LogLines.Length; i++) {
			UI::Text(g_LogLines[i]);
		}
		UI::EndChild();

		// IO::SetClipboard exists on this Openplanet build - checked in
		// OpenplanetCore.json rather than assumed, so the button only stays
		// disabled if a future build were to drop it.
		if (UI::Button("Copy log")) {
			string joined = "";
			for (uint i = 0; i < g_LogLines.Length; i++) {
				joined += g_LogLines[i] + "\n";
			}
			IO::SetClipboard(joined);
		}
	}

	// ---- Debug: instruments, not features ------------------------------

	void RenderDebugTab()
	{
		UI::TextDisabled("Nothing here is needed to decorate a map.");

		if (g_DriveSessionActive) {
			UI::Separator();
			UI::Text("Drive session (" + g_DriveDecisionLabel + "): "
				+ g_TrackCells.Count() + " cells sampled ("
				+ g_TrackCells.RawCount() + " raw + "
				+ g_TrackCells.InterpolatedCount() + " interpolated)");
		}

		UI::Separator();
		if (UI::CollapsingHeader("Survey - label blocks by hand")) {
			RenderSurvey();
		}

		if (UI::CollapsingHeader("Palette - what the 551 models declare")) {
			RenderScanButton();
			RenderResult();
		}

		if (UI::CollapsingHeader("Highlight probe - experiment")) {
			RenderHighlightProbe();
		}

		// Open by default - Once means the user's own collapse survives the
		// next frame instead of being forced back open every time.
		UI::SetNextItemOpen(true, UI::Cond::Once);
		if (UI::CollapsingHeader("Log")) {
			RenderLog();
		}

		if (UI::CollapsingHeader("Force track knowledge")) {
			UI::TextWrapped("Instrument - the Map tab's own Reset button is"
				" the normal way to discard a measurement.");
			if (UI::Button("Unknown")) SetTrackKnowledge(TrackKnowledge::Unknown);
			UI::SameLine();
			if (UI::Button("Guessed")) SetTrackKnowledge(TrackKnowledge::Guessed);
			UI::SameLine();
			if (UI::Button("Measured")) SetTrackKnowledge(TrackKnowledge::Measured);
		}
	}
}
