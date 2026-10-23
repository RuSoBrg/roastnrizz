import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:roast_n_rizz/backend/api_requests/api_calls.dart';
import 'package:roast_n_rizz/config/ad_config.dart';

class HomeController extends ChangeNotifier {
  static const _dailyFreeCredits = 3;
  static const _rewardedCredits = 3;
  static const _creditsKey = 'roast_rizz_credits';

  static final _secureStorage = const FlutterSecureStorage();
  static final _analytics = FirebaseAnalytics.instance;

  /// Maps known celebrity names to their usual language code for auto-detection.
  static const _personaLanguages = <String, String>{
    'Dave Chappelle': 'en',
    'Donald Trump': 'en',
    'Gordon Ramsay': 'en',
    'Elon Musk': 'en',
    'Kevin Hart': 'en',
    'Samuel L. Jackson': 'en',
    'Bruno Nogueira': 'pt-PT',
    'José Mourinho': 'pt-PT',
    'Cristiano Ronaldo': 'pt-PT',
    'Ricardo Araújo Pereira': 'pt-PT',
    'Salvador Sobral': 'pt-PT',
    'Herman José': 'pt-PT',
    'Whindersson Nunes': 'pt-BR',
    'Casimiro': 'pt-BR',
    'Anitta': 'pt-BR',
    'Neymar Jr': 'pt-BR',
    'Faustão': 'pt-BR',
    'Silvio Santos': 'pt-BR',
    'Ibai Llanos': 'es',
    'AuronPlay': 'es',
    'Shakira': 'es',
    'Lionel Messi': 'es',
    'Penélope Cruz': 'es',
    'Bad Bunny': 'es',
    'Emmanuel Macron': 'fr',
    'Kylian Mbappé': 'fr',
    'Omar Sy': 'fr',
    'Gad Elmaleh': 'fr',
    'Zinedine Zidane': 'fr',
    'Marion Cotillard': 'fr',
    'Angela Merkel': 'de',
    'Arnold Schwarzenegger': 'de',
    'Heidi Klum': 'de',
    'Sebastian Vettel': 'de',
    'Karl Lagerfeld': 'de',
    'Thomas Müller': 'de',
    'Monica Bellucci': 'it',
    'Sophia Loren': 'it',
    'Valentino Rossi': 'it',
    'Giorgio Armani': 'it',
    'Silvio Berlusconi': 'it',
    'Francesco Totti': 'it',
    'Vladimir Putin': 'ru',
    'Khabib Nurmagomedov': 'ru',
    'Maria Sharapova': 'ru',
    'Fyodor Dostoevsky': 'ru',
    'Lev Tolstoy': 'ru',
    'Yury Dud': 'ru',
    'Jackie Chan': 'zh',
    'Bruce Lee': 'zh',
    'Yao Ming': 'zh',
    'Jack Ma': 'zh',
    'Xi Jinping': 'zh',
    'Jay Chou': 'zh',
    'Akira Kurosawa': 'ja',
    'Hayao Miyazaki': 'ja',
    'Naomi Osaka': 'ja',
    'Ichiro Suzuki': 'ja',
    'Hideo Kojima': 'ja',
    'Shinzo Abe': 'ja',
    'BTS (RM)': 'ko',
    'Bong Joon-ho': 'ko',
    'Son Heung-min': 'ko',
    'PSY': 'ko',
    'Faker': 'ko',
    'Lee Min-ho': 'ko',
    'Mohamed Salah': 'ar',
    'Amr Diab': 'ar',
    'Nancy Ajram': 'ar',
    'Fairuz': 'ar',
    'Gibran Khalil Gibran': 'ar',
    'Majida El Roumi': 'ar',
    'Amitabh Bachchan': 'hi',
    'Shah Rukh Khan': 'hi',
    'Narendra Modi': 'hi',
    'Virat Kohli': 'hi',
    'Aishwarya Rai': 'hi',
    'Salman Khan': 'hi',
    'Recep Tayyip Erdoğan': 'tr',
    'Tarkan': 'tr',
    'Nuri Bilge Ceylan': 'tr',
    'Burak Özçivit': 'tr',
    'CZN Burak': 'tr',
    'Nusret Gökçe': 'tr',
    'Ho Chi Minh': 'vi',
    'Son Tung M-TP': 'vi',
    'Ngo Thanh Van': 'vi',
    'Dang Le Nguyen Vu': 'vi',
    'H\'Hen Niê': 'vi',
    'Tran Thanh': 'vi',
    'Sukarno': 'id',
    'Joko Widodo': 'id',
    'Agnes Monica': 'id',
    'Rich Brian': 'id',
    'Iko Uwais': 'id',
    'Raffi Ahmad': 'id',
    'Lalisa Manobal': 'th',
    'Tony Jaa': 'th',
    'Thaksin Shinawatra': 'th',
    'Mario Maurer': 'th',
    'BamBam': 'th',
    'Prayut Chan-o-cha': 'th',
    'Robert Lewandowski': 'pl',
    'Lech Wałęsa': 'pl',
    'Marie Curie': 'pl',
    'Andrzej Sapkowski': 'pl',
    'Iga Świątek': 'pl',
    'Wisława Szymborska': 'pl',
    'Max Verstappen': 'nl',
    'Vincent van Gogh': 'nl',
    'Johan Cruyff': 'nl',
    'Anne Frank': 'nl',
    'Armin van Buuren': 'nl',
    'Geert Wilders': 'nl',
    'Socrates': 'el',
    'Giannis Antetokounmpo': 'el',
    'Nana Mouskouri': 'el',
    'Mikis Theodorakis': 'el',
    'Maria Callas': 'el',
    'Alexis Tsipras': 'el',
    'Rabindranath Tagore': 'bn',
    'Sheikh Hasina': 'bn',
    'Humayun Ahmed': 'bn',
    'Sourav Ganguly': 'bn',
    'Amartya Sen': 'bn',
    'Satyajit Ray': 'bn',
  };

  /// Lists of famous celebrities grouped by language code.
  static const celebritiesByLanguage = <String, List<String>>{
    'en': ['Dave Chappelle', 'Donald Trump', 'Gordon Ramsay', 'Elon Musk', 'Kevin Hart', 'Samuel L. Jackson'],
    'pt-PT': ['Bruno Nogueira', 'José Mourinho', 'Cristiano Ronaldo', 'Ricardo Araújo Pereira', 'Salvador Sobral', 'Herman José'],
    'pt-BR': ['Whindersson Nunes', 'Casimiro', 'Anitta', 'Neymar Jr', 'Faustão', 'Silvio Santos'],
    'es': ['Ibai Llanos', 'AuronPlay', 'Shakira', 'Lionel Messi', 'Penélope Cruz', 'Bad Bunny'],
    'fr': ['Emmanuel Macron', 'Kylian Mbappé', 'Omar Sy', 'Gad Elmaleh', 'Zinedine Zidane', 'Marion Cotillard'],
    'de': ['Angela Merkel', 'Arnold Schwarzenegger', 'Heidi Klum', 'Sebastian Vettel', 'Karl Lagerfeld', 'Thomas Müller'],
    'it': ['Monica Bellucci', 'Sophia Loren', 'Valentino Rossi', 'Giorgio Armani', 'Silvio Berlusconi', 'Francesco Totti'],
    'ru': ['Vladimir Putin', 'Khabib Nurmagomedov', 'Maria Sharapova', 'Fyodor Dostoevsky', 'Lev Tolstoy', 'Yury Dud'],
    'zh': ['Jackie Chan', 'Bruce Lee', 'Yao Ming', 'Jack Ma', 'Xi Jinping', 'Jay Chou'],
    'ja': ['Akira Kurosawa', 'Hayao Miyazaki', 'Naomi Osaka', 'Ichiro Suzuki', 'Hideo Kojima', 'Shinzo Abe'],
    'ko': ['BTS (RM)', 'Bong Joon-ho', 'Son Heung-min', 'PSY', 'Faker', 'Lee Min-ho'],
    'ar': ['Mohamed Salah', 'Amr Diab', 'Nancy Ajram', 'Fairuz', 'Gibran Khalil Gibran', 'Majida El Roumi'],
    'hi': ['Amitabh Bachchan', 'Shah Rukh Khan', 'Narendra Modi', 'Virat Kohli', 'Aishwarya Rai', 'Salman Khan'],
    'tr': ['Recep Tayyip Erdoğan', 'Tarkan', 'Nuri Bilge Ceylan', 'Burak Özçivit', 'CZN Burak', 'Nusret Gökçe'],
    'vi': ['Ho Chi Minh', 'Son Tung M-TP', 'Ngo Thanh Van', 'Dang Le Nguyen Vu', 'H\'Hen Niê', 'Tran Thanh'],
    'id': ['Sukarno', 'Joko Widodo', 'Agnes Monica', 'Rich Brian', 'Iko Uwais', 'Raffi Ahmad'],
    'th': ['Lalisa Manobal', 'Tony Jaa', 'Thaksin Shinawatra', 'Mario Maurer', 'BamBam', 'Prayut Chan-o-cha'],
    'pl': ['Robert Lewandowski', 'Lech Wałęsa', 'Marie Curie', 'Andrzej Sapkowski', 'Iga Świątek', 'Wisława Szymborska'],
    'nl': ['Max Verstappen', 'Vincent van Gogh', 'Johan Cruyff', 'Anne Frank', 'Armin van Buuren', 'Geert Wilders'],
    'el': ['Socrates', 'Giannis Antetokounmpo', 'Nana Mouskouri', 'Mikis Theodorakis', 'Maria Callas', 'Alexis Tsipras'],
    'bn': ['Rabindranath Tagore', 'Sheikh Hasina', 'Humayun Ahmed', 'Sourav Ganguly', 'Amartya Sen', 'Satyajit Ray'],
  };

  /// Maps language codes to the most iconic default celebrity.
  static const _defaultCelebrityByLanguage = <String, String>{
    'en': 'Gordon Ramsay',
    'pt-PT': 'José Mourinho',
    'pt-BR': 'Faustão',
    'es': 'Ibai Llanos',
    'fr': 'Zinedine Zidane',
    'de': 'Angela Merkel',
    'it': 'Valentino Rossi',
    'ru': 'Vladimir Putin',
    'zh': 'Jackie Chan',
    'ja': 'Hayao Miyazaki',
    'ko': 'Bong Joon-ho',
    'ar': 'Mohamed Salah',
    'hi': 'Shah Rukh Khan',
    'tr': 'Tarkan',
    'vi': 'Son Tung M-TP',
    'id': 'Joko Widodo',
    'th': 'Lalisa Manobal',
    'pl': 'Robert Lewandowski',
    'nl': 'Max Verstappen',
    'el': 'Giannis Antetokounmpo',
    'bn': 'Rabindranath Tagore',
  };

  bool isRizzMode = false;
  bool isLoading = false;
  bool isCreditsReady = false;
  bool isRewardLoading = false;
  int credits = _dailyFreeCredits;
  String? selectedLanguageCode;

  String get defaultCelebrity =>
      _defaultCelebrityByLanguage[selectedLanguageCode] ?? 'Gordon Ramsay';

  void initDefaultLanguage(ui.Locale systemLocale) {
    if (selectedLanguageCode != null) return;

    final lang = systemLocale.languageCode.toLowerCase();
    final country = systemLocale.countryCode?.toUpperCase();

    if (lang == 'pt') {
      selectedLanguageCode = (country == 'BR') ? 'pt-BR' : 'pt-PT';
    } else if (celebritiesByLanguage.containsKey(lang)) {
      selectedLanguageCode = lang;
    } else {
      selectedLanguageCode = 'en';
    }
    notifyListeners();
  }

  List<String> get currentCelebrities =>
      celebritiesByLanguage[selectedLanguageCode] ?? [];

  String languageForPersona(String persona) =>
      selectedLanguageCode ?? _personaLanguages[persona] ?? 'en';

  Future<void> loadUserId() async {
    try {
      // Secure Anonymous Auth
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        UserCredential userCred = await FirebaseAuth.instance.signInAnonymously();
        user = userCred.user;
      }

      // Sync local credits from cache (for UI speed)
      final storedCredits = await _secureStorage.read(key: _creditsKey);
      if (storedCredits != null) {
        final val = int.tryParse(storedCredits) ?? _dailyFreeCredits;
        credits = val.clamp(0, 999);
      }

      // Sync credits from server in background
      final token = await user?.getIdToken();
      if (token != null) {
        String? appCheckToken;
        try {
          appCheckToken = await FirebaseAppCheck.instance.getToken();
        } catch (_) {}
        final res = await GetRoastCall.syncCredits(
          authToken: token,
          appCheckToken: appCheckToken,
        );
        if (res.succeeded && res.jsonBody != null) {
          final serverCredits = res.jsonBody!['credits'];
          if (serverCredits is int) {
            credits = serverCredits; // Server is the source of truth
            await _persistCredits();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('HomeController: Firebase Auth / sync error: $e');
    }
    isCreditsReady = true;
    notifyListeners();
  }

  void setRizzMode(bool value) {
    isRizzMode = value;
    notifyListeners();
  }

  void setLanguage(String? code) {
    selectedLanguageCode = code;
    notifyListeners();
  }

  /// Adds credits locally and explicitly notifies the server.
  Future<void> addRewardCredits() async {
    // Optimistic local update
    credits += _rewardedCredits;
    await _persistCredits();
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final authToken = await user.getIdToken();
      if (authToken == null) return;

      String? appCheckToken;
      try {
        appCheckToken = await FirebaseAppCheck.instance.getToken();
      } catch (_) {}

      final response = await GetRoastCall.claimReward(
        authToken: authToken,
        appCheckToken: appCheckToken,
      );

      if (response.succeeded && response.jsonBody != null) {
        final serverCredits = response.jsonBody!['credits'];
        if (serverCredits is int) {
          credits = serverCredits;
          await _persistCredits();
          notifyListeners();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to sync claimed reward to server: $e');
    }
  }

  Future<void> watchRewardedAd({
    required Function(String) onError,
    Future<void> Function()? onMockAd,
  }) async {
    if (isRewardLoading) return;
    isRewardLoading = true;
    notifyListeners();

    // Fallback to mock ad in debug or profile modes to prevent developer blocks
    if (!kReleaseMode && onMockAd != null) {
      await onMockAd();
      isRewardLoading = false;
      notifyListeners();
      return;
    }

    var rewardEarned = false;
    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          isRewardLoading = false;
          notifyListeners();

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!rewardEarned) onError('reward_not_earned');
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onError('ad_unavailable');
            },
          );

          // Pass secure UID for AdMob SSV
          ad.setServerSideOptions(ServerSideVerificationOptions(
            customData: FirebaseAuth.instance.currentUser?.uid,
          ));

          ad.show(onUserEarnedReward: (ad, reward) async {
            rewardEarned = true;
            await addRewardCredits();
            _analytics.logEvent(name: 'earned_reward');
          });
        },
        onAdFailedToLoad: (error) {
          isRewardLoading = false;
          notifyListeners();
          onError('ad_unavailable_${error.code}');
        },
      ),
    );
  }

  Future<ApiCallResponse> submitPhoto({
    required Uint8List imageBytes,
    required String persona,
    required String languageCode,
  }) async {
    if (credits <= 0) {
      return const ApiCallResponse(statusCode: 403, bodyText: 'Insufficient credits');
    }

    isLoading = true;
    notifyListeners();

    try {
      FirebaseCrashlytics.instance.log('submitPhoto: persona=$persona, lang=$languageCode, isRizz=$isRizzMode');
      // Ensure we are signed in anonymously first
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      }

      final authToken = await user?.getIdToken(); // cached; force-refresh only on 401 retry
      if (authToken == null) throw Exception("Failed to obtain Auth Token from Firebase");

      String? appCheckToken;
      try {
        appCheckToken = await FirebaseAppCheck.instance.getToken();
      } catch (e) {
        if (kDebugMode) debugPrint('AppCheck getToken failed: $e');
      }

      var apiResponse = await GetRoastCall.call(
        photoBase64: base64Encode(imageBytes),
        authToken: authToken,
        language: languageCode,
        persona: persona,
        appCheckToken: appCheckToken,
        isRizz: isRizzMode,
      );

      // If 401 Unauthorized, force-refresh token and retry once
      if (apiResponse.statusCode == 401) {
        final freshToken = await user?.getIdToken(true);
        if (freshToken != null) {
          apiResponse = await GetRoastCall.call(
            photoBase64: base64Encode(imageBytes),
            authToken: freshToken,
            language: languageCode,
            persona: persona,
            appCheckToken: appCheckToken,
            isRizz: isRizzMode,
          );
        }
      }

      if (apiResponse.succeeded) {
        _analytics.logEvent(name: 'generate_content', parameters: {
          'mode': isRizzMode ? 'rizz' : 'roast',
          'persona': persona,
          'language': languageCode,
        });
      } else if (apiResponse.statusCode != 403) {
        _analytics.logEvent(name: 'ai_fallback_triggered', parameters: {
          'status_code': apiResponse.statusCode,
          'mode': isRizzMode ? 'rizz' : 'roast',
        });
      }

      if (apiResponse.jsonBody != null) {
        final serverCredits = apiResponse.jsonBody!['credits'];
        if (serverCredits is int) {
          credits = serverCredits;
        }
      }

      await _persistCredits();
      isLoading = false;
      notifyListeners();
      return apiResponse;
    } catch (e) {
      if (kDebugMode) debugPrint('HomeController: submit failed: $e');
      isLoading = false;
      notifyListeners();
      return ApiCallResponse(statusCode: 500, bodyText: e.toString());
    }
  }

  Future<void> _persistCredits() async {
    try {
      await _secureStorage.write(key: _creditsKey, value: '$credits');
    } catch (e) {
      if (kDebugMode) debugPrint('HomeController: failed to persist credits: $e');
    }
  }
}
