import 'package:jappeos_services/jappeos_services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class PartitionView extends StatefulWidget {
  final StorageDeviceInfo device;
  final Map<String, String> mounts;
  final String? selectedPartition;
  final ValueChanged<StoragePartitionInfo>? onPartitionSelected;
  final List<MenuItem> Function(StoragePartitionInfo)? onPartitionContextMenu;
  final double height;
  final double minSegmentWidth;

  const PartitionView({
    super.key,
    required this.device,
    required this.mounts,
    this.selectedPartition,
    this.onPartitionSelected,
    this.onPartitionContextMenu,
    this.height = 56,
    this.minSegmentWidth = 32,
  });

  @override
  State<PartitionView> createState() => _PartitionViewState();
}

class _PartitionViewState extends State<PartitionView> {
  @override
  Widget build(BuildContext context) {
    final partitions = widget.device.partitions;
    final totalDeviceSize = widget.device.sizeMiB.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - (partitions.length * 2);

        // Compute "flex" sizes (proportional to MiB), then enforce a minimum
        // pixel width per partition and shrink the remaining partitions
        // proportionally to compensate.
        final rawSizes = partitions
            .map((p) => (p.sizeMiB / totalDeviceSize) * totalWidth)
            .toList();

        final minWidths = List<double>.filled(partitions.length, widget.minSegmentWidth);

        // Total extra width needed to bring small partitions up to minSegmentWidth.
        double deficit = 0;
        for (var i = 0; i < rawSizes.length; i++) {
          if (rawSizes[i] < minWidths[i]) {
            deficit += minWidths[i] - rawSizes[i];
          }
        }

        // Total width available from partitions that are above the minimum,
        // which can be "donated" to cover the deficit.
        double donorPool = 0;
        for (var i = 0; i < rawSizes.length; i++) {
          if (rawSizes[i] > minWidths[i]) {
            donorPool += rawSizes[i] - minWidths[i];
          }
        }

        final finalWidths = List<double>.filled(partitions.length, 0);
        final shrinkFactor = donorPool > 0 ? (deficit / donorPool).clamp(0.0, 1.0) : 0.0;

        for (var i = 0; i < rawSizes.length; i++) {
          if (rawSizes[i] < minWidths[i]) {
            finalWidths[i] = minWidths[i];
          } else {
            final donatable = rawSizes[i] - minWidths[i];
            finalWidths[i] = rawSizes[i] - donatable * shrinkFactor;
          }
        }

        // If deficit exceeds donorPool entirely (too many tiny partitions),
        // just allow horizontal overflow via scrolling instead of squishing further.
        final totalFinalWidth = finalWidths.fold<double>(0, (a, b) => a + b);
        final needsScroll = totalFinalWidth > totalWidth + 0.5;

        final row = Row(
          children: [
            for (var i = 0; i < partitions.length; i++)
              _PartitionSegment(
                partition: partitions[i],
                mountAt: widget.mounts[partitions[i].device] ?? "",
                width: finalWidths[i],
                height: widget.height,
                isSelected: partitions[i].device == widget.selectedPartition,
                isFirst: i == 0,
                isLast: i == partitions.length - 1,
                onTap: () => widget.onPartitionSelected?.call(partitions[i]),
                onPartitionContextMenu: widget.onPartitionContextMenu,
              ),
          ],
        );

        if (needsScroll) {
          return SizedBox(
            height: widget.height,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalFinalWidth,
                child: row,
              ),
            ),
          );
        }

        return SizedBox(height: widget.height, child: row);
      },
    );
  }
}

class _PartitionSegment extends StatelessWidget {
  final StoragePartitionInfo partition;
  final String mountAt;
  final double width;
  final double height;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final List<MenuItem> Function(StoragePartitionInfo)? onPartitionContextMenu;

  const _PartitionSegment({
    required this.partition,
    required this.mountAt,
    required this.width,
    required this.height,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    this.onPartitionContextMenu,
  });

  Color get _baseColor {
    switch (partition.filesystem) {
      case StorageFilesystemType.fat32:
        return const Color(0xFF4F8EF7);
      case StorageFilesystemType.ext4:
        return const Color(0xFFE2733D);
      case StorageFilesystemType.btrfs:
        return const Color(0xFF7E57C2);
      case StorageFilesystemType.xfs:
        return const Color(0xFF26A69A);
      case StorageFilesystemType.freeSpace:
        return const Color(0xFF9E9E9E);
      case StorageFilesystemType.unknown:
        return const Color(0xFF8A8A8A);
    }
  }

  String get _label {
    switch (partition.filesystem) {
      case StorageFilesystemType.fat32:
        return 'FAT32';
      case StorageFilesystemType.ext4:
        return 'ext4';
      case StorageFilesystemType.btrfs:
        return 'btrfs';
      case StorageFilesystemType.xfs:
        return 'XFS';
      case StorageFilesystemType.freeSpace:
        return 'Free Space';
      case StorageFilesystemType.unknown:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: isFirst ? const Radius.circular(8) : Radius.zero,
      right: isLast ? const Radius.circular(8) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: ContextMenu(
        enabled: onPartitionContextMenu != null,
        items: () {
          final res = onPartitionContextMenu?.call(partition);
          if (res == null || res.isEmpty) {
            return [const MenuLabel(child: Text("No context menu actions."))];
          }
          return res;
        }(),
        child: Tooltip(
          tooltip: (_) => TooltipContainer(child: Text('${partition.device}\n'
              '$_label • ${partition.sizeMiB} MiB\n'
              '${mountAt.isEmpty ? '(not mounted)' : mountAt}')),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: width,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _baseColor,
              borderRadius: radius,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(color: Colors.black.withValues(alpha: 0.15), width: 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _baseColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: width >= 40
                ? Text(
                    _label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.clip,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}