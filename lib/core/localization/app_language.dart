import 'package:flutter/foundation.dart';

class AppLanguageController {
  const AppLanguageController._();

  static const defaultLanguageCode = 'tr';
  static const supportedLanguageCodes = <String>['tr', 'en', 'de'];

  static final ValueNotifier<String> languageCode = ValueNotifier<String>(
    defaultLanguageCode,
  );

  static String normalize(String? code) {
    if (code != null && supportedLanguageCodes.contains(code)) {
      return code;
    }
    return defaultLanguageCode;
  }

  static void setLanguageCode(String code) {
    final normalizedCode = normalize(code);
    if (languageCode.value != normalizedCode) {
      languageCode.value = normalizedCode;
    }
  }

  static String labelForCode(String code) {
    switch (normalize(code)) {
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'tr':
      default:
        return 'Türkçe';
    }
  }
}
