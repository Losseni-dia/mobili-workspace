import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/mobili_app_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────

class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorName,
    required this.authorRole,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final String authorName;
  final String authorRole;

  String get formattedTime => DateFormat('dd/MM HH:mm').format(createdAt);

  factory ChannelMessage.fromJson(Map<String, dynamic> json) => ChannelMessage(
        id: json['id'] as int,
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        authorName: json['authorName'] as String? ?? '',
        authorRole: json['authorRole'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider — réutilise le même endpoint que la gare, en lecture seule ici
// ─────────────────────────────────────────────────────────────────────────────

final tripChannelMessagesProvider = FutureProvider.autoDispose
    .family<List<ChannelMessage>, int>((ref, tripId) async {
  final dio = ApiClient.instance.dio;
  final response =
      await dio.get<List<dynamic>>('/trips/$tripId/channel/messages');
  final messages = (response.data ?? [])
      .map((e) => ChannelMessage.fromJson(e as Map<String, dynamic>))
      .toList();
  messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return messages;
});

// ─────────────────────────────────────────────────────────────────────────────
// Page — lecture seule pour le voyageur (pas de champ de saisie)
// ─────────────────────────────────────────────────────────────────────────────

class TripChannelThreadPage extends ConsumerStatefulWidget {
  const TripChannelThreadPage({
    super.key,
    required this.tripId,
    required this.tripLabel,
  });

  final int tripId;
  final String tripLabel;

  @override
  ConsumerState<TripChannelThreadPage> createState() =>
      _TripChannelThreadPageState();
}

class _TripChannelThreadPageState extends ConsumerState<TripChannelThreadPage> {
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(tripChannelMessagesProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: MobiliAppBar(
        title: 'Annonces du voyage',
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.mobiliYellow.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
             children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.mobiliYellowDark,
                ),
                const SizedBox(width: 8),
               Expanded(
                  child: Text(
                    widget.tripLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mobiliYellowDark,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Erreur : $e',
                      style: const TextStyle(color: AppColors.gray500),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(
                        tripChannelMessagesProvider(widget.tripId),
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.mobiliBlueFog,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.campaign_outlined,
                            color: AppColors.mobiliBlue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aucune annonce',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref.invalidate(
                    tripChannelMessagesProvider(widget.tripId),
                  ),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) =>
                        _ReadOnlyBubble(message: messages[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulle en lecture seule — toujours alignée à gauche (l'utilisateur ne parle jamais)
// ─────────────────────────────────────────────────────────────────────────────

class _ReadOnlyBubble extends StatelessWidget {
  const _ReadOnlyBubble({required this.message});
  final ChannelMessage message;

  Color _roleColor(String role) {
    switch (role) {
      case 'GARE':
      case 'STATION':
        return AppColors.warning;
      case 'PARTNER':
      case 'ADMIN':
        return AppColors.mobiliBlue;
      case 'CHAUFFEUR':
        return AppColors.stationGreen;
      default:
        return AppColors.gray400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(message.authorRole);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.authorRole,
                    style: TextStyle(
                      fontSize: 9,
                      color: roleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  message.authorName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.gray200),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message.body,
              style: const TextStyle(
                color: AppColors.mobiliBlueDeep,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              message.formattedTime,
              style: const TextStyle(fontSize: 10, color: AppColors.gray400),
            ),
          ),
        ],
      ),
    );
  }
}
