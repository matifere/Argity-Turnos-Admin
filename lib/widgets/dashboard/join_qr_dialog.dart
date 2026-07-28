import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_saver/file_saver.dart';
import 'package:argrity/theme/kali_colors_extension.dart';

class JoinQrDialog extends StatefulWidget {
  final String joinCode;
  
  const JoinQrDialog({super.key, required this.joinCode});

  @override
  State<JoinQrDialog> createState() => _JoinQrDialogState();
}

class _JoinQrDialogState extends State<JoinQrDialog> {
  bool _isDownloading = false;

  Future<void> _downloadQR(BuildContext context, KaliColorsExtension kaliColors) async {
    setState(() => _isDownloading = true);
    try {
      final painter = QrPainter(
        data: widget.joinCode,
        version: QrVersions.auto,
        gapless: false,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: kaliColors.espresso,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: kaliColors.espresso,
        ),
      );

      const size = 1024.0;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Dibujar fondo blanco para que el PNG sea legible en modo oscuro o al imprimir
      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

      // Dibujar QR encima con un margen
      const qrSize = size * 0.9;
      const offset = (size - qrSize) / 2;
      canvas.translate(offset, offset);
      painter.paint(canvas, const Size(qrSize, qrSize));

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final picData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (picData != null) {
        await FileSaver.instance.saveFile(
          name: 'QR_Ingreso_${widget.joinCode}.png',
          bytes: picData.buffer.asUint8List(),
          ext: 'png',
          mimeType: MimeType.png,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR descargado exitosamente')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar el QR')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kaliColors = Theme.of(context).extension<KaliColorsExtension>()!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: kaliColors.warmWhite,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR de Ingreso',
              style: kaliColors.heading(kaliColors.espresso, size: 24).copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus alumnos pueden escanear este código desde la app para unirse a la institución.',
              textAlign: TextAlign.center,
              style: kaliColors.body(kaliColors.espresso.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kaliColors.warmWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kaliColors.espresso.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: kaliColors.espresso.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.joinCode,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: kaliColors.warmWhite,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: kaliColors.espresso,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: kaliColors.espresso,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kaliColors.espresso,
                  foregroundColor: kaliColors.warmWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _isDownloading
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: kaliColors.warmWhite, strokeWidth: 2))
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _isDownloading ? 'Descargando...' : 'Descargar QR',
                  style: kaliColors.body(kaliColors.warmWhite, weight: FontWeight.bold),
                ),
                onPressed: _isDownloading ? null : () => _downloadQR(context, kaliColors),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cerrar',
                style: kaliColors.body(kaliColors.espresso),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
