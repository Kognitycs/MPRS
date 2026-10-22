/// Copy this file to app_secrets.dart and fill in the values.
/// app_secrets.dart is gitignored and must not be pushed.
class AppSecrets {
  AppSecrets._();

  static const secretKey = '';
  static const publishKey = '';

  static const Map<String, String> apiKeyHeaders = {
    'secret_key': secretKey,
    'publish_key': publishKey,
  };

  static const firebaseAndroidApiKey = '';
  static const firebaseIosApiKey = '';
}
