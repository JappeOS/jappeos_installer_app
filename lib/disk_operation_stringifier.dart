import 'package:collection/collection.dart';
import 'package:jappeos_services/jappeos_services.dart';

String stringifyDiskOperations(StorageInfo storageInfo, InstallDiskInfo diskInfo) {
  switch (diskInfo.mode) {
    case InstallDiskMode.erase:
      return _stringifyEraseMode(storageInfo, diskInfo);
    case InstallDiskMode.manual:
      return _stringifyManualMode(storageInfo, diskInfo);
    case InstallDiskMode.custom:
      return _stringifyCustomMode(storageInfo, diskInfo);
  }
  // ignore: dead_code
  throw UnimplementedError("No stringifier specified for mode: ${diskInfo.mode}");
}

String diskToString(StorageDeviceInfo? dev)
    => "${dev?.device ?? "<unknown device>"} (${sizeMiBToString(dev?.sizeMiB)} MiB)";

String partitionToString(StoragePartitionInfo? part)
    => "${part?.device ?? "<unknown device>"} (${sizeMiBToString(part?.sizeMiB)} MiB${part?.filesystem != null ? part?.filesystem.name : ""})";

String sizeMiBToString([int? sizeMiB = 0, bool remaining = false]) {
  if (remaining) {
    return "(remaining size)";
  }
  if (sizeMiB == null) {
    return "<unknown size>";
  }
  return "$sizeMiB MiB";
}

String _stringifyEraseMode(StorageInfo storageInfo, InstallDiskInfo diskInfo) {
  final device = storageInfo.devices[diskInfo.device];
  return _item("Erase all data from ${diskToString(device)} and install JappeOS").trimRight();
}

String _stringifyManualMode(StorageInfo storageInfo, InstallDiskInfo diskInfo) {
  String str = "";
  for (final mnt in diskInfo.mounts) {
    str += _item("Mount ${mnt.partition} to ${mnt.mountPoint}");
    if (mnt.mountPoint == kStorageMountpointBoot) {
      str += _item("Install boot files to ${mnt.partition}");
    } else if (mnt.mountPoint == kStorageMountpointRoot) {
      str += _item("Install system files to ${mnt.partition}");
    } else {
      str += _item("Install required JappeOS files to ${mnt.partition}");
    }
  }
  return str.trimRight();
}

String _stringifyCustomMode(StorageInfo storageInfo, InstallDiskInfo diskInfo) {
  String str = "";
  final device = storageInfo.devices[diskInfo.device];
  for (final op in diskInfo.operations) {
    switch (op.type) {
      case InstallDiskOperationType.create:
        final createOp = op as InstallDiskOperationCreateInfo;
        str += _item("Create partition ${createOp.region} of ${createOp.filesystem}${createOp.mountPoint.isNotEmpty ? ", mounted to ${createOp.mountPoint}" : ""}");
        break;
      case InstallDiskOperationType.remove:
        final removeOp = op as InstallDiskOperationRemoveInfo;
        final existingPart
            = device?.partitions.firstWhereOrNull((p) => p.device == op.partition);
        str += _item("Remove partition ${removeOp.partition}${existingPart != null ? " with size ${sizeMiBToString(existingPart.sizeMiB)} of ${existingPart.filesystem}" : ""}");
        break;
      case InstallDiskOperationType.resize:
        final resizeOp = op as InstallDiskOperationResizeInfo;
        final existingPart
            = device?.partitions.firstWhereOrNull((p) => p.device == op.partition);
        str += _item("Resize partition ${resizeOp.partition} from ${sizeMiBToString(existingPart?.sizeMiB)} to ${sizeMiBToString(resizeOp.sizeMiB, resizeOp.remaining)}");
      case InstallDiskOperationType.setFilesystem:
        final setFsOp = op as InstallDiskOperationSetFilesystemInfo;
        final existingPart
            = device?.partitions.firstWhereOrNull((p) => p.device == op.partition);
        str += _item("Change filesystem of partition ${setFsOp.partition} from ${existingPart?.filesystem.name ?? "<unknown filesystem>"} to ${setFsOp.filesystem.name}");
      case InstallDiskOperationType.setMountpoint:
        final setMntOp = op as InstallDiskOperationSetMountpointInfo;
        final existingPart
            = device?.partitions.firstWhereOrNull((p) => p.device == op.partition);
        str += _item("Change mountpoint of partition ${setMntOp.partition} from ${existingPart?.mountPoint ?? "<unknown mountpoint>"} to ${setMntOp.mountPoint}");
      // ignore: unreachable_switch_default
      default: break;
    }
  }
  return str.trimRight();
}

String _item(String str) => "* $str\n";