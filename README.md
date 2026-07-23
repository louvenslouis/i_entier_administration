# i-ENTIER Administration

Troisième interface autonome de l’écosystème i-ENTIER. Ce tableau de bord Web
permet aux administrateurs autorisés de traiter les inscriptions envoyées
depuis **i-ENTIER Professionnel**.

## Fonctions disponibles

- connexion avec un compte Google ;
- contrôle du rôle dans `administrators/{uid}` ;
- liste et recherche des personnels et institutions ;
- filtres par type et statut ;
- consultation du dossier professionnel ;
- approbation ou refus avec motif obligatoire ;
- masquage de toute ancienne fiche publique lors d’une décision ;
- journal immuable des décisions dans `providerReviews`.

Les règles Firestore correspondantes sont maintenues dans le projet principal :

`/Users/louvenslouis/AndroidStudioProjects/ientier/firestore.rules`

## Autoriser le premier administrateur

L’application ne permet volontairement pas de créer son propre rôle. Pour le
premier accès :

1. lancer l’application et se connecter avec le compte Google voulu ;
2. copier l’identifiant UID affiché sur l’écran « Accès administrateur requis » ;
3. ouvrir Firebase Console, projet `i-entier`, puis **Firestore Database** ;
4. créer la collection `administrators` si elle n’existe pas ;
5. créer un document dont l’identifiant est exactement cet UID ;
6. ajouter le champ booléen `active` avec la valeur `true`.

Les champs `email` et `displayName` peuvent être ajoutés pour faciliter
l’identification, mais seul `active: true` donne accès.

## Exécuter et vérifier

```bash
flutter pub get
flutter run -d chrome
flutter test
flutter analyze
flutter build web
```

La configuration Web pointe vers le projet Firebase `i-entier`. Google doit
être activé dans **Authentication > Sign-in method**, et le domaine utilisé
pour l’hébergement doit figurer dans les domaines autorisés de Firebase Auth.

## Sécurité

Les clients ne peuvent ni créer, ni modifier, ni supprimer un document
`administrators`. Un administrateur actif peut modifier uniquement le statut,
le motif du refus, la visibilité et la date de mise à jour d’un dossier. Les
données d’identité du professionnel restent protégées contre les modifications
administratives.
