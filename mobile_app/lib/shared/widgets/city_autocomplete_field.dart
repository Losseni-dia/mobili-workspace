import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/trips/providers/trip_provider.dart';

/// Champ ville avec autocomplétion — suggestions affichées dans un overlay
/// flottant (jamais inline dans la Column), pour ne jamais décaler les
/// champs voisins pendant la saisie. Réutilisé sur l'accueil et l'onglet
/// Recherche pour une expérience de saisie cohérente partout dans l'app.
class CityAutocompleteField extends ConsumerStatefulWidget {
  const CityAutocompleteField({
    super.key,
    required this.controller,
    required this.decoration,
    this.style,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  ConsumerState<CityAutocompleteField> createState() =>
      _CityAutocompleteFieldState();
}

class _CityAutocompleteFieldState extends ConsumerState<CityAutocompleteField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() async {
    widget.onChanged?.call(widget.controller.text);
    final query = widget.controller.text;
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _suggestions = []);
      _removeOverlay();
      return;
    }
    final results = await ref.read(tripServiceProvider).fetchCities(query);
    if (!mounted) return;
    setState(() => _suggestions = results);
    if (results.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    // On récupère la largeur du champ AVANT de construire l'overlay — lire
    // context.size depuis le builder de l'OverlayEntry lui-même échoue,
    // car cet overlay n'a pas encore été mis en page à ce stade.
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldWidth = renderBox?.size.width;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 46),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gray200),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final city = _suggestions[i];
                  return InkWell(
                    onTap: () {
                      widget.controller.text = city;
                      widget.onChanged?.call(city);
                      setState(() => _suggestions = []);
                      _removeOverlay();
                      _focusNode.unfocus();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.mobiliBlue),
                          const SizedBox(width: 8),
                          Text(city,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.mobiliBlueDeep)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final clearButton = hasText
        ? IconButton(
            icon: const Icon(Icons.clear_rounded, size: 16),
            onPressed: () {
              widget.controller.clear();
              widget.onChanged?.call('');
              setState(() => _suggestions = []);
              _removeOverlay();
            },
          )
        : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: _fieldKey,
        controller: widget.controller,
        focusNode: _focusNode,
        validator: widget.validator,
        style: widget.style,
        decoration: widget.decoration.copyWith(suffixIcon: clearButton),
      ),
    );
  }
}
