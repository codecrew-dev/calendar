import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
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
  await store.load();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
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
  late SystemEventsSync _sync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync = SystemEventsSync(context.read<EventStore>());
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSync());
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

  void _goPrev() => setState(() {
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

  void _goNext() => setState(() {
    if (_view == ViewMode.month) {
      _anchorDate = date_utils.addMonths(_anchorDate, 1);
    }
    if (_view == ViewMode.week) {
      _anchorDate = date_utils.addDays(_anchorDate, 7);
    }
    if (_view == ViewMode.day) _anchorDate = date_utils.addDays(_anchorDate, 1);
  });

  void _goToday() => setState(() {
    _anchorDate = DateTime.now();
    _selectedKey = date_utils.toDateKey(_anchorDate);
  });

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
    final (from, to) = _range;
    final expanded = expandEvents(store.events, from, to, widget.deviceZone);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.bg,

      drawer: _AccountDrawer(
        theme: theme,
        user: widget.user,
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
              onDateSelected: (date) => setState(() {
                _anchorDate = date;
                _selectedKey = date_utils.toDateKey(date);
              }),
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
          onEventPress: _openEdit,
          onSlotPress: (date, hour) =>
              _openCreate(date, '${hour.toString().padLeft(2, '0')}:00'),
          onSelectDate: (key) => setState(() {
            _selectedKey = key;
            _anchorDate = date_utils.parseDateKey(key);
          }),
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
  final VoidCallback onLogout;
  const _AccountDrawer({
    required this.theme,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? '로그인이 필요합니다';
    final name = user?.email.split('@').first;
    return Drawer(
      backgroundColor: theme.bgSecondary,
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
                      color: theme.accent,
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
}
