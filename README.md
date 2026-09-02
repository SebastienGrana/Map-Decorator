# MapDecorator

Plugin **Openplanet** pour l'éditeur de ManiaPlanet / TrackMania² Stadium, qui
décore une carte déjà construite par un joueur.

Livrable **séparé** de TrackGen : aucun code partagé, et pas la même plateforme
(TrackGen est en ManiaScript). Le contexte de travail vit dans `context AI/`,
qui n'est pas versionné.

État : **premier scan** — le plugin lit la palette et rapporte les blocs qui ne
déclarent aucun clip. Rien n'est posé sur la carte.

## Structure

- `files/` — le plugin : les `.as` et `info.toml`, seuls fichiers déployés ;
- `context AI/` — contexte et notes de travail, jamais déployés ;
- `deploy.sh` — copie `files/*` vers `Openplanet4/Plugins/MapDecorator/`.

Openplanet compile tous les `.as` du dossier en un seul module : les couches MVC
sont des namespaces (`Model`, `View`, `Ctrl`), et le nom du fichier porte la
couche.

## Déployer

```sh
./deploy.sh
```

Puis recharger le plugin dans le gestionnaire d'Openplanet (F3).

⚠️ On édite toujours `files/`. Le dossier Openplanet est une copie, écrasée à
chaque déploiement — et `deploy.sh` y efface les fichiers qui ont disparu de
`files/`, sans quoi un fichier renommé serait compilé en double.
