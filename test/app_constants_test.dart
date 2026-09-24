import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/constants/app_constants.dart';

void main() {
  group('AppConstants.isInternalField', () {
    test('covers identity and TOTP bookkeeping keys', () {
      expect(AppConstants.isInternalField('Title'), isTrue);
      expect(AppConstants.isInternalField('Password'), isTrue);
      expect(AppConstants.isInternalField('TimeOtp-Secret-Base32'), isTrue);
      expect(AppConstants.isInternalField('TimeOtp-Period'), isTrue);
      expect(AppConstants.isInternalField('TOTP'), isTrue);
      expect(AppConstants.isInternalField('TimeOtp-Custom-Whatever'), isTrue);
    });

    test('allows genuine custom fields', () {
      expect(AppConstants.isInternalField('API Key'), isFalse);
      expect(AppConstants.isInternalField('Account ID'), isFalse);
    });
  });
}
