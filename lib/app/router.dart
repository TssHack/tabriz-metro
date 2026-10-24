import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/about/about_screen.dart';
import '../features/automations/automations_screen.dart';
import '../features/home/home_screen.dart';
import '../features/line_map/line_map_screen.dart';
import '../features/location/location_permission_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stations/stations_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/trip/trip_planner_screen.dart';
import '../features/update/update_screen.dart';
import '../l10n/generated/app_localizations.dart';

abstract final class Routes {
  static const home = '/';
  static const map = '/map';
  static const timetable = '/timetable';
  static const stations = '/stations';
  static const settings = '/settings';
  static const automations = '/automations';
  static const trip = '/trip';
  static const location = '/location';
  static const update = '/update';
  static const about = '/about';

  static String stationTimetable(String id) => '/station/$id';
  static String tripFromTo({String? from, String? to}) =>
      Uri(path: trip, queryParameters: {'from': ?from, 'to': ?to}).toString();
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.map,
                builder: (_, _) => const LineMapScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.timetable,
                builder: (_, _) => const TimetableScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stations,
                builder: (_, _) => const StationsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/station/:id',
        builder: (_, state) => TimetableScreen(
          stationId: state.pathParameters['id'],
          standalone: true,
        ),
      ),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: Routes.automations,
        builder: (_, _) => const AutomationsScreen(),
      ),
      GoRoute(
        path: Routes.trip,
        builder: (_, state) => TripPlannerScreen(
          fromId: state.uri.queryParameters['from'],
          toId: state.uri.queryParameters['to'],
        ),
      ),
      GoRoute(
        path: Routes.location,
        builder: (_, _) => const LocationPermissionScreen(),
      ),
      GoRoute(path: Routes.update, builder: (_, _) => const UpdateScreen()),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // In RTL the first destination sits on the right, giving
    // خانه، نقشه خط، زمان‌بندی، ایستگاه‌ها from right to left.
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.house),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.route),
            label: l.navMap,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.clock),
            label: l.navTimetable,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.list),
            label: l.navStations,
          ),
        ],
      ),
    );
  }
}
