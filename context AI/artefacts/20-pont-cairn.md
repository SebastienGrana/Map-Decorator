# Le pont cairn → plugin — notes et journal
## Résultat
Visé : le plugin lit summary.json, le résumé par modèle que cairn produit, et Preview liste un vrai plan « Fill the background ». Atteint : P1 seule — le plugin ne lit pas summary.json et Preview rend 0 bloc ; la suite passe par C1 à C3 (audit AMD).
## Notes
- P1 : grep anciens chiffres : 0 ligne ; « 7,4 % » : 2 lignes dans 13-strategies.md ; « 26-ghost-validation » : 2 lignes dans 08-etat.md
- P2 : écrite, ne compile pas (audit AMD) ; abandonnée, reprise par C1
- P3 : Section « Cairn decor model » avec Reload et couverture de la palette ; Preview grisé avec sa raison quand le fichier manque · dépend de P2
- P4 : Nouveau ModelPlanFill.as : niveau du sol, couronnes autour de la piste, cellules libres ; un bouton Debug qui les compte. Dépend de rien.
- P5 : PlanInputs, aiguillage Fill / Line the track, un nom provisoire par pose, Preview affiche le plan et ses rejets · dépend de P2 et P4
- P6 : Math::Randomizer(seed), tirage pondéré par off_route, mélange, densité, rotation · dépend de P5
## Journal
## Bilan
- Livré : P1 : le contexte remis d'accord avec Cairn. La suite du pont passe par l'audit AMD du kit, qui l'a re-découpée.
- Surpris : Le P2 raté venait en partie d'un socle faux : des notes périmées. L'audit AMD en a relevé 25 (21-audit-amd.md).
- Estimé : estimé non noté · cadré 6 · joué 1 fiches ? $
