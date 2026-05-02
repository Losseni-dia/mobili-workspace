# Recherche multi-arrêts et alignement frontend ↔ API

Ce document décrit la **recherche par segment** (une ligne longue avec étapes dans `Trip.moreInfo`) et liste **précisément** ce qui a été fait dans chaque fichier concerné par l’**étape 4 (frontend minimal, une seule vérité = API)** et les travaux associés (service HTTP, page résultats, tests).

---

## Comportement métier (rappel)

- Une ligne **Abidjan → Issia** avec étapes **Divo, Gagnoa, Lakota** dans `moreInfo` (CSV) doit permettre à un voyageur de trouver **Abidjan → Gagnoa** : le segment demandé doit apparaître **dans l’ordre** de la chaîne **départ → étapes → arrivée**.
- Si **départ et arrivée** sont tous deux **vides** (après trim), le backend renvoie les **mêmes candidats** que le chargement catalogue (tous les trajets à venir filtrés par date de recherche quand une date est fournie).

---

## Backend (fichiers touchés)

| Fichier | Modifications |
|---------|----------------|
| `backend/src/main/java/.../trip/repository/TripRepository.java` | Ancienne requête JPQL stricte départ/arrivée retirée au profit d’un chargement des candidats à venir (`findAllUpcomingTrips`) pour la recherche. |
| `backend/src/main/java/.../trip/service/TripService.java` | `searchTrips` : construction de la **chaîne de villes** (`buildCityChain`), filtrage en mémoire sur segment `i < j`, préfixe insensible à la casse ; chaîne vide sur les deux critères → retour de **tous** les candidats. |
| `mobili-boot/.../api/passenger/trip/TripReadController.java` | `GET /trips/search` : paramètres `departure` et `arrival` **optionnels** avec défaut `""` pour laisser le service décider. |
| `backend/src/main/java/.../trip/entity/Trip.java` | `moreInfo` = villes étapes (CSV), utilisée dans la chaîne de recherche. |
| `backend/src/test/java/.../trip/service/TripServiceSearchTest.java` | Tests unitaires : ordre de chaîne, segment trouvé sur longue ligne, segment inverse exclu, terminus direct sans étapes, départ+arrivée blancs → tous les candidats. |

Commande de validation : `mvn test` depuis `backend/`.

---

## Frontend — détail fichier par fichier

### `frontend/src/app/core/services/trip/trip.service.ts`

- Import de **`HttpParams`** pour construire la query de façon sûre (encodage).
- Méthode **`searchTrips(departure, arrival, date)`** : appelle **`GET /trips/search`** avec `departure` et `arrival` toujours présents (chaînes, y compris vides) ; le paramètre **`date`** n’est ajouté que s’il est non vide après trim — aligné sur le contrôleur Spring.
- Remplace l’ancienne URL avec `from` / `to` en query string manuelle.

### `frontend/src/app/core/services/trip/trip.service.spec.ts` *(nouveau)*

- Tests **Vitest** + `HttpTestingController` : vérifie que la requête part vers `/trips/search` avec les bons **`HttpParams`** ; vérifie l’**absence** du paramètre `date` lorsque la date est vide ou blanche.

### `frontend/src/app/features/public/home/home.component.ts`

- **Une seule source de vérité** : dès qu’au moins **départ** ou **arrivée** est renseigné → **`tripService.searchTrips`** ; si les deux sont vides → **`getAllTrips()`**.
- **`valueChanges`** avec **debounce 300 ms**, **`distinctUntilChanged`** sur les trois champs, **`takeUntilDestroyed`** pour éviter les fuites.
- Indicateur **`loadingTrips`** ; suppression du tableau intermédiaire **`allTrips`** (seul **`filteredTrips`** alimente l’UI).
- Pas de bouton « Rechercher » (la doc utilisateur : le filtre réagit tout seul).

### `frontend/src/app/features/public/home/home.component.html`

- Formulaire **réactif** sans bouton de soumission ; message **« Mise à jour des résultats… »** pendant le chargement.

### `frontend/src/app/features/public/search-results/search-results.component.ts`

- Suppression des **données mockées** et du type local `Trip` dupliqué.
- Souscription à **`queryParams`** avec **`switchMap`** vers **`tripService.searchTrips`** : **rétrocompatibilité** des URLs avec `from` / `to` si `departure` / `arrival` absents.
- États **`loading`**, **`error`**, liste **`trips`** typée avec l’interface exportée par le service.

### `frontend/src/app/features/public/search-results/search-results.component.html`

- Affichage aligné sur le **modèle API** (`departureCity`, `arrivalCity`, `departureDateTime`, `price`, `availableSeats`, `partnerName`, `vehicleType`, `boardingPoint`).
- Lien **Réserver** vers **`/booking/trip/:id`** (comme l’accueil) ; état **Complet** si plus de places.

### `frontend/src/app/features/public/search-results/search-results.component.scss`

- Styles pour **chargement / erreur**, ligne méta (date + point d’embarquement), **terminus** dans la colonne droite, bouton/lien **Réserver** en bloc pleine largeur, variante **sold out**.

---

## Documentation & suivi produit

| Fichier | Modifications |
|---------|----------------|
| `README.md` (racine) | Lignes **F01**, **F02**, **F30** : statut/tests/notes + lien vers ce document. |
| `frontend/README.md` | Renvoi vers **`docs/recherche-segments.md`**. |
| `docs/recherche-segments.md` | Ce fichier — inventaire et comportement. |

---

## Commandes de validation frontend

```bash
cd frontend
npm run test -- --watch=false
npm run build
```

---

## Évolutions possibles (hors périmètre actuel)

- Navigation depuis l’accueil vers **`/search-results`** avec query string (si tu veux une URL partageable systématique) tout en gardant le même appel API.
- Tests de composant (`HomeComponent` / `SearchResultsComponent`) avec `HttpClientTestingModule` et formulaire simulé.
