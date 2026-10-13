# AmdPont

Plugin **Openplanet** d'essai, écrit pour l'audit `AMD` de MapDecorator
(octobre 2026). Il ne fait pas partie de MapDecorator : `deploy.sh` ne le
déploie pas.

## Ce qu'il fait

Il ouvre la boucle **script ↔ jeu** : un programme extérieur envoie une
commande texte, le plugin l'exécute dans le jeu et répond.

- Une commande par connexion, finie par un saut de ligne.
- `ping` → `pong`.
- `lire` → durées de lecture de `summary.json` (dossier de stockage du plugin).
- `etat`, `liste` → l'état de la carte ouverte dans l'éditeur.
- `poser nd|nv [dx]` → pose un macrobloc au curseur.
- `recharger <id>` → `Meta::ReloadPlugin` sur le plugin nommé (AmdPont compris).

Le détail est en tête de `AmdPont.as`.

## Où il écoute

- Sur **`127.0.0.1`**, port **`47815`** (`AmdPont.as`, constantes `HOTE` et `PORT`).
- Seulement en local : rien ne s'ouvre vers le réseau.

## ⚠️ À n'installer que pour un essai

Une fois installé, **tout programme de l'ordinateur** peut parler au jeu par
ce port, sans mot de passe : poser des blocs, recharger des plugins.

- L'installer : copier `AmdPont.as` et `info.toml` dans
  `Openplanet4/Plugins/AmdPont/`.
- Le retirer après l'essai : supprimer ce dossier.
