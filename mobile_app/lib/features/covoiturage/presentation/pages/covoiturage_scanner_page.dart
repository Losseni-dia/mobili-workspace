import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/qr_scanner_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScannerPage — page standalone qui utilise QrScannerWidget
// ─────────────────────────────────────────────────────────────────────────────

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key, this.tripId});
  final int? tripId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.mobiliBlue,
        foregroundColor: AppColors.white,
       title: const Text('Scanner un billet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: const QrScannerWidget(showResultOverlay: true),
    );
  }
}
