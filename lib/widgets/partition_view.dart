import 'package:flutter/cupertino.dart';
import 'package:jappeos_services/jappeos_services.dart';

class PartitionView extends StatelessWidget {
  final StorageDeviceInfo device;
  final String? selectedPartition;
  final void Function(String?)? onSelectPartition;

  const PartitionView({
    super.key,
    required this.device,
    this.selectedPartition,
    this.onSelectPartition,
  });

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}