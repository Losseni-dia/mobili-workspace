import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mobilipro/core/network/api_client.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_common_widgets.dart';
import 'admin_refunds_page.dart' show CancelBookingResult;

// ─────────────────────────────────────────────────────────────────────────────
// Modèles — mirroir des DTOs backend (ClaimResponse / BookingSummaryResponse)
// ─────────────────────────────────────────────────────────────────────────────

class AdminClaimBooking {
  const AdminClaimBooking({
    required this.bookingId,
    required this.reference,
    required this.route,
    required this.totalPrice,
    required this.status,
  });

  final int bookingId;
  final String reference;
  final String route;
  final double totalPrice;
  final String status;

  factory AdminClaimBooking.fromJson(Map<String, dynamic> j) => AdminClaimBooking(
        bookingId: (j['bookingId'] as num).toInt(),
        reference: j['reference'] as String? ?? '',
        route: j['route'] as String? ?? '',
        totalPrice: (j['totalPrice'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? '',
      );
}

class AdminClaim {
  const AdminClaim({
    required this.id,
    required this.reason,
    required this.status,
    required this.message,
    required this.details,
    required this.createdAt,
    this.booking,
    this.adminNote,
    this.resolvedAt,
  });

  final int id;
  final String reason;
  final String status;
  final AdminClaimBooking? booking;
  final String message;
  final Map<String, String> details;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  factory AdminClaim.fromJson(Map<String, dynamic> j) => AdminClaim(
        id: (j['id'] as num).toInt(),
        reason: j['reason'] as String? ?? '',
        status: j['status'] as String? ?? '',
        booking: j['booking'] != null
            ? AdminClaimBooking.fromJson(j['booking'] as Map<String, dynamic>)
            : null,
        message: j['message'] as String? ?? '',
        details: (j['details'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
        adminNote: j['adminNote'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        resolvedAt:
            j['resolvedAt'] != null ? DateTime.tryParse(j['resolvedAt'] as String) : null,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Config d'affichage — motifs et statuts (même liste que ClaimReason/
// ClaimStatus côté backend, aucune logique métier ici, juste du libellé)
// ─────────────────────────────────────────────────────────────────────────────

const _reasonLabels = {
  'REFUND_REQUEST': 'Demande de remboursement',
  'CANCELLATION': "Demande d'annulation",
  'DELAY': 'Retard important',
  'DRIVER_ISSUE': 'Problème avec le chauffeur',
  'LOST_ITEM': 'Objet perdu',
  'OTHER': 'Autre',
};

const _statusLabels = {
  'RECEIVED': 'Reçue',
  'IN_PROGRESS': 'En cours',
  'RESOLVED': 'Traitée',
  'REJECTED': 'Rejetée',
};

const _statusColors = {
  'RECEIVED': AppColors.warning,
  'IN_PROGRESS': AppColors.mobiliBlue,
  'RESOLVED': AppColors.stationGreen,
  'REJECTED': AppColors.danger,
};

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final claimsListProvider =
    FutureProvider.autoDispose.family<List<AdminClaim>, String?>((ref, status) async {
  final response = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/claims',
    queryParameters: status != null ? {'status': status} : null,
  );
  if (response.data == null) return [];
  return (response.data as List<dynamic>)
      .map((e) => AdminClaim.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminClaimsPage extends ConsumerStatefulWidget {
  const AdminClaimsPage({super.key});

  @override
  ConsumerState<AdminClaimsPage> createState() => _AdminClaimsPageState();
}

class _AdminClaimsPageState extends ConsumerState<AdminClaimsPage> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final claimsAsync = ref.watch(claimsListProvider(_statusFilter));

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Réclamations',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionTitle(title: 'Filtrer par statut'),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _StatusChip(
                  label: 'Toutes',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                for (final s in _statusLabels.keys) ...[
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: _statusLabels[s]!,
                    selected: _statusFilter == s,
                    color: _statusColors[s],
                    onTap: () => setState(() => _statusFilter = s),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          claimsAsync.when(
            loading: () => const AdminLoadingCard(),
            error: (e, _) => AdminErrorCard(message: '$e'),
            data: (claims) {
              if (claims.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Aucune réclamation trouvée',
                      style: TextStyle(color: AppColors.gray400),
                    ),
                  ),
                );
              }
              return Column(
                children: claims
                    .map((c) => _ClaimCard(
                          claim: c,
                          onTap: () => _openDetail(c),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openDetail(AdminClaim claim) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ClaimDetailSheet(
        claim: claim,
        onChanged: () => ref.invalidate(claimsListProvider(_statusFilter)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte liste
// ─────────────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : c,
          ),
        ),
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.onTap});
  final AdminClaim claim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[claim.status] ?? AppColors.gray500;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _reasonLabels[claim.reason] ?? claim.reason,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.mobiliBlueDeep,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusLabels[claim.status] ?? claim.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (claim.booking != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${claim.booking!.reference} — ${claim.booking!.route}',
                  style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                claim.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.gray600),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(claim.createdAt),
                style: const TextStyle(fontSize: 10, color: AppColors.gray400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Détail / traitement
// ─────────────────────────────────────────────────────────────────────────────

class _ClaimDetailSheet extends StatefulWidget {
  const _ClaimDetailSheet({required this.claim, required this.onChanged});
  final AdminClaim claim;
  final VoidCallback onChanged;

  @override
  State<_ClaimDetailSheet> createState() => _ClaimDetailSheetState();
}

class _ClaimDetailSheetState extends State<_ClaimDetailSheet> {
  late String _status;
  late final TextEditingController _noteCtrl;
  bool _saving = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _status = widget.claim.status;
    _noteCtrl = TextEditingController(text: widget.claim.adminNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.instance.dio.patch<void>(
        '/admin/claims/${widget.claim.id}/status',
        data: {
          'status': _status,
          if (_noteCtrl.text.trim().isNotEmpty) 'adminNote': _noteCtrl.text.trim(),
        },
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Raccourci vers l'endpoint existant POST /admin/bookings/{id}/cancel —
  // la réclamation ne déclenche jamais l'annulation automatiquement, c'est
  // toujours un geste manuel de l'admin après review (voir conception
  // validée). Aucune logique de paiement/annulation dupliquée ici.
  Future<void> _cancelAndRefund() async {
    final booking = widget.claim.booking;
    if (booking == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler cette réservation ?'),
        content: Text(
          '${booking.reference} — ${booking.route}\n'
          '${booking.totalPrice.toStringAsFixed(0)} FCFA\n\n'
          'Le remboursement Stripe (si applicable) sera déclenché automatiquement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final res = await ApiClient.instance.dio
          .post<Map<String, dynamic>>('/admin/bookings/${booking.bookingId}/cancel');
      final result = CancelBookingResult.fromJson(res.data!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.stationGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claim = widget.claim;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _reasonLabels[claim.reason] ?? claim.reason,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: AppColors.mobiliBlueDeep,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(claim.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.gray400),
            ),
            const SizedBox(height: 14),
            if (claim.booking != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mobiliBlueFog,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(claim.booking!.route,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      'Réf. ${claim.booking!.reference} · ${claim.booking!.totalPrice.toStringAsFixed(0)} FCFA · ${claim.booking!.status}',
                      style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Message',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.gray500)),
            const SizedBox(height: 4),
            Text(claim.message, style: const TextStyle(fontSize: 13, color: AppColors.gray700)),
            if (claim.details.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Détails',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.gray500)),
              const SizedBox(height: 4),
              ...claim.details.entries.map((e) => Text('${e.key} : ${e.value}',
                  style: const TextStyle(fontSize: 12, color: AppColors.gray600))),
            ],
            const SizedBox(height: 16),
            const Text('Statut',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.gray500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statusLabels.keys
                  .map((s) => _StatusChip(
                        label: _statusLabels[s]!,
                        selected: _status == s,
                        color: _statusColors[s],
                        onTap: () => setState(() => _status = s),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Note interne (optionnelle)',
                filled: true,
                fillColor: AppColors.gray50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            if (claim.booking != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelling ? null : _cancelAndRefund,
                    icon: _cancelling
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.assignment_return_rounded, size: 16),
                    label: const Text('Annuler la réservation & rembourser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mobiliBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
