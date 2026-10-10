import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AdConfig {
  const AdConfig._();

  // Google's official test ad unit IDs — always fill, safe for development
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';

  static String _readEnvValue(String key, String fallback) =>
      dotenv.env[key] ?? fallback;

  static String get rewardedAdUnitId {
    // In debug mode, ALWAYS use Google's test IDs to guarantee fill
    if (kDebugMode) {
      return Platform.isIOS ? _testRewardedIOS : _testRewardedAndroid;
    }

    // In release mode, use production IDs from .env
    if (Platform.isAndroid) {
      return _readEnvValue('ADMOB_REWARDED_AD_UNIT_ANDROID', _testRewardedAndroid);
    } else if (Platform.isIOS) {
      return _readEnvValue('ADMOB_REWARDED_AD_UNIT_IOS', _testRewardedIOS);
    }

    return '';
  }
}
