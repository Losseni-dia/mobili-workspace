import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mobilipro/core/network/api_client.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/admin_common_widgets.dart';

enum AdminCouponType { percentage, fixedAmount }

extension on AdminCouponType {
  String get apiValue =>
      this == AdminCouponType.percentage ? 'PERCENTAGE' : 'FIXED_AMOUNT';
  String get label =>
      this == AdminCouponType.percentage ? 'Pourcentage' : 'Montant fixe';
}

class AdminCoupon {
  const AdminCoupon({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.active,
    this.expiresAt,
  });

  final int id;
  final String code;
  final String type; // 'PERCENTAGE' | 'FIXED_AMOUNT'
  final double value;
  final bool active;
  final DateTime? expiresAt;

  factory AdminCoupon.fromJson(Map<String, dynamic> j) => AdminCoupon(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String,
        type: j['type'] as String,
        value: (j['value'] as num).toDouble(),
        active: j['active'] as bool? ?? false,
        expiresAt: j['expiresAt'] != null
            ? DateTime.tryParse(j['expiresAt'] as String)
            : null,
      );

  String get valueLabel =>
      type == 'PERCENTAGE' ? '${value.toStringAsFixed(0)}%' : '${value.toStringAsFixed(0)} FCFA';
}

final adminCouponsProvider = FutureProvider.autoDispose<List<AdminCoupon>>((ref) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/admin/coupons');
  return (res.data ?? [])
      .map((e) => AdminCoupon.fromJson(e as Map<String, dynamic>))
      .toList();
});

class AdminCouponsPage extends ConsumerStatefulWidget {
  const AdminCouponsPage({super.key});

  @override
  ConsumerState<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends ConsumerState<AdminCouponsPage> {
  Future<void> _openCreateDialog() async {
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    AdminCouponType type = AdminCouponType.percentage;
    DateTime? expiresAt;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nouveau coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    hintText: 'PROMO2026',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminCouponType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: AdminCouponType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: type == AdminCouponType.percentage
                        ? 'Valeur (%)'
                        : 'Valeur (FCFA)',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expiresAt == null
                            ? 'Pas d\'expiration'
                            : 'Expire le ${DateFormat('dd/MM/yyyy').format(expiresAt!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.gray500),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setDialogState(() => expiresAt = picked);
                        }
                      },
                      child: const Text('Choisir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mobiliYellow,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Créer', style: TextStyle(color: AppColors.mobiliBlueDeep)),
            ),
          ],
        ),
      ),
    );

    if (created != true || !mounted) return;

    final code = codeCtrl.text.trim();
    final value = double.tryParse(valueCtrl.text.trim());
    if (code.isEmpty || value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code et valeur sont requis.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      await ApiClient.instance.dio.post<Map<String, dynamic>>('/admin/coupons', data: {
        'code': code,
        'type': type.apiValue,
        'value': value,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      });
      ref.invalidate(adminCouponsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coupon créé.'),
            backgroundColor: AppColors.stationGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _deactivate(AdminCoupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Désactiver ce coupon ?'),
        content: Text('${coupon.code} (${coupon.valueLabel}) ne sera plus utilisable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Désactiver', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.instance.dio
          .patch<Map<String, dynamic>>('/admin/coupons/${coupon.id}/deactivate');
      ref.invalidate(adminCouponsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(adminCouponsProvider);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: const Text(
          'Coupons',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.mobiliYellow,
        onPressed: _openCreateDialog,
        child: const Icon(Icons.add_rounded, color: AppColors.mobiliBlueDeep),
      ),
      body: RefreshIndicator(
        color: AppColors.mobiliBlue,
        onRefresh: () async => ref.invalidate(adminCouponsProvider),
        child: couponsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.mobiliBlue),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AdminErrorCard(message: '$e'),
            ),
          ),
          data: (coupons) {
            if (coupons.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Aucun coupon. Appuyez sur + pour en créer un.',
                        style: TextStyle(color: AppColors.gray400),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: coupons.map((c) => _CouponCard(
                    coupon: c,
                    onDeactivate: c.active ? () => _deactivate(c) : null,
                  )).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, this.onDeactivate});

  final AdminCoupon coupon;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final color = coupon.active ? AppColors.stationGreen : AppColors.gray400;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_offer_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.mobiliBlueDeep,
                  ),
                ),
                Text(
                  coupon.valueLabel +
                      (coupon.expiresAt != null
                          ? ' — expire le ${DateFormat('dd/MM/yyyy').format(coupon.expiresAt!)}'
                          : ' — sans expiration'),
                  style: const TextStyle(fontSize: 11, color: AppColors.gray500),
                ),
                Text(
                  coupon.active ? 'Actif' : 'Désactivé',
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (onDeactivate != null)
            TextButton(
              onPressed: onDeactivate,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Désactiver', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
