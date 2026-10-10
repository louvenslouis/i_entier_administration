# Répertoire des établissements de santé

Le classeur fourni contient **1 072 établissements dans les dix départements**.
Son titre mentionne Gonaïves, mais son contenu est national. La table
`ientier.health_facilities` est distincte de `ientier.provider_profiles` : le
classeur ne fournit ni compte utilisateur, ni téléphone, ni adresse précise
pour créer des profils de prestataires.

Les migrations appliquées au projet Supabase `ientier` sont également enregistrées
dans le dépôt de l'application principale :

- `../ientier/supabase/migrations/20260927171423_create_health_facility_catalog.sql`
- `../ientier/supabase/migrations/20260927171443_seed_health_facility_catalog.sql`
- `../ientier/supabase/migrations/20260927171946_expand_health_facility_name_review.sql`

Le script `build_health_facilities.py` relit le classeur, vérifie les en-têtes,
calcule son empreinte SHA-256 et produit `health_facilities.csv`,
`health_facilities_seed.sql` et `health_facilities_audit.json`. La clé d'import
est `(source_sha256, source_row)` ; le code de l'établissement n'est pas unique.
Une réexécution du SQL d'import ne duplique pas les lignes et ne remplace pas
les corrections faites ensuite par l'administration.

## Décisions de données

- La catégorie utilise un nom complet. Les développements de CS, CCS, HCR, HD
  et HU figurent dans la [classification du ministère de la Santé](https://mspp.gouv.ht/site/downloads/Liste%20Nationale%20des%20M%C3%A9dicaments%20Essentiels%202e%20%C3%A9dition_publication%202022%20%281%29.pdf).
  Le ministère utilise aussi « point de prestation de services » pour PPS
  dans ses [documents de service](https://www.mspp.gouv.ht/site/downloads/REC%20version%20finale.pdf).
- `source_name` est conservé exactement après suppression des espaces de bord.
  `display_name` reprend provisoirement ce nom. Les noms contenant un sigle
  détecté sont signalés par `name_review_required` ; la liste détaillée est
  dans `health_facilities_audit.json`.
- Le statut « À vérifier » couvre les cellules vides et les valeurs qui ne
  signifient pas explicitement « Fonctionnelle » ou « Non Fonctionnelle ».
  L'orthographe d'origine reste dans `source_operation_status`.
- Toutes les lignes commencent avec `published = false`. Leur état de
  fonctionnement n'a pas de date de vérification dans le classeur.

## Contrôles de l'import

| Contrôle | Résultat |
| --- | ---: |
| Lignes | 1 072 |
| Départements | 10 |
| Codes absents | 5 |
| Codes partagés | 2 (`811909`, `934104`) |
| Noms avec sigles repérés à vérifier | 298 |
| États de fonctionnement à vérifier | 488 |
| Fiches ayant au moins un point à vérifier | 489 |

Des sources officielles permettent déjà de développer certains sigles dans les
noms : [FOSREF](https://www.fosref.org/fr/home-francais/),
[DASH](https://dashhaiti.org/),
[OFATMA](https://ofatma.gouv.ht/index_php.html),
[GHESKIO](https://gheskio.org/wp-content/uploads/2020/05/GHESKIO-INSTITUTION-Audit-Report-as-of-September-30-2018-FINAL-REPORT-29-AVRIL-2020.pdf),
[MSF](https://www.msf.org/fr/qui-sommes-nous) et
[SSPE](https://mspp.gouv.ht/site/downloads/Paquet_minimum_de_services_1er%20niveau.pdf).
Les noms complets proposés doivent être contrôlés comme noms propres
d'établissements avant remplacement automatique des libellés.
