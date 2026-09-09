import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin_rules.dart';
import '../core/strings.dart';
import '../core/time_format.dart';
import '../core/vehicle_status.dart';
import '../data/backend_exception.dart';
import '../data/fleet_repository.dart';
import '../data/session_service.dart';
import '../models/app_user.dart';
import '../models/group_config.dart';
import '../models/vehicle.dart';
import '../widgets/status_visuals.dart';
import 'admin_groups_tab.dart';
import 'vehicle_history_screen.dart';

/// Yönetim sekmesi.
///
/// Anonim oturumdayken giriş formu, e-posta oturumundayken `admins/{uid}`
/// kontrolünden geçtikten sonra yönetim arayüzü gösterilir. Yetki cihazda
/// saklanan bir bayraktan değil, her zaman veritabanından okunur.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key, required this.isAnonymous});

  final bool isAnonymous;

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) return const _AdminLoginView();
    return const _AdminAuthorizedGate();
  }
}

// --------------------------------------------------------------- Giriş

class _AdminLoginView extends StatefulWidget {
  const _AdminLoginView();

  @override
  State<_AdminLoginView> createState() => _AdminLoginViewState();
}

class _AdminLoginViewState extends State<_AdminLoginView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Giriş başarılı olunca oturum değişir ve bu ekran yeniden kurulur.
    // Mesajı kaybetmemek için messenger ve servisler önceden yakalanıyor.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final SessionService session = context.read<SessionService>();
    final FleetRepository repository = context.read<FleetRepository>();

    setState(() => _busy = true);
    try {
      await session.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Yetki kontrolü: admins düğümünde yoksa oturum hemen kapatılır.
      final AppUser? user = session.currentUser;
      final bool authorized =
          user != null && await repository.isAdminOnce(user.uid);
      if (!authorized) {
        await session.signOut();
        messenger.showSnackBar(
          const SnackBar(content: Text(Strings.adminNotAuthorized)),
        );
      }
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _validateEmail(String? value) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) return Strings.adminEmailRequired;
    // Kaba bir kontrol; asıl doğrulamayı sunucu yapar.
    if (!email.contains('@') || !email.contains('.')) {
      return Strings.adminEmailInvalid;
    }
    return null;
  }

  static String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return Strings.adminPasswordRequired;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.adminScreenTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          children: <Widget>[
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              Strings.adminLoginTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              Strings.adminLoginHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.username],
              decoration: const InputDecoration(
                labelText: Strings.adminEmailLabel,
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              enabled: !_busy,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              decoration: InputDecoration(
                labelText: Strings.adminPasswordLabel,
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: _validatePassword,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: const Text(Strings.adminLoginButton),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Yetki kapısı

class _AdminAuthorizedGate extends StatelessWidget {
  const _AdminAuthorizedGate();

  @override
  Widget build(BuildContext context) {
    final FleetRepository repository = context.read<FleetRepository>();
    return StreamBuilder<bool>(
      stream: repository.isAdmin,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text(Strings.adminScreenTitle)),
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(Strings.adminVerifying),
                ],
              ),
            ),
          );
        }
        if (snapshot.data != true) return const _NotAuthorizedView();
        return const _AdminHome();
      },
    );
  }
}

class _NotAuthorizedView extends StatelessWidget {
  const _NotAuthorizedView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.adminScreenTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.gpp_bad_outlined, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                Strings.adminNotAuthorizedTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                Strings.adminNotAuthorizedHint,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.read<SessionService>().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text(Strings.adminLogoutButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Yönetim

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(Strings.adminScreenTitle),
          actions: <Widget>[
            IconButton(
              tooltip: Strings.adminLogoutButton,
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<SessionService>().signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: Strings.adminTabVehicles),
              Tab(text: Strings.adminTabGroups),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_AdminVehiclesTab(), AdminGroupsTab()],
        ),
      ),
    );
  }
}

class _AdminVehiclesTab extends StatelessWidget {
  const _AdminVehiclesTab();

  @override
  Widget build(BuildContext context) {
    final FleetRepository repository = context.read<FleetRepository>();
    return StreamBuilder<List<GroupConfig>>(
      stream: repository.groupConfigs,
      builder:
          (BuildContext context, AsyncSnapshot<List<GroupConfig>> groupSnap) {
            return StreamBuilder<List<Vehicle>>(
              stream: repository.vehicles,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<Vehicle>> vehicleSnap,
                  ) {
                    if (!groupSnap.hasData || !vehicleSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<GroupConfig> groups = groupSnap.data!;
                    final List<Vehicle> vehicles = sortVehiclesForAdmin(
                      vehicleSnap.data!,
                    );
                    final AdminSummary summary = AdminSummary.of(
                      vehicles,
                      groups,
                    );
                    final int nowMs = repository.nowMs();

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: <Widget>[
                        _SummaryRow(summary: summary),
                        const Divider(height: 1),
                        if (vehicles.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: _NoVehicles(),
                          )
                        else
                          for (final Vehicle vehicle in vehicles)
                            _VehicleTile(
                              vehicle: vehicle,
                              groups: groups,
                              repository: repository,
                              nowMs: nowMs,
                            ),
                      ],
                    );
                  },
            );
          },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});

  final AdminSummary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: <Widget>[
          _SummaryCard(
            label: Strings.adminSummaryTotal,
            value: summary.total,
            icon: Icons.directions_car_outlined,
          ),
          _SummaryCard(
            label: Strings.adminSummaryPending,
            value: summary.pending,
            icon: Icons.hourglass_top,
            highlight: summary.pending > 0,
          ),
          _SummaryCard(
            label: Strings.adminSummaryApproved,
            value: summary.approved,
            icon: Icons.verified_outlined,
          ),
          _SummaryCard(
            label: Strings.adminSummaryGroups,
            value: summary.groupCount,
            icon: Icons.workspaces_outline,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = highlight
        ? const Color(0xFFEF6C00)
        : theme.colorScheme.primary;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                '$value',
                style: theme.textTheme.titleLarge?.copyWith(color: color),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    required this.groups,
    required this.repository,
    required this.nowMs,
  });

  final Vehicle vehicle;
  final List<GroupConfig> groups;
  final FleetRepository repository;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VehicleStatus status = vehicleStatusOf(vehicle, nowMs: nowMs);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(statusIcon(status), color: statusColor(status)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    vehicle.plate.isEmpty ? vehicle.id : vehicle.plate,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(vehicle.driverName, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.workspaces_outline,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.hasGroup
                            ? vehicle.groupId!
                            : Strings.adminGroupNone,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          relativeTime(vehicle.updatedAt, nowMs: nowMs),
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!vehicle.approved)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  onPressed: () => _setApproved(context, approved: true),
                  child: const Text(Strings.adminApprove),
                ),
              ),
            PopupMenuButton<_VehicleAction>(
              onSelected: (_VehicleAction action) =>
                  _onAction(context, action),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_VehicleAction>>[
                    if (vehicle.approved)
                      const PopupMenuItem<_VehicleAction>(
                        value: _VehicleAction.revoke,
                        child: Text(Strings.adminRevoke),
                      )
                    else
                      const PopupMenuItem<_VehicleAction>(
                        value: _VehicleAction.approve,
                        child: Text(Strings.adminApprove),
                      ),
                    const PopupMenuItem<_VehicleAction>(
                      value: _VehicleAction.assignGroup,
                      child: Text(Strings.adminAssignGroup),
                    ),
                    const PopupMenuItem<_VehicleAction>(
                      value: _VehicleAction.history,
                      child: Text(Strings.adminViewHistory),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<_VehicleAction>(
                      value: _VehicleAction.delete,
                      child: Text(Strings.adminDeleteVehicle),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, _VehicleAction action) async {
    switch (action) {
      case _VehicleAction.approve:
        await _setApproved(context, approved: true);
      case _VehicleAction.revoke:
        await _setApproved(context, approved: false);
      case _VehicleAction.assignGroup:
        await _assignGroup(context);
      case _VehicleAction.history:
        await _openHistory(context);
      case _VehicleAction.delete:
        await _delete(context);
    }
  }

  Future<void> _setApproved(
    BuildContext context, {
    required bool approved,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await repository.setVehicleApproved(vehicle.id, approved: approved);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? Strings.adminVehicleApproved
                : Strings.adminVehicleRevoked,
          ),
        ),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _assignGroup(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (groups.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminNoGroupsHint)),
      );
      return;
    }
    final _GroupSelection? selection = await showDialog<_GroupSelection>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text(Strings.adminSelectGroupTitle),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop(const _GroupSelection(null)),
            child: const Text(Strings.adminGroupNone),
          ),
          for (final GroupConfig group in groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(
                context,
              ).pop(_GroupSelection(group.groupId)),
              child: Text(group.groupId),
            ),
        ],
      ),
    );
    if (selection == null) return;
    try {
      await repository.setVehicleGroup(vehicle.id, selection.groupId);
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminGroupAssigned)),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openHistory(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleHistoryScreen(
          // Rota bağlamı Provider'ın üstünde kaldığı için repository
          // doğrudan geçiriliyor.
          repository: repository,
          vehicleId: vehicle.id,
          plate: vehicle.plate.isEmpty ? vehicle.id : vehicle.plate,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(Strings.adminDeleteVehicleTitle),
        content: Text(
          '${vehicle.plate}\n\n${Strings.adminDeleteVehicleMessage}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.adminDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteVehicle(vehicle.id);
      messenger.showSnackBar(
        const SnackBar(content: Text(Strings.adminVehicleDeleted)),
      );
    } on BackendException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

enum _VehicleAction { approve, revoke, assignGroup, history, delete }

/// Grup seçimi. `null` groupId "grupsuz" demektir; diyalogun iptal
/// edilmesinden ayırmak için sarmalanıyor.
class _GroupSelection {
  const _GroupSelection(this.groupId);

  final String? groupId;
}

class _NoVehicles extends StatelessWidget {
  const _NoVehicles();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(
          Icons.directions_car_outlined,
          size: 48,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 12),
        Text(Strings.adminNoVehicles, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          Strings.adminNoVehiclesHint,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
