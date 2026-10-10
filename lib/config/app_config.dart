import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application endpoints and runtime configuration loaded from .env.
class AppConfig {
  const AppConfig._();

  static const _defaultDevWorkerUrl = 'http://localhost:8787';
  static const _defaultProdWorkerUrl =
      'https://roast-rizz-api.rusobrg.workers.dev';

  static const String privacyPolicyUrl = 'https://sites.google.com/view/roastnrizzpolicy';

  static Future<void> loadEnv() async {
    await dotenv.load(fileName: '.env', isOptional: true);
  }

  static String get appEnvironment => dotenv.env['APP_ENV'] ?? 'prod';

  /// Cloudflare Worker endpoint. Uses separate dev/prod values when available.
  static String get workerUrl {
    final environment = appEnvironment.toLowerCase();

    if (environment == 'dev') {
      return dotenv.env['CLOUDFLARE_WORKER_URL_DEV'] ?? _defaultDevWorkerUrl;
    }

    return dotenv.env['CLOUDFLARE_WORKER_URL_PROD'] ?? _defaultProdWorkerUrl;
  }
}
