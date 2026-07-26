# i-ENTIER Administration

Tableau de bord Flutter Web permettant aux administrateurs autorisés de traiter
les inscriptions professionnelles de l’écosystème i-ENTIER.

## Fonctions

- connexion Google par Supabase Auth ;
- contrôle du rôle dans `ientier.administrators` ;
- recherche et filtrage des dossiers professionnels ;
- approbation ou refus avec journal immuable ;
- revue atomique via `ientier.review_provider`.

## Autoriser le premier administrateur

L’application ne peut pas s’auto-attribuer un rôle. Après la première connexion
Google, insérer le UUID Supabase de l’utilisateur dans
`ientier.administrators` depuis un accès serveur ou le SQL Editor.

## Lancer et vérifier

```sh
flutter pub get
flutter run -d chrome
flutter analyze
flutter test
```

L’URL Web locale et l’URL de production doivent figurer dans les Redirect URLs
de Supabase Auth. Le schéma SQL et les migrations sont maintenus dans
`../ientier/supabase/migrations`.
