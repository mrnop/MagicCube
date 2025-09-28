import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  AnalyticsService._internal();

  String? _androidId;
  bool _isInitialized = false;

  String? get androidId => _androidId;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _androidId = androidInfo.id;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        _androidId = iosInfo.identifierForVendor;
      } else {
        _androidId = 'web_or_desktop_id';
      }

      _isInitialized = true;
      if (kDebugMode) {
        print('Analytics initialized with ID: $_androidId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize analytics: $e');
      }
      _androidId = 'unknown';
      _isInitialized = true;
    }
  }

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (!_isInitialized) return;

    if (kDebugMode) {
      print('Analytics Event: $eventName');
      if (parameters != null) {
        print('Parameters: $parameters');
      }
    }

    // In a real app, you would send this to Firebase Analytics or another service
  }

  void logScreenView(String screenName) {
    logEvent('screen_view', parameters: {'screen_name': screenName});
  }

  void logProjectCreated(String templateName) {
    logEvent('project_created', parameters: {'template': templateName});
  }

  void logImageCropped() {
    logEvent('image_cropped');
  }
}
