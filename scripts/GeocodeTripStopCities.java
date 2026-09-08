import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Script PONCTUEL, autonome — pas un composant applicatif permanent, jamais appelé par le
 * backend. Géocode (une seule fois) les villes distinctes de trip_stops encore sans
 * latitude/longitude, via l'API Mapbox Geocoding (MAPBOX_ACCESS_TOKEN — même token que
 * mapbox.access-token dans /etc/mobili/mobili.env), et génère un fichier SQL avec les UPDATE
 * correspondants, à relire et exécuter manuellement.
 *
 * N'exécute AUCUNE commande SQL lui-même — se contente d'écrire scripts/geocoded-cities.sql.
 *
 * Usage :
 *   MAPBOX_ACCESS_TOKEN=pk.xxx java GeocodeTripStopCities.java
 *
 * Chaque entrée : { requête envoyée à Mapbox (avec pays pour désambiguïser), code pays ISO
 * 3166-1 alpha-2, liste des city_label variantes trouvées en base à mettre à jour ensemble }.
 * "Touba (CI)" désambiguïsé explicitement du Touba sénégalais (deux vraies villes homonymes) —
 * voir échange avec l'utilisateur, Partie 3.
 */
public class GeocodeTripStopCities {

    record CityGroup(String query, String countryCode, List<String> variants) {}

    private static final List<CityGroup> CITIES = List.of(
        new CityGroup("Accra", "GH", List.of("Accra")),
        new CityGroup("Assini", "CI", List.of("Assini")),
        new CityGroup("Bako", "CI", List.of("Bako")),
        new CityGroup("Bamako", "ML", List.of("Bamako")),
        new CityGroup("Bangolo", "CI", List.of("Bangolo")),
        new CityGroup("Biankouman", "CI", List.of("Biankouman")),
        new CityGroup("Bobo-Dioulasso", "BF", List.of("Bobodioulasso")),
        new CityGroup("Bougouni", "ML", List.of("Bougouni")),
        new CityGroup("Bouna", "CI", List.of("Bouna")),
        new CityGroup("Boundiali", "CI", List.of("Boundiali")),
        new CityGroup("Bujumbura", "BI", List.of("Bujumbura")),
        new CityGroup("Conakry", "GN", List.of("Conakry")),
        new CityGroup("Cotonou", "BJ", List.of("Cotonou")),
        new CityGroup("Dabou", "CI", List.of("Dabou")),
        new CityGroup("Dakar", "SN", List.of("Dakar")),
        new CityGroup("Dimbokro", "CI", List.of("Dimbokro")),
        new CityGroup("Dosso", "NE", List.of("Dosso")),
        new CityGroup("Duékoué", "CI", List.of("Duékoué", "Duekoue")),
        new CityGroup("Elubo", "GH", List.of("Elubo")),
        new CityGroup("Ferkessédougou", "CI", List.of("Ferké")),
        new CityGroup("Gaya", "NE", List.of("Gaya")),
        new CityGroup("Gbéléla", "CI", List.of("Gbéléla")),
        new CityGroup("Gitega", "BI", List.of("Gitega")),
        new CityGroup("Grand-Béréby", "CI", List.of("Grand bérébi")),
        new CityGroup("Grand-Zattry", "CI", List.of("Grand zattry")),
        new CityGroup("Kankan", "GN", List.of("Kankan")),
        new CityGroup("Katiola", "CI", List.of("Katiola")),
        new CityGroup("Kolia", "CI", List.of("Kolia")),
        new CityGroup("Kouto", "CI", List.of("Kouto")),
        new CityGroup("Kumasi", "GH", List.of("Kumassi")),
        new CityGroup("Lakota", "CI", List.of("Lakota")),
        new CityGroup("Laoudi-Ba", "CI", List.of("Laoudi-ba")),
        new CityGroup("Lobia", "CI", List.of("Lobia")),
        new CityGroup("Lomé", "TG", List.of("Lomé")),
        new CityGroup("Madinani", "CI", List.of("Madinani")),
        new CityGroup("Malanville", "BJ", List.of("Malanville")),
        new CityGroup("Méagui", "CI", List.of("Méagui", "Meagui")),
        new CityGroup("Niakara", "CI", List.of("Niakara")),
        new CityGroup("Niamey", "NE", List.of("Niamey")),
        new CityGroup("Niangoloko", "BF", List.of("Niangoloko")),
        new CityGroup("Noé", "CI", List.of("Noé")),
        new CityGroup("Odienné", "CI", List.of("Odienne")), // "Odienné" déjà géocodé (voir seed-trip-stop-coordinates.sql) — ici seulement la variante sans accent
        new CityGroup("Ouangolodougou", "CI", List.of("Ouangolodougou")),
        new CityGroup("Oumé", "CI", List.of("Oumé")),
        new CityGroup("Pogo", "CI", List.of("Pogo")),
        new CityGroup("Sakassou", "CI", List.of("Sakassou")),
        new CityGroup("Samango", "CI", List.of("Samango")),
        new CityGroup("San-Pédro", "CI", List.of("San pedro", "San-pedro", "San-pédro")), // "San-Pedro" (avec tiret, sans accent) déjà géocodé
        new CityGroup("Sassandra", "CI", List.of("Sassandra")),
        new CityGroup("Sikasso", "ML", List.of("Sikasso")),
        new CityGroup("Soubré", "CI", List.of("Soubré", "Soubre")),
        new CityGroup("Tabou", "CI", List.of("Tabou")),
        new CityGroup("Tanger", "MA", List.of("Tanger")),
        new CityGroup("Thiaroye", "SN", List.of("Thiaroye")),
        new CityGroup("Thiès", "SN", List.of("Thiès")),
        new CityGroup("Tiassale", "CI", List.of("Tiassale")),
        new CityGroup("Tingrela", "CI", List.of("Tingrela")),
        new CityGroup("Touba", "CI", List.of("Touba (CI)")), // Touba Côte d'Ivoire — PAS Touba Sénégal, voir désambiguïsation Partie 2/3
        new CityGroup("Yabayo", "CI", List.of("Yabayo")),
        new CityGroup("Yamoussoukro", "CI", List.of("Yamassoukro")) // "Yamoussoukro" (orthographe correcte) déjà géocodé
    );

    private static final Pattern COORD_PATTERN =
        Pattern.compile("\"center\"\\s*:\\s*\\[\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*]");

    public static void main(String[] args) throws Exception {
        String token = System.getenv("MAPBOX_ACCESS_TOKEN");
        if (token == null || token.isBlank()) {
            System.err.println("MAPBOX_ACCESS_TOKEN non défini — voir /etc/mobili/mobili.env");
            System.exit(1);
        }

        System.out.println(CITIES.size() + " villes à géocoder (1 appel API chacune, "
            + "gratuit — tier gratuit Mapbox Geocoding : 100 000 requêtes/mois).");

        HttpClient client = HttpClient.newHttpClient();
        StringBuilder sql = new StringBuilder();
        sql.append("-- Généré par scripts/GeocodeTripStopCities.java — à relire avant exécution.\n");
        sql.append("-- Coordonnées issues du 1er résultat Mapbox Geocoding pour chaque requête ci-dessous.\n\n");

        int ok = 0, failed = 0;
        for (CityGroup city : CITIES) {
            String encodedQuery = java.net.URLEncoder.encode(city.query(), StandardCharsets.UTF_8);
            String url = "https://api.mapbox.com/geocoding/v5/mapbox.places/" + encodedQuery + ".json"
                + "?access_token=" + token
                + "&country=" + city.countryCode().toLowerCase()
                + "&limit=1";

            HttpRequest request = HttpRequest.newBuilder(URI.create(url)).GET().build();
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

            Matcher matcher = COORD_PATTERN.matcher(response.body());
            if (response.statusCode() == 200 && matcher.find()) {
                double lng = Double.parseDouble(matcher.group(1));
                double lat = Double.parseDouble(matcher.group(2));
                String variantsInClause = city.variants().stream()
                    .map(v -> "'" + v.replace("'", "''") + "'")
                    .reduce((a, b) -> a + ", " + b).orElse("");
                sql.append(String.format(java.util.Locale.ROOT,
                    "UPDATE trip_stops SET latitude = %.4f, longitude = %.4f WHERE city_label IN (%s); -- %s%n",
                    lat, lng, variantsInClause, city.query()));
                System.out.println("✅ " + city.query() + " -> " + lat + ", " + lng);
                ok++;
            } else {
                sql.append("-- ÉCHEC géocodage : ").append(city.query())
                   .append(" (variantes : ").append(city.variants()).append(") — statut HTTP ")
                   .append(response.statusCode()).append(", à traiter manuellement.\n");
                System.err.println("❌ Échec pour " + city.query() + " (HTTP " + response.statusCode() + ")");
                failed++;
            }
        }

        Path outPath = Path.of("scripts/geocoded-cities.sql");
        Files.writeString(outPath, sql.toString());
        System.out.println();
        System.out.println(ok + " villes géocodées, " + failed + " échecs.");
        System.out.println("Fichier écrit : " + outPath.toAbsolutePath());
        System.out.println("Relis-le avant de l'exécuter sur la base — aucune commande SQL n'a été lancée.");
    }
}
