import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:roast_n_rizz/l10n/app_localizations.dart';
import 'package:roast_n_rizz/services/share_service.dart';

class ResultPageWidget extends StatefulWidget {
  const ResultPageWidget({
    super.key,
    required this.imageBytes,
    required this.responseText,
    required this.persona,
    required this.isRizz,
    required this.modeName,
  });

  final Uint8List imageBytes;
  final String responseText;
  final String persona;
  final bool isRizz;
  final String modeName;

  @override
  State<ResultPageWidget> createState() => _ResultPageWidgetState();
}

class _ResultPageWidgetState extends State<ResultPageWidget> {
  bool _isSharing = false;

  Future<void> _onShare() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final result = await ShareService.buildShareImage(
        imageBytes: widget.imageBytes,
        responseText: widget.responseText,
        modeName: widget.modeName,
        persona: widget.persona,
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              result.pngBytes,
              name: 'roast-n-rizz-result.png',
              mimeType: 'image/png',
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('ResultPageWidget: share failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shareUnableToShare)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeColor = widget.isRizz
        ? const Color(0xFFFF3D9A)
        : const Color(0xFFA855F7);

    final textBlock = Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87, Colors.black],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.modeName}: ${widget.persona}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              widget.responseText,
              textAlign: TextAlign.start,
              maxLines: 6,
              overflow: TextOverflow.fade,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Semantics(
                  label: "Generated result image",
                  child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned.fill(child: textBlock),
            // Brand badge — top left
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage(
                        'assets/images/roast_n_rizz_logo.png',
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'RoastNRizz',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Close button — top right
            Positioned(
              top: 18,
              right: 18,
              child: _ActionButton(
                color: modeColor,
                icon: Icons.close,
                tooltip: 'Close result',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            // Share button — below close
            Positioned(
              top: 82,
              right: 18,
              child: _ActionButton(
                color: modeColor,
                icon: _isSharing ? Icons.hourglass_top_rounded : Icons.share_rounded,
                tooltip: 'Share result',
                onPressed: _isSharing ? () {} : _onShare,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.color,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 12, spreadRadius: 2),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
      ),
    );
  }
}
