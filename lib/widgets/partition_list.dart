import 'package:jappeos_services/jappeos_services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class PartitionList extends StatelessWidget {
  final StorageDeviceInfo device;
  final Map<String, String> mounts;
  final String? selectedPartition;
  final ValueChanged<StoragePartitionInfo>? onPartitionSelected;
  final List<MenuItem> Function(StoragePartitionInfo)? onPartitionContextMenu;

  const PartitionList({
    super.key,
    required this.device,
    required this.mounts,
    this.selectedPartition,
    this.onPartitionSelected,
    this.onPartitionContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      child: SingleChildScrollView(
        child: Table(
          rows: [
            TableHeader(
              cells: [
                _buildHeaderCell("Partition"),
                _buildHeaderCell("Filesystem"),
                _buildHeaderCell("Size (MiB)"),
                _buildHeaderCell("Mountpoint"),
              ],
            ),
            for (final p in device.partitions)
              TableRow(
                selected: p.device == selectedPartition,
                cellTheme: _buildTheme(context),
                cells: [
                  _buildCell(p, p.device),
                  _buildCell(p, p.isFreeSpace() ? "" : p.filesystem.name),
                  _buildCell(p, p.sizeMiB.toString()),
                  _buildCell(p, mounts[p.device] ?? ""),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TableCell _buildHeaderCell(
      String text, [bool alignRight = false]) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.centerRight : null,
        child: Text(text),
      ),
    );
  }

  TableCell _buildCell(
      StoragePartitionInfo partition, String text, [bool alignRight = false]) {
    return TableCell(
      child: GestureDetector(
        onTap: () => onPartitionSelected?.call(partition),
        behavior: HitTestBehavior.opaque,
        child: ContextMenu(
          enabled: onPartitionContextMenu != null,
          items: () {
            final res = onPartitionContextMenu?.call(partition);
            if (res == null || res.isEmpty) {
              return [const MenuLabel(child: Text("No context menu actions."))];
            }
            return res;
          }(),
          child: Container(
            padding: const EdgeInsets.all(8),
            alignment: alignRight ? Alignment.centerRight : null,
            child: Text(text),
          ),
        ),
      ),
    );
  }

  TableCellTheme _buildTheme(BuildContext context) {
    final theme = Theme.of(context);
    return TableCellTheme(
      border: WidgetStateProperty.resolveWith(
        (states) {
          return Border(
            bottom: BorderSide(
              color: theme.colorScheme.border,
              width: 1,
            ),
          );
        },
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return theme.colorScheme.primary;
          }
          return states.contains(WidgetState.hovered)
              ? theme.colorScheme.muted.withValues(alpha: 0.5)
              : null;
        },
      ),
      textStyle: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: theme.colorScheme.primaryForeground,
            );
          }
          return TextStyle(
            color: states.contains(WidgetState.disabled)
                ? theme.colorScheme.muted
                : null,
          );
        },
      ),
    );
  }
}