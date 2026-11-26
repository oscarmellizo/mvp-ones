import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/i18n/translations_service.dart';
import '../../../../core/ui/ones_colors.dart';
import '../../../tutorial/presentation/tutorial_keys.dart';
import '../../../events/presentation/pages/events_list_page.dart';
import 'collections_page.dart';

class HomeCollectionsEventsPage extends StatefulWidget {
  final ValueChanged<int> onTabChanged;

  const HomeCollectionsEventsPage({
    super.key,
    required this.onTabChanged,
  });

  @override
  State<HomeCollectionsEventsPage> createState() =>
      _HomeCollectionsEventsPageState();
}

class _HomeCollectionsEventsPageState extends State<HomeCollectionsEventsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: 0)
      ..addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    widget.onTabChanged(_tabs.index);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TranslationsService>();
    return Column(
      children: [
        Material(
          color: OnesColors.surfaceWarm,
          child: TabBar(
            controller: _tabs,
            indicatorColor: OnesColors.purpleMid,
            labelColor: OnesColors.purpleMid,
            unselectedLabelColor: OnesColors.inkSoft,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(
                text: t.translate('collections.title', fallback: 'Colecciones'),
                key: TutorialKeys.homeTabCollections,
              ),
              Tab(text: t.translate('home.events_tab', fallback: 'Eventos')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              CollectionsPage(),
              EventsListPage(),
            ],
          ),
        ),
      ],
    );
  }
}
