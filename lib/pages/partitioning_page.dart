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

// TODO: Custom partitioning
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
  final String? selectedDevice;
  final void Function(String?) onDeviceSelected;

  const _ErasePage({
    required this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  State<_ErasePage> createState() => _ErasePageState();
}

class _ErasePageState extends State<_ErasePage> {
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
                    for (final dev in (devices.entries))
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
    if (installProvider.installPlan.disk.mode == InstallDiskMode.manual) {
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
        children: [
          Text("Set the mountpoint of ${widget.partition.device} (${widget.partition.sizeMiB} - ${widget.partition.filesystem.name})"),
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
  StoragePartitionInfo? _selectedPartition;
  final List<InstallDiskOperationInfo> _operations = [];
  late final List<StoragePartitionInfo> _appliedPartitions;

  @override
  void initState() {
    super.initState();

    final installProvider = context.read<InstallProvider>();
    _appliedPartitions
        = installProvider.storageInfo?.devices[widget.selectedDevice]?.partitions ?? [];
    if (installProvider.installPlan.disk.mode == InstallDiskMode.custom) {
      for (final op in installProvider.installPlan.disk.operations) {
        _operations.add(op);
      }
    }

    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.pageIndex, _handleSubmit);
  }

  Future<bool> _handleSubmit() async {
    bool bootFound = false;
    bool rootFound = false;
    bool duplicates = false;
    for (final op in _operations) {
      if (op.type != InstallDiskOperationType.setMountpoint) {
        continue;
      }

      final setMntOp = op as InstallDiskOperationSetMountpointInfo;
      if (setMntOp.mountPoint == kStorageMountpointBoot) {
        if (bootFound) duplicates = true;
        bootFound = true;
      }
      if (setMntOp.mountPoint == kStorageMountpointRoot) {
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
    //final installProvider = context.watch<InstallProvider>();
    return _PartitioningLayout(
      storageInfo: _createAppliedStorageInfo(),
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
    var currentDev = map[widget.selectedDevice];
    if (currentDev == null) return null;
    map[widget.selectedDevice!] = StorageDeviceInfo(
      device: currentDev.device,
      sizeMiB: currentDev.sizeMiB,
      partitions: _appliedPartitions,
    );
    return StorageInfo(devices: map);
  }

  Map<String, String> _getMountpoints() {
    Map<String, String> ret = {};
    for (final op in _operations) {
      if (op.type != InstallDiskOperationType.setMountpoint) {
        continue;
      }

      final setMntOp = op as InstallDiskOperationSetMountpointInfo;
      if (setMntOp.mountPoint == kStorageMountpointBoot ||
          setMntOp.mountPoint == kStorageMountpointRoot) {
        ret[setMntOp.partition] = setMntOp.mountPoint;
      }
    }
    return ret;
  }

  // TODO: Store local copy of disks and modify that instead, to avoid extra
  // weird code!!!
  StorageFilesystemType _getCurrentFilesystem(StoragePartitionInfo part) {
    StorageFilesystemType fs = part.filesystem;
    for (final op in _operations) {
      if (op.type != InstallDiskOperationType.setFilesystem) {
        continue;
      }

      final setFsOp = op as InstallDiskOperationSetFilesystemInfo;
      if (setFsOp.partition != part.device) {
        continue;
      }

      fs = setFsOp.filesystem;
    }
    return fs;
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
      if (v is! (int?, String?, StorageFilesystemType?)) return;
      if (v.$1 != null) {
        _createPart(part, v.$1!);
      }
      if (v.$2 != null) {
        _setPartMountpoint(part, v.$2!);
      }
      if (v.$3 != null) {
        _setPartFilesystem(part, v.$3!);
      }
    });
  }

  bool _canResize(StoragePartitionInfo? info) {
    if (info == null) return false;
    return !info.isFreeSpace() &&
        info.filesystem != StorageFilesystemType.unknown;
  }

  void _resize(StoragePartitionInfo part) {
    throw UnimplementedError();
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
    throw UnimplementedError();
  }

  void _createPart(StoragePartitionInfo part, int sizeMiB) {

  }

  void _setPartMountpoint(StoragePartitionInfo part, String mountpoint) {
    if (mountpoint != kStorageMountpointBoot &&
        mountpoint != kStorageMountpointRoot &&
        mountpoint != _kStorageMountpointNone) {return;}

    final mountOp = InstallDiskOperationSetMountpointInfo(
      partition: part.device,
      mountPoint: mountpoint,
    );

    final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );

    final existingOps = _operations.where(
      (op) => op is InstallDiskOperationSetMountpointInfo &&
      op.partition == part.device
    );

    for (final op in existingOps) {
      _operations.remove(op);
    }

    if (index == -1) {
      setState(() {});
      return;
    }

    if (mountpoint != _kStorageMountpointNone) {
      _operations.add(mountOp);
    }

    _appliedPartitions[index] = part.copyWith(
      mountPoint: mountpoint == _kStorageMountpointNone ? "" : mountpoint,
    );

    setState(() {});
  }

  void _setPartFilesystem(StoragePartitionInfo part, StorageFilesystemType fs) {
    if (fs != StorageFilesystemType.fat32 &&
        fs != StorageFilesystemType.ext4 &&
        fs != StorageFilesystemType.btrfs &&
        fs != StorageFilesystemType.xfs) {return;}

    final fsOp = InstallDiskOperationSetFilesystemInfo(
      partition: part.device,
      filesystem: fs,
    );

    final index = _appliedPartitions.indexWhere(
      (p) => p.device == part.device,
    );

    final existingOps = _operations.where(
      (op) => op is InstallDiskOperationSetFilesystemInfo &&
      op.partition == part.device
    );

    for (final op in existingOps) {
      _operations.remove(op);
    }

    if (index == -1) {
      setState(() {});
      return;
    }

    _operations.add(fsOp);
    _appliedPartitions[index] = part.copyWith(
      filesystem: fs,
    );

    setState(() {});
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
  String? _selectedMountpoint;
  late StorageFilesystemType _selectedFilesystem;

  @override
  void initState() {
    super.initState();
    _sizeMiB = widget.partition.sizeMiB;
    _selectedFilesystem = widget.partition.filesystem;
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
                    onEditingComplete: () => _validateTextField(),
                    onSubmitted: (_) => _validateTextField(),
                    placeholder: const Text('Provide a valid size'),
                    features: const [
                      InputFeature.spinner(),
                    ],
                    submitFormatters: [
                      TextInputFormatters.mathExpression(),
                    ],
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
                          _filesystemSelectItem(StorageFilesystemType.fat32),
                          _filesystemSelectItem(StorageFilesystemType.ext4),
                          _filesystemSelectItem(StorageFilesystemType.btrfs),
                          _filesystemSelectItem(StorageFilesystemType.xfs),
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
              _validateSize(_sizeMiB) != null
                  ? () => Navigator.pop(
                    context,
                    (
                      _validateSize(_sizeMiB),
                      _selectedMountpoint,
                      _selectedFilesystem,
                    ))
                  : null,
          child: const Text("Create"),
        ),
      ],
    );
  }

  SelectItemButton _filesystemSelectItem(StorageFilesystemType fs) =>
      SelectItemButton(
        value: fs,
        child: Text(fs.name),
      );

  void _validateTextField() {
    _sizeFieldController.text = _validateSize(int.tryParse(_sizeFieldController.text))?.toString() ?? "";
  }

  int? _validateSize(int? sizeMiB) {
    if (sizeMiB == null) return null;
    int lowerLimit = 1;
    int upperLimit = widget.partition.sizeMiB;
    if (_selectedMountpoint == kStorageMountpointBoot) {
      lowerLimit = 100;
    } else if (_selectedMountpoint == kStorageMountpointRoot) {
      lowerLimit = 40960;
    }
    if (upperLimit - 1 <= lowerLimit) {
      return null;
    }
    return sizeMiB.clamp(lowerLimit, widget.partition.sizeMiB);
  }
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
                          _filesystemSelectItem(StorageFilesystemType.fat32),
                          _filesystemSelectItem(StorageFilesystemType.ext4),
                          _filesystemSelectItem(StorageFilesystemType.btrfs),
                          _filesystemSelectItem(StorageFilesystemType.xfs),
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

  SelectItemButton _filesystemSelectItem(StorageFilesystemType fs) =>
      SelectItemButton(
        value: fs,
        child: Text(fs.name),
      );

  bool _filesystemChanged() => _selectedFilesystem != widget.partition.filesystem;
}

class _PartitioningLayout extends StatelessWidget {
  final StorageInfo? storageInfo;
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
                  child: PartitionList(
                    device: devices[selectedDevice]!,
                    mounts: mounts,
                    selectedPartition: selectedPartition?.device,
                    onPartitionSelected: onPartitionSelected,
                    onPartitionContextMenu: onPartitionContextMenu,
                  ),
                ),
                _buildOperationsList(context, storageInfo),
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
      width: 250,
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