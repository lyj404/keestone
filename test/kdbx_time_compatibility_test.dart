import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kpasslib/kpasslib.dart';
import 'package:keestone/features/database/data/database_service.dart';
import 'package:xml/xml.dart';

class _EmptyBinaryTime extends KdbxTime {
  @override
  String? toXmlText({required bool isBinary}) => isBinary ? '' : null;
}

class _TextBinaryTime extends KdbxTime {
  _TextBinaryTime(super.time);

  @override
  String? toXmlText({required bool isBinary}) => time?.toIso8601String();
}

void main() {
  test('generic parser exceptions are not declared database corruption', () {
    expect(isCorruptionError(RangeError('short')), isFalse);
    expect(
      isCorruptionError(const FormatException('invalid timestamp')),
      isFalse,
    );
    expect(isCorruptionError(FileCorruptedError('bad header')), isTrue);
  });
  test('empty KDBX 4 timestamp is treated as absent', () {
    expect(KdbxTime.fromXmlText(text: '', isBinary: true).time, isNull);
  });

  test('short nonempty timestamps are treated as absent', () {
    for (var size = 1; size < 8; size++) {
      expect(
        KdbxTime.fromXmlText(
          text: base64.encode(Uint8List(size)),
          isBinary: true,
        ).time,
        isNull,
      );
    }
  });

  test('valid binary timestamps round trip', () {
    final time = KdbxTime(DateTime.utc(2024, 1, 2));
    final encoded = time.toXmlText(isBinary: true)!;
    expect(KdbxTime.fromXmlText(text: encoded, isBinary: true).time, time.time);
  });

  test('KDBX 4 timestamps accept ISO 8601 text and ignore invalid text', () {
    for (final text in ['2025-12-24T15:36:16Z', '2025-12-24T17:36:16+02:00']) {
      expect(
        KdbxTime.fromXmlText(text: text, isBinary: true).time,
        DateTime.utc(2025, 12, 24, 15, 36, 16),
      );
    }
    expect(
      KdbxTime.fromXmlText(text: 'invalid:timestamp', isBinary: true).time,
      isNull,
    );
  });

  test('opens and saves a database with text custom icon times', () async {
    final directory = await Directory.systemTemp.createTemp('kdbx_icon_time');
    final file = File('${directory.path}/test.kdbx');
    final service = DatabaseService();
    final iconId = KdbxUuid.random();
    final modified = DateTime.utc(2025, 12, 24, 15, 36, 16);
    final iconData = [1, 2, 3, 4];

    void verify() {
      final icon = service.db!.meta.customIcons[iconId]!;
      expect(icon.data, iconData);
      expect(icon.name, 'custom icon');
      expect(icon.modified.time, modified);
      expect(
        service.db!.meta.customData.map['key']!.modification.time,
        modified,
      );
    }

    try {
      await service.createDatabase('test', 'test-password', file.path);
      service.db!.meta.customIcons[iconId] = KdbxCustomIcon(
        data: iconData,
        name: 'custom icon',
        modified: _TextBinaryTime(modified),
      );
      service.db!.meta.customData.map['key'] = KdbxCustomItem(
        value: 'value',
        modification: _TextBinaryTime(modified),
      );
      await file.writeAsBytes(await service.saveToBytes());
      service.close();
      await service.openFile(file.path, 'test-password');
      verify();
      await file.writeAsBytes(await service.saveToBytes());
      service.close();
      await service.openFile(file.path, 'test-password');
      verify();
    } finally {
      if (service.isOpen) service.close();
      await directory.delete(recursive: true);
    }
  });

  test('empty timestamps in entry metadata can be parsed and serialized', () {
    final xml = XmlDocument.parse(
      '<Times><CreationTime></CreationTime>'
      '<LastModificationTime>AAAAAAAAAAA=</LastModificationTime>'
      '</Times>',
    );
    final times = KdbxTimes.fromXml(node: xml.rootElement, isBinary: true);
    expect(times.creation.time, isNull);
    final saved = times.toXml(isBinary: true);
    final reread = KdbxTimes.fromXml(node: saved as XmlElement, isBinary: true);
    expect(reread.creation.time, isNull);
    expect(reread.modification.time, times.modification.time);
  });

  test('opens and saves a KDBX with an empty entry timestamp', () async {
    final directory = await Directory.systemTemp.createTemp('kdbx_time_test');
    final file = File('${directory.path}/test.kdbx');
    final service = DatabaseService();
    try {
      await service.createDatabase('test', 'test-password', file.path);
      final entry = service.createEntry(service.db!.root);
      entry.fields['Title'] = KdbxTextField.fromText(text: 'test entry');
      entry.times.creation = _EmptyBinaryTime();
      await file.writeAsBytes(await service.saveToBytes());
      service.close();
      await service.openFile(file.path, 'test-password');
      expect(service.allEntries.single.times.creation.time, isNull);
      expect(service.allEntries.single.fields['Title']?.text, 'test entry');
      await file.writeAsBytes(await service.saveToBytes());
      service.close();
      await service.openFile(file.path, 'test-password');
      expect(service.allEntries.single.times.creation.time, isNull);
    } finally {
      if (service.isOpen) service.close();
      await directory.delete(recursive: true);
    }
  });
}
