import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/totp/data/totp_service.dart';

void main() {
  group('TotpService remainingSeconds', () {
    test('derives remaining from wall clock, not OTP.lastUsedTime', () {
      final service = TotpService();
      const config = TotpConfig(secret: 'JBSWY3DPEHPK3PXP', period: 30);

      // generateCode writes OTP.lastUsedTime; remaining must ignore it.
      service.generateCode(config);

      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final actual = service.remainingSeconds(config);
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int rem(int sec) => 30 - (sec % 30);

      expect(actual, anyOf(rem(before), rem(after)));
      expect(actual, inInclusiveRange(1, 30));
    });
  });

  group('TotpService URI parsing', () {
    test('extracts account name and issuer for a scanned URI', () {
      final config = TotpService().parseUri(
        'otpauth://totp/GitHub:alice%40example.com'
        '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );

      expect(config, isNotNull);
      expect(config!.accountName, 'alice@example.com');
      expect(config.issuer, 'GitHub');
      expect(config.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('uses the label as account name when it has no issuer prefix', () {
      final config = TotpService().parseUri(
        'otpauth://totp/alice%40example.com?secret=JBSWY3DPEHPK3PXP',
      );

      expect(config, isNotNull);
      expect(config!.accountName, 'alice@example.com');
    });
  });
}