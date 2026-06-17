import 'package:collection/collection.dart';
import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:jappeos_installer/widgets/partition_list.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../disk_operation_stringifier.dart';
import '../provider/install_provider.dart';
import '../provider/page_provider.dart';
import '../widgets/partition_view.dart';

const _kStorageMountpointNone = "<none>";
const _kValidStorageFilesystems = [
  StorageFilesystemType.fat32,
  StorageFilesystemType.ext4,
  StorageFilesystemType.btrfs,
  StorageFilesystemType.xfs,
];

class PartitioningPage extends InstallerPage {
  PartitioningPage() : super('Partitioning');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [Expanded(child: _PartitioningPageWidget(pageIndex: index))];
  }
}

class _PartitioningPageWidget extends StatefulWidget {
  final int pageIndex;

  const _PartitioningPageWidget({required this.pageIndex});

  @override
  State<_PartitioningPageWidget> createState() => _PartitioningPageWidgetState();
}

class _PartitioningPageWidgetState extends State<_PartitioningPageWidget> {
  String? _selectedDevice;

  @override
  void initState() {
    super.initState();
    final installProvider = context.read<InstallProvider>();
    final devices = installProvider.storageInfo?.devices;
    _selectedDevice = devices?.values.reduce((a, b) {
      if (b.sizeMiB != a.sizeMiB) {
        return b.sizeMiB > a.sizeMiB ? b : a;
      }
      return b.partitions.length < a.partitions.length ? b : a;
    }).device;
  }

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final mode = installProvider.selectedDiskInstallMode;
    final scaling = Theme.of(context).scaling;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Partitioning").h3(),
        Gap(2 * scaling),
        Text("Edit your partitions below. ${_desc(mode)}").muted(),
        Gap(8 * scaling),
        Expanded(
          child: () {
            switch (mode) {
              case InstallDiskMode.erase:
                return _buildErase(installProvider);
              case InstallDiskMode.manual:
                return _buildManual(installProvider);
              case InstallDiskMode.custom:
                return _buildCustom(installProvider);
              // ignore: unreachable_switch_default
              default:
                throw Exception("Unhandled disk mode.");
            }
          }(),
        ),
      ],
    );
  }

  Widget _buildErase(InstallProvider installProvider) {
    return _ErasePage(
      pageIndex: widget.pageIndex,
      selectedDevice: _selectedDevice,
      onDeviceSelected: (p0) => _handleDeviceSelected(installProvider, p0),
    );
  }

  Widget _buildManual(InstallProvider installProvider) {
    return _ManualPage(
      pageIndex: widget.pageIndex,
      selectedDevice: _selectedDevice,
      onDeviceSelected: (p0) => _handleDeviceSelected(installProvider, p0),
    );
  }

  Widget _buildCustom(InstallProvider installProvider) {
    return _CustomPage(
      pageIndex: widget.pageIndex,
      selectedDevice: _selectedDevice,
      onDeviceSelected: (p0) => _handleDeviceSelected(installProvider, p0),
    );
  }

  void _handleDeviceSelected(InstallProvider installProvider, String? dev) {
    if (installProvider.storageInfo?.devices.containsKey(dev) ?? false) {
      setState(() => _selectedDevice = dev);
    }
  }

  String _desc(InstallDiskMode mode) {
    if (mode == InstallDiskMode.erase) return "";
    if (mode == InstallDiskMode.manual) {
      return "Assign mountpoints to the partitions by right-clicking them in the partition-bar or the list.";
    }
    return "Create, resize, remove and assign mountpoints/filesystems to the partitions by right-clicking them in the partition-bar or the list.";
  }
}

class _ErasePage extends StatefulWidget {
  final int pageIndex;
  final String? selectedDevice;
  final void Function(String?) onDeviceSelected;

  const _ErasePage({
    required this.pageIndex,
    required this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  State<_ErasePage> createState() => _ErasePageState();
}

class _ErasePageState extends State<_ErasePage> {
  late PageProvider _pageProvider;

  @override
  void initState() {
    super.initState();
    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.pageIndex, _handleSubmit);
  }

  Future<bool> _handleSubmit() async {
    final installProvider = context.read<InstallProvider>();
    installProvider.installPlan = installProvider.installPlan.copyWith(
      disk: _createDiskInfo(),
    );
    return true;
  }

  @override
  void didChangeDependencies() {
    _pageProvider = context.read<PageProvider>();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageProvider.unregisterFormHandler(widget.pageIndex);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final devices = installProvider.storageInfo?.devices;
    final scaling = Theme.of(context).scaling;
    return SizedBox(
      width: 350,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 12 * scaling,
        children: [
          const Text("Select drive to erase below."),
          if (devices == null || devices.isEmpty) ...[
            const Alert(
              leading: Icon(Icons.info),
              title: Text("Note"),
              content: Text("No storage devices found. Make sure to plug it in before starting your PC."),
            ),
          ] else ...[
            Select<String>(
              itemBuilder: (context, item) => Text(item),
              onChanged: widget.onDeviceSelected,
              value: widget.selectedDevice,
              placeholder: const Text('Select a storage device'),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    for (final dev in devices.entries)
                      SelectItemButton(
                        value: dev.key,
                        child: Text(dev.key),
                      ),
                  ],
                ),
              ),
            ),
            Alert.destructive(
              leading: const Icon(Icons.warning),
              title: const Text("Warning"),
              content: Text("This will erase all files, operating systems and data from: ${widget.selectedDevice}"),
            ),
          ],
        ],
      ),
    );
  }

  InstallDiskInfo? _createDiskInfo() {
    return InstallDiskInfo.erase(
      widget.selectedDevice!,
    );
  }
}

class _ManualPage extends StatefulWidget {
  final int pageIndex;
  final String? selectedDevice;
  final void Function(String?) onDeviceSelected;

  const _ManualPage({
    required this.pageIndex,
    required this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  State<_ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<_ManualPage> {
  late PageProvider _pageProvider;
  StoragePartitionInfo? _selectedPartition;
  final Map<String, InstallDiskMountInfo> _mounts = {};

  @override
  void initState() {
    super.initState();

    final installProvider = context.read<InstallProvider>();
    if (installProvider.installPlan.disk.mode == InstallDiskMode.manual &&
        widget.selectedDevice == installProvider.installPlan.disk.device) {
      for (final mnt in installProvider.installPlan.disk.mounts) {
        _mounts[mnt.partition] = mnt;
      }
    }

    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.pageIndex, _handleSubmit);
  }

  Future<bool> _handleSubmit() async {
    bool bootFound = false;
    bool rootFound = false;
    bool duplicates = false;
    for (final mnt in _mounts.entries) {
      if (mnt.value.mountPoint == kStorageMountpointBoot) {
        if (bootFound) duplicates = true;
        bootFound = true;
      }
      if (mnt.value.mountPoint == kStorageMountpointRoot) {
        if (rootFound) duplicates = true;
        rootFound = true;
      }
    }

    if (!bootFound || !rootFound || duplicates) {
      _showErrorDialog();
      return false;
    }

    final installProvider = context.read<InstallProvider>();
    installProvider.installPlan = installProvider.installPlan.copyWith(
      disk: _createDiskInfo(),
    );

    return true;
  }

  @override
  void didChangeDependencies() {
    _pageProvider = context.read<PageProvider>();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageProvider.unregisterFormHandler(widget.pageIndex);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    return _PartitioningLayout(
      storageInfo: installProvider.storageInfo,
      mounts: _mounts.map((k, v) => MapEntry(k, v.mountPoint)),
      selectedDevice: widget.selectedDevice,
      onDeviceSelected: widget.onDeviceSelected,
      selectedPartition: _selectedPartition,
      onPartitionSelected: (v) => setState(() => _selectedPartition = v),
      onPartitionContextMenu: _buildMenuItems,
      onCreateDiskInfo: _createDiskInfo,
      actions: _buildActions(),
    );
  }

  List<MenuItem> _buildMenuItems(StoragePartitionInfo info) {
    List<MenuItem> items = [];
    if (_canSetMountpoint(info)) {
      items.add(
        MenuButton(
          child: const Text('Set Mountpoint...'),
          onPressed: (_) => _setMountpoint(info),
        ),
      );
    }
    if (items.isNotEmpty) {
      items.insert(0, MenuLabel(child: Text(info.device)));
    }
    return items;
  }

  List<Widget> _buildActions() {
    return [
      Tooltip(
        tooltip: (_) => const TooltipContainer(child: Text("Set Mountpoint...")),
        child: IconButton.ghost(
          onPressed: _canSetMountpoint(_selectedPartition)
              ? () => _setMountpoint(_selectedPartition!)
              : null,
          icon: const Icon(Icons.edit),
        ),
      ),
    ];
  }

  void _showErrorDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      leading: const Icon(Icons.error),
      title: const Text("Error"),
      content: const Text("Make sure that there is exactly one boot partition and exactly one root partition."),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Aknowledge"),
        ),
      ],
    ),
  );

  InstallDiskInfo? _createDiskInfo() {
    final mounts = _mounts.values.toList();
    if (mounts.isEmpty) return null;
    return InstallDiskInfo.manual(
      widget.selectedDevice!,
      mounts,
    );
  }

  bool _canSetMountpoint(StoragePartitionInfo? info) {
    if (info == null) return false;
    return !info.isFreeSpace() &&
        info.filesystem != StorageFilesystemType.unknown;
  }

  void _setMountpoint(StoragePartitionInfo part) {
    showDialog(
      context: context,
      builder: (context) => _SetMountpointDialog(
        partition: part,
      ),
    ).then((v) {
      if (v != kStorageMountpointBoot &&
          v != kStorageMountpointRoot &&
          v != _kStorageMountpointNone) {return;}

      if (v == _kStorageMountpointNone) {
        setState(() => _mounts.remove(part.device));
        return;
      }

      setState(() {
        _mounts[part.device] = InstallDiskMountInfo(
          partition: part.device,
          mountPoint: v,
        );
      });
    });
  }
}

class _SetMountpointDialog extends StatefulWidget {
  final StoragePartitionInfo partition;

  const _SetMountpointDialog({required this.partition});

  @override
  State<_SetMountpointDialog> createState() => _SetMountpointDialogState();
}

class _SetMountpointDialogState extends State<_SetMountpointDialog> {
  String? _selectedValue;

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    return AlertDialog(
      title: const Text("Set Mountpoint"),
      content: Column(
        spacing: 8 * scaling,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Set the mountpoint of ${partitionToString(widget.partition)}"),
          SizedBox(
            width: 250,
            child: Select<String>(
              itemBuilder: (context, item) => Text(item),
              onChanged: (value) {
                setState(() => _selectedValue = value);
              },
              value: _selectedValue,
              placeholder: const Text('Select a mountpoint'),
              popup: const SelectPopup(
                items: SelectItemList(
                  children: [
                    SelectItemButton(
                      value: _kStorageMountpointNone,
                      child: Text(_kStorageMountpointNone),
                    ),
                    SelectItemButton(
                      value: kStorageMountpointBoot,
                      child: Text(kStorageMountpointBoot),
                    ),
                    SelectItemButton(
                      value: kStorageMountpointRoot,
                      child: Text(kStorageMountpointRoot),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        PrimaryButton(
          onPressed: _selectedValue == kStorageMountpointBoot ||
              _selectedValue == kStorageMountpointRoot ||
              _selectedValue == _kStorageMountpointNone
                  ? () => Navigator.pop(context, _selectedValue) : null,
          child: const Text("Change"),
        ),
      ],
    );
  }
}

class _CustomPage extends StatefulWidget {
  final int pageIndex;
  final String? selectedDevice;
  final void Function(String?) onDeviceSelected;

  const _CustomPage({
    required this.pageIndex,
    required this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  State<_CustomPage> createState() => _CustomPageState();
}

class _CustomPageState extends State<_CustomPage> {
  late PageProvider _pageProvider;
  StorageInfo? _originalStorageInfo;
  StoragePartitionInfo? _selectedPartition;
  final List<InstallDiskOperationInfo> _operations = [];
  late final List<StoragePartitionInfo> _appliedPartitions;

  @override
  void initState() {
    super.initState();

    final installProvider = context.read<InstallProvider>();
    _originalStorageInfo = installProvider.storageInfo?.withoutMountpoints();
    _appliedPartitions
        = _originalStorageInfo?.devices[widget.selectedDevice]?.partitions.withoutMountpoints() ?? [];
    if (installProvider.installPlan.disk.mode == InstallDiskMode.custom &&
        widget.selectedDevice == installProvider.installPlan.disk.device) {
      for (final op in installProvider.installPlan.disk.operations) {
        _applyOperation(op);
        //_operations.add(op);
      }
    }

    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.pageIndex, _handleSubmit);
  }

  void _applyOperation(InstallDiskOperationInfo op) {
    switch (op.type) {
      case InstallDiskOperationType.create:
        final createOp = op as InstallDiskOperationCreateInfo;
        _createPart(
          _appliedPartitions.firstWhere((p) => p.device == createOp.region),
          op.sizeMiB,
          op.remaining,
          op.mountPoint,
          op.filesystem,
        );
      case InstallDiskOperationType.remove:
        final removeOp = op as InstallDiskOperationRemoveInfo;
        _deletePart(
          _appliedPartitions.firstWhere((p) => p.device == removeOp.partition),
        );
      case InstallDiskOperationType.resize:
        final resizeOp = op as InstallDiskOperationResizeInfo;
        final part = _appliedPartitions.firstWhere((p) => p.device == resizeOp.partition);
        var nextPart = _appliedPartitions.elementAtOrNull(_appliedPartitions.indexOf(part) + 1);
        if (nextPart != null && !nextPart.isFreeSpace()) {
          nextPart = null;
        }
        _resizePart(
          part,
          nextPart,
          resizeOp.sizeMiB,
          resizeOp.remaining,
        );
      case InstallDiskOperationType.setFilesystem:
        final setFsOp = op as InstallDiskOperationSetFilesystemInfo;
        _setPartFilesystem(
          _appliedPartitions.firstWhere((p) => p.device == setFsOp.partition),
          setFsOp.filesystem,
        );
      case InstallDiskOperationType.setMountpoint:
        final setMntOp = op as InstallDiskOperationSetMountpointInfo;
        _setPartMountpoint(
          _appliedPartitions.firstWhere((p) => p.device == setMntOp.partition),
          setMntOp.mountPoint,
        );
      // ignore: unreachable_switch_default
      default: break;
    }
  }

  Future<bool> _handleSubmit() async {
    bool bootFound = false;
    bool rootFound = false;
    bool duplicates = false;

    for (final mnt in _getMountpoints().entries) {
      if (mnt.value == kStorageMountpointBoot) {
        if (bootFound) duplicates = true;
        bootFound = true;
      }
      if (mnt.value == kStorageMountpointRoot) {
        if (rootFound) duplicates = true;
        rootFound = true;
      }
    }

    if (!bootFound || !rootFound || duplicates) {
      _showErrorDialog();
      return false;
    }

    final installProvider = context.read<InstallProvider>();
    installProvider.installPlan = installProvider.installPlan.copyWith(
      disk: _createDiskInfo(),
    );

    return true;
  }

  @override
  void didChangeDependencies() {
    _pageProvider = context.read<PageProvider>();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageProvider.unregisterFormHandler(widget.pageIndex);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PartitioningLayout(
      storageInfo: _createAppliedStorageInfo(),
      originalStorageInfo: _originalStorageInfo,
      mounts: _getMountpoints(),
      selectedDevice: widget.selectedDevice,
      onDeviceSelected: widget.onDeviceSelected,
      selectedPartition: _selectedPartition,
      onPartitionSelected: (v) => setState(() => _selectedPartition = v),
      onPartitionContextMenu: _buildMenuItems,
      onCreateDiskInfo: _createDiskInfo,
      actions: _buildActions(),
    );
  }

  List<MenuItem> _buildMenuItems(StoragePartitionInfo info) {
    List<MenuItem> items = [];
    if (_canCreate(info)) {
      items.add(
        MenuButton(
          child: const Text('Create...'),
          onPressed: (_) => _create(info),
        ),
      );
    }
    if (_canResize(info)) {
      items.add(
        MenuButton(
          child: const Text('Resize...'),
          onPressed: (_) => _resize(info),
        ),
      );
    }
    if (_canEditData(info)) {
      items.add(
        MenuButton(
          child: const Text('Edit Data...'),
          onPressed: (_) => _editData(info),
        ),
      );
    }
    if (_canDelete(info)) {
      items.add(
        MenuButton(
          child: const Text('Delete...'),
          onPressed: (_) => _delete(info),
        ),
      );
    }
    if (items.isNotEmpty) {
      items.insert(0, MenuLabel(child: Text(info.device)));
    }
    return items;
  }

  List<Widget> _buildActions() {
    return [
      Tooltip(
        tooltip: (_) => const TooltipContainer(child: Text("Create...")),
        child: IconButton.ghost(
          onPressed: _canCreate(_selectedPartition)
              ? () => _create(_selectedPartition!)
              : null,
          icon: const Icon(Icons.add),
        ),
      ),
      Tooltip(
        tooltip: (_) => const TooltipContainer(child: Text("Resize...")),
        child: IconButton.ghost(
          onPressed: _canResize(_selectedPartition)
              ? () => _resize(_selectedPartition!)
              : null,
          icon: const Icon(Icons.swap_horiz),
        ),
      ),
      Tooltip(
        tooltip: (_) => const TooltipContainer(child: Text("Edit Data...")),
        child: IconButton.ghost(
          onPressed: _canEditData(_selectedPartition)
              ? () => _editData(_selectedPartition!)
              : null,
          icon: const Icon(Icons.edit),
        ),
      ),
      Tooltip(
        tooltip: (_) => const TooltipContainer(child: Text("Delete...")),
        child: IconButton.ghost(
          onPressed: _canDelete(_selectedPartition)
              ? () => _delete(_selectedPartition!)
              : null,
          icon: const Icon(Icons.delete_forever),
        ),
      ),
    ];
  }

  void _showErrorDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      leading: const Icon(Icons.error),
      title: const Text("Error"),
      content: const Text("Make sure that there is exactly one boot partition and exactly one root partition."),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Aknowledge"),
        ),
      ],
    ),
  );

  InstallDiskInfo? _createDiskInfo() {
    if (_operations.isEmpty) return null;
    return InstallDiskInfo.custom(
      widget.selectedDevice!,
      _operations,
    );
  }

  StorageInfo? _createAppliedStorageInfo() {
    final installProvider = context.read<InstallProvider>();
    var map = installProvider.storageInfo?.devices;
    if (map == null) return null;
    map = Map.of(map);
    var currentDev = map[widget.selectedDevice];
    if (currentDev == null) return null;
    map[widget.selectedDevice!]
        = currentDev.copyWith(partitions: _appliedPartitions);
    return StorageInfo(devices: map);
  }

  Map<String, String> _getMountpoints() {
    Map<String, String> ret = {};
    for (final part in _appliedPartitions) {
      if (part.mountPoint == kStorageMountpointBoot ||
          part.mountPoint == kStorageMountpointRoot) {
        ret[part.device] = part.mountPoint;
      }
    }
    return ret;
  }

  bool _canCreate(StoragePartitionInfo? info) {
    if (info == null) return false;
    return info.isFreeSpace();
  }

  void _create(StoragePartitionInfo part) {
    showDialog(
      context: context,
      builder: (context) => _CreatePartitionDialog(
        partition: part,
      ),
    ).then((v) {
      if (v is! (int?, bool, String?, StorageFilesystemType)) return;
      assert(
        v.$1 != null || v.$2,
        "sizeMiB needs to be specified if remaining is false",
      );
      _createPart(part, v.$1, v.$2, v.$3 ?? "", v.$4);
    });
  }

  bool _canResize(StoragePartitionInfo? info) {
    if (info == null) return false;
    return !info.isFreeSpace() &&
        info.filesystem != StorageFilesystemType.unknown;
  }

  void _resize(StoragePartitionInfo part) {
    final nextIndex = _appliedPartitions.indexOf(part) + 1;
    var nextPart = nextIndex > _appliedPartitions.length - 1
        ? null
        : _appliedPartitions[nextIndex];

    if (nextPart != null && !nextPart.isFreeSpace()) {
      nextPart = null;
    }

    final nextPartSize = nextPart?.sizeMiB ?? 0;

    showDialog(
      context: context,
      builder: (context) => _ResizePartitionDialog(
        partition: part,
        trailingSizeMiB: nextPartSize,
      ),
    ).then((v) {
      if (v is! (int?, bool)) return;
      assert(
        v.$1 != null || v.$2,
        "sizeMiB needs to be specified if remaining is false",
      );
      _resizePart(part, nextPart, v.$1, v.$2);
    });
  }

  bool _canEditData(StoragePartitionInfo? info) {
    if (info == null) return false;
    return !info.isFreeSpace() &&
        info.filesystem != StorageFilesystemType.unknown;
  }

  void _editData(StoragePartitionInfo part) {
    showDialog(
      context: context,
      builder: (context) => _EditPartitionDataDialog(
        partition: part,
      ),
    ).then((v) {
      if (v is! (String?, StorageFilesystemType?)) return;
      if (v.$1 != null) {
        _setPartMountpoint(part, v.$1!);
      }
      if (v.$2 != null) {
        _setPartFilesystem(part, v.$2!);
      }
    });
  }

  bool _canDelete(StoragePartitionInfo? info) {
    if (info == null) return false;
    return !info.isFreeSpace() &&
        info.filesystem != StorageFilesystemType.unknown;
  }

  void _delete(StoragePartitionInfo part) {
    showDialog(
      context: context,
      builder: (context) => _DeletePartitionDialog(
        partition: part,
      ),
    ).then((v) {
      if (v is! bool || !v) return;
      _deletePart(part);
    });
  }

  void _createPart(
    StoragePartitionInfo freeSpace,
    int? sizeMiB,
    bool remaining,
    String mountpoint,
    StorageFilesystemType filesystem,
  ) {
    if ((sizeMiB == null && !remaining) ||
        (sizeMiB != null && sizeMiB > freeSpace.sizeMiB)) {
      return;
    }

    final finalMountpoint = mountpoint == _kStorageMountpointNone ? "" : mountpoint;
    final createOp = InstallDiskOperationCreateInfo(
      region: freeSpace.device,
      sizeMiB: sizeMiB ?? 0,
      remaining: remaining,
      filesystem: filesystem,
      mountPoint: finalMountpoint,
    );

    final index = _appliedPartitions.indexOf(freeSpace);

    /*final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );*/

    /*_operations.removeWhere(
      (op) => op is InstallDiskOperationCreateInfo &&
      op.region == part.device
    );*/

    if (index == -1) {
      //setState(() {});
      return;
    }

    _operations.add(createOp);

    final finalSizeMiB = remaining ? freeSpace.sizeMiB : sizeMiB!;
    final freeSizeMiB = freeSpace.sizeMiB - finalSizeMiB;
    if (freeSizeMiB == 0) {
      _appliedPartitions.removeAt(index);
    } else {
      _appliedPartitions[index] = freeSpace.copyWith(
        sizeMiB: freeSizeMiB,
      );
    }

    final newPart = StoragePartitionInfo(
      device: "",
      filesystem: filesystem,
      sizeMiB: finalSizeMiB,
      mountPoint: finalMountpoint,
    );
    _appliedPartitions.insert(index, newPart);
    _removePartAdjacentSpaces();
    _createPartitionNames();

    setState(() {});
  }

  void _resizePart(
    StoragePartitionInfo part,
    StoragePartitionInfo? nextPart,
    int? sizeMiB,
    bool remaining,
  ) {
    final availableTrailingSpace = nextPart?.sizeMiB ?? 0;
    final maxSize = part.sizeMiB + availableTrailingSpace;
    if ((sizeMiB == null && !remaining) ||
        (!(nextPart?.isFreeSpace() ?? true)) ||
        (sizeMiB != null && sizeMiB > maxSize) ||
        (sizeMiB == part.sizeMiB)) {
      return;
    }

    final resizeOp = InstallDiskOperationResizeInfo(
      partition: part.device,
      sizeMiB: sizeMiB ?? 0,
      remaining: remaining,
    );

    final index = _appliedPartitions.indexOf(part);
    if (index == -1) {
      return;
    }

    final nextIndex = index + 1;

    final resizeSize = remaining ? maxSize : sizeMiB!;
    final addedSpace = resizeSize - part.sizeMiB;
    if (resizeSize > part.sizeMiB && addedSpace > availableTrailingSpace) {
      return;
    }

    _operations.add(resizeOp);

    _appliedPartitions[index] = part.copyWith(
      sizeMiB: resizeSize,
    );

    if (addedSpace == availableTrailingSpace) {
      if (nextPart != null) {
        _appliedPartitions.removeAt(nextIndex);
      }
    } else if (addedSpace > 0 && nextPart != null) {
      _appliedPartitions[nextIndex] = nextPart.copyWith(
        sizeMiB: nextPart.sizeMiB - addedSpace,
      );
    }

    if (addedSpace < 0) {
      final newPart = StoragePartitionInfo(
        device: "",
        filesystem: StorageFilesystemType.freeSpace,
        sizeMiB: -addedSpace,
        mountPoint: "",
      );
      _appliedPartitions.insert(nextIndex, newPart);
    }

    _removePartAdjacentSpaces();
    _createPartitionNames();
    setState(() {});
  }

  void _deletePart(StoragePartitionInfo part) {
    final deleteOp = InstallDiskOperationRemoveInfo(
      partition: part.device,
    );

    final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );

    final existingOps = _operations.where(
      (op) => op is InstallDiskOperationRemoveInfo &&
      op.partition == part.device
    );

    for (final op in existingOps) {
      _operations.remove(op);
    }

    if (index == -1) {
      setState(() {});
      return;
    }

    _operations.add(deleteOp);
    final newPart = StoragePartitionInfo(
      device: "",
      filesystem: StorageFilesystemType.freeSpace,
      sizeMiB: part.sizeMiB,
      mountPoint: "",
    );
    _appliedPartitions[index] = newPart;
    _removePartAdjacentSpaces();
    _createPartitionNames();

    setState(() {});
  }

  void _setPartMountpoint(StoragePartitionInfo part, String mountpoint) {
    if (mountpoint != kStorageMountpointBoot &&
        mountpoint != kStorageMountpointRoot &&
        mountpoint != _kStorageMountpointNone) {return;}

    final finalMountpoint = mountpoint == _kStorageMountpointNone ? "" : mountpoint;
    final mountOp = InstallDiskOperationSetMountpointInfo(
      partition: part.device,
      mountPoint: finalMountpoint,
    );

    final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );

    _operations.removeWhere(
      (op) => op is InstallDiskOperationSetMountpointInfo &&
      op.partition == part.device
    );

    if (index == -1) {
      setState(() {});
      return;
    }

    final createOp = _operations.firstWhereOrNull(
      (op) => op is InstallDiskOperationCreateInfo &&
      op.region == part.device &&
      op.mountPoint == part.mountPoint
    ) as InstallDiskOperationCreateInfo?;

    // TODO: FIX THIS
    // If partition exists as a result of a create-operation, we can simply
    // modify the original create-operation to change the mountpoint.
    if (createOp != null) {
      final createOpIndex = _operations.indexOf(createOp);
      _operations[createOpIndex] = InstallDiskOperationCreateInfo(
        region: createOp.region,
        sizeMiB: createOp.sizeMiB,
        remaining: createOp.remaining,
        filesystem: createOp.filesystem,
        mountPoint: finalMountpoint,
      );
      _appliedPartitions[index] = part.copyWith(
        mountPoint: finalMountpoint,
      );

      setState(() {});
      return;
    }

    if (mountpoint != _kStorageMountpointNone) {
      _operations.add(mountOp);
    }

    _appliedPartitions[index] = part.copyWith(
      mountPoint: finalMountpoint,
    );

    setState(() {});
  }

  void _setPartFilesystem(StoragePartitionInfo part, StorageFilesystemType fs) {
    if (!_kValidStorageFilesystems.contains(fs)) {
      return;
    }

    final fsOp = InstallDiskOperationSetFilesystemInfo(
      partition: part.device,
      filesystem: fs,
    );

    final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );

    _operations.removeWhere(
      (op) => op is InstallDiskOperationSetFilesystemInfo &&
      op.partition == part.device
    );

    if (index == -1) {
      setState(() {});
      return;
    }

    final createOp = _operations.firstWhereOrNull(
      (op) => op is InstallDiskOperationCreateInfo &&
      op.region == part.device &&
      op.filesystem == part.filesystem
    ) as InstallDiskOperationCreateInfo?;

    // TODO: FIX THIS
    // If partition exists as a result of a create-operation, we can simply
    // modify the original create-operation to change the filesystem.
    if (createOp != null) {
      final createOpIndex = _operations.indexOf(createOp);
      _operations[createOpIndex] = InstallDiskOperationCreateInfo(
        region: createOp.region,
        sizeMiB: createOp.sizeMiB,
        remaining: createOp.remaining,
        filesystem: fs,
        mountPoint: createOp.mountPoint,
      );
      _appliedPartitions[index] = part.copyWith(
        filesystem: fs,
      );

      setState(() {});
      return;
    }

    _operations.add(fsOp);
    _appliedPartitions[index] = part.copyWith(
      filesystem: fs,
    );

    setState(() {});
  }

  void _removePartAdjacentSpaces() {
    for (int i = 1; i < _appliedPartitions.length;) {
      if (_appliedPartitions[i - 1].isFreeSpace() &&
          _appliedPartitions[i].isFreeSpace()) {
        _appliedPartitions[i - 1] = _appliedPartitions[i - 1].copyWith(
          sizeMiB: _appliedPartitions[i - 1].sizeMiB +
              _appliedPartitions[i].sizeMiB,
        );
        _appliedPartitions.removeAt(i);
      } else {
        ++i;
      }
    }
  }

  void _createPartitionNames() {
    int freeCount = 0;
    for (int i = 0; i < _appliedPartitions.length; i++) {
      final current = _appliedPartitions[i];
      if (current.isFreeSpace()) {
        freeCount++;
      }
      _appliedPartitions[i] = current.copyWith(
        device: _createName(
          current.isFreeSpace() ? freeCount : i + 1 - freeCount,
          current.isFreeSpace(),
        ),
      );
    }
  }

  String _createName(int index, bool free) {
    return "${widget.selectedDevice}${free ? "#free$index" : "$index"}";
  }
}

class _CreatePartitionDialog extends StatefulWidget {
  final StoragePartitionInfo partition;

  const _CreatePartitionDialog({required this.partition});

  @override
  State<_CreatePartitionDialog> createState() => _CreatePartitionDialogState();
}

class _CreatePartitionDialogState extends State<_CreatePartitionDialog> {
  final FormController _formController = FormController();
  late final TextEditingController _sizeFieldController;
  late int _sizeMiB;
  bool _useRemaining = false;
  String? _selectedMountpoint;
  late StorageFilesystemType _selectedFilesystem;

  @override
  void initState() {
    super.initState();
    _sizeMiB = widget.partition.sizeMiB;
    _selectedFilesystem = StorageFilesystemType.btrfs;
    _sizeFieldController = TextEditingController(text: _sizeMiB.toString());
  }

  @override
  void dispose() {
    _formController.dispose();
    _sizeFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    return AlertDialog(
      title: const Text("Create Partition"),
      content: Column(
        spacing: 8 * scaling,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Create partition to ${partitionToString(widget.partition)}"),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              controller: _formController,
              child: FormTableLayout(rows: [
                FormField<int>(
                  key: const FormKey(#size),
                  label: const Text('Size (MiB)'),
                  child: TextField(
                    controller: _sizeFieldController,
                    enabled: !_useRemaining,
                    onEditingComplete: () => _onTextFieldEdited(),
                    onSubmitted: (_) => _onTextFieldEdited(),
                    onChanged: (v) => setState(() => _sizeMiB = int.tryParse(v) ?? 0),
                    placeholder: const Text('Provide a valid size'),
                    features: const [
                      InputFeature.spinner(),
                    ],
                    submitFormatters: [
                      TextInputFormatters.mathExpression(),
                    ],
                  ),
                ),
                FormField<CheckboxState>(
                  key: const FormKey(#useRemaining),
                  label: const Text('Use remaining space'),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Checkbox(
                      state: _useRemaining
                          ? CheckboxState.checked
                          : CheckboxState.unchecked,
                      onChanged: (value) {
                        setState(() => _useRemaining = value == CheckboxState.checked);
                      },
                    ),
                  ),
                ),
                FormField<String>(
                  key: const FormKey(#filesystem),
                  label: const Text('Filesystem'),
                  child: Select<StorageFilesystemType>(
                    itemBuilder: (context, item) => Text(item.name),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedFilesystem = value);
                    },
                    value: _selectedFilesystem,
                    placeholder: const Text('Select a filesystem'),
                    popup: SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final fs in _kValidStorageFilesystems)
                            SelectItemButton(
                              value: fs,
                              child: Text(fs.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                FormField<String>(
                  key: const FormKey(#mountpoint),
                  label: const Text('Mountpoint'),
                  child: Select<String>(
                    itemBuilder: (context, item) => Text(item),
                    onChanged: (value) {
                      setState(() => _selectedMountpoint = value);
                    },
                    value: _selectedMountpoint,
                    placeholder: const Text('Select a mountpoint'),
                    popup: const SelectPopup(
                      items: SelectItemList(
                        children: [
                          SelectItemButton(
                            value: _kStorageMountpointNone,
                            child: Text(_kStorageMountpointNone),
                          ),
                          SelectItemButton(
                            value: kStorageMountpointBoot,
                            child: Text(kStorageMountpointBoot),
                          ),
                          SelectItemButton(
                            value: kStorageMountpointRoot,
                            child: Text(kStorageMountpointRoot),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ).withPadding(vertical: 16),
          ),
        ],
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        PrimaryButton(
          onPressed: () {
            //_onTextFieldEdited();

            final validatedSize = _validateSize(
              _useRemaining
                  ? widget.partition.sizeMiB
                  : _sizeMiB,
            );

            if ((_selectedMountpoint == kStorageMountpointBoot ||
                _selectedMountpoint == kStorageMountpointRoot ||
                _selectedMountpoint == _kStorageMountpointNone) &&
                validatedSize != null) {
              return () => Navigator.pop(
                context,
                (
                  _useRemaining ? null : _validateSize(_sizeMiB),
                  _useRemaining,
                  _selectedMountpoint,
                  _selectedFilesystem,
                ),
              );
            }
            return null;
          }(),
          child: const Text("Create"),
        ),
      ],
    );
  }

  void _onTextFieldEdited() {
    final value = _validateSize(int.tryParse(_sizeFieldController.text));
    _sizeFieldController.text = value?.toString() ?? "";
    if (value != null) {
      setState(() => _sizeMiB = value);
    }
  }

  int? _validateSize(int? targetSizeMiB) => PartitionUtils.validateSize(
    partition: widget.partition,
    targetSizeMiB: targetSizeMiB,
    targetMountpoint: _selectedMountpoint,
  );
}

class _ResizePartitionDialog extends StatefulWidget {
  final StoragePartitionInfo partition;
  final int trailingSizeMiB;

  const _ResizePartitionDialog({
    required this.partition,
    this.trailingSizeMiB = 0,
  });

  @override
  State<_ResizePartitionDialog> createState() => _ResizePartitionDialogState();
}

class _ResizePartitionDialogState extends State<_ResizePartitionDialog> {
  final FormController _formController = FormController();
  late final TextEditingController _sizeFieldController;
  late final int _maxSizeMiB;
  late int _sizeMiB;
  bool _useRemaining = false;

  @override
  void initState() {
    super.initState();
    _maxSizeMiB = widget.partition.sizeMiB + widget.trailingSizeMiB;
    _sizeMiB = widget.partition.sizeMiB;
    _sizeFieldController = TextEditingController(text: _sizeMiB.toString());
  }

  @override
  void dispose() {
    _formController.dispose();
    _sizeFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    return AlertDialog(
      title: const Text("Resize Partition"),
      content: Column(
        spacing: 8 * scaling,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Resize ${partitionToString(widget.partition)}"),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              controller: _formController,
              child: FormTableLayout(rows: [
                FormField<int>(
                  key: const FormKey(#size),
                  label: const Text('Current Size (MiB)'),
                  child: TextField(
                    enabled: false,
                    readOnly: true,
                    initialValue: widget.partition.sizeMiB.toString(),
                  ),
                ),
                FormField<int>(
                  key: const FormKey(#size),
                  label: const Text('New Size (MiB)'),
                  child: TextField(
                    controller: _sizeFieldController,
                    enabled: !_useRemaining,
                    onEditingComplete: () => _onTextFieldEdited(),
                    onSubmitted: (_) => _onTextFieldEdited(),
                    onChanged: (v) => setState(() => _sizeMiB = int.tryParse(v) ?? 0),
                    placeholder: const Text('Provide a valid size'),
                    features: const [
                      InputFeature.spinner(),
                    ],
                    submitFormatters: [
                      TextInputFormatters.mathExpression(),
                    ],
                  ),
                ),
                FormField<CheckboxState>(
                  key: const FormKey(#useRemaining),
                  label: const Text('Use remaining space'),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Checkbox(
                      state: _useRemaining
                          ? CheckboxState.checked
                          : CheckboxState.unchecked,
                      onChanged: (value) {
                        setState(() => _useRemaining = value == CheckboxState.checked);
                      },
                    ),
                  ),
                ),
              ]),
            ).withPadding(vertical: 16),
          ),
          const Alert.destructive(
            leading: Icon(Icons.warning),
            title: Text("Warning"),
            content: Text("Resizing a partition might cause data-loss! Make sure to back-up your data before resizing."),
          ),
        ],
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        DestructiveButton(
          onPressed: () {
            //_onTextFieldEdited();

            final validatedSize = _validateSize(
              _useRemaining
                  ? _maxSizeMiB
                  : _sizeMiB,
            );

            if (validatedSize != null) {
              return () => Navigator.pop(
                context,
                (
                  _useRemaining ? null : _validateSize(_sizeMiB),
                  _useRemaining,
                ),
              );
            }
          }(),
          child: const Text("Resize"),
        ),
      ],
    );
  }

  void _onTextFieldEdited() {
    var value = _validateSize(int.tryParse(_sizeFieldController.text));
    assert(value == null || value <= _maxSizeMiB);
    _sizeFieldController.text = value?.toString() ?? "";
    if (value != null) {
      setState(() => _sizeMiB = value);
    }
  }

  int? _validateSize(int? targetSizeMiB) => PartitionUtils.validateSize(
    partition: widget.partition,
    targetSizeMiB: targetSizeMiB,
    maxSizeMiB: _maxSizeMiB,
    targetMountpoint: widget.partition.mountPoint,
  );
}

class _EditPartitionDataDialog extends StatefulWidget {
  final StoragePartitionInfo partition;

  const _EditPartitionDataDialog({required this.partition});

  @override
  State<_EditPartitionDataDialog> createState() => _EditPartitionDataDialogState();
}

class _EditPartitionDataDialogState extends State<_EditPartitionDataDialog> {
  final FormController _controller = FormController();
  String? _selectedMountpoint;
  late StorageFilesystemType _selectedFilesystem;

  @override
  void initState() {
    super.initState();
    _selectedFilesystem = widget.partition.filesystem;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    return AlertDialog(
      title: const Text("Edit Partition"),
      content: Column(
        spacing: 8 * scaling,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Edit properties of ${partitionToString(widget.partition)}"),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              controller: _controller,
              child: FormTableLayout(rows: [
                FormField<String>(
                  key: const FormKey(#filesystem),
                  label: const Text('Filesystem'),
                  child: Select<StorageFilesystemType>(
                    itemBuilder: (context, item) => Text(item.name),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedFilesystem = value);
                    },
                    value: _selectedFilesystem,
                    placeholder: const Text('Select a filesystem'),
                    popup: SelectPopup(
                      items: SelectItemList(
                        children: [
                          for (final fs in _kValidStorageFilesystems)
                            SelectItemButton(
                              value: fs,
                              child: Text(fs.name),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                FormField<String>(
                  key: const FormKey(#mountpoint),
                  label: const Text('Mountpoint'),
                  child: Select<String>(
                    itemBuilder: (context, item) => Text(item),
                    onChanged: (value) {
                      setState(() => _selectedMountpoint = value);
                    },
                    value: _selectedMountpoint,
                    placeholder: const Text('Select a mountpoint'),
                    popup: const SelectPopup(
                      items: SelectItemList(
                        children: [
                          SelectItemButton(
                            value: _kStorageMountpointNone,
                            child: Text(_kStorageMountpointNone),
                          ),
                          SelectItemButton(
                            value: kStorageMountpointBoot,
                            child: Text(kStorageMountpointBoot),
                          ),
                          SelectItemButton(
                            value: kStorageMountpointRoot,
                            child: Text(kStorageMountpointRoot),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ).withPadding(vertical: 16),
          ),
        ],
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        PrimaryButton(
          onPressed: _selectedMountpoint == kStorageMountpointBoot ||
              _selectedMountpoint == kStorageMountpointRoot ||
              _selectedMountpoint == _kStorageMountpointNone ||
              _filesystemChanged()
                  ? () => Navigator.pop(
                    context,
                    (
                      _selectedMountpoint,
                      _filesystemChanged()
                          ? _selectedFilesystem
                          : null,
                    ))
                  : null,
          child: const Text("Change"),
        ),
      ],
    );
  }

  bool _filesystemChanged() => _selectedFilesystem != widget.partition.filesystem;
}

class _DeletePartitionDialog extends StatelessWidget {
  final StoragePartitionInfo partition;

  const _DeletePartitionDialog({required this.partition});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Delete Partition"),
      content: Text("Are you sure you wish to delete all data from ${partitionToString(partition)}?"),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        DestructiveButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    );
  }
}

class _PartitioningLayout extends StatelessWidget {
  final StorageInfo? storageInfo;
  final StorageInfo? originalStorageInfo;
  final Map<String, String> mounts;
  final String? selectedDevice;
  final void Function(String?)? onDeviceSelected;
  final StoragePartitionInfo? selectedPartition;
  final ValueChanged<StoragePartitionInfo>? onPartitionSelected;
  final List<MenuItem> Function(StoragePartitionInfo)? onPartitionContextMenu;
  final InstallDiskInfo? Function() onCreateDiskInfo;
  final List<Widget> actions;

  const _PartitioningLayout({
    required this.storageInfo,
    this.originalStorageInfo,
    required this.mounts,
    this.selectedDevice,
    this.onDeviceSelected,
    this.selectedPartition,
    this.onPartitionSelected,
    this.onPartitionContextMenu,
    required this.onCreateDiskInfo,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final devices = storageInfo?.devices;
    final scaling = Theme.of(context).scaling;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12 * scaling,
      children: devices == null || devices.isEmpty
      ? [
        const Alert(
          leading: Icon(Icons.info),
          title: Text("Note"),
          content: Text("No storage devices found. Make sure to plug it in before starting your PC."),
        ),
      ] : [
        Row(
          spacing: 8 * scaling,
          children: [
            const Text("Storage device for installation:"),
            const Gap(0),
            Select<String>(
              itemBuilder: (context, item) => Text(item),
              onChanged: onDeviceSelected,
              value: selectedDevice,
              placeholder: const Text('Select a storage device'),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    for (final dev in devices.entries)
                      SelectItemButton(
                        value: dev.key,
                        child: Text(dev.key),
                      ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
        if (selectedDevice != null) ...[
          PartitionView(
            device: devices[selectedDevice]!,
            mounts: mounts,
            selectedPartition: selectedPartition?.device,
            onPartitionSelected: onPartitionSelected,
            onPartitionContextMenu: onPartitionContextMenu,
          ),
          Expanded(
            child: Row(
              spacing: 12 * scaling,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: PartitionList(
                    device: devices[selectedDevice]!,
                    mounts: mounts,
                    selectedPartition: selectedPartition?.device,
                    onPartitionSelected: onPartitionSelected,
                    onPartitionContextMenu: onPartitionContextMenu,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildOperationsList(context, originalStorageInfo ?? storageInfo),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOperationsList(BuildContext context, StorageInfo? storageInfo) {
    final scaling = Theme.of(context).scaling;
    final diskInfo = onCreateDiskInfo();
    return OutlinedContainer(
      padding: EdgeInsets.all(8 * scaling),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8 * scaling,
        children: [
          const Text("Operations").medium().bold(),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: storageInfo != null && diskInfo != null
                  ? Text(stringifyDiskOperations(storageInfo, diskInfo)).italic()
                  : null,
            ),
          ),
        ],
      ),
    ).constrained(minWidth: 250);
  }
}

class PartitionUtils {
  static int? validateSize({
    required StoragePartitionInfo partition,
    int? targetSizeMiB,
    int? maxSizeMiB,
    String? targetMountpoint,
  }) {
    if (targetSizeMiB == null) return null;
    int lowerLimit = 1;
    int upperLimit = maxSizeMiB ?? partition.sizeMiB;
    if (targetMountpoint == kStorageMountpointBoot) {
      lowerLimit = 100;
    } else if (targetMountpoint == kStorageMountpointRoot) {
      lowerLimit = 40960;
    }
    if (upperLimit - 1 <= lowerLimit) {
      return null;
    }
    return targetSizeMiB.clamp(lowerLimit, partition.sizeMiB);
  }
}

extension StorageDeviceInfoExt on StorageDeviceInfo {
  StorageDeviceInfo copyWith({
    String? device,
    int? sizeMiB,
    List<StoragePartitionInfo>? partitions,
  }) {
    return StorageDeviceInfo(
      device: device ?? this.device,
      sizeMiB: sizeMiB ?? this.sizeMiB,
      partitions: partitions ?? this.partitions,
    );
  }
}

extension StoragePartitionInfoExt on StoragePartitionInfo {
  StoragePartitionInfo copyWith({
    String? device,
    StorageFilesystemType? filesystem,
    int? sizeMiB,
    String? mountPoint,
  }) {
    return StoragePartitionInfo(
      device: device ?? this.device,
      filesystem: filesystem ?? this.filesystem,
      sizeMiB: sizeMiB ?? this.sizeMiB,
      mountPoint: mountPoint ?? this.mountPoint,
    );
  }
}

extension StoragePartitionInfoListExt on List<StoragePartitionInfo> {
  List<StoragePartitionInfo> withoutMountpoints() {
    List<StoragePartitionInfo> list = [];
    for (final si in this) {
      list.add(si.copyWith(
        mountPoint: "",
      ));
    }
    return list;
  }
}

extension StorageInfoExt on StorageInfo {
  StorageInfo withoutMountpoints() {
    return StorageInfo(
      devices: devices.map(
        (k, v) => MapEntry(
          k,
          v.copyWith(partitions: v.partitions.withoutMountpoints()),
        ),
      ),
    );
  }
}