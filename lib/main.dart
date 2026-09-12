import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'logic/date_utils.dart' as date_utils;
import 'logic/recurrence.dart';
import 'models/calendar_event.dart';
import 'native/eventkit.dart';
import 'screens/event_sheet.dart';
import 'screens/list_view.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/search_screen.dart';
import 'screens/time_grid_view.dart';
import 'services/auth_service.dart';
import 'storage/event_store.dart';
import 'storage/display_settings.dart';
import 'storage/imported_events.dart';
import 'sync/system_events_sync.dart';
import 'theme/app_theme.dart';
import 'screens/month_agenda.dart';
import 'widgets/top_bar.dart';
import 'widgets/liquid_glass.dart';
import 'widgets/server_connection_monitor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  // Phase 1 targets Korean users only; skip a native-timezone-detection
  // plugin for this single, fixed zone (see event_details.dart for where a
  // real IANA Location matters — DST-safe wall-clock conversion).
  final deviceZone = tz.getLocation('Asia/Seoul');
  final store = EventStore();
  final importedEvents = ImportedEvents();
  await store.load();
  await importedEvents.load();
  await DisplaySettings.instance.load();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: importedEvents),
      ],
      child: CalendarApp(deviceZone: deviceZone),
    ),
  );
}

class CalendarApp extends StatelessWidget {
  final tz.Location deviceZone;
  const CalendarApp({super.key, required this.deviceZone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '캘린더',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildMaterialTheme(lightTheme),
      darkTheme: buildMaterialTheme(darkTheme),
      // Place this below MaterialApp so its dialog uses the root Navigator,
      // and above AuthGate so it also covers the login and consent flow.
      home: ServerConnectionMonitor(child: AuthGate(deviceZone: deviceZone)),
    );
  }
}

enum _AuthScreen { login, signup }

/// Port of App.tsx's auth gating: wait for a stored session to be restored,
/// then show login/signup, or fall straight through in guest mode.
class AuthGate extends StatefulWidget {
  final tz.Location deviceZone;
  const AuthGate({super.key, required this.deviceZone});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  AuthUser? _user;
  bool _guest = false;
  _AuthScreen _screen = _AuthScreen.login;

  @override
  void initState() {
    super.initState();
    // Do not block the first screen on an API request. A disconnected server
    // must show the login screen and its connection alert immediately.
    _loading = false;
    AuthService.instance.restoreSession().then((user) {
      if (mounted) setState(() => _user = user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).brightness == Brightness.dark
        ? darkTheme
        : lightTheme;
    if (_loading) {
      return Scaffold(
        backgroundColor: theme.bg,
        body: Center(
          child: Text(
            '로그인 정보를 확인하고 있습니다…',
            style: TextStyle(color: theme.textMuted),
          ),
        ),
      );
    }
    if (_user == null && !_guest) {
      if (_screen == _AuthScreen.signup) {
        return SignupScreen(
          theme: theme,
          onAuthenticated: (user) => setState(() => _user = user),
          onBack: () => setState(() => _screen = _AuthScreen.login),
        );
      }
      return LoginScreen(
        theme: theme,
        onAuthenticated: (user) => setState(() => _user = user),
        onSignup: () => setState(() => _screen = _AuthScreen.signup),
        onContinueAsGuest: () => setState(() => _guest = true),
      );
    }
    return CalendarHome(
      deviceZone: widget.deviceZone,
      user: _user,
      onLogout: () async {
        if (_user != null) await AuthService.instance.logout();
        setState(() {
          _user = null;
          _guest = false;
          _screen = _AuthScreen.login;
        });
      },
    );
  }
}

class CalendarHome extends StatefulWidget {
  final tz.Location deviceZone;
  final AuthUser? user;
  final VoidCallback onLogout;
  const CalendarHome({
    super.key,
    required this.deviceZone,
    required this.user,
    required this.onLogout,
  });

  @override
  State<CalendarHome> createState() => _CalendarHomeState();
}

class _CalendarHomeState extends State<CalendarHome>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ViewMode _view = ViewMode.month;
  DateTime _anchorDate = DateTime.now();
  String _selectedKey = date_utils.toDateKey(DateTime.now());
  bool _showHolidays = DisplaySettings.instance.enabled(
    DisplaySetting.holidays,
  );
  bool _showLunar = DisplaySettings.instance.enabled(DisplaySetting.lunar);
  bool _showSolarTerms = DisplaySettings.instance.enabled(
    DisplaySetting.solarTerms,
  );
  bool _showAnniversaries = DisplaySettings.instance.enabled(
    DisplaySetting.anniversaries,
  );
  Map<String, String> _apiHolidays = const {};
  Map<String, String> _apiSolarTerms = const {};
  Map<String, List<String>> _apiAnniversaries = const {};
  int? _apiHolidaysYear;
  late SystemEventsSync _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync = SystemEventsSync(context.read<EventStore>());
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSync());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _loadHolidays(_anchorDate.year),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshImported());
  }

  Future<void> _setDisplaySetting(
    DisplaySetting setting,
    bool value,
    VoidCallback update,
  ) async {
    setState(update);
    try {
      await DisplaySettings.instance.setEnabled(setting, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('표시 설정을 저장하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _loadHolidays(int year) async {
    try {
      final specialDays = await AuthService.instance.specialDays(year);
      if (mounted && _anchorDate.year == year) {
        setState(() {
          _apiHolidays = specialDays.holidays;
          _apiSolarTerms = specialDays.solarTerms;
          _apiAnniversaries = specialDays.anniversaries;
          _apiHolidaysYear = year;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runSync();
  }

  (String, String) get _range {
    final from = date_utils.toDateKey(
      DateTime(_anchorDate.year, _anchorDate.month - 1, 24),
    );
    final to = date_utils.toDateKey(
      DateTime(_anchorDate.year, _anchorDate.month + 1, 7),
    );
    return (from, to);
  }

  Future<void> _runSync() async {
    final (from, to) = _range;
    await _sync.sync(
      date_utils.parseDateKey(from),
      date_utils.parseDateKey(to),
    );
  }

  Future<void> _refreshImported() async {
    final imports = context.read<ImportedEvents>();
    final (from, to) = _range;
    for (final entry in imports.sources.entries) {
      try {
        await imports.refresh(
          entry.key,
          entry.value,
          date_utils.parseDateKey(from),
          date_utils.parseDateKey(to),
        );
      } catch (_) {
        // Preserve the previous import while offline or after a revoked authorization.
      }
    }
  }

  EventMap _combineEvents(EventMap local, EventMap imported) {
    final all = <String, List<CalendarEvent>>{};
    for (final entry in local.entries) all[entry.key] = [...entry.value];
    for (final entry in imported.entries)
      (all[entry.key] ??= []).addAll(entry.value);
    return all;
  }

  Future<void> _connectCalendar(String provider) async {
    try {
      if (provider == 'apple' || provider == 'naver') {
        if (!await EventKit.requestAccess())
          throw AuthException('Apple 캘린더 접근을 허용해 주세요.');
        final (from, to) = _range;
        final native = await EventKit.fetchEvents(
          date_utils.parseDateKey(from),
          date_utils.parseDateKey(to),
        );
        final imported = <String, List<CalendarEvent>>{};
        for (final event in native) {
          (imported[event.date] ??= []).add(
            event.copyWith(
              id: 'import:$provider:${event.systemEventId ?? event.id}',
              description:
                  '${provider == 'naver' ? '네이버/CalDAV' : 'Apple'} · 읽기 전용',
            ),
          );
        }
        context.read<ImportedEvents>().replaceProvider(provider, imported);
        if (mounted && provider == 'naver') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('iPhone 설정에 추가된 네이버 CalDAV 일정을 가져왔습니다.'),
            ),
          );
        }
        return;
      }
      final url = await AuthService.instance.calendarImportStart(provider);
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'calendar',
      );
      final callback = Uri.parse(result);
      if (callback.queryParameters['result'] != 'success')
        throw AuthException(callback.queryParameters['error'] ?? '연결하지 못했습니다.');
      if (!mounted) return;
      final calendars = await AuthService.instance.importCalendars(provider);
      if (!mounted) return;
      await _pickAndImport(provider, calendars);
    } on AuthException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('캘린더 연결을 완료하지 못했습니다.')));
    }
  }

  Future<void> _pickAndImport(
    String provider,
    List<ImportCalendar> calendars,
  ) async {
    final selected = <ImportCalendar>{...calendars};
    final choices = await showDialog<List<ImportCalendar>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('가져올 캘린더'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final calendar in calendars)
                  CheckboxListTile(
                    value: selected.contains(calendar),
                    title: Text(calendar.title),
                    onChanged: (checked) => setDialogState(
                      () => checked == true
                          ? selected.add(calendar)
                          : selected.remove(calendar),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected.toList()),
              child: const Text('가져오기'),
            ),
          ],
        ),
      ),
    );
    if (choices == null || choices.isEmpty || !mounted) return;
    final (from, to) = _range;
    await context.read<ImportedEvents>().refresh(
      provider,
      choices,
      date_utils.parseDateKey(from),
      date_utils.parseDateKey(to),
    );
  }

  String get _title {
    switch (_view) {
      case ViewMode.month:
        return '${_anchorDate.year}. ${_anchorDate.month}.';
      case ViewMode.week:
        return date_utils.formatWeekTitle(_anchorDate);
      case ViewMode.list:
        return '전체 일정';
      case ViewMode.day:
        return date_utils.formatDayTitle(_anchorDate);
    }
  }

  void _goPrev() {
    setState(() {
      if (_view == ViewMode.month) {
        _anchorDate = date_utils.addMonths(_anchorDate, -1);
      }
      if (_view == ViewMode.week) {
        _anchorDate = date_utils.addDays(_anchorDate, -7);
      }
      if (_view == ViewMode.day) {
        _anchorDate = date_utils.addDays(_anchorDate, -1);
      }
    });
    _refreshHolidays();
  }

  void _goNext() {
    setState(() {
      if (_view == ViewMode.month) {
        _anchorDate = date_utils.addMonths(_anchorDate, 1);
      }
      if (_view == ViewMode.week) {
        _anchorDate = date_utils.addDays(_anchorDate, 7);
      }
      if (_view == ViewMode.day) {
        _anchorDate = date_utils.addDays(_anchorDate, 1);
      }
    });
    _refreshHolidays();
  }

  void _goToday() {
    setState(() {
      _anchorDate = DateTime.now();
      _selectedKey = date_utils.toDateKey(_anchorDate);
    });
    _refreshHolidays();
  }

  void _refreshHolidays() {
    if (_apiHolidaysYear != _anchorDate.year) {
      _loadHolidays(_anchorDate.year);
    }
    _refreshImported();
  }

  bool _creatingEvent = false;

  Future<void> _openCreate(DateTime date, [String? time]) async {
    if (!_sync.isSupported) {
      await _openSheet(draft: null, date: date, time: time);
      return;
    }
    if (_creatingEvent) return;
    _creatingEvent = true;
    try {
      // Reading permission lets the app display the event saved by Apple UI.
      await EventKit.requestAccess();
      if (!mounted) return;
      final result = await EventKit.presentEventEditor(date, time);
      if (!mounted || !result.saved) return;
      if (result.event != null) {
        await context.read<EventStore>().saveEvent(result.event!);
        if (!mounted) return;
        setState(() {
          _selectedKey = result.event!.date;
          _anchorDate = date_utils.parseDateKey(_selectedKey);
        });
        await _runSync();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Apple 캘린더에 저장했습니다. 앱에 표시하려면 설정에서 캘린더 전체 접근을 허용해 주세요.',
            ),
          ),
        );
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Apple 일정 추가 화면을 열 수 없습니다.')),
        );
      }
    } finally {
      _creatingEvent = false;
    }
  }

  Future<void> _openEdit(CalendarEvent event) async {
    if (event.id.startsWith('import:')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가져온 일정은 읽기 전용입니다. 원본 캘린더에서 수정해 주세요.')),
      );
      return;
    }
    final store = context.read<EventStore>();
    final seriesId = event.seriesId;
    final source = seriesId != null
        ? store.events.values
              .expand((e) => e)
              .firstWhere((e) => e.id == seriesId, orElse: () => event)
        : event;
    final resolved = source.systemEventId != null
        ? source.copyWith(id: source.id, clearSeriesId: true)
        : source;
    await _openSheet(
      draft: resolved,
      date: date_utils.parseDateKey(resolved.date),
      time: resolved.time,
    );
  }

  Future<void> _openSheet({
    required CalendarEvent? draft,
    required DateTime date,
    String? time,
  }) async {
    final store = context.read<EventStore>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventSheet(
        theme: Theme.of(context).brightness == Brightness.dark
            ? darkTheme
            : lightTheme,
        draft: draft,
        isEditing: draft != null,
        initialDate: date,
        initialTime: time,
        onSave: (event) async {
          final saved = await store.saveEvent(event);
          await _syncToEventKit(store, saved);
          if (context.mounted) Navigator.pop(context);
        },
        onDelete: (id, dateKey) async {
          final existing = store.events[dateKey]?.firstWhere(
            (e) => e.id == id,
            orElse: () => draft!,
          );
          if (existing?.systemEventId != null) {
            await EventKit.deleteEvent(existing!.systemEventId!);
          }
          await store.deleteEvent(dateKey, id);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _syncToEventKit(EventStore store, CalendarEvent event) async {
    if (!_sync.isSupported) return;
    if (!await EventKit.isAvailable()) return;
    if (!await EventKit.requestAccess()) return;
    if (event.systemEventId != null) {
      await EventKit.updateEvent(event);
    } else {
      final identifier = await EventKit.createEvent(event);
      if (identifier != null) {
        await store.saveEvent(event.copyWith(systemEventId: identifier));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).brightness == Brightness.dark
        ? darkTheme
        : lightTheme;
    final store = context.watch<EventStore>();
    final imported = context.watch<ImportedEvents>();
    final (from, to) = _range;
    final expanded = expandEvents(
      _combineEvents(store.events, imported.events),
      from,
      to,
      widget.deviceZone,
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.bg,

      drawer: _AccountDrawer(
        theme: theme,
        user: widget.user,
        showHolidays: _showHolidays,
        showLunar: _showLunar,
        showSolarTerms: _showSolarTerms,
        showAnniversaries: _showAnniversaries,
        onAnniversariesChanged: (value) => _setDisplaySetting(
          DisplaySetting.anniversaries,
          value,
          () => _showAnniversaries = value,
        ),
        onHolidaysChanged: (value) => _setDisplaySetting(
          DisplaySetting.holidays,
          value,
          () => _showHolidays = value,
        ),
        onLunarChanged: (value) => _setDisplaySetting(
          DisplaySetting.lunar,
          value,
          () => _showLunar = value,
        ),
        onSolarTermsChanged: (value) => _setDisplaySetting(
          DisplaySetting.solarTerms,
          value,
          () => _showSolarTerms = value,
        ),
        onConnectCalendar: _connectCalendar,
        onLogout: widget.onLogout,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              theme: theme,
              title: _title,
              selectedDate: _anchorDate,
              onPrev: _goPrev,
              onNext: _goNext,
              onToday: _goToday,
              onDateSelected: (date) {
                setState(() {
                  _anchorDate = date;
                  _selectedKey = date_utils.toDateKey(date);
                });
                _refreshHolidays();
              },
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onSearch: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SearchScreen(
                    rangeFrom: from,
                    rangeTo: to,
                    deviceZone: widget.deviceZone,
                    onEventPress: _openEdit,
                  ),
                ),
              ),
            ),
            Expanded(
              child: !store.loaded
                  ? Center(
                      child: Text(
                        '일정을 불러오고 있습니다…',
                        style: TextStyle(color: theme.textMuted),
                      ),
                    )
                  : Stack(
                      children: [
                        Positioned.fill(child: _buildView(theme, expanded)),
                        Positioned(
                          right: 20,
                          bottom: 24,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: LiquidGlass(
                              radius: 24,
                              child: IconButton(
                                tooltip: '일정 추가',
                                onPressed: () => _openCreate(
                                  _view == ViewMode.month
                                      ? date_utils.parseDateKey(_selectedKey)
                                      : _anchorDate,
                                ),
                                icon: Icon(
                                  Icons.add,
                                  color: theme.text,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildView(AppTheme theme, EventMap expanded) {
    switch (_view) {
      case ViewMode.month:
        return MonthAgenda(
          theme: theme,
          viewDate: _anchorDate,
          events: expanded,
          selectedKey: _selectedKey,
          onPreviousMonth: _goPrev,
          onNextMonth: _goNext,
          showHolidays: _showHolidays,
          holidayNames: _apiHolidays,
          solarTermNames: _showSolarTerms ? _apiSolarTerms : const {},
          anniversaryNames: _showAnniversaries ? _apiAnniversaries : const {},
          showLunar: _showLunar,
          onEventPress: _openEdit,
          onSlotPress: (date, hour) =>
              _openCreate(date, '${hour.toString().padLeft(2, '0')}:00'),
          onSelectDate: (key) {
            setState(() {
              _selectedKey = key;
              _anchorDate = date_utils.parseDateKey(key);
            });
            _refreshHolidays();
          },
        );
      case ViewMode.week:
        return TimeGridView(
          theme: theme,
          days: date_utils.getWeekDays(_anchorDate),
          events: expanded,
          onSlotPress: (date, hour) =>
              _openCreate(date, '${hour.toString().padLeft(2, '0')}:00'),
          onEventPress: _openEdit,
        );
      case ViewMode.day:
        return TimeGridView(
          theme: theme,
          days: [_anchorDate],
          events: expanded,
          onSlotPress: (date, hour) =>
              _openCreate(date, '${hour.toString().padLeft(2, '0')}:00'),
          onEventPress: _openEdit,
        );
      case ViewMode.list:
        return EventListView(
          theme: theme,
          events: expanded,
          onEventPress: _openEdit,
        );
    }
  }
}

class _AccountDrawer extends StatelessWidget {
  final AppTheme theme;
  final AuthUser? user;
  final bool showHolidays;
  final bool showLunar;
  final bool showSolarTerms;
  final bool showAnniversaries;
  final ValueChanged<bool> onAnniversariesChanged;
  final ValueChanged<bool> onHolidaysChanged;
  final ValueChanged<bool> onLunarChanged;
  final ValueChanged<bool> onSolarTermsChanged;
  final VoidCallback onLogout;
  final ValueChanged<String> onConnectCalendar;
  const _AccountDrawer({
    required this.theme,
    required this.user,
    required this.showHolidays,
    required this.showLunar,
    required this.showSolarTerms,
    required this.showAnniversaries,
    required this.onAnniversariesChanged,
    required this.onHolidaysChanged,
    required this.onLunarChanged,
    required this.onSolarTermsChanged,
    required this.onLogout,
    required this.onConnectCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? '로그인이 필요합니다';
    final name = user?.name.isNotEmpty == true
        ? user!.name
        : user?.email.split('@').first;
    return Drawer(
      backgroundColor: theme.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null || name.isEmpty ? '사용자' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '캘린더 관리',
                    onPressed: () {},
                    icon: Icon(
                      Icons.calendar_month_outlined,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                    ),
                  ),
                  IconButton(
                    tooltip: '설정',
                    onPressed: () {},
                    icon: Icon(
                      Icons.settings_outlined,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: theme.border, height: 1),
              const SizedBox(height: 20),
              _sectionTitle('추가 캘린더'),
              const SizedBox(height: 10),
              _calendarConnect(
                'Apple 캘린더',
                CupertinoIcons.calendar,
                () => onConnectCalendar('apple'),
              ),
              _calendarConnect(
                '네이버 캘린더 (iPhone CalDAV)',
                CupertinoIcons.cloud,
                () => onConnectCalendar('naver'),
              ),
              _calendarConnect(
                'Google 캘린더',
                CupertinoIcons.globe,
                () => onConnectCalendar('google'),
              ),
              _calendarConnect(
                '카카오 캘린더',
                CupertinoIcons.chat_bubble_2,
                () => onConnectCalendar('kakao'),
              ),
              _calendarConnect(
                'Notion 캘린더',
                CupertinoIcons.doc_text,
                () => onConnectCalendar('notion'),
              ),
              _displayCheckbox(
                label: '법정 기념일',
                value: showAnniversaries,
                onChanged: onAnniversariesChanged,
                subscription: true,
              ),
              const SizedBox(height: 28),
              _sectionTitle('기능 표시'),
              const SizedBox(height: 10),
              _displayCheckbox(
                label: '공휴일',
                value: showHolidays,
                onChanged: onHolidaysChanged,
              ),
              _displayCheckbox(
                label: '음력',
                value: showLunar,
                onChanged: onLunarChanged,
              ),
              _displayCheckbox(
                label: '절기',
                value: showSolarTerms,
                onChanged: onSolarTermsChanged,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onLogout();
                },
                child: Text(
                  user != null ? '로그아웃' : '로그인',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _calendarConnect(String label, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.textSecondary),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: theme.text, fontSize: 15),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: theme.textMuted,
              ),
            ],
          ),
        ),
      );

  Widget _displayCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool subscription = false,
  }) {
    return Semantics(
      label: label,
      checked: value,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Icon(
                value
                    ? CupertinoIcons.checkmark_square_fill
                    : CupertinoIcons.square,
                size: 23,
                color: subscription ? theme.textSecondary : theme.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: theme.text, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
