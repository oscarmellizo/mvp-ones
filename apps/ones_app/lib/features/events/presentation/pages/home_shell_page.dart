import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../../tutorial/presentation/tutorial_store.dart';
import '../../../tutorial/presentation/tutorial_controller.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import 'create_event_page.dart';
import 'events_list_page.dart';
import 'galleries_page.dart';
import 'profile_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _index = 0;
  String? _lastLanguage;

  static const Set<String> _homeRequiredKeys = {
    'nav.home',
    'nav.galleries',
    'nav.profile',
    'home.search_events',
    'home.today',
    'home.next_events',
    'home.live_now',
    'home.no_upcoming_events',
    'common.error',
  };

  static const _pages = [
    EventsListPage(),
    GalleriesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'home',
            requiredKeys: _homeRequiredKeys,
          );
      // Autodisparo en primer arranque (sin i18n, sólo español)
      () async {
        final show = await TutorialStore().shouldShow(
          firstLaunch: true,
          routeName: EventsListPage.routeName,
        );
        if (show && mounted) {
          TutorialController.instance.start(
            context,
            routeName: EventsListPage.routeName,
          );
        }
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final translationsService = context.watch<TranslationsService>();
    final lang = translationsService.getCurrentLanguage();

    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TranslationsService>().ensurePageTranslations(
              page: 'home',
              requiredKeys: _homeRequiredKeys,
            );
      });
    }

    return Scaffold(
      body: _pages[_index],
      floatingActionButton: FloatingActionButton(
        key: TutorialKeys.homeFabCreate,
        onPressed: () =>
            Navigator.of(context).pushNamed(CreateEventPage.routeName),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: OnesColors.purpleMid.withOpacity(0.18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontWeight: FontWeight.w800,
              color: states.contains(WidgetState.selected)
                  ? OnesColors.purpleMid
                  : Colors.black54,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? OnesColors.purpleMid
                  : Colors.black54,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              key: TutorialKeys.homeTabHome,
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: translationsService.translate('nav.home'),
            ),
            NavigationDestination(
              key: TutorialKeys.homeTabGalleries,
              icon: const Icon(Icons.photo_library_outlined),
              selectedIcon: const Icon(Icons.photo_library),
              label: translationsService.translate('nav.galleries'),
            ),
            NavigationDestination(
              key: TutorialKeys.homeTabProfile,
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: translationsService.translate('nav.profile'),
            ),
          ],
        ),
      ),
    );
  }
}
