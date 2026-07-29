import 'package:flutter/widgets.dart';

class TutorialKeys {
  // Home header
  static final GlobalKey homeHelpIcon = GlobalKey(debugLabel: 'home.help');
  static final GlobalKey homeBellIcon = GlobalKey(debugLabel: 'home.bell');
  static final GlobalKey homeSearch = GlobalKey(debugLabel: 'home.search');
  static final GlobalKey homeFabCreate = GlobalKey(debugLabel: 'home.fab');
  static final GlobalKey homeHeaderToday = GlobalKey(debugLabel: 'home.header.today');
  static final GlobalKey homeHeaderNext = GlobalKey(debugLabel: 'home.header.next');

  // Tabs
  static final GlobalKey homeTabHome = GlobalKey(debugLabel: 'home.tab.home');
  static final GlobalKey homeTabGalleries = GlobalKey(debugLabel: 'home.tab.galleries');
  static final GlobalKey homeTabProfile = GlobalKey(debugLabel: 'home.tab.profile');

  // Create Event
  static final GlobalKey createHelpIcon = GlobalKey(debugLabel: 'create.help');
  static final GlobalKey createTitleField = GlobalKey(debugLabel: 'create.title');
  static final GlobalKey createWhenCard = GlobalKey(debugLabel: 'create.when');
  static final GlobalKey createCtaCreate = GlobalKey(debugLabel: 'create.cta');

  // Event Detail
  static final GlobalKey eventHelpIcon = GlobalKey(debugLabel: 'event.help');
  static final GlobalKey eventTabGallery = GlobalKey(debugLabel: 'event.tab.gallery');
  static final GlobalKey eventTabDetails = GlobalKey(debugLabel: 'event.tab.details');
  static final GlobalKey eventShareLink = GlobalKey(debugLabel: 'event.share.link');
  static final GlobalKey eventFilterAll = GlobalKey(debugLabel: 'event.filter.all');
  static final GlobalKey eventFilterShared = GlobalKey(debugLabel: 'event.filter.shared');
  static final GlobalKey eventFilterMine = GlobalKey(debugLabel: 'event.filter.mine');
  static final GlobalKey eventFilterGuests = GlobalKey(debugLabel: 'event.filter.guests');
}
