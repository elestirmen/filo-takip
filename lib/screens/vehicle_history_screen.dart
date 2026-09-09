import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/time_format.dart';
import '../data/backend_exception.dart';
import '../data/fleet_repository.dart';
import '../models/location_sample.dart';

/// Bir aracın konum geçmişi.
///
/// Okuma **tek seferliktir** ve en yeni [FleetRepository.historyReadLimit]
/// kayıtla sınırlıdır; geçmiş düğümü dinlenmez.
///
/// Repository yapıcıdan geçirilir: bu ekran yeni bir rota olarak açılıyor ve
/// rota bağlamı Provider'ın üstünde kalıyor.
class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({
    super.key,
    required this.repository,
    required this.vehicleId,
    required this.plate,
  });

  final FleetRepository repository;
  final String vehicleId;
  final String plate;

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  late Future<List<LocationSample>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadHistory(widget.vehicleId);
  }

  void _reload() {
    setState(() {
      _future = widget.repository.loadHistory(widget.vehicleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(Strings.historyTitle),
        actions: <Widget>[
          IconButton(
            tooltip: Strings.historyRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: <Widget>[
                const Icon(Icons.directions_car_outlined, size: 20),
                const SizedBox(width: 8),
                Text(widget.plate, style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                Strings.historyLimitNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<LocationSample>>(
              future: _future,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<LocationSample>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorView(
                        message: snapshot.error is BackendException
                            ? (snapshot.error! as BackendException).message
                            : Strings.errorHistoryLoadFailed,
                        onRetry: _reload,
                      );
                    }
                    final List<LocationSample> samples =
                        snapshot.data ?? const <LocationSample>[];
                    if (samples.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            Strings.historyEmpty,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: samples.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        return _HistoryRow(
                          sample: samples[index],
                          order: index + 1,
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.sample, required this.order});

  final LocationSample sample;
  final int order;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Text(
        '$order',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      title: Text(
        formatTimestamp(sample.recordedAt),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${sample.lat.toStringAsFixed(5)}, ${sample.lng.toStringAsFixed(5)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        formatSpeed(sample.speedKmh),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 44, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(Strings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
