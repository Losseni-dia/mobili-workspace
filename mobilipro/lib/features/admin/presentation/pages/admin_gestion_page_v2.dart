import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobilipro/core/services/analytics_service.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLES
// ═══════════════════════════════════════════════════════════════════════════

class AdminPartner {
  const AdminPartner({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.businessNumber,
    required this.enabled,
    this.ownerName,
    this.logoUrl,
    this.kycFrontUrl,
    this.kycBackUrl,
    this.rejectionReason,
    required this.covoiturageSoloPool,
    required this.approvalStatus,
    this.createdAt,
  });
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? businessNumber;
  final bool enabled;
  final String? ownerName;
  final String? logoUrl;
  final String? kycFrontUrl;
  final String? kycBackUrl;
  final String? rejectionReason;
  final bool covoiturageSoloPool;
  final String approvalStatus;
  final DateTime? createdAt;

  bool get isPending => approvalStatus == 'PENDING';
  bool get isApproved => approvalStatus == 'APPROVED';
  bool get isRejected => approvalStatus == 'REJECTED';

  factory AdminPartner.fromJson(Map<String, dynamic> json) => AdminPartner(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    businessNumber: json['businessNumber'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    ownerName: json['ownerName'] as String?,
    logoUrl: json['logoUrl'] as String?,
    kycFrontUrl: json['kycFrontUrl'] as String?,
    kycBackUrl: json['kycBackUrl'] as String?,
    rejectionReason: json['rejectionReason'] as String?,
    covoiturageSoloPool: json['covoiturageSoloPool'] as bool? ?? false,
    approvalStatus: json['approvalStatus'] as String? ?? 'APPROVED',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    required this.roles,
    required this.enabled,
    this.partnerName,
    this.covoiturageSoloProfile,
    this.linkedCompanyName,
    this.stationName,
    this.employerPartnerId,
    this.createdAt,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final List<String> roles;
  final bool enabled;
  final String? partnerName;
  final bool? covoiturageSoloProfile;
  final String? linkedCompanyName;
  final String? stationName;
  final int? employerPartnerId;
  final DateTime? createdAt;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
    email: json['email'] as String?,
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    enabled: json['enabled'] as bool? ?? false,
    partnerName: json['partnerName'] as String?,
    covoiturageSoloProfile: json['covoiturageSoloProfile'] as bool?,
    linkedCompanyName: json['linkedCompanyName'] as String?,
    stationName: json['stationName'] as String?,
    employerPartnerId: json['employerPartnerId'] as int?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}
class CovoiturageSoloDriver {
  const CovoiturageSoloDriver({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    this.kycStatus,
    required this.enabled,
    this.driverPhotoUrl,
    this.createdAt,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? email;
  final String? kycStatus;
  final bool enabled;
  final String? driverPhotoUrl;
  final DateTime? createdAt;

  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';

  factory CovoiturageSoloDriver.fromJson(Map<String, dynamic> json) =>
      CovoiturageSoloDriver(
        id: json['id'] as int,
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        email: json['email'] as String?,
        kycStatus: json['covoiturageKycStatus'] as String?,
        enabled: json['enabled'] as bool? ?? false,
        driverPhotoUrl: json['covoiturageDriverPhotoUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );
}

class PartnerDetail {
  const PartnerDetail({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.logoUrl,
    this.businessNumber,
    required this.enabled,
    this.registrationCode,
  });
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? logoUrl;
  final String? businessNumber;
  final bool enabled;
  final String? registrationCode;

  factory PartnerDetail.fromJson(Map<String, dynamic> json) => PartnerDetail(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    logoUrl: json['logoUrl'] as String?,
    businessNumber: json['businessNumber'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    registrationCode: json['registrationCode'] as String?,
  );
}

class UserDetail {
  const UserDetail({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.login,
    this.email,
    this.phone,
    required this.enabled,
    this.balance,
    required this.roles,
    this.stationName,
    this.covoiturageKycStatus,
    this.covoiturageVehicleBrand,
    this.covoiturageVehiclePlate,
    this.covoiturageVehicleColor,
    this.covoiturageDriverPhotoUrl,
    this.covoiturageVehiclePhotoUrl,
    this.covoiturageIdFrontUrl,
    this.covoiturageIdBackUrl,
    this.totalBookingsCount,
  });
  final int id;
  final String firstname;
  final String lastname;
  final String? login;
  final String? email;
  final String? phone;
  final bool enabled;
  final double? balance;
  final List<String> roles;
  final String? stationName;
  final String? covoiturageKycStatus;
  final String? covoiturageVehicleBrand;
  final String? covoiturageVehiclePlate;
  final String? covoiturageVehicleColor;
  final String? covoiturageDriverPhotoUrl;
  final String? covoiturageVehiclePhotoUrl;
  final String? covoiturageIdFrontUrl;
  final String? covoiturageIdBackUrl;
  final int? totalBookingsCount;
  String get fullName => '$firstname $lastname'.trim();
  String get initial => firstname.isNotEmpty ? firstname[0].toUpperCase() : '?';
  factory UserDetail.fromJson(Map<String, dynamic> json) => UserDetail(
    id: json['id'] as int,
    firstname: json['firstname'] as String? ?? '',
    lastname: json['lastname'] as String? ?? '',
    login: json['login'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    enabled: json['enabled'] as bool? ?? false,
    balance: (json['balance'] as num?)?.toDouble(),
    roles: (json['roles'] as List<dynamic>? ?? [])
        .map((e) => e as String)
        .toList(),
    stationName: json['stationName'] as String?,
    covoiturageKycStatus: json['covoiturageKycStatus'] as String?,
    covoiturageVehicleBrand: json['covoiturageVehicleBrand'] as String?,
    covoiturageVehiclePlate: json['covoiturageVehiclePlate'] as String?,
    covoiturageVehicleColor: json['covoiturageVehicleColor'] as String?,
    covoiturageDriverPhotoUrl: json['covoiturageDriverPhotoUrl'] as String?,
    covoiturageVehiclePhotoUrl: json['covoiturageVehiclePhotoUrl'] as String?,
    covoiturageIdFrontUrl: json['covoiturageIdFrontUrl'] as String?,
    covoiturageIdBackUrl: json['covoiturageIdBackUrl'] as String?,
    totalBookingsCount: json['totalBookingsCount'] as int?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final adminPartnersProvider = FutureProvider.autoDispose<List<AdminPartner>>((
  ref,
) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>(
    '/admin/partners',
  );
  return (res.data ?? [])
      .map((e) => AdminPartner.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>((
  ref,
) async {
  final res = await ApiClient.instance.dio.get<List<dynamic>>('/admin/users');
  return (res.data ?? [])
      .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
      .toList();
});

final adminCovoiturageDriversProvider =
    FutureProvider.autoDispose<List<CovoiturageSoloDriver>>((ref) async {
      final res = await ApiClient.instance.dio.get<List<dynamic>>(
        '/admin/covoiturage-solo-drivers',
      );
      return (res.data ?? [])
          .map((e) => CovoiturageSoloDriver.fromJson(e as Map<String, dynamic>))
          .toList();
    });

final partnerDetailProvider = FutureProvider.autoDispose
    .family<PartnerDetail, int>((ref, id) async {
      final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
        '/partners/$id',
      );
      return PartnerDetail.fromJson(res.data!);
    });

final userDetailProvider = FutureProvider.autoDispose.family<UserDetail, int>((
  ref,
  id,
) async {
  final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
    '/auth/$id',
  );
  return UserDetail.fromJson(res.data!);
});

// ═══════════════════════════════════════════════════════════════════════════
// PAGES DÉTAIL
// ═══════════════════════════════════════════════════════════════════════════

class PartnerDetailPage extends ConsumerWidget {
  const PartnerDetailPage({super.key, required this.partner});
  final AdminPartner partner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(partnerDetailProvider(partner.id));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(
          partner.name,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  if (partner.ownerName != null)
                    Text(
                      partner.ownerName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  _ApprovalBadge(
                    status: partner.approvalStatus,
                    enabled: partner.enabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (partner.logoUrl != null ||
                partner.kycFrontUrl != null ||
                partner.kycBackUrl != null)
              _DetailSection(
                title: 'Documents',
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (partner.logoUrl != null)
                        _DocumentThumb(label: 'Logo', path: partner.logoUrl!),
                      if (partner.kycFrontUrl != null)
                        _DocumentThumb(
                          label: 'CNI recto',
                          path: partner.kycFrontUrl!,
                        ),
                      if (partner.kycBackUrl != null)
                        _DocumentThumb(
                          label: 'CNI verso',
                          path: partner.kycBackUrl!,
                        ),
                    ],
                  ),
                ],
              ),
            if (partner.isRejected && partner.rejectionReason != null) ...[
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Motif du rejet',
                children: [
                  Text(
                    partner.rejectionReason!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Informations',
              children: [
                _DetailRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: detail.email ?? '—',
                ),
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Téléphone',
                  value: detail.phone ?? '—',
                ),
                _DetailRow(
                  icon: Icons.numbers_rounded,
                  label: "Numéro d'entreprise",
                  value: detail.businessNumber ?? '—',
                ),
                _DetailRow(
                  icon: Icons.qr_code_rounded,
                  label: "Code d'inscription",
                  value: detail.registrationCode ?? '—',
                ),
                _DetailRow(
                  icon: detail.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  label: 'Statut',
                  value: detail.enabled ? 'Actif' : 'Inactif',
                  valueColor: detail.enabled
                      ? AppColors.stationGreen
                      : AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  const _DocumentThumb({required this.label, required this.path});
  final String label;
  final String path;

  String get _fullUrl {
    // Le backend renvoie un chemin relatif (ex: "partners/kyc/xxx.jpg") ; ces
    // fichiers sont exposés sous /v1/uploads/**.
    const apiBase = 'https://api.my-mobili.com/v1/uploads';
    return path.startsWith('http') ? path : '$apiBase/$path';
  }

  @override
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                _fullUrl,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    child: Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _fullUrl,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 90,
              height: 90,
              color: AppColors.gray100,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.gray300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.gray500),
        ),
      ],
    ),
  );
}

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({
    super.key,
    required this.userId,
    required this.displayName,
  });
  final int userId;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(userDetailProvider(userId));
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
        title: Text(
          displayName.isNotEmpty ? displayName : 'Utilisateur',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.mobiliBlue),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur : $e',
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
        data: (detail) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1F6E), AppColors.mobiliBlueDeep],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        detail.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    detail.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  if (detail.login != null)
                    Text(
                      '@${detail.login}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: detail.roles
                        .map(
                          (r) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              r,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailSection(
              title: 'Coordonnées',
              children: [
                _DetailRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: detail.email ?? '—',
                ),
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Téléphone',
                  value: detail.phone ?? '—',
                ),
                _DetailRow(
                  icon: Icons.account_circle_rounded,
                  label: 'Login',
                  value: detail.login ?? '—',
                ),
                _DetailRow(
                  icon: detail.enabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  label: 'Compte',
                  value: detail.enabled ? 'Actif' : 'Désactivé',
                  valueColor: detail.enabled
                      ? AppColors.stationGreen
                      : AppColors.danger,
                ),
              ],
            ),
            if (detail.balance != null ||
                detail.stationName != null ||
                detail.totalBookingsCount != null) ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Activité',
                children: [
                  if (detail.balance != null)
                    _DetailRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Solde',
                      value: '${detail.balance!.toStringAsFixed(0)} FCFA',
                    ),
                  if (detail.totalBookingsCount != null)
                    _DetailRow(
                      icon: Icons.bookmark_rounded,
                      label: 'Réservations',
                      value: '${detail.totalBookingsCount}',
                    ),
                  if (detail.stationName != null)
                    _DetailRow(
                      icon: Icons.store_rounded,
                      label: 'Gare',
                      value: detail.stationName!,
                    ),
                ],
              ),
            ],
            if (detail.covoiturageKycStatus != null &&
                detail.covoiturageKycStatus != 'NONE') ...[
              const SizedBox(height: 12),
              _DetailSection(
                title: 'Profil covoiturage',
                children: [
                  _DetailRow(
                    icon: Icons.verified_user_rounded,
                    label: 'Statut KYC',
                    value: switch (detail.covoiturageKycStatus) {
                      'APPROVED' => 'Approuvé',
                      'PENDING' => 'En attente',
                      'REJECTED' => 'Rejeté',
                      'EXPIRED' => 'Expiré',
                      _ => detail.covoiturageKycStatus!,
                    },
                    valueColor: switch (detail.covoiturageKycStatus) {
                      'APPROVED' => AppColors.stationGreen,
                      'PENDING' => AppColors.warning,
                      'REJECTED' || 'EXPIRED' => AppColors.danger,
                      _ => AppColors.gray500,
                    },
                  ),
                  if (detail.covoiturageVehicleBrand != null)
                    _DetailRow(
                      icon: Icons.directions_car_rounded,
                      label: 'Véhicule',
                      value: detail.covoiturageVehicleBrand!,
                    ),
                  if (detail.covoiturageVehiclePlate != null)
                    _DetailRow(
                      icon: Icons.confirmation_number_rounded,
                      label: 'Plaque',
                      value: detail.covoiturageVehiclePlate!,
                    ),
                if (detail.covoiturageVehicleColor != null)
                    _DetailRow(
                      icon: Icons.palette_rounded,
                      label: 'Couleur',
                      value: detail.covoiturageVehicleColor!,
                    ),
                ],
              ),
              if (detail.covoiturageIdFrontUrl != null ||
                  detail.covoiturageIdBackUrl != null ||
                  detail.covoiturageDriverPhotoUrl != null ||
                  detail.covoiturageVehiclePhotoUrl != null) ...[
                const SizedBox(height: 12),
                _DetailSection(
                  title: 'Documents KYC',
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (detail.covoiturageIdFrontUrl != null)
                            _DocumentThumb(
                              label: 'CNI recto',
                              path: detail.covoiturageIdFrontUrl!,
                            ),
                          if (detail.covoiturageIdBackUrl != null)
                            _DocumentThumb(
                              label: 'CNI verso',
                              path: detail.covoiturageIdBackUrl!,
                            ),
                          if (detail.covoiturageDriverPhotoUrl != null)
                            _DocumentThumb(
                              label: 'Photo conducteur',
                              path: detail.covoiturageDriverPhotoUrl!,
                            ),
                          if (detail.covoiturageVehiclePhotoUrl != null)
                            _DocumentThumb(
                              label: 'Photo véhicule',
                              path: detail.covoiturageVehiclePhotoUrl!,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              // Boutons KYC — uniquement si PENDING ou EXPIRED
              if (detail.covoiturageKycStatus == 'PENDING' ||
                  detail.covoiturageKycStatus == 'EXPIRED') ...[
                const SizedBox(height: 12),
                _KycActionButtons(userId: detail.id),
              ],
              if (detail.covoiturageKycStatus == 'APPROVED') ...[
                const SizedBox(height: 12),
                _KycActionButtons(userId: detail.id, showRejectOnly: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

class _ApprovalBadge extends StatelessWidget {
  const _ApprovalBadge({required this.status, required this.enabled});
  final String status;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'PENDING' => ('En attente', AppColors.warning),
      'REJECTED' => ('Rejeté', AppColors.danger),
      _ =>
        enabled
            ? ('Actif', AppColors.stationGreen)
            : ('Inactif', AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.gray200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.mobiliBlueDeep,
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.gray100),
        ...children,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gray400),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.gray500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.mobiliBlueDeep,
          ),
        ),
      ],
    ),
  );
}


class _KycActionButtons extends ConsumerWidget {
  const _KycActionButtons({required this.userId, this.showRejectOnly = false});
  final int userId;
  final bool showRejectOnly;

  Future<void> _updateKyc(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    try {
      await ApiClient.instance.dio.patch(
        '/admin/users/$userId/covoiturage-kyc',
        queryParameters: {'status': status},
      );
      ref.invalidate(userDetailProvider(userId));
      ref.invalidate(adminCovoiturageDriversProvider);
      if (status == 'APPROVED') AnalyticsService.logApproveKyc(userId: userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut KYC mis à jour : $status'),
            backgroundColor: status == 'APPROVED'
                ? AppColors.stationGreen
                : AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Décision KYC',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppColors.mobiliBlueDeep,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!showRejectOnly) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateKyc(context, ref, 'APPROVED'),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Approuver',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stationGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateKyc(context, ref, 'REJECTED'),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Rejeter', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


