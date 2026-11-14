import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/private_network/gbm_update_settings.dart';

void main() {
  group('GBM update settings helpers', () {
    test('manifest URL selects platform specific manifest', () {
      expect(
        gbmUpdateManifestUrl(isWindows: true),
        'https://raw.githubusercontent.com/SuZiYan611/hiddify-app/private-network/updates/windows.json',
      );
      expect(
        gbmUpdateManifestUrl(isWindows: false),
        'https://raw.githubusercontent.com/SuZiYan611/hiddify-app/private-network/updates/android.json',
      );
    });

    test('version parsing and comparison', () {
      expect(parseGbmVersion('private-network-v0.1.0-test4'), [0, 1, 0, 4]);
      expect(parseGbmVersion('private-network-v0.1.0-test5'), [0, 1, 0, 5]);
      expect(parseGbmVersion('private-network-v0.1.0'), [0, 1, 0, 1000000]);
      expect(parseGbmVersion('invalid-tag'), isNull);

      expect(compareGbmTags('private-network-v0.1.0-test5', 'private-network-v0.1.0-test4'), greaterThan(0));
      expect(compareGbmTags('private-network-v0.1.0-test4', 'private-network-v0.1.0-test5'), lessThan(0));
      expect(compareGbmTags('private-network-v0.1.0-test5', 'private-network-v0.1.0-test5'), equals(0));
      expect(compareGbmTags('private-network-v0.1.0', 'private-network-v0.1.0-test5'), greaterThan(0));
    });

    test('selects Windows zip asset when uploaded', () {
      final release = {
        'assets': [
          {
            'name': 'GBM-Windows-x64.zip',
            'state': 'uploaded',
            'browser_download_url': 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Windows-x64.zip',
          },
          {
            'name': 'GBM-Android-arm64-debug.apk',
            'state': 'uploaded',
            'browser_download_url': 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Android-arm64-debug.apk',
          },
        ],
      };

      final winUrl = selectGbmDownloadUrl(release, isWindows: true, isAndroid: false);
      expect(winUrl, 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Windows-x64.zip');

      final pendingRelease = {
        'assets': [
          {
            'name': 'GBM-Windows-x64.zip',
            'state': 'starter',
            'browser_download_url': 'https://example.com',
          },
        ],
      };
      expect(selectGbmDownloadUrl(pendingRelease, isWindows: true, isAndroid: false), isNull);
    });

    test('selects Android apk asset based on ABI when uploaded', () {
      final release = {
        'assets': [
          {
            'name': 'GBM-Android-arm64-debug.apk',
            'state': 'uploaded',
            'browser_download_url': 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Android-arm64-debug.apk',
          },
          {
            'name': 'GBM-Android-x86_64-debug.apk',
            'state': 'uploaded',
            'browser_download_url': 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Android-x86_64-debug.apk',
          },
        ],
      };

      final arm64Url = selectGbmDownloadUrl(
        release,
        isWindows: false,
        isAndroid: true,
        androidAbis: ['arm64-v8a'],
      );
      expect(arm64Url, 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Android-arm64-debug.apk');

      final x86Url = selectGbmDownloadUrl(
        release,
        isWindows: false,
        isAndroid: true,
        androidAbis: ['x86_64'],
      );
      expect(x86Url, 'https://github.com/SuZiYan611/hiddify-app/releases/download/v5/GBM-Android-x86_64-debug.apk');
    });
  });
}
