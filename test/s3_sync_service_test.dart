import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/features/sync/data/s3_config.dart';
import 'package:keestone/features/sync/data/s3_sync_service.dart';

void main() {
  group('signSigV4 (AWS published test vectors)', () {
    // Example: GET Object from the AWS S3 SigV4 header-based-auth docs
    // (bucket examplebucket, key test.txt, range header, 2013-05-24). The
    // expected signature below is the value published in the docs.
    test('matches the documented GET Object example byte for byte', () async {
      final result = await signSigV4(
        method: 'GET',
        canonicalUri: '/test.txt',
        hostHeader: 'examplebucket.s3.amazonaws.com',
        payloadHash: kEmptySha256Hex,
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        extraHeaders: const {'range': 'bytes=0-9'},
        now: DateTime.utc(2013, 5, 24, 0, 0, 0),
      );

      expect(result.amzDate, '20130524T000000Z');
      expect(result.dateStamp, '20130524');
      expect(
        result.authorization,
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,'
        'SignedHeaders=host;range;x-amz-content-sha256;x-amz-date,'
        'Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41',
      );
    });

    test('matches the documented PUT Object example', () async {
      // PUT Object from the AWS docs: payload "Welcome to Amazon S3.", a
      // Date header and the storage-class header.
      const payloadHash =
          '44ce7dd67c959e0d3524ffac1771dfbba87d2b6b4b4e99e42034a8b803f8b072';
      final result = await signSigV4(
        method: 'PUT',
        canonicalUri: '/test%24file.text',
        hostHeader: 'examplebucket.s3.amazonaws.com',
        payloadHash: payloadHash,
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        extraHeaders: const {
          'date': 'Fri, 24 May 2013 00:00:00 GMT',
          'x-amz-storage-class': 'REDUCED_REDUNDANCY',
        },
        now: DateTime.utc(2013, 5, 24, 0, 0, 0),
      );

      expect(
        result.authorization,
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,'
        'SignedHeaders=date;host;x-amz-content-sha256;x-amz-date;'
        'x-amz-storage-class,'
        'Signature=98ad721746da40c64f1a55b78f14c238d841ea1380cd77a1b5971af0ece108bd',
      );
    });

    test('matches the GET Bucket Lifecycle example with a query', () async {
      // GET Bucket Lifecycle with ?lifecycle= from the AWS docs.
      final query = canonicalQueryString([const MapEntry('lifecycle', '')]);
      expect(query, 'lifecycle=');
      final result = await signSigV4(
        method: 'GET',
        canonicalUri: '/',
        hostHeader: 'examplebucket.s3.amazonaws.com',
        payloadHash: kEmptySha256Hex,
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        queryParams: [const MapEntry('lifecycle', '')],
        now: DateTime.utc(2013, 5, 24, 0, 0, 0),
      );

      expect(
        result.authorization,
        'AWS4-HMAC-SHA256 '
        'Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request,'
        'SignedHeaders=host;x-amz-content-sha256;x-amz-date,'
        'Signature=fea454ca298b7da1c68078a5d1bdbfbbe0d65c699e0f91ac7a200a0136783543',
      );
    });

    test('signs a session token into the request', () async {
      final result = await signSigV4(
        method: 'GET',
        canonicalUri: '/test.txt',
        hostHeader: 'examplebucket.s3.amazonaws.com',
        payloadHash: kEmptySha256Hex,
        accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
        secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        region: 'us-east-1',
        extraHeaders: const {'x-amz-security-token': 'TOKEN'},
        now: DateTime.utc(2013, 5, 24, 0, 0, 0),
      );

      expect(
        result.authorization,
        contains('SignedHeaders=host;x-amz-content-sha256;x-amz-date;'
            'x-amz-security-token'),
      );
    });
  });

  group('awsUriEncode / encodeS3KeyPath', () {
    test('encodes per the AWS strict rules with uppercase hex', () {
      expect(awsUriEncode('a-zA-Z0-9-._~'), 'a-zA-Z0-9-._~');
      expect(awsUriEncode('my vault'), 'my%20vault');
      expect(awsUriEncode('db#1'), 'db%231');
      expect(awsUriEncode('密码库'), '%E5%AF%86%E7%A0%81%E5%BA%93');
    });

    test('keeps path separators unencoded', () {
      expect(encodeS3KeyPath('vaults/my db/database.kdbx'),
          'vaults/my%20db/database.kdbx');
    });
  });

  group('canonicalQueryString', () {
    test('sorts by key then value and encodes pairs', () {
      expect(
        canonicalQueryString([
          const MapEntry('b', '2'),
          const MapEntry('a', 'z'),
          const MapEntry('a', 'x'),
        ]),
        'a=x&a=z&b=2',
      );
      expect(canonicalQueryString(const []), '');
    });
  });

  group('S3SyncConfig', () {
    const config = S3SyncConfig(
      id: 's3_1',
      name: 'S3',
      endpoint: 'https://play.min.io',
      region: 'us-east-1',
      bucket: 'keevault',
      accessKeyId: 'AKIA',
      secretAccessKey: 'secret',
      remotePath: '/vaults/',
      remoteFilename: 'db.kdbx',
    );

    test('joins the object key from prefix and filename', () {
      expect(config.objectKey, 'vaults/db.kdbx');
      expect(
        config.copyWith(remotePath: '').objectKey,
        'db.kdbx',
      );
      expect(
        config.copyWith(remotePath: 'a//b', remoteFilename: '').objectKey,
        'a/b/database.kdbx',
      );
    });

    test('builds the request path identically for wire and signature', () {
      // Path-style: the bucket is part of the path (and canonical URI).
      expect(config.requestPath(null), '/keevault/');
      expect(config.requestPath('vaults/db.kdbx'), '/keevault/vaults/db.kdbx');
      expect(
        config.requestPath('vaults/my db/密码库.kdbx'),
        '/keevault/vaults/my%20db/%E5%AF%86%E7%A0%81%E5%BA%93.kdbx',
      );
      // Virtual-host style: the bucket lives in the host.
      final virtual = config.copyWith(usePathStyle: false);
      expect(virtual.requestPath(null), '/');
      expect(virtual.requestPath('vaults/db.kdbx'), '/vaults/db.kdbx');
    });

    test('builds path-style and virtual-host request URLs', () {
      expect(config.requestUrl(config.requestPath('vaults/db.kdbx')),
          'https://play.min.io/keevault/vaults/db.kdbx');
      expect(config.requestUrl(config.requestPath(null)),
          'https://play.min.io/keevault/');
      final virtual = config.copyWith(usePathStyle: false);
      expect(virtual.requestUrl(virtual.requestPath('vaults/db.kdbx')),
          'https://keevault.play.min.io/vaults/db.kdbx');
      expect(virtual.requestHost(), 'keevault.play.min.io');
    });

    test('validates the endpoint scheme', () {
      expect(config.usesInsecureHttp, isFalse);
      expect(
        () => config.copyWith(endpoint: 'ftp://x').endpointUri,
        throwsFormatException,
      );
      expect(
        config.copyWith(endpoint: 'http://minio.local:9000').usesInsecureHttp,
        isTrue,
      );
    });

    test('round-trips through JSON', () {
      final decoded = S3SyncConfig.decode(config.encode());
      expect(decoded, config);
      // Defaults survive older payloads that lack the newer fields.
      final fromPartial = S3SyncConfig.fromJson({
        'id': 's3_2',
        'name': 'S3',
        'endpoint': 'https://s3.example.com',
        'bucket': 'b',
      });
      expect(fromPartial.usePathStyle, isTrue);
      expect(fromPartial.remoteFilename, 'database.kdbx');
      expect(fromPartial.enabled, isFalse);
    });
  });
}
