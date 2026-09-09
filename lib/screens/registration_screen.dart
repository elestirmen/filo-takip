import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/normalize.dart';
import '../core/strings.dart';
import '../data/backend_exception.dart';
import '../data/fleet_repository.dart';
import '../models/vehicle.dart';
import '../widgets/turkish_upper_case_formatter.dart';

/// Sürücünün kendi aracını kaydettiği / güncellediği ekran.
///
/// Yalnızca `plate` ve `driverName` alanlarını yazar. `approved` ve `groupId`
/// alanlarına dokunmaz; onlar yalnızca yöneticinin yazabildiği alanlardır.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, required this.isAnonymous});

  /// Yönetici oturumundayken kayıt formu kapatılır.
  final bool isAnonymous;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  /// Alanlar bir kez doldurulur. Araç düğümü konum yüzünden 5 saniyede bir
  /// güncellendiği için, her akış olayında yeniden doldurmak kullanıcı
  /// yazarken metni sıfırlardı.
  bool _formInitialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _plateController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FleetRepository repository = context.read<FleetRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.registrationScreenTitle)),
      body: widget.isAnonymous
          ? _buildBody(context, repository)
          : const _AdminSessionNotice(),
    );
  }

  Widget _buildBody(BuildContext context, FleetRepository repository) {
    return StreamBuilder<List<Vehicle>>(
      stream: repository.vehicles,
      builder: (BuildContext context, AsyncSnapshot<List<Vehicle>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final Vehicle? vehicle = _ownVehicle(snapshot.data!, repository.uid);
        _seedFormOnce(vehicle);
        return _buildForm(context, repository, vehicle);
      },
    );
  }

  static Vehicle? _ownVehicle(List<Vehicle> vehicles, String uid) {
    for (final Vehicle vehicle in vehicles) {
      if (vehicle.id == uid) return vehicle;
    }
    return null;
  }

  void _seedFormOnce(Vehicle? vehicle) {
    if (_formInitialized || vehicle == null) return;
    _formInitialized = true;
    // Denetleyiciye build sırasında yazmak "setState during build" hatasına
    // yol açabilir; bir kare sonraya bırakılıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _plateController.text = vehicle.plate;
      _nameController.text = vehicle.driverName;
    });
  }

  Widget _buildForm(
    BuildContext context,
    FleetRepository repository,
    Vehicle? vehicle,
  ) {
    final bool isNew = vehicle == null;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          if (isNew)
            const _NoVehicleCard()
          else
            _StatusCard(vehicle: vehicle),
          const SizedBox(height: 20),
          TextFormField(
            controller: _plateController,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            // textCapitalization bilerek kullanılmıyor: klavye harfi biz
            // görmeden kendi kuralıyla büyütüyor ve İngilizce düzende 'i'
            // harfi 'I' olarak geliyor. Büyütmenin tek kaynağı aşağıdaki
            // biçimlendirici olsun ki sonuç klavye diline bağlı olmasın.
            inputFormatters: const <TurkishUpperCaseFormatter>[
              TurkishUpperCaseFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: Strings.registrationPlateLabel,
              hintText: Strings.registrationPlateHint,
              prefixIcon: Icon(Icons.directions_car_outlined),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _formInitialized = true,
            validator: _validatePlate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            enabled: !_saving,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: Strings.registrationNameLabel,
              hintText: Strings.registrationNameHint,
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _formInitialized = true,
            onFieldSubmitted: (_) => _submit(repository, isNew: isNew),
            validator: _validateName,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : () => _submit(repository, isNew: isNew),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isNew ? Icons.send_outlined : Icons.save_outlined),
            label: Text(
              isNew
                  ? Strings.registrationSubmitNew
                  : Strings.registrationSubmitUpdate,
            ),
          ),
        ],
      ),
    );
  }

  static String? _validatePlate(String? value) {
    // Doğrulama, kaydedilecek olan normalleşmiş metin üzerinden yapılır.
    final String plate = normalizePlate(value ?? '');
    if (plate.isEmpty) return Strings.registrationPlateRequired;
    if (plate.length < 6) return Strings.registrationPlateTooShort;
    return null;
  }

  static String? _validateName(String? value) {
    final String name = normalizeDriverName(value ?? '');
    if (name.isEmpty) return Strings.registrationNameRequired;
    if (name.length < 3) return Strings.registrationNameTooShort;
    return null;
  }

  Future<void> _submit(
    FleetRepository repository, {
    required bool isNew,
  }) async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String plate = normalizePlate(_plateController.text);
    final String driverName = normalizeDriverName(_nameController.text);

    setState(() => _saving = true);
    try {
      await repository.saveRegistration(plate: plate, driverName: driverName);
      if (!mounted) return;
      // Kaydedilen normalleşmiş hali kullanıcıya geri göster.
      _plateController.text = plate;
      _nameController.text = driverName;
      _showMessage(
        isNew ? Strings.registrationRequestSent : Strings.registrationSaved,
      );
    } on BackendException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    final ThemeData theme = Theme.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? theme.colorScheme.error : null,
        ),
      );
  }
}

class _NoVehicleCard extends StatelessWidget {
  const _NoVehicleCard();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    Strings.registrationNoVehicleTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Strings.registrationNoVehicleHint,
                    style: theme.textTheme.bodySmall,
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

/// Onay durumu ve grup bilgisi. İkisini de yalnızca yönetici değiştirir.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.vehicle});

  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool approved = vehicle.approved;
    final Color accent = approved
        ? Colors.green.shade700
        : Colors.orange.shade800;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  approved ? Icons.verified : Icons.hourglass_top,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Text(
                  approved
                      ? Strings.registrationStatusApproved
                      : Strings.registrationStatusPending,
                  style: theme.textTheme.titleMedium?.copyWith(color: accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              approved
                  ? Strings.registrationApprovedHint
                  : Strings.registrationPendingHint,
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              children: <Widget>[
                Icon(
                  Icons.workspaces_outline,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Text(
                  Strings.registrationGroupLabel,
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                Text(
                  vehicle.hasGroup
                      ? vehicle.groupId!
                      : Strings.registrationGroupNone,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Strings.registrationManagedByAdmin,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSessionNotice extends StatelessWidget {
  const _AdminSessionNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              Strings.registrationAdminSessionTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              Strings.registrationAdminSessionHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
