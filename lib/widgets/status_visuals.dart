import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/vehicle_status.dart';

/// Araç durumunun rengi, etiketi ve simgesi. Harita ve Yönetim ekranları
/// aynı görselleri kullansın diye tek yerde.
Color statusColor(VehicleStatus status) {
  switch (status) {
    case VehicleStatus.moving:
      return const Color(0xFF2E7D32);
    case VehicleStatus.stopped:
      return const Color(0xFFC62828);
    case VehicleStatus.offline:
      return const Color(0xFF6D6D6D);
    case VehicleStatus.pending:
      return const Color(0xFFEF6C00);
  }
}

String statusLabel(VehicleStatus status) {
  switch (status) {
    case VehicleStatus.moving:
      return Strings.mapStatusMoving;
    case VehicleStatus.stopped:
      return Strings.mapStatusStopped;
    case VehicleStatus.offline:
      return Strings.mapStatusOffline;
    case VehicleStatus.pending:
      return Strings.mapStatusPending;
  }
}

IconData statusIcon(VehicleStatus status) {
  switch (status) {
    case VehicleStatus.moving:
      return Icons.navigation;
    case VehicleStatus.stopped:
      return Icons.pause_circle_filled;
    case VehicleStatus.offline:
      return Icons.cloud_off;
    case VehicleStatus.pending:
      return Icons.hourglass_top;
  }
}
