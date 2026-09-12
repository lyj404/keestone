import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/sync_service.dart';

enum SyncState { idle, syncing, success, error, conflict }

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);
