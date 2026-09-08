-- Script PONCTUEL, a executer manuellement (jamais une migration Flyway versionnee) — renseigne
-- les coordonnees GPS des villes deja desservies, apres la migration V52
-- (add_trip_stop_coordinates). Coordonnees ci-dessous approximatives (centre-ville, source
-- geographique generale) : A VERIFIER/CORRIGER avant execution, ne pas faire confiance a ces
-- valeurs sans relecture. Comparaison insensible a la casse/accents non geree : verifier que
-- city_label correspond exactement (SELECT DISTINCT city_label FROM trip_stops; pour lister les
-- valeurs reelles avant d'executer les UPDATE ci-dessous).

UPDATE trip_stops SET latitude = 6.4969,  longitude = -6.5854 WHERE city_label = 'Issia';
UPDATE trip_stops SET latitude = 4.7485,  longitude = -6.6363 WHERE city_label = 'San-Pedro';
UPDATE trip_stops SET latitude = 5.8372,  longitude = -5.3572 WHERE city_label = 'Divo';
UPDATE trip_stops SET latitude = 12.3714, longitude = -1.5197 WHERE city_label = 'Ouagadougou';
UPDATE trip_stops SET latitude = 11.1771, longitude = -4.2979 WHERE city_label = 'Bobo-Dioulasso';

-- Verification apres execution : lister les arrets encore sans coordonnees (ETA indisponible
-- pour tout trajet passant par ces villes tant qu'elles ne sont pas renseignees).
-- SELECT DISTINCT city_label FROM trip_stops WHERE latitude IS NULL OR longitude IS NULL;
