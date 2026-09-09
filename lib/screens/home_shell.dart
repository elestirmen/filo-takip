import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/visibility_rules.dart';
import '../data/fleet_repository.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';
import 'admin_screen.dart';
import 'map_screen.dart';
import 'registration_screen.dart';
import 'settings_screen.dart';

/// Alt gezinme çubuğu ve dört sekme.
///
/// Sekmeler [IndexedStack] içinde tutulur; böylece harita sekmesinden
/// çıkılınca harita durumu (merkez, zoom, seçili araç) korunur.
///
/// Ayrıca konum servisinin gözetimi burada yapılır: bu widget oturum boyunca
/// ayakta kaldığı için hangi sekmenin açık olduğundan bağımsız çalışır.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.uid,
    required this.isAnonymous,
    required this.initialIndex,
    required this.onTabChanged,
  });

  final String uid;
  final bool isAnonymous;

  /// Oturum değişince bu widget yeniden kurulur; açık sekmenin korunması
  /// için başlangıç değeri dışarıdan verilir.
  final int initialIndex;
  final ValueChanged<int> onTabChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _selectedIndex = widget.initialIndex;
  StreamSubscription<List<Vehicle>>? _vehicleSubscription;
  FleetRepository? _repository;
  bool _superviseStarted = false;

  /// Uygulama açılışında tercih bir kez uygulanır.
  bool _autoStartChecked = false;

  @override
  void initState() {
    super.initState();
    // Sahte arka uçta servis isolate'i belleğe erişemediği için konumu
    // buraya gönderir; sahte veriyi ana isolate günceller.
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_superviseStarted) return;
    _superviseStarted = true;
    _repository = context.read<FleetRepository>();
    _superviseTracking(_repository!);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _vehicleSubscription?.cancel();
    super.dispose();
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final FleetRepository? repository = _repository;
    if (repository == null) return;
    final Object? lat = data['lat'];
    final Object? lng = data['lng'];
    final Object? speed = data['speedKmh'];
    if (lat is! num || lng is! num || speed is! num) return;
    unawaited(
      repository
          .writeLocation(
            lat: lat.toDouble(),
            lng: lng.toDouble(),
            speedKmh: speed.toDouble(),
          )
          .catchError((Object _) {}),
    );
  }

  /// Servis yalnızca kayıtlı bir araç varken çalışır. Araç kaydı silinirse
  /// servis durdurulur ve tercih kapatılır.
  void _superviseTracking(FleetRepository repository) {
    // Yönetici oturumunda bu cihazın aracı zaten yoktur; araç listesini
    // "kayıt silindi" diye yorumlamamak için akış hiç dinlenmez.
    if (!widget.isAnonymous) {
      unawaited(_applyTrackingPreference(repository));
      return;
    }

    _vehicleSubscription = repository.vehicles.listen((
      List<Vehicle> vehicles,
    ) async {
      final Vehicle? own = findVehicleById(vehicles, repository.uid);

      if (own == null) {
        if (await LocationService.isRunning()) {
          await LocationService.stop();
          await LocationService.setTrackingPreference(enabled: false);
          if (mounted) _showMessage(Strings.trackingVehicleDeleted);
        }
        return;
      }

      if (_autoStartChecked) return;
      _autoStartChecked = true;
      await _applyTrackingPreference(repository);
    });
  }

  Future<void> _applyTrackingPreference(FleetRepository repository) async {
    // Yönetici cihazı takip edilen bir araç olmamalı: yönetici girişi
    // yapıldıysa sürücü oturumundan kalan servis durdurulur. Kullanıcının
    // açık/kapalı tercihi korunur, sürücü oturumuna dönünce yeniden başlar.
    if (!widget.isAnonymous) {
      if (await LocationService.isRunning()) await LocationService.stop();
      return;
    }
    if (!await LocationService.trackingPreference()) return;
    if (await LocationService.isRunning()) return;
    await LocationService.start(uid: repository.uid);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const MapScreen(),
          RegistrationScreen(isAnonymous: widget.isAnonymous),
          AdminScreen(isAnonymous: widget.isAnonymous),
          SettingsScreen(uid: widget.uid, isAnonymous: widget.isAnonymous),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
          widget.onTabChanged(index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: Strings.tabMap,
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_reg_outlined),
            selectedIcon: Icon(Icons.how_to_reg),
            label: Strings.tabRegistration,
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: Strings.tabAdmin,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: Strings.tabSettings,
          ),
        ],
      ),
    );
  }
}
