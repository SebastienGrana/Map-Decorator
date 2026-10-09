// Le journal ne garde aucun handle moteur (invariant 3) : un CGameCtnBlock@
// gardé au travers d'une sortie d'éditeur fait tomber le jeu, comme
// Model::PlacedBlock. Il ne stocke que de quoi retrouver le bloc en relisant
// la carte au moment d'annuler : nom du modèle, coordonnée, direction.
//
// Il vit dans Model bien que son instance appartienne au Controller
// (03-architecture.md : l'état appartient au Controller) parce que c'est une
// donnée pure, sans appel à l'API du jeu — à sa place parmi les autres types
// de modèle, pas parmi la logique qui la manipule.

namespace Model {

class PlacementRecord {
    string name;
    int3 coord;
    int dir;

    PlacementRecord(const string &in name, const int3 &in coord, int dir) {
        this.name = name;
        this.coord = coord;
        this.dir = dir;
    }
}

class PlacementJournal {
    private array<PlacementRecord@> m_records;

    void Record(const string &in name, const int3 &in coord, int dir) {
        m_records.InsertLast(PlacementRecord(name, coord, dir));
    }

    void Clear() {
        m_records.RemoveRange(0, m_records.Length);
    }

    uint Count() {
        return m_records.Length;
    }

    PlacementRecord@ Get(uint index) {
        return m_records[index];
    }
}

}
