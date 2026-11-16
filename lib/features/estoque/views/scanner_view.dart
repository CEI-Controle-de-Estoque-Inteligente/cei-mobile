import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';

/// Leitor de código de barras pela câmera (recurso nativo - C5.8).
/// Devolve o código lido para a tela anterior. Há digitação manual como
/// alternativa (câmera negada ou indisponível).
class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128],
  );
  final TextEditingController _manual = TextEditingController();
  bool _lido = false;

  @override
  void dispose() {
    _controller.dispose(); // C2.6: libera a câmera
    _manual.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_lido) return;
    for (final barcode in capture.barcodes) {
      final valor = barcode.rawValue;
      if (valor != null && valor.isNotEmpty) {
        _lido = true;
        HapticFeedback.mediumImpact();
        context.pop(valor);
        return;
      }
    }
  }

  void _confirmarManual() {
    final codigo = _manual.text.trim();
    final erro = Validators.optionalBarcode(codigo);
    if (codigo.isEmpty || erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro ?? 'Digite o código de barras')),
      );
      return;
    }
    context.pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ler código de barras'),
        actions: [
          IconButton(
            tooltip: 'Lanterna',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Não foi possível usar a câmera. Verifique a permissão ou digite o código abaixo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 140,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: AppRadius.mdAll,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manual,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Ou digite o código',
                        prefixIcon: Icon(Icons.keyboard_outlined),
                      ),
                      onSubmitted: (_) => _confirmarManual(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: 'Usar código digitado',
                    icon: const Icon(Icons.check),
                    onPressed: _confirmarManual,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
