import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

typedef InternalPdfViewerBuilder = Widget Function(
  BuildContext context,
  Uint8List bytes,
);

/// Vista privada de un PDF generado en memoria.
///
/// La pantalla comprueba el alcance de autorizacion antes y despues
/// de generar los bytes, y escucha cambios de cuenta o seguimiento.
///
/// El origen de la autorizacion se proporciona desde la pantalla
/// que abre este visor.
class InternalReportPdfPreview extends StatefulWidget {
  const InternalReportPdfPreview({
    required this.generatePdf,
    required this.scopeChanges,
    required this.isAuthorized,
    this.viewerBuilder,
    super.key,
  });

  final Future<Uint8List> Function() generatePdf;
  final Listenable scopeChanges;
  final bool Function() isAuthorized;

  /// Sustituye solo la vista nativa durante las pruebas de widgets.
  final InternalPdfViewerBuilder? viewerBuilder;

  @override
  State<InternalReportPdfPreview> createState() =>
      _InternalReportPdfPreviewState();
}

class _InternalReportPdfPreviewState extends State<InternalReportPdfPreview>
    with WidgetsBindingObserver {
  Uint8List? _bytes;
  bool _loading = true;
  bool _revoked = false;
  String? _errorMessage;

  bool _hasAccess() {
    if (_revoked) return false;

    try {
      return widget.isAuthorized();
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    widget.scopeChanges.addListener(_checkScope);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPdf();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InternalReportPdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scopeChanges != widget.scopeChanges) {
      oldWidget.scopeChanges.removeListener(_checkScope);
      widget.scopeChanges.addListener(_checkScope);
    }

    _checkScope();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _checkScope();
    }
  }

  void _checkScope() {
    if (!mounted || _revoked) return;

    if (!_hasAccess()) {
      _revokeAccess();
    }
  }

  void _clearPdfBytes() {
    final bytes = _bytes;
    _bytes = null;

    // Limpieza de la copia que controla este widget.
    // No sustituye las protecciones de memoria del sistema operativo.
    bytes?.fillRange(0, bytes.length, 0);
  }

  void _revokeAccess() {
    if (!mounted || _revoked) return;

    _revoked = true;
    _clearPdfBytes();

    setState(() {
      _loading = false;
      _errorMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final navigator = Navigator.of(context);
      final route = ModalRoute.of(context);

      if (route?.isCurrent == true && navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  Future<void> _loadPdf() async {
    if (!_hasAccess()) {
      _revokeAccess();
      return;
    }

    try {
      final generated = await widget.generatePdf();

      if (!mounted || _revoked) return;

      if (!_hasAccess()) {
        _revokeAccess();
        return;
      }

      // Evita entregar bytes evidentemente invalidos al visor nativo.
      if (generated.length < 5 ||
          generated[0] != 0x25 ||
          generated[1] != 0x50 ||
          generated[2] != 0x44 ||
          generated[3] != 0x46 ||
          generated[4] != 0x2D) {
        throw const FormatException('Documento PDF no valido.');
      }

      setState(() {
        _bytes = Uint8List.fromList(generated);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _revoked) return;

      if (!_hasAccess()) {
        _revokeAccess();
        return;
      }

      setState(() {
        _loading = false;
        _errorMessage = 'No fue posible preparar el reporte PDF.';
      });
    }
  }

  void _showViewerError() {
    if (!mounted || _revoked) return;

    if (!_hasAccess()) {
      _revokeAccess();
      return;
    }

    _clearPdfBytes();

    setState(() {
      _errorMessage = 'No fue posible mostrar el documento PDF.';
    });
  }

  Widget _buildContent() {
    if (_revoked || !_hasAccess()) {
      return const Center(
        child: Text(
          'El acceso al reporte ha finalizado.',
          key: Key('internal-report-pdf-access-ended'),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('internal-report-pdf-loading'),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            key: const Key('internal-report-pdf-error'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bytes = _bytes;

    if (bytes == null) {
      return const Center(child: Text('No existe un documento disponible.'));
    }

    final customViewer = widget.viewerBuilder;

    if (customViewer != null) {
      return customViewer(context, bytes);
    }

    return PDFView(
      key: const Key('internal-report-pdf-native-viewer'),
      pdfData: bytes,
      preventLinkNavigation: true,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      fitPolicy: FitPolicy.WIDTH,
      onError: (_) => _showViewerError(),
      onPageError: (_, _) => _showViewerError(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('internal-report-pdf-preview'),
      appBar: AppBar(title: const Text('Vista previa del reporte')),
      body: SafeArea(child: _buildContent()),
    );
  }

  @override
  void dispose() {
    widget.scopeChanges.removeListener(_checkScope);
    WidgetsBinding.instance.removeObserver(this);

    _clearPdfBytes();

    super.dispose();
  }
}
