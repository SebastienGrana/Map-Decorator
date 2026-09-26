# MCD et diagramme de classes — notes et journal
## Résultat
Deux schémas en couleur, publiés dans draw.io : un MCD du domaine que le plugin manipule (la carte, les labels, le plan, le journal) et un diagramme de classes de l'architecture MVC réelle — chaque couleur renvoie à un fichier source précis.
## Notes
- M1 : Diagramme affiché dans draw.io, 12 entités colorées par fichier source, relations confirmées par l'utilisateur.
- M2 : Non jouée. Clôture décidée le 2026-09-15 pour ouvrir le chantier cairn ; le MCD de M1 suffit comme schéma de référence pour l'instant.
## Journal
- 2026-09-06 : L'utilisateur demande des couleurs qui séparent les parties du plugin, pas un rendu noir et blanc — d'où la table de couleurs par fichier source dans le socle commun, réutilisée à l'identique dans M1 et M2.
- 2026-09-06 : M1 : en vérifiant les relations contre le code, `Ctrl::PlacePlan`/`UndoPass` se sont révélés utiliser un global `g_PlacedLog`, pas les classes `PlacementJournal`/`PlacementRecord` que le socle nommait — celles-ci existent mais ne sont câblées nulle part.
- 2026-09-15 : Clôture tel quel, décidée par l'utilisateur : M2 est abandonnée, pas cochée. La priorité passe à un chantier sur ce que cairn peut apporter à MapDecorator.
## Bilan
- Livré : le MCD Merise du domaine carte, dans draw.io, 12 entités colorées par fichier source, relations confirmées contre le code. Le diagramme de classes MVC (M2) n'a pas été dessiné — abandonné, pas fait.
- Ce qui a surpris : le journal réel des poses est le global g_PlacedLog, pas les classes PlacementJournal / PlacementRecord, qui existent en code mais ne sont câblées nulle part. Deux relations du MCD restent en pointillé : conceptuelles, pas encore branchées.
