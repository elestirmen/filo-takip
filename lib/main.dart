import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'data/fake_fleet_repository.dart';
import 'data/fake_session_service.dart';
import 'data/firebase_fleet_repository.dart';
import 'data/firebase_session_service.dart';
import 'data/fleet_repository.dart';
import 'data/session_service.dart';
import 'models/app_user.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Servis isolate'i ile arayüz arasındaki iletişim kanalı; sahte arka uçta
  // konum verisi buradan geçer.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const HaritaTakipApp());
}

class HaritaTakipApp extends StatelessWidget {
  const HaritaTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const <Locale>[Locale('tr', 'TR')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _SimulationBanner(child: AuthGate()),
    );
  }
}

/// Sahte arka uçla çalışırken ekranın köşesine uyarı şeridi koyar.
/// Gerçek Firebase modunda hiçbir şey eklemez.
class _SimulationBanner extends StatelessWidget {
  const _SimulationBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.useFakeBackend) return child;
    return Banner(
      message: Strings.simulationRibbon,
      location: BannerLocation.topEnd,
      color: Colors.deepOrange,
      child: child,
    );
  }
}

/// Açılış akışı: arka ucu kur, oturum yoksa anonim giriş yap, hazır olunca
/// repository'yi widget ağacına ver.
///
/// Oturum tek bir yerden dinlenir. Yönetici çıkış yaptığında akış `null`
/// yayar ve cihaz kendiliğinden anonim sürücü oturumuna döner.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

enum _BootPhase { connecting, signingIn, ready, failed }

class _AuthGateState extends State<AuthGate> {
  _BootPhase _phase = _BootPhase.connecting;
  String _errorMessage = '';
  AppUser? _user;
  SessionService? _session;
  StreamSubscription<AppUser?>? _userSubscription;
  bool _signInInProgress = false;

  /// Oturum değişince alt ağaç yeniden kurulduğu için açık sekme burada
  /// hatırlanır; yönetici girişinden sonra kullanıcı Yönetim sekmesinde kalır.
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _session?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _phase = _BootPhase.connecting;
      _errorMessage = '';
    });

    await _userSubscription?.cancel();
    _session?.dispose();
    _session = null;

    try {
      if (AppConfig.useFakeBackend) {
        _session = FakeSessionService();
      } else {
        await Firebase.initializeApp();
        _session = FirebaseSessionService();
      }
    } catch (_) {
      _fail(Strings.startupFirebaseFailed);
      return;
    }
    if (!mounted) return;

    _userSubscription = _session!.userChanges.listen(_onUserChanged);
  }

  Future<void> _onUserChanged(AppUser? user) async {
    if (!mounted) return;
    if (user != null) {
      setState(() {
        _user = user;
        _phase = _BootPhase.ready;
      });
      return;
    }
    setState(() {
      _user = null;
      _phase = _BootPhase.signingIn;
    });
    await _signInAnonymously();
  }

  Future<void> _signInAnonymously() async {
    if (_signInInProgress) return;
    _signInInProgress = true;
    try {
      // Başarılı girişi userChanges yayar; burada state'e dokunmuyoruz.
      await _session?.signInAnonymously();
    } catch (_) {
      _fail(Strings.startupSignInFailed);
    } finally {
      _signInInProgress = false;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _BootPhase.failed;
      _errorMessage = message;
    });
  }

  FleetRepository _createRepository(String uid) {
    if (AppConfig.useFakeBackend) return FakeFleetRepository(uid: uid);
    return FirebaseFleetRepository(uid: uid);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _BootPhase.connecting:
        return const _BootScreen(message: Strings.startupConnecting);
      case _BootPhase.signingIn:
        return const _BootScreen(message: Strings.startupSigningIn);
      case _BootPhase.failed:
        return _BootErrorScreen(message: _errorMessage, onRetry: _bootstrap);
      case _BootPhase.ready:
        final AppUser user = _user!;
        return Provider<SessionService>.value(
          value: _session!,
          // Oturum değişince (sürücü <-> yönetici) repository yeniden
          // kurulmalı: anahtar uid olduğu için eskisi atılıp yenisi yaratılır.
          child: Provider<FleetRepository>(
            key: ValueKey<String>(user.uid),
            create: (_) => _createRepository(user.uid),
            dispose: (_, FleetRepository repository) => repository.dispose(),
            child: HomeShell(
              uid: user.uid,
              isAnonymous: user.isAnonymous,
              initialIndex: _tabIndex,
              onTabChanged: (int index) => _tabIndex = index,
            ),
          ),
        );
    }
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.cloud_off, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                Strings.startupFailedTitle,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(Strings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
