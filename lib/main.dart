import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const black = Color(0xFF000000);
const white = Color(0xFFFFFFFF);
const muted = Color(0xFF969696);
const line = Color(0xFF292929);

const weekdays = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: black,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await AlarmScheduler.instance.initialize();
  runApp(const ClockApp());
}

class ClockApp extends StatelessWidget {
  const ClockApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Clock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: black,
          canvasColor: black,
          colorScheme: const ColorScheme.dark(
            primary: white,
            onPrimary: black,
            surface: black,
            onSurface: white,
            secondary: white,
            onSecondary: black,
          ),
          dividerColor: line,
          dialogBackgroundColor: const Color(0xFF101010),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: black,
            hintStyle: const TextStyle(color: muted),
            labelStyle: const TextStyle(color: muted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: white),
            ),
          ),
          timePickerTheme: const TimePickerThemeData(
            backgroundColor: Color(0xFF101010),
            hourMinuteTextColor: white,
            dayPeriodTextColor: white,
            dialHandColor: white,
            dialBackgroundColor: Color(0xFF202020),
            dialTextColor: white,
            entryModeIconColor: white,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF202020),
            contentTextStyle: TextStyle(color: white),
            behavior: SnackBarBehavior.floating,
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? black : muted),
            trackColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? white
                    : const Color(0xFF303030)),
            trackOutlineColor: WidgetStateProperty.all(line),
          ),
        ),
        home: const ClockHomePage(),
      );
}

class ClockHomePage extends StatefulWidget {
  const ClockHomePage({super.key});

  @override
  State<ClockHomePage> createState() => _ClockHomePageState();
}

class _ClockHomePageState extends State<ClockHomePage> {
  int _tab = 0;
  DateTime _now = DateTime.now();
  List<AlarmEntry> _alarms = <AlarmEntry>[];
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadAlarms();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('clock_alarms_v1');
      if (stored != null) {
        final decoded = jsonDecode(stored) as List<dynamic>;
        _alarms = decoded
            .map((entry) => AlarmEntry.fromJson(entry as Map<String, dynamic>))
            .toList()
          ..sort(_compareAlarms);
      }
    } catch (error) {
      debugPrint('Could not load alarms: $error');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'clock_alarms_v1',
      jsonEncode(_alarms.map((alarm) => alarm.toJson()).toList()),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editAlarm([AlarmEntry? oldAlarm]) async {
    final labelController = TextEditingController(text: oldAlarm?.label ?? '');
    var selectedTime = TimeOfDay(
      hour: oldAlarm?.hour ?? _now.hour,
      minute: oldAlarm?.minute ?? _now.minute,
    );
    final selectedDays = <int>{...?oldAlarm?.days};

    final draft = await showModalBottomSheet<AlarmDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: black,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: line),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 6, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oldAlarm == null ? 'New alarm' : 'Edit alarm',
                  style: const TextStyle(
                    color: white, fontSize: 24, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: sheetContext,
                        initialTime: selectedTime,
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: white,
                              onPrimary: black,
                              surface: Color(0xFF101010),
                              onSurface: white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        updateSheet(() => selectedTime = picked);
                      }
                    },
                    child: Text(
                      _formatTimeOfDay(selectedTime),
                      style: const TextStyle(
                        color: white, fontSize: 52,
                        fontWeight: FontWeight.w300, letterSpacing: -2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  maxLength: 40,
                  style: const TextStyle(color: white),
                  decoration: const InputDecoration(
                    labelText: 'Alarm name (optional)',
                    hintText: 'Wake up',
                    counterStyle: TextStyle(color: muted),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Repeat', style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List<Widget>.generate(7, (index) {
                    final day = index + 1;
                    const letters = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final chosen = selectedDays.contains(day);
                    return Tooltip(
                      message: weekdays[index],
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => updateSheet(() {
                          if (chosen) {
                            selectedDays.remove(day);
                          } else {
                            selectedDays.add(day);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: chosen ? white : black,
                            border: Border.all(color: chosen ? white : line),
                          ),
                          child: Text(
                            letters[index],
                            style: TextStyle(
                              color: chosen ? black : white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _repeatDescription(selectedDays.toList()),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: white,
                      foregroundColor: black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(
                      AlarmDraft(
                        hour: selectedTime.hour,
                        minute: selectedTime.minute,
                        label: labelController.text.trim(),
                        days: selectedDays.toList()..sort(),
                      ),
                    ),
                    child: Text(
                      oldAlarm == null ? 'Save alarm' : 'Save changes',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    labelController.dispose();
    if (!mounted || draft == null) return;

    final alarm = AlarmEntry(
      id: oldAlarm?.id ?? DateTime.now().microsecondsSinceEpoch % 9000000 + 1,
      hour: draft.hour,
      minute: draft.minute,
      label: draft.label,
      days: draft.days,
      enabled: oldAlarm?.enabled ?? true,
    );
    if (oldAlarm != null) await AlarmScheduler.instance.cancel(oldAlarm.id);
    setState(() {
      final index = _alarms.indexWhere((item) => item.id == alarm.id);
      if (index < 0) {
        _alarms.add(alarm);
      } else {
        _alarms[index] = alarm;
      }
      _alarms.sort(_compareAlarms);
    });
    await _saveAlarms();
    if (alarm.enabled) await _scheduleAlarm(alarm);
  }

  Future<void> _scheduleAlarm(AlarmEntry alarm) async {
    final notificationsAllowed =
        await AlarmScheduler.instance.requestPermissions();
    if (!notificationsAllowed) {
      _message('Allow notifications so alarms can alert you.');
      return;
    }
    try {
      final exact = await AlarmScheduler.instance.schedule(alarm);
      if (!exact) {
        _message('Exact alarm access is off. This alarm may be delayed.');
      }
    } catch (error) {
      debugPrint('Could not schedule alarm: $error');
      _message('Could not schedule alarm. Check Android alarm permissions.');
    }
  }

  Future<void> _toggleAlarm(AlarmEntry alarm, bool enabled) async {
    final updated = alarm.copyWith(enabled: enabled);
    setState(() {
      _alarms = _alarms
          .map((item) => item.id == alarm.id ? updated : item)
          .toList();
    });
    await _saveAlarms();
    if (enabled) {
      await _scheduleAlarm(updated);
    } else {
      await AlarmScheduler.instance.cancel(alarm.id);
    }
  }

  Future<void> _deleteAlarm(AlarmEntry alarm) async {
    setState(() => _alarms.removeWhere((item) => item.id == alarm.id));
    await AlarmScheduler.instance.cancel(alarm.id);
    await _saveAlarms();
    _message('Alarm deleted');
  }

  @override
  Widget build(BuildContext context) {
    final title = _tab == 0 ? 'Clock' : 'Alarm';
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 16, 20, 10),
              child: Row(
                children: [
                  Text(title, style: const TextStyle(
                    color: white, fontSize: 29, fontWeight: FontWeight.w600,
                    letterSpacing: -0.7,
                  )),
                  const Spacer(),
                  if (_tab == 1 && _alarms.isNotEmpty)
                    Text(_alarms.length.toString(),
                        style: const TextStyle(color: muted, fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  ClockFace(now: _now),
                  AlarmList(
                    alarms: _alarms,
                    loading: _loading,
                    onAdd: () => _editAlarm(),
                    onEdit: _editAlarm,
                    onToggle: _toggleAlarm,
                    onDelete: _deleteAlarm,
                  ),
                ],
              ),
            ),
            BottomNavigation(
              selectedIndex: _tab,
              onChanged: (index) => setState(() => _tab = index),
            ),
          ],
        ),
      ),
    );
  }
}

class ClockFace extends StatelessWidget {
  const ClockFace({required this.now, super.key});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rawHour = now.hour % 12;
    final hour = (rawHour == 0 ? 12 : rawHour).toString();
    final minute = now.minute.toString().padLeft(2, '0');
    final date = weekdays[now.weekday - 1] +
        ', ' + months[now.month - 1] + ' ' + now.day.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$hour:$minute',
                maxLines: 1,
                style: const TextStyle(
                  color: white, fontSize: 82, height: 1.08,
                  fontWeight: FontWeight.w300, letterSpacing: -3.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(date, style: const TextStyle(color: white, fontSize: 17)),
          ],
        ),
      ),
    );
  }
}

class AlarmList extends StatelessWidget {
  const AlarmList({
    required this.alarms,
    required this.loading,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final List<AlarmEntry> alarms;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<AlarmEntry> onEdit;
  final Future<void> Function(AlarmEntry, bool) onToggle;
  final Future<void> Function(AlarmEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: white),
        ),
      );
    }
    if (alarms.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.alarm_outlined, size: 78, color: white),
                  SizedBox(height: 24),
                  Text('No alarms', style: TextStyle(
                    color: white, fontSize: 24, fontWeight: FontWeight.w500,
                  )),
                  SizedBox(height: 12),
                  Text('Tap the + button to add an alarm',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 14)),
                ],
              ),
            ),
          ),
          Positioned(right: 24, bottom: 25,
              child: AddAlarmButton(onPressed: onAdd)),
        ],
      );
    }
    return Stack(
      children: [
        ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: alarms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final alarm = alarms[index];
            final displayHour =
                (alarm.hour % 12 == 0 ? 12 : alarm.hour % 12).toString();
            final displayMinute = alarm.minute.toString().padLeft(2, '0');
            final period = alarm.hour < 12 ? 'AM' : 'PM';
            return Dismissible(
              key: ValueKey<int>(alarm.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  border: Border.all(color: line),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.delete_outline, color: white),
              ),
              onDismissed: (_) => onDelete(alarm),
              child: Material(
                color: black,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () => onEdit(alarm),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$displayHour:$displayMinute $period',
                                style: TextStyle(
                                  color: alarm.enabled ? white : muted,
                                  fontSize: 36, fontWeight: FontWeight.w300,
                                  letterSpacing: -1.1,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                )),
                              if (alarm.label.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(alarm.label, maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: alarm.enabled ? white : muted)),
                              ],
                              const SizedBox(height: 7),
                              Text(_repeatDescription(alarm.days),
                                style: const TextStyle(color: muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: alarm.enabled,
                          onChanged: (value) => onToggle(alarm, value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(right: 24, bottom: 25,
            child: AddAlarmButton(onPressed: onAdd)),
      ],
    );
  }
}

class AddAlarmButton extends StatelessWidget {
  const AddAlarmButton({required this.onPressed, super.key});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: 62, height: 62,
            child: Icon(Icons.add, color: black, size: 30),
          ),
        ),
      );
}

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        height: 82,
        padding: const EdgeInsets.fromLTRB(25, 8, 25, 6),
        decoration: const BoxDecoration(
          color: black,
          border: Border(top: BorderSide(color: Color(0xFF080808))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavigationItem(
              icon: Icons.access_time,
              label: 'Clock',
              selected: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
            _NavigationItem(
              icon: Icons.alarm_outlined,
              label: 'Alarm',
              selected: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ],
        ),
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              Icon(icon, size: 25, color: selected ? white : muted),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(
                color: selected ? white : muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 28 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      );
}

class AlarmEntry {
  const AlarmEntry({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.days,
    required this.enabled,
  });
  final int id;
  final int hour;
  final int minute;
  final String label;
  final List<int> days;
  final bool enabled;

  AlarmEntry copyWith({bool? enabled}) => AlarmEntry(
        id: id, hour: hour, minute: minute, label: label, days: days,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id, 'hour': hour, 'minute': minute, 'label': label,
        'days': days, 'enabled': enabled,
      };

  factory AlarmEntry.fromJson(Map<String, dynamic> json) => AlarmEntry(
        id: json['id'] as int,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        label: json['label'] as String? ?? '',
        days: (json['days'] as List<dynamic>? ?? <dynamic>[])
            .map((day) => day as int).toList(),
        enabled: json['enabled'] as bool? ?? true,
      );
}

class AlarmDraft {
  const AlarmDraft({
    required this.hour,
    required this.minute,
    required this.label,
    required this.days,
  });
  final int hour;
  final int minute;
  final String label;
  final List<int> days;
}

class AlarmScheduler {
  AlarmScheduler._();
  static final AlarmScheduler instance = AlarmScheduler._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (error) {
      debugPrint('Could not detect local timezone: $error');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
      ),
    );
  }

  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final notificationAccess =
        await android.requestNotificationsPermission() ?? true;
    if (!notificationAccess) return false;
    final exact = await android.canScheduleExactNotifications() ?? false;
    if (!exact) await android.requestExactAlarmsPermission();
    return true;
  }

  Future<bool> schedule(AlarmEntry alarm) async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final exact = await android.canScheduleExactNotifications() ?? false;
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'clock_alarms_v2',
        'Alarms',
        channelDescription: 'Scheduled alerts from Clock.',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        icon: 'ic_stat_clock',
      ),
    );

    await cancel(alarm.id);
    final now = tz.TZDateTime.now(tz.local);
    if (alarm.days.isEmpty) {
      var next = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, alarm.hour, alarm.minute,
      );
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _singleId(alarm.id),
        title: alarm.label.isEmpty ? 'Alarm' : alarm.label,
        body: 'It is time.',
        scheduledDate: next,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: 'clock-alarm:' + alarm.id.toString(),
      );
    } else {
      for (final day in (alarm.days.toSet().toList()..sort())) {
        final distance = (day - now.weekday + 7) % 7;
        final date = DateTime(now.year, now.month, now.day)
            .add(Duration(days: distance));
        var next = tz.TZDateTime(
          tz.local, date.year, date.month, date.day, alarm.hour, alarm.minute,
        );
        if (!next.isAfter(now)) next = next.add(const Duration(days: 7));
        await _plugin.zonedSchedule(
          id: _weeklyId(alarm.id, day),
          title: alarm.label.isEmpty ? 'Alarm' : alarm.label,
          body: 'It is time.',
          scheduledDate: next,
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'clock-alarm:' + alarm.id.toString(),
        );
      }
    }
    return exact;
  }

  Future<void> cancel(int alarmId) async {
    for (var day = 1; day <= 7; day++) {
      await _plugin.cancel(id: _weeklyId(alarmId, day));
    }
    await _plugin.cancel(id: _singleId(alarmId));
  }

  int _weeklyId(int id, int day) => id * 10 + day;
  int _singleId(int id) => id * 10 + 8;
}

int _compareAlarms(AlarmEntry a, AlarmEntry b) =>
    (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

String _repeatDescription(List<int> days) {
  if (days.isEmpty) return 'Once';
  if (days.length == 7) return 'Every day';
  return (days.toSet().toList()..sort())
      .map((day) => weekdays[day - 1].substring(0, 3))
      .join(' · ');
}

String _formatTimeOfDay(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
