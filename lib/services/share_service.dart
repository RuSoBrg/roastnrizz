import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles off-thread share-image composition.
class ShareService {
  const ShareService._();

  static ui.Image? _cachedLogo;

  /// Builds the branded share image for a roast/rizz result.
  static Future<ShareImageResult> buildShareImage({
    required Uint8List imageBytes,
    required String responseText,
    required String modeName,
    required String persona,
  }) async {
    final imageCodec = await ui.instantiateImageCodec(imageBytes);
    final sourceImage = (await imageCodec.getNextFrame()).image;

    // Logo Cache Logic
    if (_cachedLogo == null) {
      final logoData = await rootBundle.load('assets/images/roast_n_rizz_logo.png');
      final logoCodec = await ui.instantiateImageCodec(logoData.buffer.asUint8List());
      _cachedLogo = (await logoCodec.getNextFrame()).image;
    }
    final logoImage = _cachedLogo!;

    const width = 1080.0;
    final sourceSize = Size(sourceImage.width.toDouble(), sourceImage.height.toDouble());
    final aspectRatio = sourceSize.height / sourceSize.width;
    final photoAreaHeight = (width * aspectRatio).clamp(800.0, 1600.0);

    final imageSize = applyBoxFit(BoxFit.contain, sourceSize, Size(width, photoAreaHeight)).destination;
    final photoRect = Alignment.center.inscribe(imageSize, Rect.fromLTWH(0, 0, width, photoAreaHeight));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.srcOver);

    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
      photoRect,
      Paint(),
    );

    // --- Brand Panel ---
    const logoSize = 120.0;
    const spacing = 28.0;
    const brandFontSize = 46.0;
    const horizontalPadding = 48.0;
    const panelHeight = 170.0;

    final brandBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: brandFontSize, fontWeight: FontWeight.bold))
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('RoastNRizz');
    final brandParagraph = brandBuilder.build()..layout(const ui.ParagraphConstraints(width: 600));

    final panelWidth = logoSize + spacing + brandParagraph.minIntrinsicWidth + (horizontalPadding * 2);
    final panelLeft = (width - panelWidth) / 2;
    final panelRect = Rect.fromLTWH(panelLeft, 32, panelWidth, panelHeight);

    canvas.drawRRect(RRect.fromRectAndRadius(panelRect, const Radius.circular(panelHeight / 2)), Paint()..color = Colors.black54);

    final logoRect = Rect.fromLTWH(panelLeft + horizontalPadding, panelRect.top + (panelHeight - logoSize) / 2, logoSize, logoSize);
    canvas.save();
    canvas.clipPath(Path()..addOval(logoRect));
    canvas.drawImageRect(logoImage, Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()), logoRect, Paint());
    canvas.restore();

    canvas.drawParagraph(brandParagraph, Offset(panelLeft + horizontalPadding + logoSize + spacing, panelRect.top + (panelHeight - brandParagraph.height) / 2));

    // --- Metadata and Response ---
    final metadataBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 28, height: 1.2, maxLines: 1, ellipsis: '...'))
      ..pushStyle(ui.TextStyle(color: Colors.white70))
      ..addText('$modeName: $persona');
    final metadata = metadataBuilder.build()..layout(const ui.ParagraphConstraints(width: 980));

    final responseBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 38, height: 1.25))
      ..pushStyle(ui.TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
      ..addText(responseText);
    final response = responseBuilder.build()..layout(const ui.ParagraphConstraints(width: 980));

    final metadataTop = photoAreaHeight + 34;
    final responseTop = metadataTop + metadata.height + 14;
    final height = responseTop + response.height + 44;
    final gradientTop = photoAreaHeight - 60;

    final gradient = Paint()..shader = ui.Gradient.linear(Offset(0, gradientTop), Offset(0, height), [Colors.transparent, Colors.black]);
    canvas.drawRect(Rect.fromLTWH(0, gradientTop, width, height - gradientTop), gradient);
    canvas.drawParagraph(metadata, Offset(50, metadataTop));
    canvas.drawParagraph(response, Offset(50, responseTop));

    final rendered = await recorder.endRecording().toImage(width.round(), height.round());
    final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return ShareImageResult(pngBytes: data!.buffer.asUint8List());
  }
}

class ShareImageResult {
  const ShareImageResult({required this.pngBytes});
  final Uint8List pngBytes;
}
