import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/features/partnergarecom/data/partner_gare_com_service.dart';
import 'package:mobilipro/features/partnergarecom/domain/models/partner_gare_com_models.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';

class _StationOption {
  const _StationOption({
    required this.id,
    required this.name,
    required this.city,
    this.code,
  });
  final int id;
  final String name;
  final String city;
  final String? code;

  factory _StationOption.fromJson(Map<String, dynamic> json) => _StationOption(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    code: json['code'] as String?,
  );
}

final _comServiceProvider = Provider.autoDispose<PartnerGareComService>(
  (_) => PartnerGareComService(),
);

final _threadsProvider = FutureProvider.autoDispose<List<ComThread>>((
  ref,
) async {
  return ref.read(_comServiceProvider).getThreads();
});

final _messagesProvider = FutureProvider.autoDispose
    .family<List<ComMessage>, int>((ref, threadId) async {
      return ref.read(_comServiceProvider).getMessages(threadId);
    });

final _stationsProvider = FutureProvider.autoDispose<List<_StationOption>>((
  ref,
) async {
  final dio = ApiClient.instance.dio;
  final res = await dio.get<List<dynamic>>('/partenaire/stations');
  return (res.data ?? [])
      .map((e) => _StationOption.fromJson(e as Map<String, dynamic>))
      .toList();
});

// Modèles & providers — Messages Mobili (admin ↔ partenaire)
class AdminComThread {
  const AdminComThread({
    required this.id,
    required this.subject,
    required this.adminUserName,
    required this.partnerUserId,
    required this.lastActivityAtFormatted,
  });
  final int id;
  final String subject;
  final String adminUserName;
  final int partnerUserId;
  final String lastActivityAtFormatted;

  factory AdminComThread.fromJson(Map<String, dynamic> j) => AdminComThread(
    id: (j['id'] as num).toInt(),
    subject: j['subject'] as String? ?? '',
    adminUserName: j['adminUserName'] as String? ?? '—',
    partnerUserId: (j['partnerUserId'] as num).toInt(),
    lastActivityAtFormatted: j['lastActivityAtFormatted'] as String? ?? '',
  );
}

class AdminComMessage {
  const AdminComMessage({
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

  factory AdminComMessage.fromJson(Map<String, dynamic> j) => AdminComMessage(
    id: (j['id'] as num).toInt(),
    authorId: (j['authorId'] as num).toInt(),
    authorName: j['authorName'] as String? ?? '—',
    body: j['body'] as String? ?? '',
    createdAtFormatted: j['createdAtFormatted'] as String? ?? '',
  );
}

final _adminComThreadsProvider =
    FutureProvider.autoDispose<List<AdminComThread>>((ref) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin-com/threads',
      );
      return (res.data ?? [])
          .map((e) => AdminComThread.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final _adminComMessagesProvider = FutureProvider.autoDispose
    .family<List<AdminComMessage>, int>((ref, threadId) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin-com/threads/$threadId/messages',
      );
      return (res.data ?? [])
          .map((e) => AdminComMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    });

// ─────────────────────────────────────────────────────────────────────────────
// Page principale — 2 onglets
// ─────────────────────────────────────────────────────────────────────────────

class PartnerGareComPage extends ConsumerStatefulWidget {
  const PartnerGareComPage({super.key});

  @override
  ConsumerState<PartnerGareComPage> createState() => _PartnerGareComPageState();
}
class _PartnerGareComPageState extends ConsumerState<PartnerGareComPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool? _stationOnly;

  void _ensureController(bool stationOnly) {
    if (_stationOnly == stationOnly) return;
    _stationOnly = stationOnly;
    _tabController?.dispose();
    _tabController = TabController(length: stationOnly ? 1 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final stationOnly = profile != null && profile.roles.contains('STATION');
    _ensureController(stationOnly);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Communications',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        bottom: stationOnly
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.mobiliYellow,
                indicatorWeight: 3,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.business_rounded, size: 18),
                    text: 'Canal société',
                  ),
                  Tab(
                    icon: Icon(Icons.admin_panel_settings_rounded, size: 18),
                    text: 'Canal support',
                  ),
                ],
              ),
      ),
      body: stationOnly
          ? const _CanalSocieteTab()
          : TabBarView(
              controller: _tabController,
              children: const [_CanalSocieteTab(), _MessagesMobiliTab()],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet 1 — Canal société
// ─────────────────────────────────────────────────────────────────────────────

class _CanalSocieteTab extends ConsumerWidget {
  const _CanalSocieteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(_threadsProvider);
    final profile = ref.watch(currentProfileProvider);
    final canCreateThread =
        profile != null &&
        (profile.isPartner ||
            profile.isGare ||
            profile.roles.contains('STATION'));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_threadsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) return _EmptyThreads(canCreate: canCreateThread);
          return RefreshIndicator(
            color: AppColors.mobiliBlue,
            onRefresh: () async => ref.invalidate(_threadsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: threads.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ThreadCard(
                  thread: threads[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ThreadPage(thread: threads[i]),
                    ),
                  ),
                  onLongPress: () => _showDeleteMenu(context, ref, threads[i]),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: canCreateThread
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.mobiliBlue,
              foregroundColor: AppColors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nouveau fil'),
              onPressed: () => _showCreateDialog(context, ref, profile),
            )
          : null,
    );
  }

  void _showDeleteMenu(BuildContext context, WidgetRef ref, ComThread thread) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.gray500,
              ),
              title: const Text('Supprimer pour moi'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                try {
                  await PartnerGareComService().deleteThread(
                    thread.id,
                    forEveryone: false,
                  );
                  ref.invalidate(_threadsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Supprimer pour tout le monde',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Confirmer la suppression'),
                    content: const Text(
                      'Ce fil sera supprimé pour tous les participants. Cette action est irréversible.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text(
                          'Supprimer',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await PartnerGareComService().deleteThread(
                    thread.id,
                    forEveryone: true,
                  );
                  ref.invalidate(_threadsProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                  }
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic profile,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CreateThreadDialog(
        isGareOnly:
            (profile.isGare || profile.roles.contains('STATION')) &&
            !profile.isPartner,
        onCreated: () => ref.invalidate(_threadsProvider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onglet 2 — Messages Mobili
// ─────────────────────────────────────────────────────────────────────────────

class _MessagesMobiliTab extends ConsumerWidget {
  const _MessagesMobiliTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(_adminComThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_adminComThreadsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) {
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
                      Icons.mark_email_unread_rounded,
                      color: AppColors.mobiliBlue,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Aucun message de Mobili',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlueDeep,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Les messages de l\'équipe Mobili apparaîtront ici',
                    style: TextStyle(color: AppColors.gray400, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.mobiliBlue,
            onRefresh: () async => ref.invalidate(_adminComThreadsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: threads.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AdminComThreadCard(
                  thread: threads[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminComThreadPage(thread: threads[i]),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card thread canal société
// ─────────────────────────────────────────────────────────────────────────────

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({
    required this.thread,
    required this.onTap,
    this.onLongPress,
  });
  final ComThread thread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final isAll = thread.scope == ThreadScope.all;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
                  color: isAll
                      ? AppColors.mobiliBlue.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAll
                      ? Icons.broadcast_on_home_rounded
                      : Icons.location_on_rounded,
                  color: isAll ? AppColors.mobiliBlue : AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.mobiliBlueDeep,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _ScopeBadge(scope: thread.scope),
                        if (!isAll && thread.stationLabels.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              thread.stationLabels.join(' · '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.gray400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    thread.formattedDate,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.gray400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray300,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card thread Messages Mobili
// ─────────────────────────────────────────────────────────────────────────────

class _AdminComThreadCard extends StatelessWidget {
  const _AdminComThreadCard({required this.thread, required this.onTap});
  final AdminComThread thread;
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
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.mobiliBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.subject,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.mobiliBlueDeep,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Équipe Mobili',
                    style: TextStyle(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  thread.lastActivityAtFormatted,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.gray400,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.gray300,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page thread canal société
// ─────────────────────────────────────────────────────────────────────────────

class ThreadPage extends ConsumerStatefulWidget {
  const ThreadPage({super.key, required this.thread});
  final ComThread thread;

  @override
  ConsumerState<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends ConsumerState<ThreadPage> {
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
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _msgCtrl.clear();
    try {
      await ref.read(_comServiceProvider).postMessage(widget.thread.id, text);
      ref.invalidate(_messagesProvider(widget.thread.id));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _msgCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(_messagesProvider(widget.thread.id));
    final profile = ref.watch(currentProfileProvider);
    final myId = profile?.id;
    final isAll = widget.thread.scope == ThreadScope.all;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isAll
                  ? 'Toutes les gares'
                  : widget.thread.stationLabels.join(' · '),
              style: const TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_messagesProvider(widget.thread.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: isAll
                ? AppColors.mobiliBlue.withValues(alpha: 0.08)
                : AppColors.warning.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Icon(
                  isAll
                      ? Icons.broadcast_on_home_rounded
                      : Icons.location_on_rounded,
                  size: 13,
                  color: isAll ? AppColors.mobiliBlue : AppColors.warning,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isAll
                        ? 'Visible par toutes les gares de la compagnie'
                        : 'Ciblé : ${widget.thread.stationLabels.join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAll ? AppColors.mobiliBlue : AppColors.warning,
                    ),
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
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(_messagesProvider(widget.thread.id)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Commencez la conversation',
                          style: TextStyle(
                            color: AppColors.gray300,
                            fontSize: 12,
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
                      ref.invalidate(_messagesProvider(widget.thread.id)),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MsgBubble(
                      message: messages[i],
                      isMe: messages[i].authorId == myId,
                    ),
                  ),
                );
              },
            ),
          ),
          _MessageInputBar(
            ctrl: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page thread Messages Mobili
// ─────────────────────────────────────────────────────────────────────────────

class AdminComThreadPage extends ConsumerStatefulWidget {
  const AdminComThreadPage({super.key, required this.thread});
  final AdminComThread thread;

  @override
  ConsumerState<AdminComThreadPage> createState() => _AdminComThreadPageState();
}

class _AdminComThreadPageState extends ConsumerState<AdminComThreadPage> {
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
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
      ref.invalidate(_adminComMessagesProvider(widget.thread.id));
      ref.invalidate(_adminComThreadsProvider);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _msgCtrl.text = text;
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      _adminComMessagesProvider(widget.thread.id),
    );
    final profile = ref.watch(currentProfileProvider);
    final myId = profile?.id;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.subject,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              'Équipe Mobili',
              style: TextStyle(fontSize: 11, color: Color(0xCCFFFFFF)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () =>
                ref.invalidate(_adminComMessagesProvider(widget.thread.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.mobiliBlue.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: const Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 13,
                  color: AppColors.mobiliBlue,
                ),
                SizedBox(width: 7),
                Text(
                  'Conversation avec l\'équipe Mobili',
                  style: TextStyle(fontSize: 11, color: AppColors.mobiliBlue),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mobiliBlue),
              ),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(_adminComMessagesProvider(widget.thread.id)),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: AppColors.gray300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w600,
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
                    _adminComMessagesProvider(widget.thread.id),
                  ),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return _AdminMsgBubble(
                        message: m,
                        isMe: m.authorId == myId,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _MessageInputBar(
            ctrl: _msgCtrl,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulles messages
// ─────────────────────────────────────────────────────────────────────────────

class _MsgBubble extends StatelessWidget {
  const _MsgBubble({required this.message, required this.isMe});
  final ComMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            message.authorName,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.gray400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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

class _AdminMsgBubble extends StatelessWidget {
  const _AdminMsgBubble({required this.message, required this.isMe});
  final AdminComMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            message.authorName,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.gray400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
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
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            message.createdAtFormatted,
            style: const TextStyle(fontSize: 10, color: AppColors.gray400),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Barre saisie message (partagée)
// ─────────────────────────────────────────────────────────────────────────────

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.ctrl,
    required this.isSending,
    required this.onSend,
  });
  final TextEditingController ctrl;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.gray200)),
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
              controller: ctrl,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Votre message...',
                hintStyle: TextStyle(color: AppColors.gray400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: isSending ? null : onSend,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSending ? AppColors.gray300 : AppColors.mobiliBlue,
              shape: BoxShape.circle,
            ),
            child: isSending
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
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog création thread canal société
// ─────────────────────────────────────────────────────────────────────────────

class _CreateThreadDialog extends ConsumerStatefulWidget {
  const _CreateThreadDialog({
    required this.isGareOnly,
    required this.onCreated,
  });
  final bool isGareOnly;
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateThreadDialog> createState() =>
      _CreateThreadDialogState();
}

class _CreateThreadDialogState extends ConsumerState<_CreateThreadDialog> {
  final _titleCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  ThreadScope _scope = ThreadScope.all;
  final Set<int> _selectedStationIds = {};
  bool _showStationPicker = true;
  bool _isLoading = false;
  String? _error;
 bool _gareTargetsPartner = true;
  int? _otherStationId;
  bool _showOtherStationPicker = true;
  @override
  void initState() {
    super.initState();
    if (widget.isGareOnly) _scope = ThreadScope.targeted;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (title.isEmpty || msg.isEmpty) {
      setState(() => _error = 'Titre et message obligatoires');
      return;
    }
    if (_scope == ThreadScope.targeted &&
        !widget.isGareOnly &&
        _selectedStationIds.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins une gare');
      return;
    }
    if (widget.isGareOnly && !_gareTargetsPartner && _otherStationId == null) {
      setState(() => _error = 'Sélectionnez la gare destinataire');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(_comServiceProvider)
          .createThread(
            CreateThreadRequest(
              scope: _scope,
              title: title,
              firstMessage: msg,
              stationIds: widget.isGareOnly
                  ? (_gareTargetsPartner ? null : [_otherStationId!])
                  : (_scope == ThreadScope.targeted
                        ? _selectedStationIds.toList()
                        : null),
            ),
          );
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(_stationsProvider);
    final showStationList =
        _scope == ThreadScope.targeted && !widget.isGareOnly;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Nouveau fil de discussion',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.mobiliBlueDeep,
          fontSize: 16,
        ),
      ),
     content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isGareOnly) ...[
              const Text(
                'Destinataire',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ScopeChip(
                    label: 'Vers le partenaire',
                    icon: Icons.business_rounded,
                    selected: _gareTargetsPartner,
                    onTap: () => setState(() {
                      _gareTargetsPartner = true;
                      _otherStationId = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Vers une autre gare',
                    icon: Icons.location_on_rounded,
                    selected: !_gareTargetsPartner,
                    onTap: () => setState(() => _gareTargetsPartner = false),
                  ),
                ],
              ),
          if (!_gareTargetsPartner) ...[
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final stationsAsync = ref.watch(_stationsProvider);
                    final myProfile = ref.watch(currentProfileProvider);
                    return stationsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.mobiliBlue,
                        ),
                      ),
                      error: (e, _) => const Text(
                        'Erreur chargement gares',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                      data: (stations) {
                        final others = stations
                            .where((s) => s.code != myProfile?.login)
                            .toList();

                        if (!_showOtherStationPicker &&
                            _otherStationId != null) {
                          final selected = others.firstWhere(
                            (s) => s.id == _otherStationId,
                            orElse: () => others.first,
                          );
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  selected.name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                backgroundColor: AppColors.mobiliBlueFog,
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setState(() {
                                  _otherStationId = null;
                                  _showOtherStationPicker = true;
                                }),
                              ),
                            ],
                          );
                        }

                        return SizedBox(
                          height: 140,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.gray200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ListView.builder(
                                physics: const ClampingScrollPhysics(),
                                itemCount: others.length,
                                itemBuilder: (_, i) {
                                  final station = others[i];
                                  return RadioListTile<int>(
                                    dense: true,
                                    value: station.id,
                                    groupValue: _otherStationId,
                                    onChanged: (v) => setState(() {
                                      _otherStationId = v;
                                      _showOtherStationPicker = false;
                                    }),
                                    title: Text(
                                      station.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.mobiliBlueDeep,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      station.city,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.gray400,
                                      ),
                                    ),
                                    activeColor: AppColors.mobiliBlue,
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (!widget.isGareOnly) ...[
              const Text(
                'Destinataires',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _ScopeSelector(
                value: _scope,
                onChanged: (s) => setState(() {
                  _scope = s;
                  _selectedStationIds.clear();
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (showStationList) ...[
              const Text(
                'Gares ciblées',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (!_showStationPicker && _selectedStationIds.isNotEmpty) ...[
                stationsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (stations) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in _selectedStationIds)
                        Builder(
                          builder: (_) {
                            final station = stations.firstWhere(
                              (s) => s.id == id,
                              orElse: () => stations.first,
                            );
                            return Chip(
                              label: Text(
                                station.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: AppColors.mobiliBlueFog,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => setState(() {
                                _selectedStationIds.remove(id);
                                if (_selectedStationIds.isEmpty) {
                                  _showStationPicker = true;
                                }
                              }),
                            );
                          },
                        ),
                      ActionChip(
                        label: const Text(
                          '+ Ajouter une gare',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: () =>
                            setState(() => _showStationPicker = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                SizedBox(
                  height: 160,
                  child: stationsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.mobiliBlue,
                      ),
                    ),
                    error: (e, _) => const Center(
                      child: Text(
                        'Erreur chargement gares',
                        style: TextStyle(color: AppColors.danger, fontSize: 12),
                      ),
                    ),
                    data: (stations) => stations.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune gare disponible',
                              style: TextStyle(
                                color: AppColors.gray400,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.gray200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ListView.builder(
                                physics: const ClampingScrollPhysics(),
                                itemCount: stations.length,
                                itemBuilder: (_, i) {
                                  final station = stations[i];
                                  final selected = _selectedStationIds.contains(
                                    station.id,
                                  );
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected,
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selectedStationIds.add(station.id);
                                        _showStationPicker = false;
                                      } else {
                                        _selectedStationIds.remove(station.id);
                                      }
                                    }),
                                    title: Text(
                                      station.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.mobiliBlueDeep,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      station.city,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.gray400,
                                      ),
                                    ),
                                    activeColor: AppColors.mobiliBlue,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Titre',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 200,
                      decoration: _inputDecoration(
                        'Ex : Nouvelles consignes bagages',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Premier message',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.gray400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: _inputDecoration('Rédigez votre message...'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.mobiliBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Créer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.gray300, fontSize: 13),
    filled: true,
    fillColor: AppColors.gray50,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.gray200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.gray200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.mobiliBlue, width: 2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets utilitaires
// ─────────────────────────────────────────────────────────────────────────────

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({required this.value, required this.onChanged});
  final ThreadScope value;
  final ValueChanged<ThreadScope> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ScopeChip(
        label: 'Toutes les gares',
        icon: Icons.broadcast_on_home_rounded,
        selected: value == ThreadScope.all,
        onTap: () => onChanged(ThreadScope.all),
      ),
      const SizedBox(width: 8),
      _ScopeChip(
        label: 'Gares ciblées',
        icon: Icons.location_on_rounded,
        selected: value == ThreadScope.targeted,
        onTap: () => onChanged(ThreadScope.targeted),
      ),
    ],
  );
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.mobiliBlue.withValues(alpha: 0.1)
            : AppColors.gray50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.mobiliBlue : AppColors.gray200,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: selected ? AppColors.mobiliBlue : AppColors.gray400,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.mobiliBlue : AppColors.gray500,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.scope});
  final ThreadScope scope;

  @override
  Widget build(BuildContext context) {
    final isAll = scope == ThreadScope.all;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isAll
            ? AppColors.mobiliBlue.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAll ? Icons.broadcast_on_home_rounded : Icons.location_on_rounded,
            size: 10,
            color: isAll ? AppColors.mobiliBlue : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            isAll ? 'Toutes les gares' : 'Ciblé',
            style: TextStyle(
              fontSize: 10,
              color: isAll ? AppColors.mobiliBlue : AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyThreads extends StatelessWidget {
  const _EmptyThreads({required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) => Center(
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
            Icons.forum_rounded,
            color: AppColors.mobiliBlue,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Aucun fil de discussion',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.mobiliBlueDeep,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          canCreate
              ? 'Appuyez sur + pour créer un fil'
              : 'Aucune conversation pour le moment',
          style: const TextStyle(color: AppColors.gray400, fontSize: 13),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
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
            message,
            style: const TextStyle(color: AppColors.gray500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.mobiliBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Réessayer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
