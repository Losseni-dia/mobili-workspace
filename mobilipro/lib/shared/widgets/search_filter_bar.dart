import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Barre de recherche + dropdown filtre réutilisable.
/// S'intègre dans un AppBar bottom ou en header de page.
///
/// Exemple d'utilisation :
/// ```dart
/// SearchFilterBar(
///   hintText: 'Rechercher un trajet...',
///   filterValue: _filter,
///   filterItems: const [
///     FilterItem(value: 'TOUS', label: 'Tous'),
///     FilterItem(value: 'CONFIRMED', label: 'Confirmé'),
///   ],
///   onSearchChanged: (v) => setState(() => _search = v),
///   onFilterChanged: (v) => setState(() => _filter = v),
/// )
/// ```

class FilterItem {
  const FilterItem({required this.value, required this.label});
  final String value;
  final String label;
}

class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.hintText,
    required this.filterValue,
    required this.filterItems,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.backgroundColor = AppColors.mobiliBlue,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
    this.controller,
  });

  final String hintText;
  final String filterValue;
  final List<FilterItem> filterItems;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final Color backgroundColor;
  final EdgeInsets padding;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: padding,
      child: Row(
        children: [
          // Champ recherche
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: AppColors.gray500.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Dropdown filtre
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filterValue,
                dropdownColor: AppColors.mobiliBlueDeep,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.white,
                  size: 18,
                ),
                items: filterItems
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.value,
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onFilterChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

