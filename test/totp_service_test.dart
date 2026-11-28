import 'package:flutter_test/flutter_test.dart';
import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/totp/data/totp_service.dart';

KdbxEntry _emptyEntry() {
  final meta = KdbxMeta.create();
  final group = KdbxGroup.create(
    name: 'root',
    icon: KdbxIcon.folder,
    id: KdbxUuid.random(),
  );
  return KdbxEntry.create(parent: group, meta: meta, id: KdbxUuid.random());
}

void main() {
  const sampleSeed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
  final fixedTime = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);

  group('TOTP from external KDBX fields', () {
    final service = TotpService();

    test('reads a protected otp URI with its custom options', () {
      final entry = _emptyEntry();
      entry.fields['otp'] = KdbxTextField.fromText(
        text:
            '  otpauth://totp/Test:Account%252Fname'
            '?secret=$sampleSeed&period=29&digits=8&algorithm=SHA1  ',
        protected: true,
      );

      expect(service.hasTotp(entry), isTrue);
      final config = service.loadFromEntry(entry)!;
      expect(config.accountName, 'Account%2Fname');
      expect(config.issuer, 'Test');
      expect(config.period, 29);
      expect(service.remainingSeconds(config, at: fixedTime), 28);
      expect(service.timeWindow(config, fixedTime), 2);
      final nextStep = fixedTime.add(const Duration(seconds: 29));
      expect(service.remainingSeconds(config, at: nextStep), 28);
      expect(service.timeWindow(config, nextStep), 3);
    });

    test('reads seed settings and falls back past an invalid URI', () {
      final entry = _emptyEntry();
      entry.fields['otp'] = KdbxTextField.fromText(
        text: 'otpauth://totp/Test?secret=$sampleSeed&period=0',
      );
      entry.fields['TOTP Seed'] = KdbxTextField.fromText(text: sampleSeed);
      entry.fields['TOTP Settings'] = KdbxTextField.fromText(text: '30;8');

      final config = service.loadFromEntry(entry)!;
      expect(config.period, 30);
      expect(config.digits, 8);
      expect(service.generateCode(config, at: fixedTime), '94287082');
      entry.fields.remove('TOTP Settings');
      expect(
        service.generateCode(service.loadFromEntry(entry)!, at: fixedTime),
        '287082',
      );
    });

    test('matches RFC 6238 vectors for SHA-256 and SHA-512', () {
      const seedBlock = 'GEZDGNBVGY3TQOJQ';
      final vectors = {
        'SHA256': ('$seedBlock$seedBlock${seedBlock}GEZA====', '46119246'),
        'SHA512': ('${List.filled(6, seedBlock).join()}GEZDGNA=', '90693936'),
      };
      for (final MapEntry(key: algorithm, value: (seed, expected))
          in vectors.entries) {
        final entry = _emptyEntry();
        entry.fields['otp'] = KdbxTextField.fromText(
          text:
              'otpauth://totp/Test?secret=$seed&digits=8&algorithm=$algorithm',
        );
        expect(
          service.generateCode(service.loadFromEntry(entry)!, at: fixedTime),
          expected,
        );
      }
    });

    test('does not enumerate malformed or unsupported TOTP', () {
      for (final uri in [
        'otpauth://totp/Test?secret=ABC0',
        'otpauth://totp/Test?secret=A',
        'otpauth://totp/Test?secret=$sampleSeed&digits=-1',
        'otpauth://totp/Test?secret=$sampleSeed&algorithm=MD5',
        'otpauth://totp/Test?secret=$sampleSeed&encoder=steam',
        'otpauth://totp/Test?secret=%FF',
        'otpauth://hotp/Test?secret=$sampleSeed',
      ]) {
        final entry = _emptyEntry();
        entry.fields['otp'] = KdbxTextField.fromText(text: uri);
        expect(service.hasTotp(entry), isFalse, reason: uri);
        expect(service.loadFromEntry(entry), isNull, reason: uri);
      }
    });

    test('replaces recognized formats and removes all valid fallbacks', () {
      final entry = _emptyEntry();
      entry.fields['otp'] = KdbxTextField.fromText(
        text: 'otpauth://totp/Test?secret=$sampleSeed',
      );
      entry.fields['TOTP Seed'] = KdbxTextField.fromText(text: sampleSeed);
      entry.fields['TOTP Settings'] = KdbxTextField.fromText(text: '30;6');
      const config = TotpConfig(secret: sampleSeed, period: 45, digits: 8);

      service.replaceInEntry(entry, config);
      expect(entry.fields['otp'], isA<ProtectedTextField>());
      expect(service.parseUri(entry.fields['otp']!.text)?.period, 45);
      expect(entry.fields, isNot(contains('TOTP Seed')));
      expect(entry.fields, isNot(contains('TimeOtp-Period')));
      expect(service.loadFromEntry(entry)?.digits, 8);

      service.removeFromEntry(entry);
      expect(service.hasTotp(entry), isFalse);
      expect(entry.fields, isNot(contains('otp')));
    });
  });

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

  group('TotpService KeePass field compatibility', () {
    test('detects TimeOtp-Secret-Base32 on entry fields', () {
      final entry = _emptyEntry();
      entry.fields['TimeOtp-Secret-Base32'] = KdbxTextField.fromText(
        text: 'JBSWY3DPEHPK3PXP',
        protected: true,
      );
      entry.fields['TimeOtp-Period'] = KdbxTextField.fromText(text: '30');
      entry.fields['TimeOtp-Length'] = KdbxTextField.fromText(text: '6');
      entry.fields['TimeOtp-Algorithm'] = KdbxTextField.fromText(
        text: 'HMAC-SHA-1',
      );

      final service = TotpService();
      expect(service.hasTotp(entry), isTrue);
      final config = service.loadFromEntry(entry);
      expect(config, isNotNull);
      expect(config!.secret, 'JBSWY3DPEHPK3PXP');
      expect(config.period, 30);
      expect(config.digits, 6);
      expect(service.generateCode(config).length, 6);
    });

    test('detects otpauth URI stored in TOTP custom field', () {
      final entry = _emptyEntry();
      entry.fields['TOTP'] = KdbxTextField.fromText(
        text:
            'otpauth://totp/GitHub:alice%40example.com'
            '?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
      );

      final service = TotpService();
      expect(service.hasTotp(entry), isTrue);
      final config = service.loadFromEntry(entry);
      expect(config, isNotNull);
      expect(config!.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('still reads legacy customData TimeOtp-Secret', () {
      final entry = _emptyEntry();
      entry.customData = KdbxCustomData();
      entry.customData!.map['TimeOtp-Secret'] = KdbxCustomItem(
        value: 'JBSWY3DPEHPK3PXP',
      );

      final service = TotpService();
      expect(service.hasTotp(entry), isTrue);
      final config = service.loadFromEntry(entry);
      expect(config, isNotNull);
      expect(config!.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('saveToEntry writes KeePass TimeOtp-Secret-Base32 field', () {
      final entry = _emptyEntry();
      TotpService().saveToEntry(
        entry,
        const TotpConfig(secret: 'JBSWY3DPEHPK3PXP', period: 30, digits: 6),
      );

      expect(entry.fields['TimeOtp-Secret-Base32']?.text, 'JBSWY3DPEHPK3PXP');
      expect(entry.fields['TimeOtp-Length']?.text, '6');
      expect(TotpService().hasTotp(entry), isTrue);
    });

    test('migrateLegacyTotp copies customData secret into standard fields', () {
      final entry = _emptyEntry();
      entry.customData = KdbxCustomData();
      entry.customData!.map['TimeOtp-Secret'] = KdbxCustomItem(
        value: 'JBSWY3DPEHPK3PXP',
      );
      entry.customData!.map['TimeOtp-Period'] = KdbxCustomItem(value: '30');
      entry.customData!.map['TimeOtp-Size'] = KdbxCustomItem(value: '6');

      final service = TotpService();
      expect(service.migrateLegacyTotp(entry), isTrue);
      expect(entry.fields['TimeOtp-Secret-Base32']?.text, 'JBSWY3DPEHPK3PXP');
      // Second run is a no-op once the standard field exists.
      expect(service.migrateLegacyTotp(entry), isFalse);
    });
  });
}
