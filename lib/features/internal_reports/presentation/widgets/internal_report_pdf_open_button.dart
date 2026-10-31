import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../views/internal_report_pdf_preview.dart';

typedef InternalPdfSaveCallback = Future<String?> Function(Uint8List bytes);

/// Acciones autorizadas para consultar o guardar el PDF interno.
///
/// La previsualización se mantiene dentro de Sendaris.
/// La descarga requiere confirmación explícita y utiliza el
/// selector de documentos del sistema operativo.
///
/// El documento se vuelve a generar para cada descarga y no se
/// conserva como un archivo permanente dentro de la aplicación.
class InternalReportPdfOpenButton extends StatefulWidget {
  const InternalReportPdfOpenButton({
    required this.scopeChanges,
    required this.isAuthorized,
    required this.generatePdf,
    this.trackingNumber,
    this.viewerBuilder,
    this.savePdf,
    super.key,
  });

  final Listenable scopeChanges;
  final bool Function() isAuthorized;
  final Future<Uint8List> Function() generatePdf;

  /// Número real del seguimiento activo, obtenido por la vista.
  ///
  /// Si no está disponible, se utiliza un nombre genérico.
  final int? trackingNumber;

  /// Sustituye el visor nativo durante las pruebas.
  final InternalPdfViewerBuilder? viewerBuilder;

  /// Permite probar el flujo de guardado sin abrir Android Documents.
  ///
  /// Una respuesta null indica que se canceló la selección.
  final InternalPdfSaveCallback? savePdf;

  /// Construye un nombre seguro a partir del número del seguimiento.
  ///
  /// No utiliza identificadores internos, correos ni otros datos
  /// del perfil en el nombre del archivo.
  static String fileNameForTracking(int? trackingNumber) {
    if (trackingNumber == null || trackingNumber <= 0) {
      return 'Sendaris_Reporte_Interno.pdf';
    }

    return 'Sendaris_Reporte_Seguimiento_$trackingNumber.pdf';
  }

  String get downloadFileName => fileNameForTracking(trackingNumber);

  @override
  State<InternalReportPdfOpenButton> createState() =>
      _InternalReportPdfOpenButtonState();
}

class _InternalReportPdfOpenButtonState
    extends State<InternalReportPdfOpenButton> {
  bool _saving = false;
  bool _authorizationRevoked = false;

  bool _hasAccess() {
    try {
      return widget.isAuthorized();
    } catch (_) {
      return false;
    }
  }

  bool _canContinue() {
    return mounted && !_authorizationRevoked && _hasAccess();
  }

  @override
  void initState() {
    super.initState();
    widget.scopeChanges.addListener(_onScopeChanged);
  }

  @override
  void didUpdateWidget(covariant InternalReportPdfOpenButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.scopeChanges != widget.scopeChanges) {
      oldWidget.scopeChanges.removeListener(_onScopeChanged);
      widget.scopeChanges.addListener(_onScopeChanged);
    }

    if (_saving && !_hasAccess()) {
      _authorizationRevoked = true;
    }
  }

  void _onScopeChanged() {
    if (_saving && !_hasAccess()) {
      _authorizationRevoked = true;
    }
  }

  void _openPreview(BuildContext context) {
    if (_saving || !_hasAccess()) {
      return;
    }

    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(
            name: 'internal-report-private-pdf-preview',
          ),
          builder: (context) {
            return InternalReportPdfPreview(
              scopeChanges: widget.scopeChanges,
              isAuthorized: widget.isAuthorized,
              generatePdf: widget.generatePdf,
              viewerBuilder: widget.viewerBuilder,
            );
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('internal-report-pdf-download-warning'),
          title: const Text('Guardar reporte PDF'),
          content: const Text(
            'Vas a guardar una copia del reporte fuera de Sendaris. '
            'El archivo podrá abrirse desde otras aplicaciones y '
            'ya no estará protegido por el acceso de Sendaris.\n\n'
            'Guárdalo únicamente en una ubicación de confianza.',
          ),
          actions: [
            TextButton(
              key: const Key('internal-report-pdf-download-cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('internal-report-pdf-download-confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Elegir ubicación'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  static bool _looksLikePdf(Uint8List bytes) {
    return bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  /// El usuario elige la ubicación mediante Android Documents.
  ///
  /// El nombre incluye el número del seguimiento cuando está
  /// disponible y validado por la vista de reportes.
  static Future<String?> _saveWithSystem(Uint8List bytes, String fileName) {
    return FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: bytes,
        fileName: fileName,
        mimeTypesFilter: const ['application/pdf'],
        localOnly: true,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _downloadPdf() async {
    if (_saving || !_hasAccess()) {
      return;
    }

    setState(() {
      _saving = true;
      _authorizationRevoked = false;
    });

    Uint8List? generatedBytes;

    try {
      final confirmed = await _confirmDownload();

      if (!confirmed || !_canContinue()) {
        return;
      }

      generatedBytes = await widget.generatePdf();

      // Un cambio de seguimiento o sesión durante la generación
      // impide transferir el documento al selector del sistema.
      if (!_canContinue()) {
        return;
      }

      if (!_looksLikePdf(generatedBytes)) {
        throw const FormatException('Documento PDF no válido.');
      }

      if (!_canContinue()) {
        return;
      }

      final savedLocation = widget.savePdf != null
          ? await widget.savePdf!(generatedBytes)
          : await _saveWithSystem(generatedBytes, widget.downloadFileName);

      if (!_canContinue()) {
        return;
      }

      if (savedLocation == null || savedLocation.isEmpty) {
        return;
      }

      _showMessage('PDF guardado en la ubicación seleccionada.');
    } catch (_) {
      if (_canContinue()) {
        _showMessage('No fue posible guardar el reporte PDF.');
      }
    } finally {
      // Se descarta el búfer temporal usado en esta operación.
      // Las copias ya guardadas fuera de Sendaris no son revocables.
      generatedBytes?.fillRange(0, generatedBytes.length, 0);

      if (mounted) {
        setState(() {
          _saving = false;
          _authorizationRevoked = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.scopeChanges,
      builder: (context, child) {
        final enabled = _hasAccess() && !_saving;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('internal-report-pdf-open-button'),
                onPressed: enabled ? () => _openPreview(context) : null,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Ver PDF'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('internal-report-pdf-download-button'),
                onPressed: enabled ? () => unawaited(_downloadPdf()) : null,
                icon: _saving
                    ? const SizedBox(
                        key: Key('internal-report-pdf-download-progress'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(
                  _saving ? 'Preparando descarga...' : 'Descargar PDF',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    widget.scopeChanges.removeListener(_onScopeChanged);
    super.dispose();
  }
}
