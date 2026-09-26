# Le pont cairn → plugin — notes et journal
## Résultat
Le plugin lit summary.json, le résumé par modèle que cairn produit, et Preview liste un vrai plan « Fill the background » choisi grâce à ces chiffres — sans rien poser sur la carte. Les chiffres sont consommés tels quels et affichés « provisional » : cairn les juge en doute jusqu'à sa colonne role.
## Notes
- P1 : grep anciens chiffres : 0 ligne ; « 7,4 % » : 2 lignes dans 13-strategies.md ; « 26-ghost-validation » : 2 lignes dans 08-etat.md
- P2 : écrite et déployée, summary.json copié (3 476 706 octets) — en attente du rechargement en jeu, non cochée
- P3 : Section « Cairn decor model » avec Reload et couverture de la palette ; Preview grisé avec sa raison quand le fichier manque · dépend de P2
- P4 : Nouveau ModelPlanFill.as : niveau du sol, couronnes autour de la piste, cellules libres ; un bouton Debug qui les compte. Dépend de rien.
- P5 : PlanInputs, aiguillage Fill / Line the track, un nom provisoire par pose, Preview affiche le plan et ses rejets · dépend de P2 et P4
- P6 : Math::Randomizer(seed), tirage pondéré par off_route, mélange, densité, rotation · dépend de P5
## Journal
## Bilan
