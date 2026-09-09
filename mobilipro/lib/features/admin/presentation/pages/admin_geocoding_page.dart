import 'package:flutter/material.dart';

import 'package:mobilipro/core/network/api_client.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_common_widgets.dart';

/// Portage mobile de l'écran admin-geocoding (frontend Angular) — même backend
/// (AdminTripStopGeocodingController), mêmes 3 actions par ligne (Ignorer,
/// Modifier le nom + Re-géocoder, filtre pays), voir historique du chantier
/// tracking temps réel. Aucune écriture en base tant que "Appliquer" n'est
/// pas explicitement pressé.

/// Aligné sur GeocodingPreviewItem (backend).
class GeocodingPreviewItem {
  const GeocodingPreviewItem({
    required this.cityLabel,
    this.latitude,
    this.longitude,
    required this.ambiguous,
    this.errorMessage,
  });

  final String cityLabel;
  final double? latitude;
  final double? longitude;
  final bool ambiguous;
  final String? errorMessage;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory GeocodingPreviewItem.fromJson(Map<String, dynamic> j) => GeocodingPreviewItem(
        cityLabel: j['cityLabel'] as String,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        ambiguous: j['ambiguous'] as bool? ?? false,
        errorMessage: j['errorMessage'] as String?,
      );
}

/// Pays desservis en Afrique + tests ponctuels hors zone (ex. Bruxelles-Lille-
/// Paris) — même liste que GEOCODING_COUNTRY_OPTIONS côté frontend Angular.
const List<(String code, String label, String group)> kGeocodingCountryOptions = [
  ('DZ', 'Algérie', 'Afrique'),
  ('AO', 'Angola', 'Afrique'),
  ('BJ', 'Bénin', 'Afrique'),
  ('BW', 'Botswana', 'Afrique'),
  ('BF', 'Burkina Faso', 'Afrique'),
  ('BI', 'Burundi', 'Afrique'),
  ('CV', 'Cap-Vert', 'Afrique'),
  ('CM', 'Cameroun', 'Afrique'),
  ('CF', 'République centrafricaine', 'Afrique'),
  ('TD', 'Tchad', 'Afrique'),
  ('KM', 'Comores', 'Afrique'),
  ('CG', 'Congo', 'Afrique'),
  ('CD', 'RD Congo', 'Afrique'),
  ('DJ', 'Djibouti', 'Afrique'),
  ('EG', 'Égypte', 'Afrique'),
  ('GQ', 'Guinée équatoriale', 'Afrique'),
  ('ER', 'Érythrée', 'Afrique'),
  ('SZ', 'Eswatini', 'Afrique'),
  ('ET', 'Éthiopie', 'Afrique'),
  ('GA', 'Gabon', 'Afrique'),
  ('GM', 'Gambie', 'Afrique'),
  ('GH', 'Ghana', 'Afrique'),
  ('GN', 'Guinée', 'Afrique'),
  ('GW', 'Guinée-Bissau', 'Afrique'),
  ('CI', "Côte d'Ivoire", 'Afrique'),
  ('KE', 'Kenya', 'Afrique'),
  ('LS', 'Lesotho', 'Afrique'),
  ('LR', 'Liberia', 'Afrique'),
  ('LY', 'Libye', 'Afrique'),
  ('MG', 'Madagascar', 'Afrique'),
  ('MW', 'Malawi', 'Afrique'),
  ('ML', 'Mali', 'Afrique'),
  ('MR', 'Mauritanie', 'Afrique'),
  ('MU', 'Maurice', 'Afrique'),
  ('MA', 'Maroc', 'Afrique'),
  ('MZ', 'Mozambique', 'Afrique'),
  ('NA', 'Namibie', 'Afrique'),
  ('NE', 'Niger', 'Afrique'),
  ('NG', 'Nigeria', 'Afrique'),
  ('RW', 'Rwanda', 'Afrique'),
  ('ST', 'Sao Tomé-et-Principe', 'Afrique'),
  ('SN', 'Sénégal', 'Afrique'),
  ('SC', 'Seychelles', 'Afrique'),
  ('SL', 'Sierra Leone', 'Afrique'),
  ('SO', 'Somalie', 'Afrique'),
  ('ZA', 'Afrique du Sud', 'Afrique'),
  ('SS', 'Soudan du Sud', 'Afrique'),
  ('SD', 'Soudan', 'Afrique'),
  ('TZ', 'Tanzanie', 'Afrique'),
  ('TG', 'Togo', 'Afrique'),
  ('TN', 'Tunisie', 'Afrique'),
  ('UG', 'Ouganda', 'Afrique'),
  ('ZM', 'Zambie', 'Afrique'),
  ('ZW', 'Zimbabwe', 'Afrique'),
  ('AL', 'Albanie', 'Europe'),
  ('AD', 'Andorre', 'Europe'),
  ('AT', 'Autriche', 'Europe'),
  ('BY', 'Biélorussie', 'Europe'),
  ('BE', 'Belgique', 'Europe'),
  ('BA', 'Bosnie-Herzégovine', 'Europe'),
  ('BG', 'Bulgarie', 'Europe'),
  ('HR', 'Croatie', 'Europe'),
  ('CY', 'Chypre', 'Europe'),
  ('CZ', 'Tchéquie', 'Europe'),
  ('DK', 'Danemark', 'Europe'),
  ('EE', 'Estonie', 'Europe'),
  ('FI', 'Finlande', 'Europe'),
  ('FR', 'France', 'Europe'),
  ('DE', 'Allemagne', 'Europe'),
  ('GR', 'Grèce', 'Europe'),
  ('HU', 'Hongrie', 'Europe'),
  ('IS', 'Islande', 'Europe'),
  ('IE', 'Irlande', 'Europe'),
  ('IT', 'Italie', 'Europe'),
  ('XK', 'Kosovo', 'Europe'),
  ('LV', 'Lettonie', 'Europe'),
  ('LI', 'Liechtenstein', 'Europe'),
  ('LT', 'Lituanie', 'Europe'),
  ('LU', 'Luxembourg', 'Europe'),
  ('MT', 'Malte', 'Europe'),
  ('MD', 'Moldavie', 'Europe'),
  ('MC', 'Monaco', 'Europe'),
  ('ME', 'Monténégro', 'Europe'),
  ('NL', 'Pays-Bas', 'Europe'),
  ('MK', 'Macédoine du Nord', 'Europe'),
  ('NO', 'Norvège', 'Europe'),
  ('PL', 'Pologne', 'Europe'),
  ('PT', 'Portugal', 'Europe'),
  ('RO', 'Roumanie', 'Europe'),
  ('RU', 'Russie', 'Europe'),
  ('SM', 'Saint-Marin', 'Europe'),
  ('RS', 'Serbie', 'Europe'),
  ('SK', 'Slovaquie', 'Europe'),
  ('SI', 'Slovénie', 'Europe'),
  ('ES', 'Espagne', 'Europe'),
  ('SE', 'Suède', 'Europe'),
  ('CH', 'Suisse', 'Europe'),
  ('UA', 'Ukraine', 'Europe'),
  ('GB', 'Royaume-Uni', 'Europe'),
  ('VA', 'Vatican', 'Europe'),
];

/// Une ligne d'aperçu + son état d'édition local — jamais persisté tant que
/// "Appliquer" n'a pas été pressé.
class _GeocodingRow {
  _GeocodingRow(this.item)
      : selected = item.hasCoordinates && !item.ambiguous,
        editedLabel = item.cityLabel,
        country = '',
        reGeocoding = false;

  GeocodingPreviewItem item;
  bool selected;
  String editedLabel;
  String country;
  bool reGeocoding;
}

class AdminGeocodingPage extends StatefulWidget {
  const AdminGeocodingPage({super.key});

  @override
  State<AdminGeocodingPage> createState() => _AdminGeocodingPageState();
}

class _AdminGeocodingPageState extends State<AdminGeocodingPage> {
  List<_GeocodingRow> _rows = [];
  bool _loading = false;
  bool _applying = false;
  bool _hasLoadedOnce = false;
  String? _loadError;

  int get _selectedCount => _rows.where((r) => r.selected).length;
  int get _selectableCount => _rows.where((r) => r.item.hasCoordinates).length;

  Future<void> _loadPreview() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await ApiClient.instance.dio
          .get<Map<String, dynamic>>('/admin/trip-stops-geocoding/preview');
      final items = ((res.data?['items'] as List<dynamic>?) ?? [])
          .map((e) => GeocodingPreviewItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _rows = items.map((i) => _GeocodingRow(i)).toList();
        _loading = false;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      setState(() {
        _loadError = "Impossible de charger l'aperçu : $e";
        _loading = false;
      });
    }
  }

  void _toggleRow(_GeocodingRow row) {
    if (!row.item.hasCoordinates) return;
    setState(() => row.selected = !row.selected);
  }

  void _selectAllValid() {
    setState(() {
      for (final r in _rows) {
        if (r.item.hasCoordinates) r.selected = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      for (final r in _rows) {
        r.selected = false;
      }
    });
  }

  /// Retire la ligne de l'écran — jamais d'appel backend, purement local.
  void _ignoreRow(_GeocodingRow row) {
    setState(() => _rows.remove(row));
  }

  Future<void> _pickCountry(_GeocodingRow row) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CountryPickerSheet(current: row.country),
    );
    if (selected != null) {
      setState(() => row.country = selected);
    }
  }

  Future<void> _reGeocode(_GeocodingRow row) async {
    final query = row.editedLabel.trim();
    if (query.isEmpty) {
      _showSnack('Le nom de ville ne peut pas être vide.', AppColors.danger);
      return;
    }
    setState(() => row.reGeocoding = true);
    try {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/admin/trip-stops-geocoding/geocode-one',
        queryParameters: {
          'query': query,
          if (row.country.isNotEmpty) 'country': row.country,
        },
      );
      final result = GeocodingPreviewItem.fromJson(res.data!);
      setState(() {
        row.item = result;
        row.reGeocoding = false;
        row.selected = result.hasCoordinates && !result.ambiguous;
      });
    } catch (e) {
      setState(() => row.reGeocoding = false);
      _showSnack('Échec du re-géocodage : $e', AppColors.danger);
    }
  }

  Future<void> _apply() async {
    final items = _rows
        .where((r) => r.selected && r.item.hasCoordinates)
        .map((r) {
      final newLabel = r.editedLabel.trim();
      final renamed = newLabel.isNotEmpty && newLabel != r.item.cityLabel;
      return {
        'cityLabel': r.item.cityLabel,
        'latitude': r.item.latitude,
        'longitude': r.item.longitude,
        'newCityLabel': renamed ? newLabel : null,
      };
    }).toList();

    if (items.isEmpty) {
      _showSnack('Coche au moins une ville avant de valider.', AppColors.danger);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Appliquer les coordonnées ?'),
        content: Text(
          '${items.length} ville(s) — cette action écrit en base immédiatement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mobiliBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Appliquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _applying = true);
    try {
      final res = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/admin/trip-stops-geocoding/apply',
        data: {'items': items},
      );
      final appliedCount = res.data?['appliedCount'] as int? ?? 0;
      final appliedLabels = ((res.data?['appliedCityLabels'] as List<dynamic>?) ?? [])
          .map((e) => e as String)
          .toSet();
      setState(() {
        _applying = false;
        _rows = _rows.where((r) => !appliedLabels.contains(r.item.cityLabel)).toList();
      });
      _showSnack(
        '$appliedCount ville(s) mise(s) à jour.',
        appliedCount > 0 ? AppColors.stationGreen : AppColors.gray500,
      );
    } catch (e) {
      setState(() => _applying = false);
      _showSnack("Échec de l'application des coordonnées : $e", AppColors.danger);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          backgroundColor: AppColors.mobiliBlue,
          foregroundColor: AppColors.white,
          title: const Text(
            'Géocodage arrêts',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          actions: [
            if (_hasLoadedOnce && _rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    '$_selectedCount / $_selectableCount',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : _loadPreview,
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.mobiliBlue,
          onRefresh: _loadPreview,
          child: _buildBody(),
        ),
        bottomNavigationBar: _hasLoadedOnce && _rows.isNotEmpty
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _selectAllValid,
                          child: const Text('Tout cocher'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearSelection,
                          child: const Text('Tout décocher'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _applying || _selectedCount == 0 ? null : _apply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mobiliBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(_applying ? 'Application…' : 'Appliquer ($_selectedCount)'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      );

  Widget _buildBody() {
    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [AdminErrorCard(message: _loadError!)],
      );
    }
    if (!_hasLoadedOnce && !_loading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "Villes d'arrêts de trajet sans coordonnées GPS — nécessaires au calcul "
            "d'ETA temps réel. Aucune écriture en base tant que tu n'as pas validé.",
            style: TextStyle(color: AppColors.gray500, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPreview,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mobiliBlue),
            child: const Text(
              'Chercher les villes manquantes',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mobiliBlue));
    }
    if (_rows.isEmpty) {
      return ListView(
        children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Aucune ville sans coordonnées — tout est déjà géocodé.',
                style: TextStyle(color: AppColors.gray400),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: _rows.length,
      itemBuilder: (context, i) => _GeocodingRowCard(
        row: _rows[i],
        onToggle: () => _toggleRow(_rows[i]),
        onIgnore: () => _ignoreRow(_rows[i]),
        onEditedLabelChanged: (v) => setState(() => _rows[i].editedLabel = v),
        onPickCountry: () => _pickCountry(_rows[i]),
        onReGeocode: () => _reGeocode(_rows[i]),
      ),
    );
  }
}

class _GeocodingRowCard extends StatelessWidget {
  const _GeocodingRowCard({
    required this.row,
    required this.onToggle,
    required this.onIgnore,
    required this.onEditedLabelChanged,
    required this.onPickCountry,
    required this.onReGeocode,
  });

  final _GeocodingRow row;
  final VoidCallback onToggle;
  final VoidCallback onIgnore;
  final ValueChanged<String> onEditedLabelChanged;
  final VoidCallback onPickCountry;
  final VoidCallback onReGeocode;

  (String, Color) get _statusLabelColor {
    if (row.item.ambiguous) return ('Ambigu — vérifier le pays', AppColors.warning);
    if (row.item.errorMessage != null) return (row.item.errorMessage!, AppColors.danger);
    return ('OK', AppColors.stationGreen);
  }

  String get _countryLabel {
    if (row.country.isEmpty) return 'Aucun (recherche mondiale)';
    final match = kGeocodingCountryOptions.firstWhere((o) => o.$1 == row.country);
    return match.$2;
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _statusLabelColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: row.item.ambiguous
              ? AppColors.warning.withValues(alpha: 0.4)
              : (row.item.errorMessage != null
                  ? AppColors.danger.withValues(alpha: 0.3)
                  : AppColors.gray200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (row.item.hasCoordinates)
                Checkbox(
                  value: row.selected,
                  onChanged: (_) => onToggle(),
                  activeColor: AppColors.mobiliBlue,
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Text(
                  row.item.cityLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (row.item.hasCoordinates) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                '${row.item.latitude}, ${row.item.longitude}',
                style: const TextStyle(fontSize: 11, color: AppColors.gray500),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: TextEditingController(text: row.editedLabel)
              ..selection = TextSelection.collapsed(offset: row.editedLabel.length),
            onChanged: onEditedLabelChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Nom corrigé',
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPickCountry,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: Text(_countryLabel, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: row.reGeocoding ? null : onReGeocode,
                  icon: row.reGeocoding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Re-géocoder', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onIgnore,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.gray500),
                  icon: const Icon(Icons.visibility_off_rounded, size: 16),
                  label: const Text('Ignorer', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sélecteur pays en feuille modale, groupé Afrique/Europe avec recherche —
/// équivalent mobile de l'<optgroup> du <select> web.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.current});
  final String current;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = kGeocodingCountryOptions
        .where((o) => o.$2.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final groups = <String, List<(String, String, String)>>{};
    for (final o in filtered) {
      groups.putIfAbsent(o.$3, () => []).add(o);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un pays…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('Aucun (recherche mondiale)'),
                    trailing: widget.current.isEmpty
                        ? const Icon(Icons.check_rounded, color: AppColors.mobiliBlue)
                        : null,
                    onTap: () => Navigator.pop(context, ''),
                  ),
                  for (final group in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        group.key,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                    for (final o in group.value)
                      ListTile(
                        dense: true,
                        title: Text(o.$2),
                        trailing: widget.current == o.$1
                            ? const Icon(Icons.check_rounded, color: AppColors.mobiliBlue)
                            : null,
                        onTap: () => Navigator.pop(context, o.$1),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
