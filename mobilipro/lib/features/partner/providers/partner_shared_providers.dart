import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

import '../../stations/presentation/pages/gare_detail_page.dart'
    show GareChauffeur;

class StationItem {
  const StationItem({
    required this.id,
    required this.name,
    required this.city,
    required this.active,
    required this.responsibleName,
    required this.chauffeurs,
  });

  final int id;
  final String name;
  final String city;
  final bool active;
  final String responsibleName;
  final List<GareChauffeur> chauffeurs;

  factory StationItem.fromJson(Map<String, dynamic> json) => StationItem(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    active: json['active'] as bool? ?? false,
    responsibleName: json['responsibleName'] as String? ?? '',
    chauffeurs: (json['assignedChauffeurs'] as List<dynamic>? ?? [])
        .map((e) => GareChauffeur.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

final partnerStationsProvider = FutureProvider.autoDispose<List<StationItem>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final response = await dio.get<List<dynamic>>('/partenaire/stations');
  return (response.data ?? [])
      .map((e) => StationItem.fromJson(e as Map<String, dynamic>))
      .toList();
});
