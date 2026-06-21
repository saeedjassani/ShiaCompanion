import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants.dart';
import '../models/prayer_counter_state.dart';
import '../services/proximity_sensor_service.dart';
import '../utils/shared_preferences.dart';
import '../widgets/responsive_content.dart';

class PrayerCounterPage extends StatefulWidget {
  const PrayerCounterPage({
    super.key,
    this.proximitySensorService = const ProximitySensorService(),
  });

  final ProximitySensorService proximitySensorService;

  @override
  State<PrayerCounterPage> createState() => _PrayerCounterPageState();
}

class _PrayerCounterPageState extends State<PrayerCounterPage>
    with WidgetsBindingObserver {
  static const _totalRakaatKey = 'prayer_counter_total_rakaat';
  static const _completedSajdahsKey = 'prayer_counter_completed_sajdahs';
  static const _sensorDebounce = Duration(milliseconds: 700);

  late PrayerCounterState _counter;
  StreamSubscription<bool>? _proximitySubscription;
  bool? _sensorAvailable;
  bool _sensorEnabled = false;
  bool _sensorNear = false;
  bool _sensorArmed = false;
  bool _resumeSensorWhenActive = false;
  DateTime? _lastSensorCountAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _counter = _loadCounter();
    unawaited(trackScreen('Rakaat Counter Page'));
    unawaited(WakelockPlus.enable());
    unawaited(_checkSensorAvailability());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _resumeSensorWhenActive) {
      _resumeSensorWhenActive = false;
      if (_sensorAvailable == true && !_counter.isComplete) {
        unawaited(_setSensorEnabled(true));
      }
    } else if (state != AppLifecycleState.resumed && _sensorEnabled) {
      _resumeSensorWhenActive = true;
      unawaited(_setSensorEnabled(false));
    }
  }

  PrayerCounterState _loadCounter() {
    if (!SP.isInitialized) {
      return const PrayerCounterState(totalRakaat: 4);
    }

    final savedTotal = SP.prefs.getInt(_totalRakaatKey) ?? 4;
    final totalRakaat = const {2, 3, 4}.contains(savedTotal) ? savedTotal : 4;
    final savedSajdahs = SP.prefs.getInt(_completedSajdahsKey) ?? 0;
    final completedSajdahs = savedSajdahs.clamp(0, totalRakaat * 2);
    final savedCounter = PrayerCounterState(
      totalRakaat: totalRakaat,
      completedSajdahs: completedSajdahs,
    );
    if (savedCounter.isComplete) {
      unawaited(SP.prefs.setInt(_completedSajdahsKey, 0));
      return savedCounter.reset();
    }
    return savedCounter;
  }

  Future<void> _checkSensorAvailability() async {
    final available = await widget.proximitySensorService.isAvailable();
    if (!mounted) return;
    setState(() => _sensorAvailable = available);
    if (available && !_counter.isComplete) {
      await _setSensorEnabled(true);
    }
  }

  Future<void> _setSensorEnabled(bool enabled) async {
    if (enabled && _sensorEnabled) return;

    if (!enabled) {
      final subscription = _proximitySubscription;
      _proximitySubscription = null;
      if (mounted) {
        setState(() {
          _sensorEnabled = false;
          _sensorNear = false;
          _sensorArmed = false;
        });
      }
      await subscription?.cancel();
      return;
    }

    if (_sensorAvailable != true || _counter.isComplete) return;

    setState(() {
      _sensorEnabled = true;
      _sensorNear = false;
      _sensorArmed = false;
    });
    _proximitySubscription =
        widget.proximitySensorService.proximityStates.listen(
      _handleProximityState,
      onError: (_) {
        if (!mounted) return;
        unawaited(_setSensorEnabled(false));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The proximity sensor stopped responding. Check the phone position and turn automatic sensing on again.',
            ),
          ),
        );
      },
    );
  }

  void _handleProximityState(bool isNear) {
    if (!mounted || !_sensorEnabled) return;

    setState(() => _sensorNear = isNear);
    if (!isNear) {
      _sensorArmed = true;
      return;
    }

    final now = DateTime.now();
    final wasRecentlyCounted = _lastSensorCountAt != null &&
        now.difference(_lastSensorCountAt!) < _sensorDebounce;
    if (!_sensorArmed || wasRecentlyCounted || _counter.isComplete) return;

    _sensorArmed = false;
    _lastSensorCountAt = now;
    _recordSajdah();
  }

  void _recordSajdah() {
    if (_counter.isComplete) return;

    setState(() => _counter = _counter.recordSajdah());
    _saveCounter();
    if (_counter.isComplete) {
      HapticFeedback.heavyImpact();
      unawaited(_setSensorEnabled(false));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text(
            'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَآلِ مُحَمَّدٍ وَعَجِّلْ فَرَجَهُمْ وَالْعَنْ أَعْدَاءَهُمْ أَجْمَعِينَ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  void _undoSajdah() {
    if (!_counter.hasStarted) return;
    setState(() => _counter = _counter.undoSajdah());
    _saveCounter();
    HapticFeedback.selectionClick();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  void _reset() {
    setState(() => _counter = _counter.reset());
    _saveCounter();
    HapticFeedback.selectionClick();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  Future<void> _changeTotalRakaat(int totalRakaat) async {
    if (totalRakaat == _counter.totalRakaat) return;

    if (_counter.hasStarted) {
      final shouldReset = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Start over?'),
              content: const Text(
                'Changing the number of rakaat will reset the current prayer count.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Start over'),
                ),
              ],
            ),
          ) ??
          false;
      if (!shouldReset || !mounted) return;
    }

    setState(() => _counter = _counter.reset(totalRakaat: totalRakaat));
    _saveCounter();
    if (_sensorAvailable == true && !_sensorEnabled) {
      unawaited(_setSensorEnabled(true));
    }
  }

  void _saveCounter() {
    if (!SP.isInitialized) return;
    unawaited(SP.prefs.setInt(_totalRakaatKey, _counter.totalRakaat));
    unawaited(
      SP.prefs.setInt(_completedSajdahsKey, _counter.completedSajdahs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Rakaat Counter'),
        actions: [
          IconButton(
            tooltip: 'How to place your phone',
            onPressed: _showPlacementGuide,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveScrollableContent(
        maxWidth: compactContentWidth,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPlacementPrompt(context),
            const SizedBox(height: 16),
            _buildPrayerLengthSelector(context),
            const SizedBox(height: 16),
            _buildCounterCard(context),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _counter.hasStarted ? _undoSajdah : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Undo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _counter.hasStarted ? _reset : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Start over'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSensorCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacementPrompt(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_iphone_rounded,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Place phone below the turbah',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Lay it flat below the turbah, with the top edge pointing toward it. Keep your forehead’s path clear.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerLengthSelector(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mosque_outlined,
                  size: 21,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prayer length', style: theme.textTheme.titleMedium),
                    Text(
                      'Select the number of rakaat',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_counter.totalRakaat},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                unawaited(_changeTotalRakaat(selection.first));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = _counter.isComplete
        ? 'Complete'
        : _sensorEnabled && _sensorNear
            ? 'Sajdah detected'
            : _sensorEnabled
                ? 'Sensor ready'
                : _sensorAvailable == null
                    ? 'Checking sensor'
                    : 'Automatic sensing off';
    final statusIcon = _counter.isComplete
        ? Icons.check_circle_rounded
        : _sensorEnabled
            ? Icons.sensors_rounded
            : _sensorAvailable == null
                ? Icons.hourglass_top_rounded
                : Icons.sensors_off_rounded;

    return Semantics(
      button: !_counter.isComplete,
      label: 'Current rakaat and sajdah',
      value: _counter.displayValue,
      hint: _counter.isComplete
          ? null
          : 'Tap only if a sajdah was not detected automatically',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _counter.isComplete ? null : _recordSajdah,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                Color.lerp(
                  colorScheme.primaryContainer,
                  colorScheme.surfaceContainerHighest,
                  0.55,
                )!,
              ],
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 17,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          status,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: Tween<double>(begin: 0.88, end: 1).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: Text(
                    _counter.displayValue,
                    key: ValueKey(_counter.displayValue),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 100,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -4,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _counter.isComplete
                      ? '${_counter.totalRakaat} rakaat completed'
                      : _counter.hasStarted
                          ? 'Rakaat ${_counter.rakaat}  ·  Sajdah ${_counter.sajdah}'
                          : 'Ready for the first sajdah',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                _buildProgressDots(context),
                const SizedBox(height: 13),
                Text(
                  '${_counter.completedSajdahs} of ${_counter.totalSajdahs} sajdahs',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.78,
                    ),
                  ),
                ),
                if (!_counter.isComplete) ...[
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _sensorEnabled
                            ? Icons.sensors_rounded
                            : Icons.touch_app_outlined,
                        size: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _sensorEnabled
                              ? 'Automatic counting · tap only if one is missed'
                              : 'Tap card to add a sajdah manually',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressDots(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: List.generate(_counter.totalSajdahs, (index) {
        final isComplete = index < _counter.completedSajdahs;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 7,
            margin: EdgeInsets.only(
              right: index == _counter.totalSajdahs - 1 ? 0 : 6,
            ),
            decoration: BoxDecoration(
              color: isComplete
                  ? colorScheme.primary
                  : colorScheme.onPrimaryContainer.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSensorCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = switch (_sensorAvailable) {
      null => 'Checking this device…',
      false => 'Automatic counting is not available on this device.',
      true when _sensorEnabled && _sensorNear =>
        'Object detected. Move away to arm the next count.',
      true when _sensorEnabled => 'Ready — each detected sajdah counts once.',
      true => 'Off — turn this on to count sajdahs automatically.',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _sensorEnabled
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
            value: _sensorEnabled,
            onChanged: _sensorAvailable == true && !_counter.isComplete
                ? (value) => unawaited(_setSensorEnabled(value))
                : null,
            secondary: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: _sensorAvailable == null
                  ? const Padding(
                      padding: EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _sensorNear ? Icons.sensors : Icons.sensors_outlined,
                      color: colorScheme.primary,
                    ),
            ),
            title: const Text('Automatic sensing'),
            subtitle: Text(subtitle),
          ),
          if (_sensorAvailable == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                defaultTargetPlatform == TargetPlatform.iOS
                    ? 'On iPhone, the display may turn off briefly while the sensor is covered. Sensor position and range vary by model.'
                    : 'Sensor position and range vary by phone. Some Android phones use a less reliable virtual proximity sensor.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPlacementGuide() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.phone_iphone_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Phone placement',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Place the phone flat below the turbah, with its top edge and sensor pointing toward it. Keep the phone completely out of the path of your forehead.',
            ),
            const SizedBox(height: 12),
            Text(
              'Before beginning, enable the sensor and test it with your hand. Move your hand away after each test so the next count can arm.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proximitySubscription?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }
}
