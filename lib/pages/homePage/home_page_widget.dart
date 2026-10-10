import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:roast_n_rizz/config/app_config.dart';
import 'package:roast_n_rizz/backend/api_requests/api_calls.dart';
import 'package:roast_n_rizz/controllers/home_controller.dart';
import 'package:roast_n_rizz/l10n/app_localizations.dart';
import 'package:roast_n_rizz/widgets/custom_icons.dart';
import 'package:roast_n_rizz/widgets/mock_rewarded_ad_page.dart';
import 'package:roast_n_rizz/pages/resultPage/result_page_widget.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  static const _maxPersonaLength = 80;
  static const _maxImageBytes = 6 * 1024 * 1024;

  final TextEditingController _personaController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final HomeController _controller = HomeController();

  Uint8List? _pickedImageBytes;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  static const _languageCodes = [
    'en', 'pt-PT', 'pt-BR', 'es', 'fr', 'de', 'it', 'ru', 'zh', 'ja',
    'ko', 'ar', 'hi', 'tr', 'vi', 'id', 'th', 'pl', 'nl', 'el', 'bn'
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) setState(() => _isOffline = results.contains(ConnectivityResult.none));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _recoverLostImage();
        _controller.loadUserId();
        _controller.initDefaultLanguage(View.of(context).platformDispatcher.locale);
        if (_personaController.text.isEmpty) {
          _personaController.text = _controller.defaultCelebrity;
        }
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isOffline = results.contains(ConnectivityResult.none));
  }

  Future<void> _watchRewardedAd() async {
    final l10n = AppLocalizations.of(context);
    await _controller.watchRewardedAd(
      onError: (code) {
        if (code == 'reward_not_earned') {
          _showError(l10n.rewardNotEarned);
        } else if (code.contains('3')) {
          _showError("Nenhum anúncio disponível neste momento. Tenta novamente mais tarde.");
        } else {
          _showError("${l10n.adUnavailable} (Error: $code)");
        }
      },
      onMockAd: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MockRewardedAdPage(
              onRewardEarned: () async {
                await _controller.addRewardCredits();
              },
            ),
          ),
        );
      },
    );
  }

  Color get _modeAccent =>
      _controller.isRizzMode ? const Color(0xFFFF3D9A) : const Color(0xFFA855F7);

  Color get _modeAccentDeep =>
      _controller.isRizzMode ? const Color(0xFFB71968) : const Color(0xFF5B21B6);

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);

    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showError(l10n.cameraPermissionDenied);
      openAppSettings();
      return;
    }
    if (!status.isGranted) return;

    if (!mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF24242A),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: Text(l10n.camera,
                  style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(l10n.gallery,
                  style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        await _loadPickedImage(pickedFile);
      } catch (e) {
        if (kDebugMode) debugPrint('_HomePageWidgetState._pickImage: $e');
        _showError(l10n.imageLoadError);
      }
    }
  }

  Future<void> _recoverLostImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final lostData = await _picker.retrieveLostData();
      if (lostData.isEmpty) return;
      await _loadPickedImage(lostData.files?.first);
    } catch (e) {
      if (kDebugMode) debugPrint('_HomePageWidgetState._recoverLostImage: $e');
      _showError(l10n.imageRecoverError);
    }
  }

  Future<void> _loadPickedImage(XFile? pickedFile) async {
    final l10n = AppLocalizations.of(context);
    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      _showError(l10n.imageTooLarge(6));
      return;
    }
    if (!mounted) return;
    setState(() => _pickedImageBytes = bytes);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildFallbackResponse(String persona, String language) {
    final style = persona.isEmpty ? 'your chosen persona' : persona;

    if (_controller.isRizzMode) {
      return switch (language) {
        'pt-PT' => 'No estilo de $style: essa energia entra na sala antes de você. Carisma de protagonista e zero necessidade de apresentação.',
        'pt-BR' => 'No estilo de $style: essa energia chega antes de você. Carisma de protagonista e nem precisa de apresentação.',
        'es' => 'Al estilo de $style: esa energía entra en la sala antes que tú. Carisma de protagonista y sin necesidad de presentación.',
        'fr' => 'Dans le style de $style : cette énergie entre dans la pièce avant vous. Un charisme de premier rôle, sans présentation nécessaire.',
        _ => 'In the style of $style: that energy enters the room before you do. Main-character charm, with no introduction required.',
      };
    }

    return switch (language) {
      'pt-PT' => 'No estilo de $style: foi ousado, confuso e impossível de ignorar. A confiança está lá; agora falta calibrar a entrega.',
      'pt-BR' => 'No estilo de $style: foi ousado, confuso e impossível de ignorar. A confiança está aí; agora só falta ajustar a entrega.',
      'es' => 'Al estilo de $style: fue atrevido, confuso e imposible de ignorar. La confianza está ahí; ahora falta ajustar a entrega.',
      'fr' => "Dans le style de $style : c'était audacieux, confus et impossible à ignorer. La confiance est là ; il faut maintenant soigner la livraison.",
      _ => 'In the style of $style: bold, confusing, and impossible to ignore. The confidence is there; now the delivery needs a little calibration.',
    };
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_controller.isLoading || _controller.isRewardLoading) return;

    if (_controller.credits == 0) {
      if (!_controller.isCreditsReady) {
        _showError(l10n.creditsLoading);
        return;
      }
      await _watchRewardedAd();
      return;
    }

    if (_pickedImageBytes == null) {
      _showError(l10n.photoRequired);
      return;
    }

    final persona = _personaController.text.trim();
    if (persona.length > _maxPersonaLength) {
      _showError(l10n.personaTooLong(_maxPersonaLength));
      return;
    }

    final effectivePersona = persona.isNotEmpty
        ? persona
        : (_controller.isRizzMode ? 'José Mourinho' : 'Gordon Ramsay');
    final languageCode = _controller.languageForPersona(effectivePersona);

    final apiResponse = await _controller.submitPhoto(
      imageBytes: _pickedImageBytes!,
      persona: effectivePersona,
      languageCode: languageCode,
    );

    if (!apiResponse.succeeded) {
      if (apiResponse.statusCode == 403) {
        _showError(l10n.insufficientCredits);
        return;
      }
      // If it's another error (like 500, 503), we show the fallback response below
      _showError(l10n.apiUnavailable);
    }

    final responseText = apiResponse.succeeded
        ? GetRoastCall.roastText(apiResponse.jsonBody, apiResponse.bodyText)
        : _buildFallbackResponse(effectivePersona, languageCode);

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultPageWidget(
            imageBytes: _pickedImageBytes!,
            responseText: responseText,
            persona: effectivePersona,
            isRizz: _controller.isRizzMode,
            modeName: _controller.isRizzMode ? l10n.rizz : l10n.roast,
          ),
        ),
      );
    }
  }

  String _languageName(String code, AppLocalizations l10n) => switch (code) {
    'pt-PT' => l10n.portuguesePortugal,
    'pt-BR' => l10n.portugueseBrazil,
    'es' => l10n.spanish,
    'fr' => l10n.french,
    'de' => l10n.german,
    'it' => l10n.italian,
    'ru' => l10n.russian,
    'zh' => l10n.chinese,
    'ja' => l10n.japanese,
    'ko' => l10n.korean,
    'ar' => l10n.arabic,
    'hi' => l10n.hindi,
    'tr' => l10n.turkish,
    'vi' => l10n.vietnamese,
    'id' => l10n.indonesian,
    'th' => l10n.thai,
    'pl' => l10n.polish,
    'nl' => l10n.dutch,
    'el' => l10n.greek,
    'bn' => l10n.bengali,
    _ => l10n.english,
  };

  @override
  void dispose() {
    _personaController.dispose();
    _connectivitySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availH = constraints.maxHeight;
            final isCompact = availH < 650;

            final logoSize = isCompact ? 56.0 : 86.0;
            final outerPadH = isCompact ? 14.0 : 20.0;
            final outerPadV = isCompact ? 6.0 : 10.0;
            final cardPad = isCompact ? 14.0 : 18.0;
            final gapXS = isCompact ? 4.0 : 8.0;
            final gapS = isCompact ? 8.0 : 14.0;
            final gapM = isCompact ? 10.0 : 20.0;
            final buttonH = isCompact ? 44.0 : 50.0;
            final submitH = isCompact ? 46.0 : 54.0;
            final imagePreviewH = (availH * 0.15).clamp(80.0, 180.0);

            final roundedBorder = OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white24),
            );

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final hasPhoto = _pickedImageBytes != null;
                  final focusedBorder = OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _modeAccent, width: 1.5),
                  );

                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.8, -0.9),
                        radius: 1.35,
                        colors: [
                          _modeAccent.withAlpha(55),
                          Colors.black,
                        ],
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          minHeight: availH,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: outerPadH,
                            vertical: outerPadV,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: gapXS),
                              _AnimatedLogo(size: logoSize),
                              SizedBox(height: gapXS),
                              Text(
                                l10n.title,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  letterSpacing: 2,
                                  color: _modeAccent,
                                ),
                              ),
                              if (!hasPhoto) ...[
                                SizedBox(height: gapXS),
                                Text(
                                  l10n.tagline,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: gapXS / 2),
                                Text(
                                  l10n.subtitle,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                              SizedBox(height: gapM),
                              Container(
                                padding: EdgeInsets.all(cardPad),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6141418),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _modeAccent.withAlpha(90),
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SegmentedButton<bool>(
                                      segments: [
                                        ButtonSegment(
                                          value: false,
                                          label: Text(l10n.roast),
                                          icon: const Icon(MyFlutterApp.skullCrossbones),
                                        ),
                                        ButtonSegment(
                                          value: true,
                                          label: Text(l10n.rizz),
                                          icon: const Icon(MyFlutterApp.emoSunglasses),
                                        ),
                                      ],
                                      selected: {_controller.isRizzMode},
                                      onSelectionChanged: (value) => _controller.setRizzMode(value.first),
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.resolveWith(
                                          (states) => states.contains(WidgetState.selected)
                                              ? _modeAccentDeep
                                              : Colors.white10,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: gapS),
                                    DropdownButtonFormField<String?>(
                                      initialValue: _controller.selectedLanguageCode,
                                      isExpanded: true,
                                      style: const TextStyle(color: Colors.white),
                                      dropdownColor: const Color(0xFF24242A),
                                      decoration: InputDecoration(
                                        labelText: l10n.language,
                                        prefixIcon: const Icon(Icons.language_rounded),
                                        border: roundedBorder,
                                        enabledBorder: roundedBorder,
                                        focusedBorder: focusedBorder,
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(l10n.autoFromPersona),
                                        ),
                                        ..._languageCodes.map(
                                          (code) => DropdownMenuItem<String?>(
                                            value: code,
                                            child: Text(_languageName(code, l10n)),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        _controller.setLanguage(value);
                                        _personaController.text = _controller.defaultCelebrity;
                                      },
                                    ),
                                    SizedBox(height: gapXS),
                                    DropdownMenu<String>(
                                      controller: _personaController,
                                      requestFocusOnTap: true,
                                      enableSearch: true,
                                      expandedInsets: EdgeInsets.zero,
                                      label: Text(l10n.persona),
                                      hintText: _controller.isRizzMode ? 'José Mourinho' : 'Gordon Ramsay',
                                      leadingIcon: const Icon(Icons.face_retouching_natural_outlined, color: Colors.white60),
                                      textStyle: const TextStyle(color: Colors.white),
                                      menuStyle: MenuStyle(backgroundColor: WidgetStateProperty.all(const Color(0xFF24242A))),
                                      inputDecorationTheme: InputDecorationTheme(
                                        filled: true,
                                        fillColor: Colors.white10,
                                        border: roundedBorder,
                                        enabledBorder: roundedBorder,
                                        focusedBorder: focusedBorder,
                                      ),
                                      dropdownMenuEntries: _controller.currentCelebrities
                                          .map((name) => DropdownMenuEntry(value: name, label: name, style: MenuItemButton.styleFrom(foregroundColor: Colors.white)))
                                          .toList(),
                                      onSelected: (val) {
                                        if (val != null) setState(() => _personaController.text = val);
                                      },
                                    ),
                                    if (hasPhoto) ...[
                                      SizedBox(height: gapXS),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.memory(
                                          _pickedImageBytes!,
                                          height: imagePreviewH,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: gapXS),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.add_a_photo_outlined),
                                        label: Text(hasPhoto ? l10n.changePhoto : l10n.choosePhoto),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _modeAccent,
                                          side: BorderSide(color: _modeAccent),
                                          minimumSize: Size.fromHeight(buttonH),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: gapXS),
                                    if (_isOffline)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          l10n.offlineAviso,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                        ),
                                      ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _controller.isLoading || _controller.isRewardLoading || _isOffline ? null : _submit,
                                        icon: _controller.isLoading || _controller.isRewardLoading
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : Icon(
                                                _controller.credits == 0
                                                    ? Icons.card_giftcard_outlined
                                                    : (_controller.isRizzMode ? MyFlutterApp.emoSunglasses : MyFlutterApp.skullCrossbones),
                                              ),
                                        label: Text(
                                          _controller.credits == 0
                                              ? l10n.watchAdToUnlock
                                              : (_controller.isRizzMode ? l10n.rizzMeUp : l10n.roastMeDown),
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: Size.fromHeight(submitH),
                                          backgroundColor: _modeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: gapXS),
                              TextButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: const Color(0xFF141418),
                                      title: Text(l10n.privacyPolicy, style: const TextStyle(color: Colors.white)),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "RoastNRizz respects your privacy. We process photos only to generate a temporary roast or rizz. "
                                              "Images are sent to our secure API and are not stored permanently.",
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              "For the full policy, visit:",
                                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: () async {
                                                final uri = Uri.parse(AppConfig.privacyPolicyUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                              child: Text(
                                                AppConfig.privacyPolicyUrl,
                                                style: TextStyle(color: _modeAccent, decoration: TextDecoration.underline),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                                    ),
                                  );
                                },
                                child: Text(l10n.privacyPolicy, style: const TextStyle(color: Colors.white38, fontSize: 12, decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo({required this.size});
  final double size;

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const shadowColor = Color(0xFFB23AE8);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withAlpha((20 + (10 * progress)).toInt()),
                  blurRadius: 15 + (10 * progress),
                  spreadRadius: 2 + (5 * progress),
                ),
              ],
            ),
            child: child,
          );
        },
        child: ClipOval(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/roast_n_rizz_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
              // Shimmer sweep effect
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(-widget.size + (widget.size * 3 * _controller.value), 0),
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Container(
                          width: widget.size * 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withAlpha(0),
                                Colors.white.withAlpha(50),
                                Colors.white.withAlpha(0),
                              ],
                              stops: const [0.3, 0.5, 0.7],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
