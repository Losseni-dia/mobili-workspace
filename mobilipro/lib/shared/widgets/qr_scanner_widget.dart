import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle résultat scan
// ─────────────────────────────────────────────────────────────────────────────

class QrScanResult {
  const QrScanResult({
    required this.valid,
    required this.ticketNumber,
    this.passengerName,
    this.seatNumber,
    this.departureCity,
    this.arrivalCity,
    this.status,
    this.message,
    this.transportPrice,
    this.extraHoldBags = 0,
    this.luggageFee = 0,
  });
  final bool valid;
  final String ticketNumber;
  final String? passengerName;
  final String? seatNumber;
  final String? departureCity;
  final String? arrivalCity;
  final String? status;
  final String? message;
  final double? transportPrice;
  final int extraHoldBags;
  final double luggageFee;
  String get route => (departureCity != null && arrivalCity != null)
      ? '$departureCity → $arrivalCity'
      : '';
  double get totalPaid => (transportPrice ?? 0) + luggageFee;
}

// ─────────────────────────────────────────────────────────────────────────────
// QrScannerWidget — widget réutilisable
//
// Usage minimal :
//   QrScannerWidget(onResult: (result) { ... })
//
// Avec tripId (validation montée passager) :
//   QrScannerWidget(tripId: 42, onResult: (result) { ... })
// ─────────────────────────────────────────────────────────────────────────────

class QrScannerWidget extends StatefulWidget {
  const QrScannerWidget({
    super.key,
    this.tripId,
    this.onResult,
    this.showResultOverlay = true,
    this.overlayColor = Colors.black87,
  });

  /// Si renseigné, appelle PATCH /tickets/verify/{n} (confirme la montée)
  /// Sinon, appelle GET /tickets/{n} pour vérification simple
  final int? tripId;

  /// Callback appelé après chaque scan avec le résultat
  final void Function(QrScanResult result)? onResult;

  /// Afficher l'overlay résultat intégré (défaut true)
  /// Mettre false si vous gérez l'affichage vous-même via onResult
  final bool showResultOverlay;

  /// Couleur du fond de l'overlay résultat
  final Color overlayColor;

  @override
  State<QrScannerWidget> createState() => _QrScannerWidgetState();
}

class _QrScannerWidgetState extends State<QrScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  QrScanResult? _lastResult;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final qrData = barcode!.rawValue!;
    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    await _controller.stop();

    QrScanResult result;
    try {
      final ticketNumber = _extractTicketNumber(qrData);

      if (widget.tripId != null) {
        // Scanner un billet = confirmer la montée (passager "à bord").
        // La descente ("arrivé") est gérée automatiquement quand le chauffeur
        // quitte la ville de descente (POST /trips/{id}/driver/departures).
        final res = await ApiClient.instance.dio.patch<Map<String, dynamic>>(
          '/tickets/verify/$ticketNumber',
        );
        final data = res.data!;
       result = QrScanResult(
          valid: true,
          ticketNumber: ticketNumber,
          passengerName: data['passengerFullName'] as String?,
          seatNumber: data['seatNumber'] as String?,
          departureCity: data['departureCity'] as String?,
          arrivalCity: data['arrivalCity'] as String?,
          status: data['status'] as String?,
          transportPrice: (data['transportPrice'] as num?)?.toDouble(),
          extraHoldBags: (data['extraHoldBags'] as num?)?.toInt() ?? 0,
          luggageFee: (data['luggageFee'] as num?)?.toDouble() ?? 0,
        );
      } else {
        final res = await ApiClient.instance.dio.get<Map<String, dynamic>>(
          '/tickets/$ticketNumber',
        );
        final data = res.data!;
        final status = data['status'] as String? ?? '';
       result = QrScanResult(
          valid: status == 'CONFIRMED' || status == 'USED',
          ticketNumber: ticketNumber,
          passengerName: data['passengerFullName'] as String?,
          seatNumber: data['seatNumber'] as String?,
          departureCity: data['departureCity'] as String?,
          arrivalCity: data['arrivalCity'] as String?,
          status: status,
          transportPrice: (data['transportPrice'] as num?)?.toDouble(),
          extraHoldBags: (data['extraHoldBags'] as num?)?.toInt() ?? 0,
          luggageFee: (data['luggageFee'] as num?)?.toDouble() ?? 0,
        );
      }
    } catch (e) {
      result = QrScanResult(
        valid: false,
        ticketNumber: qrData,
        message: 'Ticket invalide ou introuvable',
      );
    }

    setState(() {
      _isProcessing = false;
      if (widget.showResultOverlay) _lastResult = result;
    });

    widget.onResult?.call(result);
  }

  String _extractTicketNumber(String qrData) {
    try {
      if (qrData.contains('ticketNumber')) {
        final match = RegExp(
          r'"ticketNumber"\s*:\s*"([^"]+)"',
        ).firstMatch(qrData);
        if (match != null) return match.group(1)!;
      }
    } catch (_) {}
    return qrData.trim();
  }

  /// Réinitialiser pour scanner un nouveau ticket
  void reset() {
    setState(() {
      _lastResult = null;
      _isProcessing = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Caméra ──────────────────────────────────
        MobileScanner(controller: _controller, onDetect: _onDetect),

        // ── Viseur ──────────────────────────────────
        if (_lastResult == null && !_isProcessing) _ScanViewfinder(),

        // ── Chargement ──────────────────────────────
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.mobiliYellow),
                  SizedBox(height: 16),
                  Text(
                    'Vérification...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // ── Résultat (si showResultOverlay = true) ──
        if (_lastResult != null && widget.showResultOverlay)
          QrScanResultOverlay(
            result: _lastResult!,
            overlayColor: widget.overlayColor,
            onReset: reset,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viseur
// ─────────────────────────────────────────────────────────────────────────────

class _ScanViewfinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(flex: 1, child: SizedBox()),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.mobiliYellow, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Stack(
              children: [
                _ScanCorner(top: true, left: true),
                _ScanCorner(top: true, left: false),
                _ScanCorner(top: false, left: true),
                _ScanCorner(top: false, left: false),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Placez le QR code dans le cadre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(flex: 1, child: SizedBox()),
      ],
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({required this.top, required this.left});
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top ? 0 : null,
    bottom: top ? null : 0,
    left: left ? 0 : null,
    right: left ? null : 0,
    child: Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: top
              ? const BorderSide(color: AppColors.mobiliYellow, width: 4)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: AppColors.mobiliYellow, width: 4)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: AppColors.mobiliYellow, width: 4)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: AppColors.mobiliYellow, width: 4)
              : BorderSide.none,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay résultat — aussi exporté pour usage externe
// ─────────────────────────────────────────────────────────────────────────────

class QrScanResultOverlay extends StatelessWidget {
  const QrScanResultOverlay({
    super.key,
    required this.result,
    required this.onReset,
    this.overlayColor = Colors.black87,
  });

  final QrScanResult result;
  final VoidCallback onReset;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    final isValid = result.valid;

    return Container(
      color: overlayColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isValid ? AppColors.stationGreen : AppColors.danger,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isValid
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isValid ? 'Ticket Valide ✓' : 'Ticket Invalide ✗',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                // Détails
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (result.passengerName != null)
                        _Row(
                          icon: Icons.person_rounded,
                          label: 'Passager',
                          value: result.passengerName!,
                        ),
                      if (result.seatNumber != null)
                        _Row(
                          icon: Icons.event_seat_rounded,
                          label: 'Siège',
                          value: result.seatNumber!,
                        ),
                      if (result.route.isNotEmpty)
                        _Row(
                          icon: Icons.route_rounded,
                          label: 'Trajet',
                          value: result.route,
                        ),
                      if (result.status != null)
                        _Row(
                          icon: Icons.info_outline_rounded,
                          label: 'Statut',
                          value: result.status!,
                        ),
                    _Row(
                        icon: Icons.qr_code_rounded,
                        label: 'N° ticket',
                        value: result.ticketNumber,
                      ),
                      if (isValid && result.transportPrice != null) ...[
                        const SizedBox(height: 4),
                        _Row(
                          icon: Icons.directions_bus_rounded,
                          label: 'Transport',
                          value:
                              '${result.transportPrice!.toStringAsFixed(0)} FCFA',
                        ),
                        if (result.extraHoldBags > 0)
                          _Row(
                            icon: Icons.luggage_rounded,
                            label: 'Bagages (${result.extraHoldBags})',
                            value:
                                '${result.luggageFee.toStringAsFixed(0)} FCFA',
                          ),
                        _Row(
                          icon: Icons.payments_rounded,
                          label: 'Total payé',
                          value: '${result.totalPaid.toStringAsFixed(0)} FCFA',
                        ),
                      ],
                      if (!isValid && result.message != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result.message!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onReset,
                          icon: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 18,
                          ),
                          label: const Text('Scanner un autre ticket'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mobiliBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AppColors.mobiliBlue),
        const SizedBox(width: 10),
        Text(
          '$label : ',
          style: const TextStyle(
            color: AppColors.gray400,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.mobiliBlueDeep,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
