-- Script PONCTUEL, a executer manuellement (jamais une migration Flyway versionnee) — renseigne
-- les coordonnees GPS des villes deja desservies, apres la migration V52
-- (add_trip_stop_coordinates). Coordonnees ci-dessous approximatives (centre-ville, source
-- geographique generale) : A VERIFIER/CORRIGER avant execution, ne pas faire confiance a ces
-- valeurs sans relecture. Comparaison insensible a la casse/accents non geree : verifier que
-- city_label correspond exactement (SELECT DISTINCT city_label FROM trip_stops; pour lister les
-- valeurs reelles avant d'executer les UPDATE ci-dessous) — un accent different (ex. "Séguéla"
-- vs "Seguela") fait un UPDATE silencieusement sans effet (0 ligne modifiee, pas d'erreur).

UPDATE trip_stops SET latitude = 5.3600,  longitude = -4.0083 WHERE city_label = 'Abidjan';
UPDATE trip_stops SET latitude = 6.8206,  longitude = -5.2767 WHERE city_label = 'Yamoussoukro';
UPDATE trip_stops SET latitude = 7.6906,  longitude = -5.0301 WHERE city_label = 'Bouaké';
UPDATE trip_stops SET latitude = 6.8770,  longitude = -6.4502 WHERE city_label = 'Daloa';
UPDATE trip_stops SET latitude = 4.7485,  longitude = -6.6363 WHERE city_label = 'San-Pedro';
UPDATE trip_stops SET latitude = 9.4580,  longitude = -5.6296 WHERE city_label = 'Korhogo';
UPDATE trip_stops SET latitude = 7.4125,  longitude = -7.5539 WHERE city_label = 'Man';
UPDATE trip_stops SET latitude = 5.8372,  longitude = -5.3572 WHERE city_label = 'Divo';
UPDATE trip_stops SET latitude = 6.1319,  longitude = -5.9506 WHERE city_label = 'Gagnoa';
UPDATE trip_stops SET latitude = 6.7297,  longitude = -3.4964 WHERE city_label = 'Abengourou';
UPDATE trip_stops SET latitude = 5.9298,  longitude = -4.2153 WHERE city_label = 'Agboville';
UPDATE trip_stops SET latitude = 5.2118,  longitude = -3.7380 WHERE city_label = 'Grand-Bassam';
UPDATE trip_stops SET latitude = 8.0402,  longitude = -2.8000 WHERE city_label = 'Bondoukou';
UPDATE trip_stops SET latitude = 7.9614,  longitude = -6.6737 WHERE city_label = 'Séguéla';
UPDATE trip_stops SET latitude = 9.5045,  longitude = -7.5646 WHERE city_label = 'Odienné';
UPDATE trip_stops SET latitude = 6.9946,  longitude = -5.7433 WHERE city_label = 'Bouaflé';
UPDATE trip_stops SET latitude = 6.5500,  longitude = -5.0167 WHERE city_label = 'Toumodi';
UPDATE trip_stops SET latitude = 6.4969,  longitude = -6.5854 WHERE city_label = 'Issia';
UPDATE trip_stops SET latitude = 6.6167,  longitude = -5.9167 WHERE city_label = 'Sinfra';
UPDATE trip_stops SET latitude = 6.1053,  longitude = -3.8622 WHERE city_label = 'Adzopé';

-- Verification apres execution : lister les arrets encore sans coordonnees (ETA indisponible
-- pour tout trajet passant par ces villes tant qu'elles ne sont pas renseignees).
-- SELECT DISTINCT city_label FROM trip_stops WHERE latitude IS NULL OR longitude IS NULL;
