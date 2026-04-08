import 'package:flutter/material.dart';
import '../../models/git_status.dart';

class SyncStateIndicator extends StatelessWidget {
  final SyncState state;

  const SyncStateIndicator({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _stateInfo(context, state);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  (IconData, String, Color) _stateInfo(BuildContext context, SyncState s) {
    final cs = Theme.of(context).colorScheme;
    return switch (s) {
      SyncStateUpToDate() => (Icons.check_circle_outline, 'Up to date', cs.primary),
      SyncStateLocalChanges(count: final n) =>
        (Icons.upload_outlined, '$n change${n == 1 ? '' : 's'}', Colors.orange),
      SyncStateRemoteChanges() => (Icons.download_outlined, 'Pull available', cs.secondary),
      SyncStateConflict() => (Icons.warning_amber_outlined, 'Conflict', cs.error),
      SyncStateError(message: final m) => (Icons.error_outline, m, cs.error),
      SyncStateChecking() => (Icons.sync, 'Checking...', cs.onSurfaceVariant),
      SyncStateUnknown() => (Icons.help_outline, 'Unknown', cs.onSurfaceVariant),
    };
  }
}
