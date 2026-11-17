import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'wardrobe_models.dart';
import 'wardrobe_features.dart';
import 'wardrobe_store.dart';
import 'carousel_3d.dart';
import 'auth_gate.dart';
import 'background_removal.dart';
import 'weather_service.dart';

const _ink = Color(0xFF28362E);
const _muted = Color(0xFF818980);
const _paper = Color(0xFFF4F5F0);
const _fern = Color(0xFF58735D);
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
final _notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const notificationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _notifications.initialize(notificationSettings);
  final authConfigured = _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty;
  if (authConfigured) {
    await Supabase.initialize(url: _supabaseUrl, anonKey: _supabasePublishableKey);
  }
  runApp(ThreadWardrobeApp(authConfigured: authConfigured));
}

class ThreadWardrobeApp extends StatelessWidget {
  const ThreadWardrobeApp({required this.authConfigured, super.key});

  final bool authConfigured;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'AuraShift',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _paper,
          colorScheme: ColorScheme.fromSeed(seedColor: _fern, brightness: Brightness.light),
          textTheme: ThemeData.light().textTheme.apply(bodyColor: _ink, displayColor: _ink),
          appBarTheme: const AppBarTheme(backgroundColor: _paper, foregroundColor: _ink, elevation: 0),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white.withValues(alpha: .8),
            indicatorColor: const Color(0xFFE4EBE2),
            labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFFF8F9F5),
            elevation: 3,
            shadowColor: const Color(0x18323E34),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: EdgeInsets.zero,
          ),
        ),
        home: authConfigured
            ? const SupabaseAuthGate(child: WardrobeHome())
            : const WardrobeHome(),
      );
}

class WardrobeHome extends StatefulWidget {
  const WardrobeHome({super.key});

  @override
  State<WardrobeHome> createState() => _WardrobeHomeState();
}

class _WardrobeHomeState extends State<WardrobeHome> {
  final _store = WardrobeStore();
  WardrobeData _data = WardrobeData();
  int _tab = 0;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateUtils.dateOnly(DateTime.now());
  bool _loading = true;
  WeatherSnapshot? _weather;
  String _weatherError = '';
  bool _weatherLoading = false;
  bool _rainReadyOnly = false;
  String _closetCategory = 'All';
  String _closetSort = 'recent';
  String _closetSearch = '';
  String _styleOccasion = 'Everyday';
  DateTime _clockNow = DateTime.now();
  Timer? _careTimer;

  static final _sampleItems = <ClothingItem>[
    const ClothingItem(id: 'linen-shirt', name: 'Linen overshirt', category: 'Top', color: 'cream', colorHex: '#D9CDB8', image: 'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'knit-tee', name: 'Ribbed knit tee', category: 'Top', color: 'olive', colorHex: '#77795A', image: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'straight-denim', name: 'Relaxed straight denim', category: 'Bottom', color: 'denim', colorHex: '#617C91', image: 'https://images.unsplash.com/photo-1542272604-787c3835535d?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'slip-dress', name: 'Sunday slip dress', category: 'Dress', color: 'burgundy', colorHex: '#794B54', image: 'https://images.unsplash.com/photo-1539008835657-9e8e9680c956?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'wool-cardigan', name: 'Soft wool cardigan', category: 'Layer', color: 'navy', colorHex: '#34475B', image: 'https://images.unsplash.com/photo-1576566588028-4147f3842f27?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'leather-loafers', name: 'Everyday loafers', category: 'Shoes', color: 'brown', colorHex: '#805C47', image: 'https://images.unsplash.com/photo-1531310197839-ccf54634509e?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'market-tote', name: 'Market tote', category: 'Accessory', color: 'red', colorHex: '#AC5B4C', image: 'https://images.unsplash.com/photo-1590874103328-eac38a683ce7?auto=format&fit=crop&w=700&q=85'),
    const ClothingItem(id: 'canvas-sneakers', name: 'Canvas sneakers', category: 'Shoes', color: 'white', colorHex: '#E4E1D8', image: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=700&q=85'),
  ];

  static const _styleReferencePhotos = {
    'Casual': [
      'https://images.pexels.com/photos/27542890/pexels-photo-27542890.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/8811247/pexels-photo-8811247.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/29047212/pexels-photo-29047212.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/15576193/pexels-photo-15576193.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/30381007/pexels-photo-30381007.jpeg?auto=compress&cs=tinysrgb&w=900',
    ],
    'Semi-casual': [
      'https://images.pexels.com/photos/7760002/pexels-photo-7760002.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/15343587/pexels-photo-15343587.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/30833074/pexels-photo-30833074.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/6211660/pexels-photo-6211660.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/36905971/pexels-photo-36905971.jpeg?auto=compress&cs=tinysrgb&w=900',
    ],
    'Work': [
      'https://images.pexels.com/photos/10532718/pexels-photo-10532718.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/17323594/pexels-photo-17323594.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/16970143/pexels-photo-16970143.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/26728093/pexels-photo-26728093.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/30468649/pexels-photo-30468649.jpeg?auto=compress&cs=tinysrgb&w=900',
    ],
    'Everyday': [
      'https://images.pexels.com/photos/32870716/pexels-photo-32870716.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/8217535/pexels-photo-8217535.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/28494855/pexels-photo-28494855.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/616376/pexels-photo-616376.jpeg?auto=compress&cs=tinysrgb&w=900',
      'https://images.pexels.com/photos/38432409/pexels-photo-38432409.jpeg?auto=compress&cs=tinysrgb&w=900',
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
    _careTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _clockNow = DateTime.now();
      _completeLaundryCycles();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _careTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (loaded.items.isEmpty && !_store.lastLoadHadData) loaded.items.addAll(_sampleItems);
    if (loaded.looks.isEmpty && !_store.lastLoadHadData) {
      loaded.looks[_dateKey(_selectedDay)] = const PlannedLook(title: 'Easy layers', items: ['linen-shirt', 'straight-denim', 'wool-cardigan', 'leather-loafers'], note: 'A little texture, a lot of ease.');
    }
    final savedStyle = loaded.settings['stylePreference'];
    if (savedStyle is String && const {'Casual', 'Semi-casual', 'Work', 'Everyday'}.contains(savedStyle)) {
      _styleOccasion = savedStyle;
    }
    if (!mounted) return;
    setState(() {
      _data = loaded;
      _loading = false;
    });
    await _store.save(loaded);
    if (_store.lastSyncError != null) _showMessage(_store.lastSyncError!);
    await _refreshWeather();
    _completeLaundryCycles();
  }

  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  PlannedLook? get _todayLook => _data.looks[_dateKey(_selectedDay)];
  List<ClothingItem> _piecesFor(PlannedLook? look) => (look?.items ?? []).map(_itemById).whereType<ClothingItem>().toList();

  ClothingItem? _itemById(String id) {
    for (final item in _data.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _persist() async {
    final savedStyle = _data.settings['stylePreference'];
    if (savedStyle is String && const {'Casual', 'Semi-casual', 'Work', 'Everyday'}.contains(savedStyle)) {
      _styleOccasion = savedStyle;
    }
    setState(() {});
    await _store.save(_data);
    if (_store.lastSyncError != null) _showMessage(_store.lastSyncError!);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshWeather() async {
    final city = (_data.settings['city'] as String? ?? '').trim();
    if (city.isEmpty) {
      if (mounted) setState(() {
        _weather = null;
        _weatherError = 'Add your city in settings for local weather suggestions.';
      });
      return;
    }
    setState(() {
      _weatherLoading = true;
      _weatherError = '';
    });
    try {
      final forecast = await WeatherService().forecastFor(city);
      if (mounted) {
        setState(() => _weather = forecast);
        final hasRainReady = _data.items.any((item) => item.status == 'Clean' && item.tags.any((tag) => RegExp(r'rain|waterproof', caseSensitive: false).hasMatch(tag)));
        if (forecast.precipitation > 0 && !hasRainReady) {
          unawaited(_notify('Weather outfit reminder', 'Rain is expected. Consider a rain-ready or waterproof piece.'));
        }
      }
    } on FormatException catch (error) {
      if (mounted) setState(() {
        _weather = null;
        _weatherError = error.message;
      });
    } catch (error) {
      if (mounted) setState(() {
        _weather = null;
        _weatherError = 'Weather could not be loaded: $error';
      });
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  Future<void> _changeGarmentStatus(ClothingItem item) async {
    final nextStatus = nextGarmentStatus(item.status);
    if (nextStatus == null) return;
    final index = _data.items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0) return;
    _data.items[index] = item.copyWith(
      status: nextStatus,
      laundryStartedAt: nextStatus == 'Laundry' ? DateTime.now().toUtc().toIso8601String() : null,
      clearLaundryStartedAt: nextStatus != 'Laundry',
    );
    if (nextStatus == 'Laundry') _showMessage('${item.name} added to the laundry queue.');
    if (nextStatus == 'Clean') _showMessage('${item.name} is clean and ready to wear.');
    if (nextStatus == 'Laundry') await _notify('Laundry started', '${item.name} is in the laundry queue.');
    if (nextStatus == 'Clean') await _notify('Laundry complete', '${item.name} is ready to wear again.');
    await _persist();
  }

  void _completeLaundryCycles() {
    final completed = _data.items.where((item) => item.status == 'Laundry' && laundryMinutesLeft(item, _clockNow) == 0).toList();
    if (completed.isEmpty) return;
    for (final item in completed) {
      final index = _data.items.indexWhere((candidate) => candidate.id == item.id);
      if (index >= 0) {
        _data.items[index] = item.copyWith(status: 'Clean', clearLaundryStartedAt: true);
      }
      unawaited(_notify('Laundry complete', '${item.name} is ready to wear again.'));
    }
    unawaited(_persist());
  }

  Future<void> _editLook([PlannedLook? initial]) async {
    final result = await showModalBottomSheet<PlannedLook>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OutfitComposer(
        items: _data.items,
        initial: initial,
        weather: _weather,
        dateLabel: DateFormat('EEEE, MMMM d').format(_selectedDay),
      ),
    );
    if (result == null) return;
    final key = _dateKey(_selectedDay);
    if (result.items.isEmpty) {
      _data.looks.remove(key);
    } else {
      _data.looks[key] = result;
    }
    await _persist();
  }

  Future<void> _addItem() async {
    final item = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddClothingSheet(),
    );
    if (item == null) return;
    _data.items.insert(0, item);
    await _persist();
  }

  Future<void> _editItem(ClothingItem item) async {
    final updated = await showModalBottomSheet<ClothingItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddClothingSheet(initial: item),
    );
    if (updated == null) return;
    final index = _data.items.indexWhere((candidate) => candidate.id == item.id);
    if (index >= 0) {
      _data.items[index] = updated;
      await _persist();
    }
  }

  Future<void> _removeItem(ClothingItem item) async {
    _data.items.removeWhere((candidate) => candidate.id == item.id);
    for (final entry in _data.looks.entries.toList()) {
      final look = entry.value;
      _data.looks[entry.key] = PlannedLook(
        title: look.title,
        note: look.note,
        event: look.event,
        eventTime: look.eventTime,
        items: look.items.where((id) => id != item.id).toList(),
      );
    }
    await _persist();
  }

  Future<void> _copyWardrobeReport() async {
    await Clipboard.setData(ClipboardData(text: buildWardrobeReportCsv(_data, _weather)));
    if (mounted) _showMessage('Wardrobe CSV report copied to the clipboard.');
  }

  Future<void> _syncNow() async {
    if (_store.apiBaseUrl.isEmpty) {
      _showMessage('This APK is missing WARDROBE_API_URL. Add it to GitHub Actions Variables and rebuild.');
      return;
    }
    if (_store.syncStatus == 'Sign in to sync') {
      _showMessage('Mobile sync needs an active Supabase sign-in. Check the Supabase build variables and sign in with your web account.');
      return;
    }
    final remote = await _store.load();
    if (!mounted) return;
    if (_store.lastSyncError != null) {
      _showMessage(_store.lastSyncError!);
      setState(() {});
      return;
    }
    setState(() {
      _data = remote;
      final savedStyle = remote.settings['stylePreference'];
      if (savedStyle is String && const {'Casual', 'Semi-casual', 'Work', 'Everyday'}.contains(savedStyle)) {
        _styleOccasion = savedStyle;
      }
    });
    _showMessage('Wardrobe synced with the web app.');
    await _refreshWeather();
  }

  Future<void> _toggleReminders(bool enabled) async {
    if (enabled) {
      final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      _data.settings['remindersEnabled'] = granted;
      await _persist();
      if (!granted) _showMessage('Allow notifications in Android settings to enable laundry reminders.');
      return;
    }
    _data.settings['remindersEnabled'] = false;
    await _persist();
  }

  Future<void> _notify(String title, String body) async {
    if (_data.settings['remindersEnabled'] != true) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'aurashift_care',
        'AuraShift care reminders',
        channelDescription: 'Laundry and wardrobe care updates',
        importance: Importance.defaultImportance,
      ),
    );
    await _notifications.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }

  Future<void> _markLookWorn(List<ClothingItem> items) async {
    for (final item in items.where((piece) => piece.status == 'Clean')) {
      final index = _data.items.indexWhere((candidate) => candidate.id == item.id);
      if (index >= 0) _data.items[index] = item.copyWith(status: 'Worn', clearLaundryStartedAt: true);
    }
    await _persist();
  }

  Future<void> _addWeatherSuggestion(ClothingItem item) async {
    if (item.status != 'Clean') return;
    final key = _dateKey(_selectedDay);
    final look = _data.looks[key];
    if (look?.items.contains(item.id) == true) return;
    _data.looks[key] = PlannedLook(
      title: look?.title.isNotEmpty == true ? look!.title : 'Weather-ready look',
      note: look?.note ?? '',
      event: look?.event ?? '',
      eventTime: look?.eventTime ?? '',
      items: [...?look?.items, item.id],
    );
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final themeName = _data.settings['theme'] as String? ?? 'light';
    final accentName = _data.settings['accent'] as String? ?? 'forest';
    final accent = switch (accentName) {
      'cobalt' => const Color(0xFF536F9C),
      'coral' => const Color(0xFFBD6858),
      _ => _fern,
    };
    final dark = themeName == 'dark';
    final inheritedTheme = Theme.of(context);
    final pageTheme = inheritedTheme.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: dark ? const Color(0xFF1F2822) : _paper,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: dark ? Brightness.dark : Brightness.light),
      appBarTheme: AppBarTheme(backgroundColor: dark ? const Color(0xFF1F2822) : _paper, foregroundColor: dark ? Colors.white : _ink, elevation: 0),
      textTheme: inheritedTheme.textTheme.apply(bodyColor: dark ? Colors.white : _ink, displayColor: dark ? Colors.white : _ink),
      cardTheme: inheritedTheme.cardTheme.copyWith(color: dark ? const Color(0xFF2C362F) : const Color(0xFFF8F9F5), elevation: 3),
    );
    return Theme(
      data: pageTheme,
      child: Scaffold(
      extendBody: true,
      appBar: AppBar(
        titleSpacing: 22,
        title: const Text('AuraShift', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        actions: [
          if (!_loading) Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('${_data.items.length} pieces', style: const TextStyle(color: _muted, fontSize: 12)))),
          if (!_loading) Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _syncNow,
              tooltip: _store.lastSyncError ?? 'Sync with web · ${_store.syncStatus}',
              icon: Icon(_store.lastSyncError == null && _store.syncStatus == 'Synced' ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 18, color: _store.lastSyncError == null && _store.syncStatus == 'Synced' ? accent : _muted),
            ),
          ),
          IconButton(onPressed: () => _showSettings(), icon: const Icon(Icons.tune_rounded), tooltip: 'Profile and preferences'),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: IndexedStack(
                index: _tab,
                children: [
                  _calendarView(),
                  _closetView(),
                  _ideasView(),
                  _colorsView(),
                  _laundryView(),
                ],
              ),
            ),
      floatingActionButton: _loading || _tab >= 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _tab == 0 ? () => _editLook() : _addItem,
              backgroundColor: _fern,
              foregroundColor: Colors.white,
              icon: Icon(_tab == 0 ? Icons.add_rounded : Icons.add_a_photo_outlined),
              label: Text(_tab == 0 ? 'Plan a look' : 'Add a piece'),
            ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
              NavigationDestination(icon: Icon(Icons.checkroom_outlined), selectedIcon: Icon(Icons.checkroom_rounded), label: 'Closet'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Style ideas'),
              NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette_rounded), label: 'Colors'),
              NavigationDestination(icon: Icon(Icons.local_laundry_service_outlined), selectedIcon: Icon(Icons.local_laundry_service_rounded), label: 'Laundry'),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _calendarView() {
    final look = _todayLook;
    final pieces = _piecesFor(look);
    final todayApproach = dailyApproaches[_selectedDay.weekday % 7];
    final first = DateTime(_month.year, _month.month, 1);
    final weekStarts = _data.settings['weekStarts'] as int? ?? 0;
    final offset = (first.weekday % 7 - weekStarts + 7) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final cellCount = ((offset + days + 6) ~/ 7) * 7;
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final visibleWeekdays = [...weekdays.skip(weekStarts), ...weekdays.take(weekStarts)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 104),
      children: [
        _eyebrow('YOUR WEEK, YOUR WAY'),
        Text(DateFormat('EEEE, MMMM d').format(_selectedDay), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6)),
        const SizedBox(height: 16),
        _clayCard(
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(DateFormat('MMMM yyyy').format(_month), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Today', onPressed: () => setState(() {
                _month = DateTime.now();
                _selectedDay = DateUtils.dateOnly(DateTime.now());
              }), icon: const Icon(Icons.today_rounded)),
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            Row(
              children: visibleWeekdays
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 1),
              itemBuilder: (context, index) {
                final number = index - offset + 1;
                if (number < 1 || number > days) return const SizedBox.shrink();
                final date = DateTime(_month.year, _month.month, number);
                final key = _dateKey(date);
                final chosen = _dateKey(_selectedDay) == key;
                final planned = _data.looks[key] != null;
                final plannedLook = _data.looks[key];
                return Tooltip(
                  message: plannedLook == null ? DateFormat('MMMM d').format(date) : '${DateFormat('MMMM d').format(date)} · ${plannedLook.title}',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selectedDay = date),
                    child: Container(
                      decoration: BoxDecoration(color: chosen ? _fern : planned ? const Color(0xFFE7EDE5) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                      child: Stack(alignment: Alignment.center, children: [
                        Text('$number', style: TextStyle(color: chosen ? Colors.white : _ink, fontSize: 13, fontWeight: chosen || planned ? FontWeight.w700 : FontWeight.w400)),
                        if (planned && (_data.settings['showLookNames'] as bool? ?? true))
                          Positioned(left: 1, right: 1, bottom: 1, child: Text(plannedLook!.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: chosen ? Colors.white : _muted, fontSize: 6))),
                        if (planned) Positioned(top: 3, child: Row(mainAxisSize: MainAxisSize.min, children: [
                          for (final item in _piecesFor(plannedLook).take(3))
                            Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: _colorFromHex(item.colorHex), shape: BoxShape.circle)),
                        ])),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 15),
        _clayCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFE2EADF), shape: BoxShape.circle), child: const Icon(Icons.auto_awesome_rounded, color: _fern, size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _eyebrow('TODAY’S INTENTION'),
              Text(todayApproach.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(todayApproach.$2, style: const TextStyle(color: _muted, height: 1.4, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 15),
        if (look == null || pieces.isEmpty)
          _clayCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.checkroom_rounded, color: _fern, size: 28), const SizedBox(height: 10), const Text('A day with possibility.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 4), const Text('Pick a few pieces and give this day a look of its own.', style: TextStyle(color: _muted)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => _editLook(), icon: const Icon(Icons.add), label: const Text('Build an outfit'))]))
        else
          _clayCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _heroLookImage(pieces),
              Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _eyebrow('LOOK OF THE DAY'),
                Text(look.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                if (look.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('“${look.note}”', style: const TextStyle(color: _muted, fontStyle: FontStyle.italic))),
                const SizedBox(height: 14),
                _colorStory(pieces),
                const SizedBox(height: 12),
                SizedBox(height: 108, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: pieces.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) => _itemThumb(pieces[index], width: 76))),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _editLook(look), icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('Edit look'))),
              ])),
            ]),
          ),
        if (look?.event.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _clayCard(
              child: Row(children: [
                const Icon(Icons.event_available_outlined, color: _fern),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text([if (look!.eventTime.isNotEmpty) look.eventTime, look.event].join(' · '), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Outfit planned for this event', style: TextStyle(color: _muted, fontSize: 12)),
                ])),
              ]),
            ),
          ),
        if (look != null && pieces.any((item) => item.status == 'Clean'))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _markLookWorn(pieces),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Mark outfit as worn'),
            ),
          ),
        const SizedBox(height: 8),
        _weatherSuggestionsCard(),
      ],
    );
  }

  Widget _weatherSuggestionsCard() {
    final advice = getWeatherSuggestions(_data.items, _weather);
    return _clayCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_weather != null && _weather!.precipitation > 0 ? Icons.water_drop_outlined : Icons.wb_sunny_outlined, color: _fern),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_weather == null ? advice.title : '${advice.title} · ${_weather!.city}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_weather == null ? _weatherError.isNotEmpty ? _weatherError : advice.detail : '${_weather!.temperature.round()}°C · ${_weather!.description}', style: const TextStyle(color: _muted, fontSize: 12)),
          ])),
          IconButton(onPressed: _weatherLoading ? null : _refreshWeather, icon: _weatherLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded), tooltip: 'Refresh weather'),
        ]),
        const SizedBox(height: 8),
        if (advice.items.isEmpty)
          const Text('Add clean pieces to your closet to see outfit picks.', style: TextStyle(color: _muted))
        else
          for (final item in advice.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(borderRadius: BorderRadius.circular(9), child: SizedBox(width: 42, height: 48, child: _image(item.image, colorHex: item.colorHex))),
              title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.category} · ${item.color}'),
              trailing: IconButton(
                onPressed: _todayLook?.items.contains(item.id) == true ? null : () => _addWeatherSuggestion(item),
                icon: Icon(_todayLook?.items.contains(item.id) == true ? Icons.check_rounded : Icons.add_rounded),
                tooltip: 'Add to this look',
              ),
            ),
      ]),
    );
  }

  Widget _closetView() {
    final visibleItems = filterClosetItems(
      _data.items,
      category: _closetCategory,
      query: _closetSearch,
      rainReadyOnly: _rainReadyOnly,
      sort: _closetSort,
    );
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 104), children: [
      _eyebrow('EVERYTHING YOU LOVE TO WEAR'),
      Text('Your closet', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6)),
      Text('${_data.items.length} pieces, all in one thoughtful place.', style: const TextStyle(color: _muted)),
      const SizedBox(height: 14),
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Find a piece', border: OutlineInputBorder()),
        onChanged: (value) => setState(() => _closetSearch = value),
      ),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final category in ['All', ...wardrobeCategories])
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(category),
                selected: _closetCategory == category,
                onSelected: (_) => setState(() => _closetCategory = category),
              ),
            ),
        ]),
      ),
      Row(children: [
        const Text('Sort by', style: TextStyle(color: _muted)),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _closetSort,
          items: const [
            DropdownMenuItem(value: 'recent', child: Text('Recently added')),
            DropdownMenuItem(value: 'name', child: Text('Name')),
            DropdownMenuItem(value: 'category', child: Text('Category')),
            DropdownMenuItem(value: 'color', child: Text('Color')),
            DropdownMenuItem(value: 'status', child: Text('Wear status')),
          ],
          onChanged: (value) => setState(() => _closetSort = value ?? 'recent'),
        ),
        const Spacer(),
        Flexible(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Rain-ready', style: TextStyle(fontSize: 12)),
            value: _rainReadyOnly,
            onChanged: (value) => setState(() => _rainReadyOnly = value ?? false),
          ),
        ),
      ]),
      if (visibleItems.isEmpty)
        _clayCard(child: Text(_rainReadyOnly ? 'Tag items as rain-ready to filter them here.' : 'No pieces match these filters.'))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .58),
          itemBuilder: (context, index) {
            final item = visibleItems[index];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Stack(children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _editItem(item),
                    child: ClipRRect(borderRadius: BorderRadius.circular(18), child: _image(item.image, fit: BoxFit.cover, colorHex: item.colorHex)),
                  ),
                ),
                Positioned(left: 9, top: 9, child: _glassPill(item.category)),
                Positioned(right: 2, top: 2, child: PopupMenuButton<String>(
                  onSelected: (action) => action == 'edit' ? _editItem(item) : _removeItem(item),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit piece')),
                    PopupMenuItem(value: 'remove', child: Text('Remove piece')),
                  ],
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                )),
              ])),
              const SizedBox(height: 7),
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${item.brand.isEmpty ? item.category : item.brand} · ${item.season}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10)),
              Text('${item.color} · ${item.status}', style: const TextStyle(color: _muted, fontSize: 10)),
              TextButton(
                onPressed: () => _changeGarmentStatus(item),
                child: Text(switch (item.status) { 'Clean' => 'Mark worn', 'Worn' => 'Add to laundry', _ => 'Mark clean' }),
              ),
            ]);
          },
        ),
      const SizedBox(height: 18),
      _eyebrow('OUTFIT INSPIRATION'),
      const Text('Five looks for every style', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _styleSelector(),
      SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _styleReferencePhotos[_styleOccasion]!.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 130,
              child: Image.network(_styleReferencePhotos[_styleOccasion]![index], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2EADF), child: const Icon(Icons.checkroom_rounded, color: _fern))),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _ideasView() {
    final suggestions = suggestOutfits(_data.items, _styleOccasion);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 104), children: [
      _eyebrow('FRONT-VIEW STYLE REFERENCES'),
      const Text('Style ideas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6)),
      const Text('Choose an outfit style, then wear pieces from your closet.', style: TextStyle(color: _muted)),
      const SizedBox(height: 16),
      _styleSelector(),
      SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _styleReferencePhotos[_styleOccasion]!.length,
          separatorBuilder: (_, __) => const SizedBox(width: 9),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(width: 130, child: Image.network(_styleReferencePhotos[_styleOccasion]![index], fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFE2EADF), child: const Icon(Icons.checkroom_rounded, color: _fern)))),
          ),
        ),
      ),
      const SizedBox(height: 15),
      for (var index = 0; index < suggestions.length; index++) _ideaCard(suggestions[index], index),
      if (suggestions.isEmpty) _clayCard(child: const Text('Add tops, bottoms, or dresses to see outfit ideas.')),
    ]);
  }

  Widget _styleSelector() => Wrap(
        spacing: 7,
        children: ['Casual', 'Semi-casual', 'Work', 'Everyday']
            .map((style) => ChoiceChip(label: Text(style), selected: _styleOccasion == style, onSelected: (_) => setState(() => _styleOccasion = style)))
            .toList(),
      );

  Widget _ideaCard(OutfitSuggestion idea, int index) {
    final pieces = idea.items.map(_itemById).whereType<ClothingItem>().toList();
    return Padding(padding: const EdgeInsets.only(bottom: 13), child: _clayCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 128, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: pieces.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, itemIndex) => _itemThumb(pieces[itemIndex], width: 94))),
      const SizedBox(height: 13),
      _eyebrow('IDEA ${index + 1} · ${_styleOccasion.toUpperCase()}'),
      Text(idea.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 4),
      Text(idea.note, style: const TextStyle(color: _muted, fontSize: 12)),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async {
        final today = DateUtils.dateOnly(DateTime.now());
        _selectedDay = today;
        _month = DateTime(today.year, today.month);
        _data.looks[_dateKey(today)] = PlannedLook(title: idea.title, note: idea.note, items: idea.items);
        await _persist();
        if (mounted) setState(() => _tab = 0);
      }, icon: const Icon(Icons.check_circle_outline_rounded), label: const Text('Wear this today'))),
    ])));
  }

  Widget _colorsView() {
    final grouped = <String, List<ClothingItem>>{};
    for (final item in _data.items.where((piece) => piece.color.trim().isNotEmpty)) { grouped.putIfAbsent(item.color, () => []).add(item); }
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 104), children: [
      _eyebrow('NOTICE THE LITTLE PATTERNS'),
      const Text('Color notes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6)),
      const SizedBox(height: 14),
      _clayCard(child: Row(children: [const Icon(Icons.palette_rounded, color: _fern, size: 31), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Getting dressed in color.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('${_data.looks.length} looks planned · ${_data.items.length} pieces in your palette', style: const TextStyle(color: _muted, fontSize: 12))]))])),
      const SizedBox(height: 14),
      for (final entry in grouped.entries) _clayCard(child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: _colorFromHex(entry.value.first.colorHex), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.white, offset: Offset(-3, -3), blurRadius: 6), BoxShadow(color: Color(0x22343C34), offset: Offset(3, 3), blurRadius: 6)])), const SizedBox(width: 12), Expanded(child: Text(entry.key[0].toUpperCase() + entry.key.substring(1), style: const TextStyle(fontWeight: FontWeight.w700))), Text('${entry.value.length} piece${entry.value.length == 1 ? '' : 's'}', style: const TextStyle(color: _muted, fontSize: 12))])),
      const SizedBox(height: 6),
      const Text('Try tonal layers, one bright accent, or a crisp contrast. Your closet is the color wheel.', style: TextStyle(color: _muted, height: 1.5)),
      const SizedBox(height: 16),
      _eyebrow('YOUR PLANNED COLOR STORIES'),
      for (final entry in _data.looks.entries)
        Builder(builder: (context) {
          final pieces = _piecesFor(entry.value);
          final harmony = coordinatePalette(pieces);
          return _clayCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('MMM d').format(DateTime.parse(entry.key))} · ${entry.value.title}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('${harmony.score}% together · ${harmony.label}', style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          );
        }),
    ]);
  }

  Widget _laundryView() {
    final analytics = WardrobeAnalytics.from(_data);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 104), children: [
      _eyebrow('GARMENT CARE, AT A GLANCE'),
      const Text('Laundry queue', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.6)),
      Text('${analytics.statusCounts['Laundry']} in laundry · Clean → Worn → Laundry → Clean', style: const TextStyle(color: _muted)),
      const SizedBox(height: 14),
      Row(children: [
        for (final status in garmentStatuses)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _clayCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(status, style: const TextStyle(color: _muted, fontSize: 11)),
                  Text('${analytics.statusCounts[status]}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                  Text(switch (status) { 'Clean' => 'Ready to wear', 'Worn' => 'Ready for laundry', _ => 'In the wash' }, style: const TextStyle(color: _muted, fontSize: 9)),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      _clayCard(
        child: const Text('Each button moves a piece through Clean → Worn → Laundry. Laundry returns to clean when its wash-cycle estimate ends.', style: TextStyle(color: _muted, height: 1.4)),
      ),
      const SizedBox(height: 12),
      if (_data.items.isEmpty)
        _clayCard(child: const Text('Add pieces to see their care status.'))
      else
        for (final item in _data.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _clayCard(
              padding: EdgeInsets.zero,
              child: Row(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                  child: SizedBox(width: 92, height: 132, child: _image(item.image, colorHex: item.colorHex)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${item.category} · ${item.brand.isEmpty ? 'Your wardrobe' : item.brand}', style: const TextStyle(color: _muted, fontSize: 10)),
                    const SizedBox(height: 3),
                    Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    _glassPill(item.status),
                    const SizedBox(height: 4),
                    Text(
                      item.status == 'Laundry'
                          ? '${laundryMinutesLeft(item, _clockNow)} min left'
                          : item.status == 'Worn'
                              ? 'Ready to add to the wash'
                              : 'Available to wear',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    TextButton(
                      onPressed: () => _changeGarmentStatus(item),
                      child: Text(switch (item.status) { 'Clean' => 'Mark as worn', 'Worn' => 'Add to laundry', _ => 'Mark clean' }),
                    ),
                  ]),
                )),
              ]),
            ),
          ),
    ]);
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileSettingsSheet(
        data: _data,
        analytics: WardrobeAnalytics.from(_data),
        syncStatus: _store.syncStatus,
        syncError: _store.lastSyncError,
        canSignOut: _supabaseUrl.isNotEmpty && _supabasePublishableKey.isNotEmpty,
        onSave: _persist,
        onRefreshWeather: _refreshWeather,
        onSync: _syncNow,
        onExport: _copyWardrobeReport,
        onToggleReminders: _toggleReminders,
        onSignOut: () async {
          Navigator.pop(context);
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (error) {
            _showMessage('Could not sign out: $error');
          }
        },
      ),
    );
  }

  Widget _heroLookImage(List<ClothingItem> items) {
    final hero = items.firstWhere((item) => item.category == 'Dress' || item.category == 'Top', orElse: () => items.first);
    return SizedBox(height: 185, width: double.infinity, child: Stack(fit: StackFit.expand, children: [ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), child: _image(hero.image, fit: BoxFit.cover, colorHex: hero.colorHex)), DecoratedBox(decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99000000)]))), Positioned(left: 17, bottom: 15, child: Text(_todayLook?.title ?? '', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)))]));
  }

  Widget _colorStory(List<ClothingItem> pieces) {
    final harmony = coordinatePalette(pieces);
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Color story',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${harmony.score}% · ${harmony.label}',
          style: const TextStyle(
            color: _fern,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        ...pieces.take(4).map(
              (item) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _colorFromHex(item.colorHex),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _itemThumb(ClothingItem item, {double width = 84}) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: width, child: _image(item.image, fit: BoxFit.cover, colorHex: item.colorHex)))), const SizedBox(height: 4), Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))]));

  Widget _image(String url, {BoxFit fit = BoxFit.cover, String colorHex = '#E5E9E1'}) {
    final fallback = Container(color: _colorFromHex(colorHex), child: const Center(child: Icon(Icons.checkroom_rounded, color: Colors.white70, size: 31)));
    if (url.isEmpty) return fallback;
    if (url.startsWith('data:image/')) {
      final separator = url.indexOf(',');
      if (separator < 0) return fallback;
      try {
        return Image.memory(
          base64Decode(url.substring(separator + 1)),
          fit: fit,
          errorBuilder: (_, __, ___) => fallback,
        );
      } on FormatException {
        return fallback;
      }
    }
    return Image.network(url, fit: fit, errorBuilder: (_, __, ___) => fallback, loadingBuilder: (context, child, progress) => progress == null ? child : fallback);
  }

  Widget _clayCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) => Card(child: Padding(padding: padding, child: child));
  Widget _eyebrow(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)));
  Widget _glassPill(String text) => ClipRRect(borderRadius: BorderRadius.circular(12), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), color: Colors.white.withValues(alpha: .78), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)))));

  Color _colorFromHex(String hex) {
    final normalized = hex.replaceAll('#', '');
    final value = normalized.length == 6 ? 'FF$normalized' : normalized;
    return Color(int.tryParse(value, radix: 16) ?? 0xFF59745C);
  }
}

class OutfitComposer extends StatefulWidget {
  const OutfitComposer({super.key, required this.items, this.initial, this.weather, this.dateLabel = ''});
  final List<ClothingItem> items;
  final PlannedLook? initial;
  final WeatherSnapshot? weather;
  final String dateLabel;

  @override
  State<OutfitComposer> createState() => _OutfitComposerState();
}

class _OutfitComposerState extends State<OutfitComposer> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _event;
  late final TextEditingController _eventTime;
  late final Set<String> _selected;
  final Map<String, int> _carouselIndexes = {};
  bool _weatherReadyOnly = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _note = TextEditingController(text: widget.initial?.note ?? '');
    _event = TextEditingController(text: widget.initial?.event ?? '');
    _eventTime = TextEditingController(text: widget.initial?.eventTime ?? '');
    _selected = {...?widget.initial?.items};
    for (final category in wardrobeCategories) {
      _carouselIndexes[category] = 0;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _event.dispose();
    _eventTime.dispose();
    super.dispose();
  }

  bool _matchesWeather(ClothingItem item) {
    if (item.status != 'Clean' && !_selected.contains(item.id)) return false;
    if (!_weatherReadyOnly || _selected.contains(item.id)) return true;
    final weather = widget.weather;
    if (weather == null) return true;
    final tags = item.tags.join(' ').toLowerCase();
    if (weather.precipitation > 0 || RegExp(r'rain|shower|storm|snow', caseSensitive: false).hasMatch(weather.description)) {
      return RegExp(r'rain|waterproof|water-resistant|water resistant|quick-dry|umbrella', caseSensitive: false).hasMatch(tags);
    }
    if (weather.temperature <= 12) {
      return RegExp(r'warm|wool|thermal|knit|coat|jacket|sweater|fleece', caseSensitive: false).hasMatch(tags);
    }
    if (weather.temperature >= 28) {
      return RegExp(r'breathable|lightweight|linen|cotton|summer|sleeveless|sun', caseSensitive: false).hasMatch(tags);
    }
    return true;
  }

  List<ClothingItem> _itemsFor(String category) => widget.items.where((item) => item.category == category && _matchesWeather(item)).toList();

  void _toggle(ClothingItem item) {
    setState(() {
      if (!_selected.add(item.id)) _selected.remove(item.id);
    });
  }

  Future<void> _pickEventTime() async {
    final current = _eventTime.text.split(':');
    final initial = current.length == 2
        ? TimeOfDay(hour: int.tryParse(current[0]) ?? 9, minute: int.tryParse(current[1]) ?? 0)
        : TimeOfDay.now();
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null) return;
    _eventTime.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selectedItems = widget.items.where((item) => _selected.contains(item.id)).toList();
    return Container(
      height: MediaQuery.sizeOf(context).height * .94,
      padding: EdgeInsets.fromLTRB(18, 10, 18, MediaQuery.viewInsetsOf(context).bottom + 12),
      decoration: const BoxDecoration(color: _paper, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFC7CEC5), borderRadius: BorderRadius.circular(4))),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.dateLabel.isNotEmpty) _eyebrowLocal(widget.dateLabel.toUpperCase()),
            Text(_title.text.isEmpty ? (widget.initial == null ? 'Build a look' : 'Edit this look') : _title.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ])),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        Expanded(child: ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            TextField(controller: _title, onChanged: (_) => setState(() {}), maxLength: 50, decoration: const InputDecoration(labelText: 'Give it a name', hintText: 'e.g. Soft Sunday layers')),
            TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'A note for later (optional)', hintText: 'The feeling, the plan, the little detail…')),
            Row(children: [
              Expanded(child: TextField(controller: _event, maxLength: 70, decoration: const InputDecoration(labelText: 'Event or appointment (optional)', hintText: 'Studio meeting'))),
              const SizedBox(width: 10),
              SizedBox(width: 105, child: TextField(controller: _eventTime, readOnly: true, onTap: _pickEventTime, decoration: const InputDecoration(labelText: 'Time', suffixIcon: Icon(Icons.schedule_rounded)))),
            ]),
            const SizedBox(height: 12),
            _preview(selectedItems),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Pick your pieces', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              Text('${_selected.length} selected', style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
            if (selectedItems.map((item) => item.category).toSet().length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(children: [
                  const Expanded(child: Text('Outfit Aura', style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('${coordinatePalette(selectedItems).score}% · ${coordinatePalette(selectedItems).label}', style: const TextStyle(color: _fern, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
            if (widget.weather != null)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weather-ready pieces only'),
                subtitle: Text('${widget.weather!.city} · ${widget.weather!.temperature.round()}°C · ${widget.weather!.description}'),
                value: _weatherReadyOnly,
                onChanged: (value) => setState(() => _weatherReadyOnly = value ?? false),
              ),
            for (final category in wardrobeCategories) _categoryCarousel(category),
          ],
        )),
        const SizedBox(height: 9),
        Row(children: [
          if (widget.initial != null)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, const PlannedLook(title: '', items: [])),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              label: const Text('Remove look', style: TextStyle(color: Colors.red)),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, PlannedLook(
                      title: _title.text.trim().isEmpty ? 'A new look' : _title.text.trim(),
                      note: _note.text.trim(),
                      event: _event.text.trim(),
                      eventTime: _eventTime.text.trim(),
                      items: wardrobeCategories
                          .expand((category) => _itemsFor(category).where((item) => _selected.contains(item.id)).map((item) => item.id))
                          .toList(),
                    )),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save look'),
          ),
        ]),
      ]),
    );
  }

  Widget _categoryCarousel(String category) {
    final items = _itemsFor(category);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.checkroom_outlined, color: _muted),
              const SizedBox(width: 10),
              Expanded(child: Text('$category · no clean options', style: const TextStyle(color: _muted))),
            ]),
          ),
        ),
      );
    }
    final index = (_carouselIndexes[category] ?? 0) % items.length;
    final active = items[index];
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(category, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          Text('${items.length} options · ${items.where((item) => _selected.contains(item.id)).length} selected', style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(color: const Color(0xFFE9ECE5), borderRadius: BorderRadius.circular(18)),
          child: Carousel3D(
            key: ValueKey('$category-${items.map((item) => item.id).join('-')}'),
            items: items,
            height: 145,
            itemWidth: 112,
            initialIndex: index,
            onChanged: (value) => setState(() => _carouselIndexes[category] = value),
          ),
        ),
        Row(children: [
          TextButton(onPressed: items.length < 2 ? null : () => setState(() => _carouselIndexes[category] = (index - 1 + items.length) % items.length), child: const Text('Previous')),
          Expanded(child: Text('${active.name} · ${active.color}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
          FilledButton.tonal(onPressed: () => _toggle(active), child: Text(_selected.contains(active.id) ? 'Remove' : 'Add to look')),
          TextButton(onPressed: items.length < 2 ? null : () => setState(() => _carouselIndexes[category] = (index + 1) % items.length), child: const Text('Next')),
        ]),
        if (_selected.contains(active.id))
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: () => _toggle(active), icon: const Icon(Icons.check_circle_rounded), label: const Text('Selected · tap to remove')),
          ),
      ]),
    );
  }

  Widget _preview(List<ClothingItem> items) {
    if (items.isEmpty) {
      return Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECE5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 9),
            BoxShadow(color: Color(0x22353E35), offset: Offset(4, 4), blurRadius: 9)
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom_rounded, color: _fern),
            SizedBox(width: 8),
            Text('Swipe the category carousels below to build your look', style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ),
      );
    }
    return Container(
      height: 160,
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECE5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.white, offset: Offset(-4, -4), blurRadius: 9),
          BoxShadow(color: Color(0x22353E35), offset: Offset(4, 4), blurRadius: 9)
        ],
      ),
      child: Carousel3D(
        items: items,
        height: 140,
        itemWidth: 90,
      ),
    );
  }

}

class AddClothingSheet extends StatefulWidget {
  const AddClothingSheet({super.key, this.initial});

  final ClothingItem? initial;

  @override
  State<AddClothingSheet> createState() => _AddClothingSheetState();
}

class _AddClothingSheetState extends State<AddClothingSheet> {
  late final TextEditingController _name;
  late final TextEditingController _image;
  late final TextEditingController _brand;
  late final TextEditingController _tags;
  late final TextEditingController _hexController;
  final _picker = ImagePicker();
  String _photoData = '';
  String? _photoError;
  bool _isPickingPhoto = false;
  String _category = 'Top';
  String _color = 'sage';
  String _season = 'All season';
  int _laundryDuration = 45;
  static const colors = {'sage': '#789078', 'cream': '#D9CDB8', 'denim': '#617C91', 'rose': '#C18484', 'navy': '#34475B', 'red': '#AC5B4C'};

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    _name = TextEditingController(text: item?.name ?? '');
    _image = TextEditingController(text: item != null && !item.image.startsWith('data:image/') ? item.image : '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _tags = TextEditingController(text: item?.tags.join(', ') ?? '');
    _hexController = TextEditingController(text: item?.colorHex ?? colors['sage']!);
    _category = item?.category ?? 'Top';
    _color = item?.color ?? 'sage';
    _season = item?.season ?? 'All season';
    _laundryDuration = item?.laundryDurationMinutes ?? 45;
    _photoData = item?.image.startsWith('data:image/') == true ? item!.image : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _image.dispose();
    _brand.dispose();
    _tags.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() {
      _isPickingPhoto = true;
      _photoError = null;
    });
    try {
      if (source == ImageSource.camera) {
        final permission = await Permission.camera.request();
        if (!mounted) return;
        if (!permission.isGranted) {
          setState(() => _photoError = permission.isPermanentlyDenied
              ? 'Enable camera permission in your device settings to take a photo.'
              : 'Camera permission is needed to take a photo.');
          return;
        }
      }
      final photo = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 65);
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('The selected photo is empty.');
      if (!mounted) return;
      setState(() {
        _photoData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        _image.clear();
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _photoError = error.message ?? 'Could not open the selected photo.');
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoError = error.message);
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _removeBackground() async {
    try {
      final bytes = base64Decode(_photoData.substring(_photoData.indexOf(',') + 1));
      final output = removeFlatBackground(bytes);
      setState(() {
        _photoData = 'data:image/png;base64,${base64Encode(output)}';
        _photoError = 'Background removed. Review the edges before saving.';
      });
    } on FormatException catch (error) {
      setState(() => _photoError = error.message);
    }
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    final hex = _hexController.text.trim();
    if (!RegExp(r'^#?[\da-fA-F]{6}$').hasMatch(hex)) {
      setState(() => _photoError = 'Enter a six-digit color value such as #789078.');
      return;
    }
    final colorHex = hex.startsWith('#') ? hex : '#$hex';
    final item = widget.initial;
    final image = _photoData.isNotEmpty ? _photoData : _image.text.trim().isNotEmpty ? _image.text.trim() : item?.image ?? '';
    final tags = _tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
    final updated = item == null
        ? ClothingItem(
            id: 'item-${DateTime.now().microsecondsSinceEpoch}',
            name: _name.text.trim(),
            category: _category,
            color: _color,
            colorHex: colorHex,
            image: image,
            season: _season,
            brand: _brand.text.trim(),
            tags: tags,
            laundryDurationMinutes: _laundryDuration,
          )
        : item.copyWith(
            name: _name.text.trim(),
            category: _category,
            color: _color,
            colorHex: colorHex,
            image: image,
            season: _season,
            brand: _brand.text.trim(),
            tags: tags,
            laundryDurationMinutes: _laundryDuration,
          );
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final colorOptions = {...colors.keys, if (!colors.containsKey(_color)) _color}.toList();
    return Container(
      height: MediaQuery.sizeOf(context).height * .94,
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.viewInsetsOf(context).bottom + 18),
      decoration: const BoxDecoration(color: _paper, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFC7CEC5), borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 17),
        Text(widget.initial == null ? 'Add a piece' : 'Edit piece', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 15),
        Expanded(child: ListView(children: [
          TextField(controller: _name, maxLength: 60, decoration: const InputDecoration(labelText: 'Piece name', hintText: 'e.g. Cropped denim jacket')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: wardrobeCategories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _category = value ?? 'Top'),
            )),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: _season,
              decoration: const InputDecoration(labelText: 'Season'),
              items: const ['All season', 'Spring / Summer', 'Fall / Winter'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _season = value ?? 'All season'),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _brand, maxLength: 50, decoration: const InputDecoration(labelText: 'Brand (optional)'))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(
              value: _color,
              decoration: const InputDecoration(labelText: 'Color'),
              items: colorOptions.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _color = value;
                  _hexController.text = colors[value] ?? _hexController.text;
                });
              },
            )),
          ]),
          TextField(controller: _hexController, decoration: const InputDecoration(labelText: 'Color swatch (hex)', hintText: '#789078')),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: _laundryDuration,
            decoration: const InputDecoration(labelText: 'Wash cycle estimate'),
            items: const [30, 45, 60, 90].map((value) => DropdownMenuItem(value: value, child: Text('$value minutes'))).toList(),
            onChanged: (value) => setState(() => _laundryDuration = value ?? 45),
          ),
          TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'rain-ready, lightweight')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: _isPickingPhoto ? null : () => _pickPhoto(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Camera')),
            OutlinedButton.icon(onPressed: _isPickingPhoto ? null : () => _pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Gallery')),
          ]),
          if (_isPickingPhoto) const LinearProgressIndicator(),
          if (_photoError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_photoError!, style: const TextStyle(color: Colors.red))),
          if (_photoData.isNotEmpty) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(base64Decode(_photoData.substring(_photoData.indexOf(',') + 1)), height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            TextButton.icon(onPressed: _removeBackground, icon: const Icon(Icons.auto_fix_high_rounded), label: const Text('Remove flat background')),
          ],
          TextField(controller: _image, onChanged: (_) => setState(() => _photoData = ''), decoration: const InputDecoration(labelText: 'Photo URL (optional)', hintText: 'https://…')),
        ])),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: Icon(widget.initial == null ? Icons.add_rounded : Icons.save_outlined), label: Text(widget.initial == null ? 'Add to closet' : 'Save changes'))),
      ]),
    );
  }
}

class ProfileSettingsSheet extends StatefulWidget {
  const ProfileSettingsSheet({
    super.key,
    required this.data,
    required this.analytics,
    required this.syncStatus,
    required this.syncError,
    required this.canSignOut,
    required this.onSave,
    required this.onRefreshWeather,
    required this.onSync,
    required this.onExport,
    required this.onToggleReminders,
    required this.onSignOut,
  });

  final WardrobeData data;
  final WardrobeAnalytics analytics;
  final String syncStatus;
  final String? syncError;
  final bool canSignOut;
  final Future<void> Function() onSave;
  final Future<void> Function() onRefreshWeather;
  final Future<void> Function() onSync;
  final Future<void> Function() onExport;
  final Future<void> Function(bool) onToggleReminders;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<ProfileSettingsSheet> {
  late final TextEditingController _city;
  late final TextEditingController _profileName;

  @override
  void initState() {
    super.initState();
    _city = TextEditingController(text: widget.data.settings['city'] as String? ?? '');
    _profileName = TextEditingController(text: widget.data.settings['profileName'] as String? ?? '');
  }

  @override
  void dispose() {
    _city.dispose();
    _profileName.dispose();
    super.dispose();
  }

  Future<void> _setSetting(String key, Object value) async {
    widget.data.settings[key] = value;
    if (mounted) setState(() {});
    await widget.onSave();
  }

  Future<void> _saveCity(String value) async {
    widget.data.settings['city'] = value.trim();
    if (mounted) setState(() {});
    await widget.onSave();
    await widget.onRefreshWeather();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.data.settings;
    final intensityValue = double.tryParse('${settings['auraIntensity']}') ?? 65;
    final intensity = intensityValue <= 1 ? intensityValue * 100 : intensityValue;
    final weekStarts = settings['weekStarts'] as int? ?? 0;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .92,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: const BoxDecoration(color: _paper, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFC7CEC5), borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 15),
          const Text('Profile & preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Expanded(child: ListView(children: [
            TextField(
              controller: _profileName,
              decoration: const InputDecoration(labelText: 'Profile name'),
              onSubmitted: (value) => _setSetting('profileName', value.trim()),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings['profileStyle'] as String? ?? 'All styles',
              decoration: const InputDecoration(labelText: 'Clothing style'),
              items: const ['All styles', "Women's styles", "Men's styles"].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) { if (value != null) _setSetting('profileStyle', value); },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: settings['stylePreference'] as String? ?? 'Everyday',
              decoration: const InputDecoration(labelText: 'Style preference'),
              items: const ['Everyday', 'Casual', 'Semi-casual', 'Work'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) { if (value != null) _setSetting('stylePreference', value); },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _city,
              decoration: InputDecoration(labelText: 'Local weather city', hintText: 'e.g. Manila', suffixIcon: IconButton(onPressed: () => _saveCity(_city.text), icon: const Icon(Icons.refresh_rounded))),
              textInputAction: TextInputAction.done,
              onSubmitted: _saveCity,
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'light', label: Text('Light')), ButtonSegment(value: 'dark', label: Text('Dark'))],
              selected: {settings['theme'] as String? ?? 'light'},
              onSelectionChanged: (value) => _setSetting('theme', value.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show look names in calendar'),
              value: settings['showLookNames'] as bool? ?? true,
              onChanged: (value) => _setSetting('showLookNames', value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Week begins on'),
              trailing: SegmentedButton<int>(
                segments: const [ButtonSegment(value: 0, label: Text('Sun')), ButtonSegment(value: 1, label: Text('Mon'))],
                selected: {weekStarts == 1 ? 1 : 0},
                onSelectionChanged: (value) => _setSetting('weekStarts', value.first),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Calendar accent'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'forest', label: Text('Forest')),
                  ButtonSegment(value: 'cobalt', label: Text('Blue')),
                  ButtonSegment(value: 'coral', label: Text('Coral')),
                ],
                selected: {settings['accent'] as String? ?? 'forest'},
                onSelectionChanged: (value) => _setSetting('accent', value.first),
              ),
            ),
            DropdownButtonFormField<String>(
              value: settings['colorBlindMode'] as String? ?? 'None',
              decoration: const InputDecoration(labelText: 'Color accessibility'),
              items: const ['None', 'Deuteranopia', 'Protanopia', 'Tritanopia'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) { if (value != null) _setSetting('colorBlindMode', value); },
            ),
            const SizedBox(height: 10),
            Text('Aura intensity · ${intensity.round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
            Slider(value: intensity.clamp(0, 100).toDouble(), min: 0, max: 100, onChanged: (value) => setState(() => settings['auraIntensity'] = value.round()), onChangeEnd: (_) => widget.onSave()),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Laundry reminders'),
              subtitle: const Text('Notify when a wash starts or finishes.'),
              value: settings['remindersEnabled'] as bool? ?? false,
              onChanged: widget.onToggleReminders,
            ),
            const Divider(height: 26),
            const Text('Wardrobe report & analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${widget.analytics.totalItems} pieces · ${widget.analytics.plannedLooks} planned looks', style: const TextStyle(color: _muted)),
            Text('Clean ${widget.analytics.statusCounts['Clean']} · Worn ${widget.analytics.statusCounts['Worn']} · Laundry ${widget.analytics.statusCounts['Laundry']}', style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 8),
            for (final category in wardrobeCategories)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(category),
                trailing: Text('${widget.analytics.categoryCounts[category] ?? 0}'),
              ),
            FilledButton.tonalIcon(onPressed: widget.onExport, icon: const Icon(Icons.copy_all_rounded), label: const Text('Copy CSV report')),
            const Divider(height: 26),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(widget.syncError == null && widget.syncStatus == 'Synced' ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
              title: Text(widget.syncStatus),
              subtitle: widget.syncError == null ? const Text('Wardrobe data is shared with the web app.') : Text(widget.syncError!),
              trailing: IconButton(onPressed: widget.onSync, icon: const Icon(Icons.sync_rounded), tooltip: 'Sync now'),
            ),
            if (widget.canSignOut)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: widget.onSignOut,
              ),
          ])),
        ]),
      ),
    );
  }
}

Widget _eyebrowLocal(String text) => Text(text, style: const TextStyle(color: _muted, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1.1));
