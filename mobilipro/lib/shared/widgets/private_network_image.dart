import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

/// Affiche une image hébergée sur un endpoint privé (`/media/private?rel=...`)
/// nécessitant un JWT — contrairement à `Image.network`, qui ne peut pas
/// porter de header d'authentification, ce widget passe par l'instance Dio
/// de l'app (JWT déjà attaché via l'intercepteur d'auth) puis affiche les
/// octets reçus avec `Image.memory`. Même widget que mobile_app (parité).
class PrivateNetworkImage extends StatefulWidget {
  const PrivateNetworkImage({
    super.key,
    required this.relativePath,
    this.fit = BoxFit.cover,
    this.errorWidget,
    this.loadingWidget,
  });

  /// Chemin relatif stocké en base (ex: `sensitive/support/attachments/xxx.jpg`).
  final String relativePath;
  final BoxFit fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  @override
  State<PrivateNetworkImage> createState() => _PrivateNetworkImageState();
}

class _PrivateNetworkImageState extends State<PrivateNetworkImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PrivateNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _future = _load();
    }
  }

  Future<Uint8List> _load() async {
    final response = await ApiClient.instance.dio.get<List<int>>(
      '/media/private',
      queryParameters: {'rel': widget.relativePath},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingWidget ??
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return widget.errorWidget ?? const SizedBox.shrink();
        }
        return Image.memory(
          snapshot.data!,
          fit: widget.fit,
          width: double.infinity,
        );
      },
    );
  }
}
