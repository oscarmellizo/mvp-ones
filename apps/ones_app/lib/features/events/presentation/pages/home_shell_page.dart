import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../invitations/presentation/invitations_controller.dart';
import '../../../invitations/presentation/widgets/invitations_sheet.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../../tutorial/presentation/tutorial_store.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import 'create_event_page.dart';
import 'events_list_page.dart';
import 'galleries_page.dart';
import 'profile_page.dart';
import 'event_join_scan_page.dart';
import 'event_join_code_page.dart';
import '../../../account/presentation/pages/account_page.dart';
import '../../../account/presentation/pages/about_page.dart';
import '../../../tutorial/presentation/tutorial_controller.dart';
import '../../../collections/presentation/pages/collection_join_qr_page.dart';
import '../../../collections/presentation/pages/create_collection_page.dart';
import '../../../collections/presentation/pages/home_collections_events_page.dart';

class HomeShellPage extends StatefulWidget {
  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

enum _DrawerDest { perfil, cuenta, acercaDe }

class _MainDrawer extends StatelessWidget {
  final ValueChanged<_DrawerDest> onSelect;
  const _MainDrawer({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Center(
                child: Image(
                  image: AssetImage('assets/splash/symbol_purple.png'),
                  width: 96,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil'),
              onTap: () => onSelect(_DrawerDest.perfil),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cuenta'),
              onTap: () => onSelect(_DrawerDest.cuenta),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de'),
              onTap: () => onSelect(_DrawerDest.acercaDe),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeShellPageState extends State<HomeShellPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  int _homeTabIndex = 0;
  String? _lastLanguage;
  bool _isFabMenuExpanded = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TranslationsService>().ensurePageTranslations(
            page: 'home',
            requiredKeys: _homeRequiredKeys,
          );
      unawaited(context.read<InvitationsController>().refresh());
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
      key: _scaffoldKey,
      backgroundColor: OnesColors.surfaceWarm,
      drawer: _MainDrawer(
        onSelect: (dest) {
          Navigator.of(context).pop();
          if (dest == _DrawerDest.perfil) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          } else if (dest == _DrawerDest.cuenta) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountPage()),
            );
          } else if (dest == _DrawerDest.acercaDe) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage()),
            );
          }
        },
      ),
      body: Stack(
        children: [
          if (_index == 0)
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _HomeHeader(
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                    onHelp: () => TutorialController.instance.start(
                      context,
                      routeName: EventsListPage.routeName,
                    ),
                    onBell: () => showInvitationsSheet(context),
                  ),
                ),
                Expanded(
                  child: HomeCollectionsEventsPage(
                    onTabChanged: (tab) {
                      if (_homeTabIndex == tab) return;
                      setState(() {
                        _homeTabIndex = tab;
                        _isFabMenuExpanded = false;
                      });
                    },
                  ),
                ),
              ],
            )
          else
            const GalleriesPage(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isFabMenuExpanded,
              child: Semantics(
                excludeSemantics: true,
                child: AnimatedOpacity(
                  opacity: _isFabMenuExpanded ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _isFabMenuExpanded = false),
                    child: ColoredBox(
                      color: OnesColors.black.withOpacity(0.32),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.bottomRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (_isFabMenuExpanded && _index == 0 && _homeTabIndex == 0) ...[
              _buildFabMenuAction(
                animationIndex: 0,
                icon: Icons.collections_bookmark_outlined,
                label: translationsService.translate(
                  'collections.create',
                  fallback: 'Crear colección',
                ),
                onTap: () {
                  setState(() => _isFabMenuExpanded = false);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateCollectionPage(),
                    ),
                  );
                },
              ),
              _buildFabMenuAction(
                animationIndex: 1,
                icon: Icons.qr_code_scanner,
                label: translationsService.translate(
                  'collections.scan_qr',
                  fallback: 'Escanear QR de colección',
                ),
                onTap: () {
                  setState(() => _isFabMenuExpanded = false);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CollectionJoinQrPage(),
                    ),
                  );
                },
              ),
            ] else if (_isFabMenuExpanded) ...[
              _buildFabMenuAction(
                animationIndex: 0,
                icon: Icons.event,
                label: translationsService.translate(
                  'home.action_create_event',
                  fallback: 'Crear evento',
                ),
                onTap: () {
                  setState(() => _isFabMenuExpanded = false);
                  Navigator.of(context).pushNamed(CreateEventPage.routeName);
                },
              ),
              _buildFabMenuAction(
                animationIndex: 1,
                icon: Icons.qr_code_scanner,
                label: translationsService.translate(
                  'home.action_scan_event_qr',
                  fallback: 'Escanear QR de evento',
                ),
                onTap: () {
                  setState(() => _isFabMenuExpanded = false);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EventJoinScanPage(),
                    ),
                  );
                },
              ),
              _buildFabMenuAction(
                animationIndex: 2,
                icon: Icons.dialpad,
                label: translationsService.translate(
                  'home.action_enter_event_code',
                  fallback: 'Ingresar código de evento',
                ),
                onTap: () {
                  setState(() => _isFabMenuExpanded = false);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EventJoinCodePage(),
                    ),
                  );
                },
              ),
            ],
            FloatingActionButton(
              key: TutorialKeys.homeFabCreate,
              onPressed: () => setState(
                () => _isFabMenuExpanded = !_isFabMenuExpanded,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _isFabMenuExpanded ? Icons.close : Icons.add,
                  key: ValueKey(_isFabMenuExpanded),
                ),
              ),
            ),
          ],
        ),
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
          onDestinationSelected: (i) => setState(() {
            _index = i;
            _isFabMenuExpanded = false;
          }),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenuAction({
    required int animationIndex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final borderRadius = BorderRadius.circular(28);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 160 + (animationIndex * 60)),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        ),
        child: Semantics(
          button: true,
          label: label,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 6,
              borderRadius: borderRadius,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: OnesColors.purpleMid),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback onHelp;
  final VoidCallback onBell;

  const _HomeHeader({
    required this.onMenu,
    required this.onHelp,
    required this.onBell,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    final unread = context.watch<InvitationsController>().unreadCount;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: t.translate('common.menu', fallback: 'Menú'),
            onPressed: onMenu,
            icon: const Icon(Icons.menu),
          ),
          const Expanded(
            child: Center(
              child: Image(
                image: AssetImage('assets/splash/symbol_purple.png'),
                width: 112,
              ),
            ),
          ),
          IconButton(
            key: TutorialKeys.homeHelpIcon,
            tooltip: t.translate('common.help', fallback: 'Ayuda'),
            onPressed: onHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            key: TutorialKeys.homeBellIcon,
            tooltip: t.translate(
              'invitations.title',
              fallback: 'Invitaciones',
            ),
            onPressed: onBell,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none),
                if (unread > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: const BoxDecoration(
                        color: OnesColors.danger,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: const TextStyle(
                          color: OnesColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
