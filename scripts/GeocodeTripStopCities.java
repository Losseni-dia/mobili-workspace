import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Script PONCTUEL, autonome — pas un composant applicatif permanent, jamais appelé par le
 * backend. À relancer de temps en temps (manuellement) pour rattraper les nouvelles villes
 * ajoutées via de nouveaux trajets. Interroge lui-même trip_stops (via `psql` en sous-processus
 * — aucune dépendance JDBC ajoutée) pour trouver les city_label encore sans coordonnées, les
 * géocode via l'API Mapbox Geocoding, et écrit les UPDATE correspondants dans un fichier SQL à
 * relire et exécuter manuellement.
 *
 * N'exécute AUCUNE commande d'écriture SQL lui-même — seulement un SELECT en lecture pour
 * trouver les villes, puis écrit le fichier SQL des UPDATE.
 *
 * IMPORTANT — ce que ce script ne peut PAS faire à ta place :
 *  - Désambiguïser un nom de ville qui existe dans plusieurs pays (ex. "Touba" au Sénégal ET en
 *    Côte d'Ivoire) — la recherche Mapbox se fait sans filtre pays, donc le 1er résultat mondial
 *    est retenu, qui peut être le mauvais pays. Les noms listés dans AMBIGUOUS_NAMES ci-dessous
 *    déclenchent un avertissement explicite dans le fichier de sortie, à vérifier à la main.
 *  - Détecter des données de test (ex. "Ssss", "Ville desservie 1") au-delà du filtre basique
 *    ci-dessous (EXCLUDE_PATTERNS) — relis toujours le fichier généré avant de l'exécuter.
 *
 * Usage :
 *   MAPBOX_ACCESS_TOKEN=pk.xxx \
 *   DB_CONNINFO="host=... port=5432 dbname=mobili_db user=postgres sslmode=require" \
 *   PGPASSWORD=... \
 *   java GeocodeTripStopCities.java
 */
public class GeocodeTripStopCities {

    /** Noms connus pour exister dans plusieurs pays — à vérifier manuellement dans le fichier
     *  de sortie avant exécution (voir échange Partie 2/3 sur "Touba" CI vs SN). */
    private static final Set<String> AMBIGUOUS_NAMES = Set.of("touba");

    /** Filtre basique anti-données-de-test — pas exhaustif, une relecture manuelle reste
     *  nécessaire (voir Partie 1 du nettoyage : "Ssss", "Ville desservie N", combinaisons
     *  "Ville A - Ville B - Ville C", etc.). */
    private static final Pattern[] EXCLUDE_PATTERNS = {
        Pattern.compile("^(.)\\1{2,}$", Pattern.CASE_INSENSITIVE), // lettre répétée (Ssss, Dddd, Ffff...)
        Pattern.compile("^ville desservie \\d+$", Pattern.CASE_INSENSITIVE), // placeholders
        Pattern.compile("^none$", Pattern.CASE_INSENSITIVE),
        Pattern.compile(".* - .* - .*"),               // tronçons compressés type "A - B - C"
    };

    /** Ajoutés manuellement après un géocodage automatique qui les a résolus vers un mauvais
     *  pays/une mauvaise ville homonyme (voir historique du chat) — la recherche par nom seul,
     *  même avec biais géographique, ne peut pas fiabiliser ces cas ambigus/tronqués. */
    private static final Set<String> KNOWN_MANUAL_REVIEW = Set.of("coto", "bobo");

    /** Biaise (sans exclure) les résultats vers l'Afrique de l'Ouest — la plupart des trajets
     *  sont dans cette zone, mais un vrai trajet européen (ex. Bruxelles/Lille/Paris, trajet de
     *  test) reste correctement géocodé : `proximity` influence juste le classement, il ne
     *  filtre pas les autres pays comme le ferait `country`. */
    private static final String PROXIMITY_ABIDJAN = "-4.0083,5.3600";

    private static final Pattern COORD_PATTERN =
        Pattern.compile("\"center\"\\s*:\\s*\\[\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*]");

    public static void main(String[] args) throws Exception {
        String mapboxToken = requireEnv("MAPBOX_ACCESS_TOKEN");
        String dbConnInfo = requireEnv("DB_CONNINFO");

        List<String> cities = fetchCitiesMissingCoordinates(dbConnInfo);
        List<String> filtered = new ArrayList<>();
        List<String> excluded = new ArrayList<>();
        for (String city : cities) {
            if (looksLikeTestData(city) || KNOWN_MANUAL_REVIEW.contains(city.trim().toLowerCase())) {
                excluded.add(city);
            } else {
                filtered.add(city);
            }
        }

        System.out.println(cities.size() + " ville(s) sans coordonnées trouvée(s) en base.");
        if (!excluded.isEmpty()) {
            System.out.println(excluded.size() + " exclue(s) par le filtre anti-test (à vérifier "
                + "quand même à l'oeil, ce filtre n'est pas exhaustif) : " + excluded);
        }
        if (filtered.isEmpty()) {
            System.out.println("Rien à géocoder — toutes les villes ont déjà des coordonnées "
                + "(ou ont été exclues par le filtre).");
            return;
        }
        System.out.println(filtered.size() + " ville(s) à géocoder (1 appel API Mapbox chacune, "
            + "gratuit — tier gratuit : 100 000 requêtes/mois).");

        HttpClient client = HttpClient.newHttpClient();
        StringBuilder sql = new StringBuilder();
        sql.append("-- Généré automatiquement par scripts/GeocodeTripStopCities.java — à relire avant exécution.\n");
        sql.append("-- Recherche Mapbox SANS filtre pays (villes découvertes automatiquement, pays inconnu\n");
        sql.append("-- à l'avance) : vérifier en particulier les lignes marquées AMBIGU ci-dessous.\n\n");

        int ok = 0, failed = 0, ambiguous = 0;
        for (String city : filtered) {
            String encodedQuery = java.net.URLEncoder.encode(city, StandardCharsets.UTF_8);
            String url = "https://api.mapbox.com/geocoding/v5/mapbox.places/" + encodedQuery + ".json"
                + "?access_token=" + mapboxToken
                + "&proximity=" + PROXIMITY_ABIDJAN
                + "&limit=1";

            HttpRequest request = HttpRequest.newBuilder(URI.create(url)).GET().build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            Matcher matcher = COORD_PATTERN.matcher(response.body());
            boolean isAmbiguous = AMBIGUOUS_NAMES.contains(city.trim().toLowerCase());
            if (response.statusCode() == 200 && matcher.find()) {
                double lng = Double.parseDouble(matcher.group(1));
                double lat = Double.parseDouble(matcher.group(2));
                if (isAmbiguous) {
                    sql.append("-- ⚠️ AMBIGU (plusieurs pays possibles pour ce nom) — VÉRIFIER avant d'exécuter :\n");
                    ambiguous++;
                }
                sql.append(String.format(java.util.Locale.ROOT,
                    "UPDATE trip_stops SET latitude = %.4f, longitude = %.4f WHERE city_label = '%s';%n",
                    lat, lng, city.replace("'", "''")));
                System.out.println((isAmbiguous ? "⚠️ " : "✅ ") + city + " -> " + lat + ", " + lng);
                ok++;
            } else {
                sql.append("-- ÉCHEC géocodage : '").append(city.replace("'", "''"))
                   .append("' — statut HTTP ").append(response.statusCode())
                   .append(", à traiter manuellement.\n");
                System.err.println("❌ Échec pour " + city + " (HTTP " + response.statusCode() + ")");
                failed++;
            }
        }

        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
        // Écrit dans le répertoire courant (pas "scripts/..." en dur) — ce script est lancé
        // depuis n'importe où (ex. /tmp sur le serveur), pas forcément depuis la racine du repo.
        Path outPath = Path.of("geocoded-cities-" + timestamp + ".sql");
        Files.writeString(outPath, sql.toString());
        System.out.println();
        System.out.println(ok + " géocodée(s) (dont " + ambiguous + " ambiguë(s) à vérifier), " + failed + " échec(s).");
        System.out.println("Fichier écrit : " + outPath.toAbsolutePath());
        System.out.println("Relis-le avant de l'exécuter sur la base — aucune commande d'écriture SQL n'a été lancée.");
    }

    private static boolean looksLikeTestData(String city) {
        for (Pattern p : EXCLUDE_PATTERNS) {
            if (p.matcher(city).matches() || p.matcher(city).find()) {
                return true;
            }
        }
        return false;
    }

    /** Lit trip_stops via `psql -t -A` (sortie brute, une valeur par ligne) — pas de driver
     *  JDBC ajouté, réutilise le psql déjà présent sur ce serveur. PGPASSWORD (env) évite le
     *  prompt interactif. */
    private static List<String> fetchCitiesMissingCoordinates(String dbConnInfo) throws Exception {
        String query = "SELECT DISTINCT city_label FROM trip_stops "
            + "WHERE latitude IS NULL OR longitude IS NULL ORDER BY city_label;";
        ProcessBuilder pb = new ProcessBuilder("psql", dbConnInfo, "-t", "-A", "-c", query);
        pb.redirectErrorStream(false);
        Process process = pb.start();

        List<String> cities = new ArrayList<>();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (!line.isBlank()) {
                    cities.add(line.trim());
                }
            }
        }
        int exitCode = process.waitFor();
        if (exitCode != 0) {
            try (BufferedReader err = new BufferedReader(
                    new InputStreamReader(process.getErrorStream(), StandardCharsets.UTF_8))) {
                err.lines().forEach(System.err::println);
            }
            throw new IllegalStateException("psql a échoué (code " + exitCode + ") — voir stderr ci-dessus.");
        }
        return cities;
    }

    private static String requireEnv(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) {
            System.err.println(name + " non défini.");
            System.exit(1);
        }
        return value;
    }
}
