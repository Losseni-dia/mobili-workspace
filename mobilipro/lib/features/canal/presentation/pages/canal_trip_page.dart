import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

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

  bool get isGare =>
      authorRole == 'GARE' || authorRole == 'PARTNER' || authorRole == 'ADMIN';
  bool get isChauffeur => authorRole == 'CHAUFFEUR';

  String get formattedTime => DateFormat('dd/MM HH:mm').format(createdAt);

  factory ChannelMessage.fromJson(Map<String, dynamic> json) => ChannelMessage(
    id: json['id'] as int,
    body: json['body'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    authorName: json['authorName'] as String? ?? '',
    authorRole: json['authorRole'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final _channelMessagesProvider = FutureProvider.autoDispose
    .family<List<ChannelMessage>, int>((ref, tripId) async {
      final dio = ApiClient.instance.dio;
      final response = await dio.get<List<dynamic>>(
        '/trips/$tripId/channel/messages',
      );
      final messages = (response.data ?? [])
          .map((e) => ChannelMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    });

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class CanalTripPage extends ConsumerStatefulWidget {
  const CanalTripPage({
    super.key,
    required this.tripId,
    required this.tripLabel,
  });

  final int tripId;
  final String tripLabel;

  @override
  ConsumerState<CanalTripPage> createState() => _CanalTripPageState();
}

class _CanalTripPageState extends ConsumerState<CanalTripPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
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

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageCtrl.clear();

    try {
      await ApiClient.instance.dio.post<void>(
        '/trips/${widget.tripId}/channel/messages',
        data: {'body': text},
      );
      ref.invalidate(_channelMessagesProvider(widget.tripId));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _messageCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_channelMessagesProvider(widget.tripId));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Canal trajet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              widget.tripLabel,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_channelMessagesProvider(widget.tripId)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau info
          Container(
            width: double.infinity,
            color: AppColors.mobiliYellow.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.proGold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages visibles par tous les passagers de ce trajet',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.proGold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste messages
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
                        _channelMessagesProvider(widget.tripId),
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
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.mobiliBlue,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Aucun message',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Envoyez un message aux passagers',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                _scrollToBottom();

                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async =>
                      ref.invalidate(_channelMessagesProvider(widget.tripId)),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = messages[i];
                      final isMe = msg.isGare || msg.isChauffeur;
                      return _MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
                );
              },
            ),
          ),

          // Zone saisie
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: const Border(top: BorderSide(color: AppColors.gray200)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: TextField(
                      controller: _messageCtrl,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message aux passagers...',
                        hintStyle: TextStyle(
                          color: AppColors.gray400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Bouton envoyer
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _isSending
                          ? AppColors.gray300
                          : AppColors.mobiliBlue,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulle de message
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChannelMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(message.authorRole);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Auteur + rôle
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                ],
                Text(
                  message.authorName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                ],
              ],
            ),
          ),

          // Bulle
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.mobiliBlue : AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                bottomRight: isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
              border: isMe ? null : Border.all(color: AppColors.gray200),
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
              style: TextStyle(
                color: isMe ? AppColors.white : AppColors.mobiliBlueDeep,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),

          // Heure
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

  Color _roleColor(String role) {
    switch (role) {
      case 'GARE':
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
}
