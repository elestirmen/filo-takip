import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/strings.dart';
import '../core/visibility_rules.dart';
import '../data/fleet_repository.dart';
import '../services/location_permission.dart';
import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.uid,
    required this.isAnonymous,
  });

  final String uid;
  final bool isAnonymous;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  LocationPermissionStage _stage = LocationPermissionStage.denied;
  bool _serviceRunning = false;
  bool _trackingEnabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönmüş olabilir; izin durumu değişmiştir.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final LocationPermissionStage stage = await LocationService.currentStage();
    final bool running = await LocationService.isRunning();
    final bool preference = await LocationService.trackingPreference();
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _serviceRunning = running;
      _trackingEnabled = preference;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settingsScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          if (AppConfig.useFakeBackend) _buildSimulationCard(theme),
          _sectionTitle(theme, Strings.trackingSection),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text(Strings.trackingPermissionLabel),
            subtitle: Text(locationStageLabel(_stage)),
            trailing: _permissionAction(),
          ),
          SwitchListTile(
            secondary: Icon(
              _serviceRunning ? Icons.gps_fixed : Icons.gps_off,
              color: _serviceRunning ? theme.colorScheme.primary : null,
            ),
            title: const Text(Strings.trackingSwitch),
            subtitle: Text(
              _serviceRunning
                  ? Strings.trackingStateOn
                  : Strings.trackingStateOff,
            ),
            value: _trackingEnabled,
            onChanged: _busy || !widget.isAnonymous ? null : _onTrackingToggled,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              Strings.trackingSwitchHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          if (AppConfig.useFakeBackend)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                Strings.trackingSimulationNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          const Divider(),
          _sectionTitle(theme, Strings.settingsSessionSection),
          ListTile(
            leading: Icon(
              widget.isAnonymous
                  ? Icons.person_outline
                  : Icons.verified_user_outlined,
            ),
            title: Text(
              widget.isAnonymous
                  ? Strings.settingsSessionAnonymous
                  : Strings.settingsSessionEmail,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text(Strings.settingsSessionUid),
            subtitle: SelectableText(widget.uid),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, color: theme.colorScheme.tertiary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    Strings.settingsAdminDeviceWarning,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget? _permissionAction() {
    if (canTrackInBackground(_stage)) return null;
    if (_stage == LocationPermissionStage.serviceDisabled) {
      return TextButton(
        onPressed: LocationService.openLocationSettings,
        child: const Text(Strings.permissionOpenLocationSettings),
      );
    }
    return TextButton(
      onPressed: _busy ? null : () => _onTrackingToggled(true),
      child: const Text(Strings.trackingPermissionAction),
    );
  }

  // ------------------------------------------------------- İzin akışı

  Future<void> _onTrackingToggled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        await _enableTracking();
      } else {
        await LocationService.stop();
        await LocationService.setTrackingPreference(enabled: false);
        if (mounted) _showMessage(Strings.trackingStopped);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      await _refresh();
    }
  }

  /// Kademeli akış: önce araç kaydı, sonra konum servisi, sonra ön plan
  /// izni, en son ayrı bir açıklamayla arka plan izni.
  Future<void> _enableTracking() async {
    final FleetRepository repository = context.read<FleetRepository>();

    // 1) Servis yalnızca kayıtlı araç varken çalışır.
    if (findVehicleById(repository.latestVehicles, repository.uid) == null) {
      _showMessage(Strings.trackingNeedsVehicle);
      return;
    }

    // 2) Cihazın konum servisi.
    LocationPermissionStage stage = await LocationService.currentStage();
    if (stage == LocationPermissionStage.serviceDisabled) {
      final bool go = await _ask(
        title: Strings.permissionServiceDisabledTitle,
        message: Strings.permissionServiceDisabledRationale,
        action: Strings.permissionOpenLocationSettings,
      );
      if (go) await LocationService.openLocationSettings();
      return;
    }

    // 3) Ön plan konum izni.
    if (stage == LocationPermissionStage.denied) {
      final bool go = await _ask(
        title: Strings.permissionForegroundTitle,
        message: Strings.permissionForegroundRationale,
        action: Strings.permissionContinue,
      );
      if (!go) return;
      stage = await LocationService.requestForegroundPermission();
    }
    if (stage == LocationPermissionStage.deniedForever) {
      final bool go = await _ask(
        title: Strings.permissionForegroundTitle,
        message: Strings.permissionDeniedForeverRationale,
        action: Strings.permissionOpenAppSettings,
      );
      if (go) await LocationService.openAppSettings();
      return;
    }
    if (!canReadLocation(stage)) {
      if (mounted) _showMessage(Strings.trackingNeedsPermission);
      return;
    }

    // 4) Arka plan izni ayrı bir adım ve ayrı bir açıklama.
    if (!canTrackInBackground(stage)) {
      final bool go = await _ask(
        title: Strings.permissionBackgroundTitle,
        message: Strings.permissionBackgroundRationale,
        action: Strings.permissionOpenAppSettings,
      );
      if (go) {
        stage = await LocationService.requestBackgroundPermission();
        if (!canTrackInBackground(stage)) {
          // Android 11+ bu izni yalnızca ayarlar ekranından verdirir.
          await LocationService.openAppSettings();
          return;
        }
      }
      // "Şimdilik geç" seçildiyse yalnızca ön plan takibiyle devam edilir.
    }

    // 5) Servisi başlat.
    final TrackingStartResult result = await LocationService.start(
      uid: repository.uid,
    );
    if (!mounted) return;
    switch (result) {
      case TrackingStartResult.started:
        await LocationService.setTrackingPreference(enabled: true);
        if (mounted) _showMessage(Strings.trackingStarted);
      case TrackingStartResult.startedForegroundOnly:
        await LocationService.setTrackingPreference(enabled: true);
        if (mounted) _showMessage(Strings.trackingForegroundOnlyWarning);
      case TrackingStartResult.permissionMissing:
        _showMessage(Strings.trackingNeedsPermission);
      case TrackingStartResult.notificationMissing:
        _showMessage(Strings.trackingNeedsNotification);
      case TrackingStartResult.failed:
        _showMessage(Strings.trackingStartFailed);
    }
  }

  Future<bool> _ask({
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.permissionSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildSimulationCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.science_outlined,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    Strings.simulationBadge,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Strings.simulationNotice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Strings.simulationAdminHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
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
}
