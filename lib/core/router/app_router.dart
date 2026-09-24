import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/database/providers/database_provider.dart';
import '../../features/database/screens/welcome_screen.dart';
import '../../features/database/screens/unlock_screen.dart';
import '../../features/database/screens/create_database_screen.dart';
import '../../features/explorer/screens/explorer_screen.dart';
import '../../features/entry/screens/entry_detail_screen.dart';
import '../../features/entry/screens/entry_edit_screen.dart';
import '../../features/entry/screens/entry_history_screen.dart';
import '../../features/group/screens/group_edit_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/backup/screens/backup_screen.dart';
import '../../features/audit/screens/password_audit_screen.dart';
import '../../features/about/screens/about_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter(Ref ref) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/welcome',
  redirect: (context, state) {
    const protectedPrefixes = [
      '/explorer',
      '/entry/',
      '/group/',
      '/search',
      '/backup',
      '/audit',
    ];
    final protected = protectedPrefixes.any(
      (prefix) => state.uri.path.startsWith(prefix),
    );
    if (protected && !ref.read(databaseServiceProvider).isOpen) {
      return '/welcome';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/unlock',
      builder: (context, state) {
        final filePath = state.uri.queryParameters['path'] ?? '';
        final isCloud = state.uri.queryParameters['cloud'] == 'true';
        final webDavProfileId = state.uri.queryParameters['profile'];
        final syncedETag = state.uri.queryParameters['etag'];
        return UnlockScreen(
          filePath: filePath,
          isCloud: isCloud,
          webDavProfileId: webDavProfileId,
          syncedETag: syncedETag,
        );
      },
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreateDatabaseScreen(),
    ),
    GoRoute(
      path: '/explorer',
      builder: (context, state) => const ExplorerScreen(),
    ),
    GoRoute(
      path: '/entry/detail',
      builder: (context, state) {
        final entryUuid = state.uri.queryParameters['uuid'] ?? '';
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return EntryDetailScreen(entryUuid: entryUuid, groupPath: groupPath);
      },
    ),
    GoRoute(
      path: '/entry/edit',
      builder: (context, state) {
        final entryUuid = state.uri.queryParameters['uuid'];
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return EntryEditScreen(entryUuid: entryUuid, groupPath: groupPath);
      },
    ),
    GoRoute(
      path: '/entry/history',
      builder: (context, state) {
        final entryUuid = state.uri.queryParameters['uuid'] ?? '';
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return EntryHistoryScreen(entryUuid: entryUuid, groupPath: groupPath);
      },
    ),
    GoRoute(
      path: '/group/edit',
      builder: (context, state) {
        final groupPath = state.uri.queryParameters['groupPath'] ?? '';
        return GroupEditScreen(groupPath: groupPath);
      },
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(path: '/backup', builder: (context, state) => const BackupScreen()),
    GoRoute(
      path: '/audit',
      builder: (context, state) => const PasswordAuditScreen(),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
  ],
);
