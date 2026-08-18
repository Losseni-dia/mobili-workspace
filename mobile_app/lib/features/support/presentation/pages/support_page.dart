import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobili/shared/widgets/mobili_app_bar.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class _SupportThread {
  const _SupportThread({
    required this.id,
    required this.subject,
    required this.lastActivityAtFormatted,
  });
  final int id;
  final String subject;
  final String lastActivityAtFormatted;

  factory _SupportThread.fromJson(Map<String, dynamic> j) => _SupportThread(
        id: (j['id'] as num).toInt(),
        subject: j['subject'] as String? ?? '',
        lastActivityAtFormatted: j['lastActivityAtFormatted'] as String? ?? '',
      );
}

class _SupportMessage {
  const _SupportMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAtFormatted,
  });
  final int id;
  final int authorId;
  final String authorName;
  final String body;
  final String createdAtFormatted;

  factory _SupportMessage.fromJson(Map<String, dynamic> j) => _SupportMessage(
        id: (j['id'] as num).toInt(),
        authorId: (j['authorId'] as num).toInt(),
        authorName: j['authorName'] as String? ?? '—',
        body: j['body'] as String? ?? '',
        createdAtFormatted: j['createdAtFormatted'] as String? ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final _supportThreadsProvider =
    FutureProvider.autoDispose<List<_SupportThread>>((ref) async {
  final res =
      await ApiClient.instance.dio.get<List<dynamic>>('/admin-com/threads');
  return (res.data ?? [])
      .map((e) => _SupportThread.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _supportMessagesProvider = FutureProvider.autoDispose
    .family<List<_SupportMessage>, int>((ref, threadId) async {
  final res = await ApiClient.instance.dio
      .get<List<dynamic>>('/admin-com/threads/$threadId/messages');
  return (res.data ?? [])
      .map((e) => _SupportMessage.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE SUPPORT
// ═══════════════════════════════════════════════════════════════════════════

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(_supportThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: 'Support Mobili',
        subtitle: 'Nous sommes là pour vous aider',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.mobiliBlueDeep),
            onPressed: () => ref.invalidate(_supportThreadsProvider),
          ),
        ],
      ),
      body: threadsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mobiliBlue)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text('$e',
                style: const TextStyle(color: AppColors.gray500),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(_supportThreadsProvider),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobiliBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Réessayer',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                          color: AppColors.mobiliBlueFog,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.support_agent_rounded,
                          color: AppColors.mobiliBlue, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('Besoin d\'aide ?',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.mobiliBlueDeep,
                            fontSize: 18)),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Notre équipe est disponible pour répondre à vos questions.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.gray400, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _NewSupportThreadDialog(
                          onCreated: () =>
                              ref.invalidate(_supportThreadsProvider),
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Démarrer une conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mobiliBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ]),
            );
          }
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.mobiliBlue.withValues(alpha: 0.07),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: const Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.mobiliBlue),
                    SizedBox(width: 8),
                    Text('Temps de réponse habituel : moins de 24h',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mobiliBlue,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async =>
                      ref.invalidate(_supportThreadsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: threads.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SupportThreadCard(
                        thread: threads[i],
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  _SupportConversationPage(thread: threads[i]),
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: threadsAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.mobiliBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouvelle demande'),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _NewSupportThreadDialog(
                  onCreated: () => ref.invalidate(_supportThreadsProvider),
                ),
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE THREAD SUPPORT
// ═══════════════════════════════════════════════════════════════════════════

class _SupportThreadCard extends StatelessWidget {
  const _SupportThreadCard({required this.thread, required this.onTap});
  final _SupportThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gray200),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.mobiliBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.mobiliBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thread.subject,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mobiliBlueDeep,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      const Text('Support Mobili',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.gray500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(thread.lastActivityAtFormatted,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.gray400)),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.gray300, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE CONVERSATION SUPPORT
// ═══════════════════════════════════════════════════════════════════════════

class _SupportConversationPage extends ConsumerStatefulWidget {
  const _SupportConversationPage({required this.thread});
  final _SupportThread thread;

  @override
  ConsumerState<_SupportConversationPage> createState() =>
      _SupportConversationPageState();
}

class _SupportConversationPageState
    extends ConsumerState<_SupportConversationPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    try {
      await ApiClient.instance.dio.post(
        '/admin-com/threads/${widget.thread.id}/messages',
        data: {'body': text},
      );
      ref.invalidate(_supportMessagesProvider(widget.thread.id));
      ref.invalidate(_supportThreadsProvider);
      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Message envoyé'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating));
        _msgCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_supportMessagesProvider(widget.thread.id));
    final profile = ref.watch(currentProfileProvider);
    final myId = profile?.id;

    return Scaffold(
      backgroundColor: AppColors.mobiliYellowPale,
      appBar: MobiliAppBar(
        title: widget.thread.subject,
        subtitle: 'Support Mobili',
        showBackButton: true,
        titleFontSize: 15,
        showPattern: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.mobiliBlueDeep),
            onPressed: () =>
                ref.invalidate(_supportMessagesProvider(widget.thread.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.warning.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: const Row(
              children: [
                Icon(Icons.support_agent_rounded,
                    size: 13, color: AppColors.warning),
                SizedBox(width: 7),
                Text('Support client · Mobili',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.mobiliBlue)),
              error: (e, _) => Center(
                  child: Text('$e',
                      style: const TextStyle(color: AppColors.danger))),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 48, color: AppColors.gray300),
                          SizedBox(height: 12),
                          Text('Aucun message',
                              style: TextStyle(
                                  color: AppColors.gray400,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  );
                }
                _scrollToBottom();
                return RefreshIndicator(
                  color: AppColors.mobiliBlue,
                  onRefresh: () async => ref
                      .invalidate(_supportMessagesProvider(widget.thread.id)),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      final isMe = m.authorId == myId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(m.authorName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.gray400,
                                        fontWeight: FontWeight.w500))),
                            Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? AppColors.mobiliBlue
                                    : AppColors.white,
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
                                border: isMe
                                    ? null
                                    : Border.all(color: AppColors.gray200),
                              ),
                              child: Text(m.body,
                                  style: TextStyle(
                                      color: isMe
                                          ? AppColors.white
                                          : AppColors.mobiliBlueDeep,
                                      fontSize: 14,
                                      height: 1.4)),
                            ),
                            Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(m.createdAtFormatted,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.gray400))),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.gray200))),
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.gray200)),
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Votre message...',
                        hintStyle:
                            TextStyle(color: AppColors.gray400, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isSending ? null : _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: _isSending
                            ? AppColors.gray300
                            : AppColors.mobiliBlue,
                        shape: BoxShape.circle),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                                color: AppColors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded,
                            color: AppColors.white, size: 20),
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

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG NOUVELLE DEMANDE SUPPORT
// ═══════════════════════════════════════════════════════════════════════════

class _NewSupportThreadDialog extends ConsumerStatefulWidget {
  const _NewSupportThreadDialog({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_NewSupportThreadDialog> createState() =>
      _NewSupportThreadDialogState();
}

class _NewSupportThreadDialogState
    extends ConsumerState<_NewSupportThreadDialog> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  static const _subjects = [
    'Problème de réservation',
    'Remboursement',
    'Problème de paiement',
    'Trajet annulé',
    'Billet non reçu',
    'Autre',
  ];
  String? _selectedSubject;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _selectedSubject == 'Autre'
        ? _subjectCtrl.text.trim()
        : _selectedSubject;
    final msg = _msgCtrl.text.trim();
    if (subject == null || subject.isEmpty) {
      setState(() => _error = 'Choisissez un sujet');
      return;
    }
    if (msg.isEmpty) {
      setState(() => _error = 'Décrivez votre problème');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = ref.read(currentProfileProvider);
      if (profile == null) throw Exception('Non connecté');
      await ApiClient.instance.dio.post('/admin-com/threads', data: {
        'subject': subject,
        'partnerUserId': profile.id,
        'firstMessage': msg,
      });
      widget.onCreated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.support_agent_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Votre demande a été envoyée au support Mobili.'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded,
                color: AppColors.mobiliBlue, size: 22),
            SizedBox(width: 8),
            Text('Contacter le support',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.mobiliBlueDeep,
                    fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sujet',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray400,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subjects.map((s) {
                    final selected = _selectedSubject == s;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSubject = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.mobiliBlue.withValues(alpha: 0.1)
                              : AppColors.gray50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppColors.mobiliBlue
                                  : AppColors.gray200,
                              width: selected ? 1.5 : 1),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: selected
                                    ? AppColors.mobiliBlue
                                    : AppColors.gray500)),
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedSubject == 'Autre') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectCtrl,
                    maxLength: 300,
                    decoration: _inputDeco('Précisez votre sujet...'),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Description',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray400,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration:
                      _inputDeco('Décrivez votre problème en détail...'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12))),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.gray300, fontSize: 13),
        filled: true,
        fillColor: AppColors.gray50,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.gray200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.gray200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColors.mobiliBlue, width: 2)),
      );
}
