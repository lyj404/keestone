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

  test('short nonempty timestamps are rejected', () {
    for (var size = 1; size < 8; size++) {
      expect(
        () => KdbxTime.fromXmlText(
          text: base64.encode(Uint8List(size)),
          isBinary: true,
        ),
        throwsFormatException,
      );
    }
  });

  test('valid binary timestamps round trip', () {
    final time = KdbxTime(DateTime.utc(2024, 1, 2));
    final encoded = time.toXmlText(isBinary: true)!;
    expect(KdbxTime.fromXmlText(text: encoded, isBinary: true).time, time.time);
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
