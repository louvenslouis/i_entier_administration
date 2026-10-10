# i-ENTIER Administration

Tableau de bord Flutter Web permettant aux administrateurs autorisés de traiter
les inscriptions professionnelles de l’écosystème i-ENTIER.

## Fonctions

- connexion Google par Supabase Auth ;
- contrôle du rôle dans `ientier.administrators` ;
- recherche et filtrage des dossiers professionnels ;
- approbation ou refus avec journal immuable ;
- revue atomique via `ientier.review_provider`.
- régulation des pharmacies : licence, activation, suspension ou refus ;
- suivi des alertes de stock, commandes ouvertes et ventes mensuelles ;
- vérification des campagnes de financement solidaire ;
- rapprochement des contributions avec leur référence de paiement.

## Données de référence

Le répertoire national des établissements de santé est importé dans
`ientier.health_facilities`. La préparation des données et les contrôles sont
documentés dans [`database/README.md`](database/README.md).

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
