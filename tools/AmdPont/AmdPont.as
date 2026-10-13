// AmdPont — essai de la fiche AMD5 (audit de MapDecorator), le 2026-10-10.
// Un script parle au jeu par un socket local : « ping » -> « pong ».
// Il mesure aussi la lecture de summary.json, et essaie Meta::ReloadPlugin.
// Commandes, une par connexion, finies par un saut de ligne :
//   ping              -> pong
//   lire              -> durées de lecture de summary.json, en ms
//   recharger <id>    -> Meta::ReloadPlugin sur ce plugin (AmdPont compris)
// Ajoutées pour AMD6 (poser un item par un macrobloc) :
//   etat              -> carte, validation, blocs, items, macrobloc choisi, curseur
//   poser nd|nv [dx]  -> pose le macrobloc choisi dans l'inventaire au curseur,
//                        décalé de dx cases en x ; nd = PlaceMacroblock_NoDestruction,
//                        nv = PlaceMacroblock_NoTerrain_NoUnvalidate

const uint16 PORT = 47815;
const string HOTE = "127.0.0.1";  // Listen(port) seul ouvre sur toutes les interfaces

Net::Socket@ g_Serveur = null;
string g_ARecharger = "";

void Main()
{
	print("AmdPont: démarré");
	MesurerLecture();

	@g_Serveur = Net::Socket();
	if (!g_Serveur.Listen(HOTE, PORT)) {
		error("AmdPont: Listen " + HOTE + ":" + PORT + " a échoué");
		return;
	}
	print("AmdPont: écoute sur " + HOTE + ":" + PORT);

	while (true) {
		auto client = g_Serveur.Accept();
		if (client !is null) {
			Servir(client);
		}
		if (g_ARecharger != "") {
			string id = g_ARecharger;
			g_ARecharger = "";
			Recharger(id);
		}
		yield();
	}
}

void OnDestroyed()
{
	if (g_Serveur !is null) {
		g_Serveur.Close();
		print("AmdPont: socket fermé");
	}
}

// Lit une ligne (5 s au plus), répond, ferme.
void Servir(Net::Socket@ client)
{
	uint64 debut = Time::Now;
	string tampon = "";
	while (Time::Now - debut < 5000) {
		int n = client.Available();
		if (n > 0) {
			tampon += client.ReadRaw(n);
			int fin = tampon.IndexOf("\n");
			if (fin >= 0) {
				string ligne = tampon.SubStr(0, fin).Trim();
				client.WriteRaw(Repondre(ligne) + "\n");
				break;
			}
		}
		if (client.IsHungUp()) break;
		yield();
	}
	client.Close();
}

string Repondre(const string &in ligne)
{
	print("AmdPont: reçu « " + ligne + " »");
	if (ligne == "ping") return "pong";
	if (ligne == "lire") return MesurerLecture();
	if (ligne == "etat") return Etat();
	if (ligne == "liste") return Liste();
	if (ligne.StartsWith("poser")) return Poser(ligne.SubStr(5).Trim());
	if (ligne.StartsWith("recharger ")) {
		// La réponse part d'abord : recharger AmdPont tue cette coroutine.
		g_ARecharger = ligne.SubStr(10).Trim();
		return "AmdPont: rechargement demandé pour " + g_ARecharger;
	}
	return "AmdPont: commande inconnue « " + ligne + " »";
}

void Recharger(const string &in id)
{
	auto plugin = Meta::GetPluginFromID(id);
	if (plugin is null) {
		warn("AmdPont: plugin introuvable (non chargé ?) : " + id);
		return;
	}
	print("AmdPont: Meta::ReloadPlugin(" + id + ")");
	Meta::ReloadPlugin(plugin);
}

CGameCtnEditorFree@ Editeur()
{
	auto ed = cast<CGameCtnEditorFree>(GetApp().Editor);
	if (ed is null || ed.PluginMapType is null) return null;
	return ed;
}

// Second compteur d'items : la liste de la carte elle-même, pas celle de ManiaScript.
string Ancres(CGameEditorPluginMap@ pm)
{
	if (pm.Map is null) return "?";
	return "" + pm.Map.AnchoredObjects.Length;
}

string Etat()
{
	auto ed = Editeur();
	if (ed is null) return "AmdPont: pas d'éditeur ouvert";
	auto pm = ed.PluginMapType;
	string carte = pm.Map !is null ? string(pm.Map.MapName) : "?";
	string macro = ed.CurrentMacroBlockInfo !is null ? string(ed.CurrentMacroBlockInfo.Name) : "aucun";
	auto c = ed.Cursor.Coord;
	string etat = "AmdPont: carte « " + carte + " » · validation " + int(pm.ValidationStatus)
		+ " (0 non validable, 1 validable, 2 validée) · blocs " + pm.Blocks.Length
		+ " · items " + pm.Items.Length + " · AnchoredObjects " + Ancres(pm)
		+ " · macrobloc choisi « " + macro + " »"
		+ " · curseur " + c.x + "/" + c.y + "/" + c.z + " dir " + int(ed.Cursor.Dir)
		+ " · mode " + int(pm.PlaceMode);
	print(etat);
	return etat;
}

const string MACRO_ESSAI = "CAIRN TEST 01";  // le macrobloc d'essai de l'utilisateur (AMD6)

CGameCtnMacroBlockInfo@ MacroblocParNom(CGameEditorPluginMap@ pm, const string &in nom)
{
	for (uint i = 0; i < pm.MacroblockModels.Length; i++) {
		auto m = pm.MacroblockModels[i];
		if (m !is null && string(m.Name) == nom) return m;
	}
	return null;
}

// Où est chaque item (AnchoredObjects) et chaque bloc posé (ClassicBlocks, sans le terrain).
string Liste()
{
	auto ed = Editeur();
	if (ed is null) return "AmdPont: pas d'éditeur ouvert";
	auto pm = ed.PluginMapType;
	string sortie = "AmdPont: items";
	if (pm.Map !is null) {
		for (uint i = 0; i < pm.Map.AnchoredObjects.Length; i++) {
			auto o = pm.Map.AnchoredObjects[i];
			string nom = o.ItemModel !is null ? o.ItemModel.IdName : "?";
			sortie += " | " + nom + " case " + o.BlockUnitCoord.x + "/" + o.BlockUnitCoord.y + "/"
				+ o.BlockUnitCoord.z;
		}
	}
	sortie += " || blocs posés";
	for (uint i = 0; i < pm.ClassicBlocks.Length; i++) {
		auto b = pm.ClassicBlocks[i];
		string nom = b.BlockModel !is null ? string(b.BlockModel.Name) : "?";
		sortie += " | " + nom + " " + b.Coord.x + "/" + b.Coord.y + "/" + b.Coord.z;
	}
	print(sortie);
	return sortie;
}

// Pose le macrobloc choisi dans l'inventaire, au curseur ; compte avant et après.
string Poser(const string &in args)
{
	auto ed = Editeur();
	if (ed is null) return "AmdPont: pas d'éditeur ouvert";
	auto pm = ed.PluginMapType;
	auto modele = ed.CurrentMacroBlockInfo;
	if (modele is null) @modele = MacroblocParNom(pm, MACRO_ESSAI);
	if (modele is null) return "AmdPont: ni macrobloc choisi, ni « " + MACRO_ESSAI + " » dans MacroblockModels";

	// poser nd|nv [dx]  ou  poser nd|nv x y z, suivi de « save » : AutoSave() après la pose
	// (une piste pour en faire un pas d'annulation à part, non vérifiée)
	bool sauver = args.EndsWith(" save");
	auto mots = (sauver ? args.SubStr(0, args.Length - 5) : args).Split(" ");
	string variante = (mots.Length > 0 && mots[0] != "") ? mots[0] : "nd";
	auto c = ed.Cursor.Coord;
	int3 coord = int3(int(c.x), int(c.y), int(c.z));
	if (mots.Length >= 4) {
		coord = int3(Text::ParseInt(mots[1], 10), Text::ParseInt(mots[2], 10), Text::ParseInt(mots[3], 10));
	} else if (mots.Length > 1) {
		coord.x += Text::ParseInt(mots[1], 10);
	}
	auto dir = CGameEditorPluginMap::ECardinalDirections(int(ed.Cursor.Dir));

	uint itemsAvant = pm.Items.Length;
	string ancresAvant = Ancres(pm);
	uint blocsAvant = pm.Blocks.Length;
	int validAvant = int(pm.ValidationStatus);
	bool ok = false;
	if (variante == "nv") {
		ok = pm.PlaceMacroblock_NoTerrain_NoUnvalidate(modele, coord, dir);
	} else {
		variante = "nd";
		ok = pm.PlaceMacroblock_NoDestruction(modele, coord, dir);
	}
	yield(2);  // l'éditeur met à jour ses listes à l'image suivante
	if (sauver) {
		pm.AutoSave();
		variante += "+save";
	}

	string bilan = "AmdPont: poser " + variante + " « " + string(modele.Name) + " » en "
		+ coord.x + "/" + coord.y + "/" + coord.z + " dir " + int(dir) + " -> " + (ok ? "true" : "false")
		+ " · items " + itemsAvant + " -> " + pm.Items.Length
		+ " · AnchoredObjects " + ancresAvant + " -> " + Ancres(pm)
		+ " · blocs " + blocsAvant + " -> " + pm.Blocks.Length
		+ " · validation " + validAvant + " -> " + int(pm.ValidationStatus);
	print(bilan);
	return bilan;
}

// Les trois durées, en millisecondes (Time::Now) : lecture brute, Json::Parse,
// et Json::FromFile, le chemin de MapDecorator (ModelDecorModel.as:51).
string MesurerLecture()
{
	string chemin = IO::FromStorageFolder("summary.json");
	if (!IO::FileExists(chemin)) {
		string absent = "AmdPont: summary.json absent : " + chemin;
		warn(absent);
		return absent;
	}

	uint64 t0 = Time::Now;
	IO::File fichier(chemin, IO::FileMode::Read);
	uint64 taille = fichier.Size();
	string texte = fichier.ReadToEnd();
	fichier.Close();
	uint64 t1 = Time::Now;
	Json::Value@ parse = Json::Parse(texte);
	uint64 t2 = Time::Now;
	Json::Value@ depuisFichier = Json::FromFile(chemin);
	uint64 t3 = Time::Now;

	string ok = (parse !is null && depuisFichier !is null) ? "ok" : "ÉCHEC";
	string mesure = "AmdPont: summary.json " + taille + " octets · lecture brute "
		+ (t1 - t0) + " ms · Json::Parse " + (t2 - t1) + " ms · Json::FromFile "
		+ (t3 - t2) + " ms · " + ok;
	print(mesure);
	return mesure;
}
