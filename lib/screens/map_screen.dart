import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../core/time_format.dart';
import '../core/vehicle_status.dart';
import '../core/visibility_rules.dart';
import '../data/fleet_repository.dart';
import '../models/group_config.dart';
import '../models/vehicle.dart';
import '../widgets/status_visuals.dart';

/// Filo haritası.
///
/// Görünürlük kararları [visibility_rules.dart] içindeki saf fonksiyonlarda,
/// durum/renk kararları [vehicle_status.dart] içinde. Bu ekran yalnızca
/// onların sonucunu çizer.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// Varsayılan harita merkezi (şartnamede verilen koordinat).
  /// Not: bu nokta Nevşehir merkezine denk gelir. Kırşehir istenirse
  /// 39.1425, 34.1709 kullanılmalı.
  static const LatLng _initialCenter = LatLng(38.6246, 34.7142);
  static const double _initialZoom = 12;

  final MapController _mapController = MapController();

  /// Seçim **kimlikle** tutulur, araç nesnesiyle değil. Araç düğümü 5
  /// saniyede bir yenilendiği için nesneye bağlanan seçim her güncellemede
  /// kaybolur ve açık kart kapanırdı.
  String? _selectedVehicleId;

  GroupFilter _groupFilter = const GroupFilter.all();
  bool _summaryExpanded = true;
  bool _detailExpanded = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Bayatlık zamanla değişir: çevrimdışına düşen araç için yeni veri
    // gelmeyeceğinden durumu düzenli aralıklarla yeniden hesaplıyoruz.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FleetRepository repository = context.read<FleetRepository>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.mapScreenTitle),
        actions: <Widget>[
          IconButton(
            tooltip: Strings.mapGoToOwnVehicle,
            icon: const Icon(Icons.my_location),
            onPressed: () => _goToOwnVehicle(repository),
          ),
        ],
      ),
      body: StreamBuilder<bool>(
        stream: repository.isAdmin,
        initialData: repository.latestIsAdmin,
        builder: (BuildContext context, AsyncSnapshot<bool> adminSnapshot) {
          return StreamBuilder<List<GroupConfig>>(
            stream: repository.groupConfigs,
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<GroupConfig>> groupSnapshot,
                ) {
                  return StreamBuilder<List<Vehicle>>(
                    stream: repository.vehicles,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<List<Vehicle>> vehicleSnapshot,
                        ) {
                          if (!groupSnapshot.hasData ||
                              !vehicleSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          return _buildContent(
                            context,
                            repository,
                            isAdmin: adminSnapshot.data ?? false,
                            allVehicles: vehicleSnapshot.data!,
                            groups: groupSnapshot.data!,
                          );
                        },
                  );
                },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    FleetRepository repository, {
    required bool isAdmin,
    required List<Vehicle> allVehicles,
    required List<GroupConfig> groups,
  }) {
    // Tek "şu an" kaynağı: cihaz saati + sunucu ofseti.
    final int nowMs = repository.nowMs();

    final List<Vehicle> visible = visibleVehiclesFor(
      allVehicles: allVehicles,
      groups: groups,
      viewerUid: repository.uid,
      isAdmin: isAdmin,
    );
    // Grup filtresi yalnızca yöneticide var.
    final List<Vehicle> shown = isAdmin
        ? visible.where(_groupFilter.matches).toList()
        : visible;

    final Vehicle? selected = _selectedVehicleId == null
        ? null
        : findVehicleById(shown, _selectedVehicleId!);

    return Stack(
      children: <Widget>[
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            onTap: (_, _) => setState(() => _selectedVehicleId = null),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.filo.harita_takip',
            ),
            MarkerLayer(
              markers: _buildMarkers(
                context,
                vehicles: shown,
                ownUid: repository.uid,
                selectedId: selected?.id,
                nowMs: nowMs,
              ),
            ),
            const SimpleAttributionWidget(
              source: Text(Strings.mapAttribution),
              alignment: Alignment.bottomLeft,
            ),
          ],
        ),
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: _SummaryCard(
            summary: FleetSummary.of(shown, nowMs: nowMs),
            expanded: _summaryExpanded,
            onToggle: () =>
                setState(() => _summaryExpanded = !_summaryExpanded),
            isAdmin: isAdmin,
            groups: groups,
            filter: _groupFilter,
            onFilterChanged: (GroupFilter filter) =>
                setState(() => _groupFilter = filter),
          ),
        ),
        if (shown.isEmpty)
          Center(child: _EmptyCard(isAdmin: isAdmin))
        else if (selected != null)
          Positioned(
            // Altta OpenStreetMap katkı yazısına yer bırakılıyor.
            bottom: 26,
            left: 8,
            right: 8,
            child: _VehicleCard(
              vehicle: selected,
              isOwn: selected.id == repository.uid,
              visibility: fieldVisibilityFor(
                vehicle: selected,
                groups: groups,
                viewerUid: repository.uid,
                isAdmin: isAdmin,
              ),
              nowMs: nowMs,
              expanded: _detailExpanded,
              onToggle: () =>
                  setState(() => _detailExpanded = !_detailExpanded),
              onClose: () => setState(() => _selectedVehicleId = null),
            ),
          ),
      ],
    );
  }

  List<Marker> _buildMarkers(
    BuildContext context, {
    required List<Vehicle> vehicles,
    required String ownUid,
    required String? selectedId,
    required int nowMs,
  }) {
    final List<Marker> markers = <Marker>[];
    for (final Vehicle vehicle in vehicles) {
      // Hiç konum yazılmamış araç haritaya konmaz; özet kartında sayılır.
      if (!vehicle.hasLocation) continue;
      final bool isSelected = vehicle.id == selectedId;
      markers.add(
        Marker(
          // Kimliğe bağlı anahtar: veri yenilendiğinde Flutter aynı
          // widget'ı yeniden kullanır, işaretçi sıfırdan kurulmaz.
          key: ValueKey<String>(vehicle.id),
          point: LatLng(vehicle.lat, vehicle.lng),
          width: 46,
          height: 46,
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedVehicleId = vehicle.id;
              _detailExpanded = true;
            }),
            child: _VehicleMarker(
              status: vehicleStatusOf(vehicle, nowMs: nowMs),
              selected: isSelected,
              isOwn: vehicle.id == ownUid,
            ),
          ),
        ),
      );
    }
    return markers;
  }

  void _goToOwnVehicle(FleetRepository repository) {
    final Vehicle? own = findVehicleById(
      repository.latestVehicles,
      repository.uid,
    );
    if (own == null || !own.hasLocation) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(Strings.mapOwnVehicleMissing)),
        );
      return;
    }
    _mapController.move(LatLng(own.lat, own.lng), 15);
    setState(() {
      _selectedVehicleId = own.id;
      _detailExpanded = true;
    });
  }
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({
    required this.status,
    required this.selected,
    required this.isOwn,
  });

  final VehicleStatus status;
  final bool selected;
  final bool isOwn;

  @override
  Widget build(BuildContext context) {
    final Color color = statusColor(status);
    final Color ring = isOwn
        ? Theme.of(context).colorScheme.primary
        : Colors.white;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: selected ? 42 : 32,
        height: selected ? 42 : 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: selected ? 4 : 2.5),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.directions_car,
          size: selected ? 20 : 16,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.isAdmin,
    required this.groups,
    required this.filter,
    required this.onFilterChanged,
  });

  final FleetSummary summary;
  final bool expanded;
  final VoidCallback onToggle;
  final bool isAdmin;
  final List<GroupConfig> groups;
  final GroupFilter filter;
  final ValueChanged<GroupFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.dashboard_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Strings.mapSummaryTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Text(
                    '${Strings.mapSummaryTotal}: ${summary.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: <Widget>[
                      _CountChip(
                        status: VehicleStatus.moving,
                        count: summary.moving,
                      ),
                      _CountChip(
                        status: VehicleStatus.stopped,
                        count: summary.stopped,
                      ),
                      _CountChip(
                        status: VehicleStatus.offline,
                        count: summary.offline,
                      ),
                      _CountChip(
                        status: VehicleStatus.pending,
                        count: summary.pending,
                      ),
                    ],
                  ),
                  if (isAdmin) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _FilterChip(
                          label: Strings.mapFilterAll,
                          value: const GroupFilter.all(),
                          selected: filter == const GroupFilter.all(),
                          onSelected: onFilterChanged,
                        ),
                        for (final GroupConfig group in groups)
                          _FilterChip(
                            label: group.groupId,
                            value: GroupFilter.group(group.groupId),
                            selected:
                                filter == GroupFilter.group(group.groupId),
                            onSelected: onFilterChanged,
                          ),
                        _FilterChip(
                          label: Strings.mapFilterUngrouped,
                          value: const GroupFilter.ungrouped(),
                          selected: filter == const GroupFilter.ungrouped(),
                          onSelected: onFilterChanged,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.status, required this.count});

  final VehicleStatus status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: statusColor(status),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${statusLabel(status)} $count',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final GroupFilter value;
  final bool selected;
  final ValueChanged<GroupFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onSelected(value),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isOwn,
    required this.visibility,
    required this.nowMs,
    required this.expanded,
    required this.onToggle,
    required this.onClose,
  });

  final Vehicle vehicle;
  final bool isOwn;
  final FieldVisibility visibility;
  final int nowMs;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VehicleStatus status = vehicleStatusOf(vehicle, nowMs: nowMs);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
              child: Row(
                children: <Widget>[
                  Icon(statusIcon(status), color: statusColor(status)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          vehicle.plate,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          statusLabel(status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOwn)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Chip(
                        label: const Text(Strings.mapOwnVehicle),
                        visualDensity: VisualDensity.compact,
                        labelStyle: theme.textTheme.labelSmall,
                      ),
                    ),
                  Icon(expanded ? Icons.expand_more : Icons.expand_less),
                  IconButton(
                    tooltip: Strings.close,
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: <Widget>[
                  _DetailRow(
                    label: Strings.mapFieldDriver,
                    value: visibility.showDriverName
                        ? vehicle.driverName
                        : Strings.mapFieldHidden,
                    dimmed: !visibility.showDriverName,
                  ),
                  _DetailRow(
                    label: Strings.mapFieldSpeed,
                    value: visibility.showSpeed
                        ? formatSpeed(vehicle.speedKmh)
                        : Strings.mapFieldHidden,
                    dimmed: !visibility.showSpeed,
                  ),
                  _DetailRow(
                    label: Strings.mapFieldGroup,
                    value: vehicle.hasGroup
                        ? vehicle.groupId!
                        : Strings.mapGroupNone,
                  ),
                  _DetailRow(
                    label: Strings.mapFieldUpdated,
                    value: relativeTime(vehicle.updatedAt, nowMs: nowMs),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  final String label;
  final String value;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: dimmed ? FontWeight.normal : FontWeight.w600,
              fontStyle: dimmed ? FontStyle.italic : FontStyle.normal,
              color: dimmed ? theme.colorScheme.outline : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.location_off_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              Strings.mapEmptyTitle,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? Strings.mapEmptyAdminHint
                  : Strings.mapEmptyDriverHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
