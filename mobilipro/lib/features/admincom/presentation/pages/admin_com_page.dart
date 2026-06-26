import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class AdminComThread {
  const AdminComThread({
    required this.id,
    required this.subject,
    required this.type,
    required this.adminUserId,
    required this.adminUserName,
    required this.partnerUserId,
    required this.partnerUserName,
    this.companyName,
    required this.displayLabel,
    required this.lastActivityAtFormatted,
  });
  final int id;
  final String subject;
  final String type;
  final int adminUserId;
  final String adminUserName;
  final int partnerUserId;
  final String partnerUserName;
  final String? companyName;
  final String displayLabel;
  final String lastActivityAtFormatted;

  factory AdminComThread.fromJson(Map<String, dynamic> j) => AdminComThread(
    id: (j['id'] as num).toInt(),
    subject: j['subject'] as String? ?? '',
    type: j['type'] as String? ?? 'PARTNER',
    adminUserId: (j['adminUserId'] as num).toInt(),
    adminUserName: j['adminUserName'] as String? ?? '—',
    partnerUserId: (j['partnerUserId'] as num).toInt(),
    partnerUserName: j['partnerUserName'] as String? ?? '—',
    companyName: j['companyName'] as String?,
    displayLabel: j['displayLabel'] as String? ?? '—',
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

class _UserOption {
  const _UserOption({
    required this.id,
    required this.name,
    this.email,
    this.companyName,
    required this.type,
  });
  final int id;
  final String name;
  final String? email;
  final String? companyName;
  final String type;

  String get displayLabel {
    if (type == 'PARTNER' && companyName != null) return '$companyName — $name';
    return name;
  }

  factory _UserOption.fromJson(Map<String, dynamic> j) {
    final covoiturageSolo = j['covoiturageSoloProfile'] as bool? ?? false;
    final partnerName = j['partnerName'] as String?;
    final linkedCompanyName = j['linkedCompanyName'] as String?;
    String type;
    if (covoiturageSolo) {
      type = 'COVOITURAGE';
    } else if (partnerName != null || linkedCompanyName != null) {
      type = 'PARTNER';
    } else {
      type = 'SUPPORT';
    }
    final firstname = j['firstname'] as String? ?? '';
    final lastname = j['lastname'] as String? ?? '';
    final name = '$firstname $lastname'.trim();
    return _UserOption(
      id: (j['id'] as num).toInt(),
      name: name.isEmpty ? (j['login'] as String? ?? '—') : name,
      email: j['email'] as String?,
      companyName: partnerName ?? linkedCompanyName,
      type: type,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final adminComThreadsProvider =
    FutureProvider.autoDispose<List<AdminComThread>>((ref) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin-com/threads',
      );
      return (res.data ?? [])
          .map((e) => AdminComThread.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final adminComMessagesProvider = FutureProvider.autoDispose
    .family<List<AdminComMessage>, int>((ref, threadId) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin-com/threads/$threadId/messages',
      );
      return (res.data ?? [])
          .map((e) => AdminComMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final _adminUsersProvider = FutureProvider.autoDispose<List<_UserOption>>((
  ref,
) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/admin/users');
  return (res.data ?? [])
      .map((e) => _UserOption.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ═══════════════════════════════════════════════════════════════════════════
// HELPER UI
// ═══════════════════════════════════════════════════════════════════════════

(IconData, Color, String) _typeConfig(String type) => switch (type) {
  'COVOITURAGE' => (
    Icons.directions_car_rounded,
    AppColors.stationGreen,
    'Covoiturage',
  ),
  'SUPPORT' => (
    Icons.support_agent_rounded,
    AppColors.warning,
    'Support client',
  ),
  _ => (Icons.business_rounded, AppColors.mobiliBlue, 'Partenaire'),
};

// ═══════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ═══════════════════════════════════════════════════════════════════════════

class AdminComPage extends ConsumerStatefulWidget {
  const AdminComPage({super.key});

  @override
  ConsumerState<AdminComPage> createState() => _AdminComPageState();
}

class _AdminComPageState extends ConsumerState<AdminComPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = ['TOUS', 'PARTNER', 'COVOITURAGE', 'SUPPORT'];
  static const _tabLabels = ['Tous', 'Partenaires', 'Covoiturage', 'Support'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(adminComThreadsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Messages',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              'Admin ↔ Partenaires · Covoiturage · Support',
              style: TextStyle(fontSize: 10, color: Color(0xCCFFFFFF)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminComThreadsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.mobiliYellow,
          indicatorWeight: 3,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          isScrollable: true,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: threadsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(adminComThreadsProvider),
        ),
        data: (threads) => TabBarView(
          controller: _tabController,
          children: _tabs.map((filter) {
            final filtered = filter == 'TOUS'
                ? threads
                : threads.where((t) => t.type == filter).toList();
            if (filtered.isEmpty) {
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
                        Icons.forum_rounded,
                        color: AppColors.mobiliBlue,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Aucune conversation',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.mobiliBlueDeep,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Appuyez sur + pour démarrer',
                      style: TextStyle(color: AppColors.gray400, fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: AppColors.mobiliBlue,
              onRefresh: () async => ref.invalidate(adminComThreadsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ThreadCard(
                    thread: filtered[i],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminComThreadPage(thread: filtered[i]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau message'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _CreateThreadDialog(
            onCreated: () => ref.invalidate(adminComThreadsProvider),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARTE THREAD
// ═══════════════════════════════════════════════════════════════════════════

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.thread, required this.onTap});
  final AdminComThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, typeLabel) = _typeConfig(thread.type);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            thread.subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.mobiliBlueDeep,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      thread.displayLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.gray500,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
}

// ═══════════════════════════════════════════════════════════════════════════
// PAGE CONVERSATION
// ═══════════════════════════════════════════════════════════════════════════

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
      ref.invalidate(adminComMessagesProvider(widget.thread.id));
      ref.invalidate(adminComThreadsProvider);
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
    final messagesAsync = ref.watch(adminComMessagesProvider(widget.thread.id));
    final profile = ref.watch(currentProfileProvider);
    final myId = profile?.id;
    final (icon, color, typeLabel) = _typeConfig(widget.thread.type);

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
            Text(
              widget.thread.displayLabel,
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
                ref.invalidate(adminComMessagesProvider(widget.thread.id)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: color.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 7),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(color: AppColors.gray400)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.thread.displayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gray500,
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
              error: (e, _) => _ErrorView(
                message: '$e',
                onRetry: () =>
                    ref.invalidate(adminComMessagesProvider(widget.thread.id)),
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
                    adminComMessagesProvider(widget.thread.id),
                  ),
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

// ═══════════════════════════════════════════════════════════════════════════
// DIALOG CRÉATION
// ═══════════════════════════════════════════════════════════════════════════

class _CreateThreadDialog extends ConsumerStatefulWidget {
  const _CreateThreadDialog({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateThreadDialog> createState() =>
      _CreateThreadDialogState();
}

class _CreateThreadDialogState extends ConsumerState<_CreateThreadDialog> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  _UserOption? _selectedUser;
  String _search = '';
  String _typeFilter = 'TOUS';
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (subject.isEmpty || msg.isEmpty) {
      setState(() => _error = 'Sujet et message obligatoires');
      return;
    }
    if (_selectedUser == null) {
      setState(() => _error = 'Sélectionnez un destinataire');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ApiClient.instance.dio.post(
        '/admin-com/threads',
        data: {
          'subject': subject,
          'partnerUserId': _selectedUser!.id,
          'firstMessage': msg,
        },
      );
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Nouveau message',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.mobiliBlueDeep,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Destinataire',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedUser != null)
                _SelectedUserChip(
                  user: _selectedUser!,
                  onClear: () => setState(() => _selectedUser = null),
                )
              else
                usersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.mobiliBlue,
                    ),
                  ),
                  error: (e, _) => Text(
                    '$e',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                  data: (users) {
                    final byType = _typeFilter == 'TOUS'
                        ? users
                        : users.where((u) => u.type == _typeFilter).toList();
                    final filtered = _search.isEmpty
                        ? byType
                        : byType
                              .where(
                                (u) =>
                                    u.name.toLowerCase().contains(
                                      _search.toLowerCase(),
                                    ) ||
                                    (u.email ?? '').toLowerCase().contains(
                                      _search.toLowerCase(),
                                    ) ||
                                    (u.companyName ?? '')
                                        .toLowerCase()
                                        .contains(_search.toLowerCase()),
                              )
                              .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _TypeFilterChip(
                                label: 'Tous',
                                selected: _typeFilter == 'TOUS',
                                onTap: () =>
                                    setState(() => _typeFilter = 'TOUS'),
                              ),
                              const SizedBox(width: 6),
                              _TypeFilterChip(
                                label: 'Partenaires',
                                selected: _typeFilter == 'PARTNER',
                                onTap: () =>
                                    setState(() => _typeFilter = 'PARTNER'),
                                color: AppColors.mobiliBlue,
                              ),
                              const SizedBox(width: 6),
                              _TypeFilterChip(
                                label: 'Covoiturage',
                                selected: _typeFilter == 'COVOITURAGE',
                                onTap: () =>
                                    setState(() => _typeFilter = 'COVOITURAGE'),
                                color: AppColors.stationGreen,
                              ),
                              const SizedBox(width: 6),
                              _TypeFilterChip(
                                label: 'Support',
                                selected: _typeFilter == 'SUPPORT',
                                onTap: () =>
                                    setState(() => _typeFilter = 'SUPPORT'),
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _search = v),
                          decoration: const InputDecoration(
                            hintText: 'Rechercher...',
                            isDense: true,
                            prefixIcon: Icon(Icons.search_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Color(0xFFF8F9FA),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: filtered.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Aucun résultat',
                                      style: TextStyle(
                                        color: AppColors.gray400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (_, i) {
                                      final u = filtered[i];
                                      final (icon, color, _) = _typeConfig(
                                        u.type,
                                      );
                                      return ListTile(
                                        dense: true,
                                        leading: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Icon(
                                            icon,
                                            size: 16,
                                            color: color,
                                          ),
                                        ),
                                        title: Text(
                                          u.displayLabel,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.mobiliBlueDeep,
                                          ),
                                        ),
                                        subtitle: u.email != null
                                            ? Text(
                                                u.email!,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.gray400,
                                                ),
                                              )
                                            : null,
                                        onTap: () =>
                                            setState(() => _selectedUser = u),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Text(
                'Sujet',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _subjectCtrl,
                maxLength: 300,
                decoration: _inputDeco('Ex : Validation de votre dossier'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Message',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gray400,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _msgCtrl,
                maxLines: 4,
                maxLength: 4000,
                decoration: _inputDeco('Rédigez votre message...'),
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
              : const Text('Envoyer', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
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

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({required this.user, required this.onClear});
  final _UserOption user;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final (icon, color, typeLabel) = _typeConfig(user.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.gray400,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close_rounded, size: 16, color: color),
          ),
        ],
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mobiliBlue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.1) : AppColors.gray50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : AppColors.gray200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            color: selected ? c : AppColors.gray500,
          ),
        ),
      ),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  const _MsgBubble({required this.message, required this.isMe});
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
