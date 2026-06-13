import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:jappeos_installer/widgets/partition_list.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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
                return _buildCustom();
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

  Widget _buildCustom() {
    return const Placeholder();
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
      disk: InstallDiskInfo.manual(
        widget.selectedDevice!,
        _mounts.values.toList(),
      ),
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
            const Spacer(),
            Tooltip(
              tooltip: (_) => const TooltipContainer(child: Text("Set Mountpoint...")),
              child: IconButton.ghost(
                onPressed: _canSetMountpoint(_selectedPartition)
                    ? () => _setMountpoint(_selectedPartition!)
                    : null,
                icon: const Icon(Icons.edit),
              ),
            ),
            /*IconButton.ghost(
              onPressed: () {},
              icon: const Icon(Icons.add),
            ),
            IconButton.ghost(
              onPressed: () {},
              icon: const Icon(Icons.swap_horiz),
            ),
            IconButton.ghost(
              onPressed: () {},
              icon: const Icon(Icons.edit),
            ),
            IconButton.ghost(
              onPressed: () {},
              icon: const Icon(Icons.delete_forever),
            ),*/
          ],
        ),
        if (widget.selectedDevice != null) ...[
          PartitionView(
            device: devices[widget.selectedDevice]!,
            mounts: _mounts.map((k, v) => MapEntry(k, v.mountPoint)),
            selectedPartition: _selectedPartition?.device,
            onPartitionSelected: (v) => setState(() => _selectedPartition = v),
            onPartitionContextMenu: _buildMenuItems,
          ),
          Expanded(
            child: Row(
              spacing: 12 * scaling,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PartitionList(
                    device: devices[widget.selectedDevice]!,
                    mounts: _mounts.map((k, v) => MapEntry(k, v.mountPoint)),
                    selectedPartition: _selectedPartition?.device,
                    onPartitionSelected: (v) => setState(() => _selectedPartition = v),
                    onPartitionContextMenu: _buildMenuItems,
                  ),
                ),
                _buildOperationsList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOperationsList() {
    final scaling = Theme.of(context).scaling;
    Widget item(String text) => Text("* $text").italic();
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
            child: ListView(
              children: [
                for (final mnt in _mounts.entries) ...[
                  item("Mount ${mnt.value.partition} to ${mnt.value.mountPoint}"),
                  if (mnt.value.mountPoint == kStorageMountpointBoot)
                    item("Install boot files to ${mnt.value.partition}")
                  else if (mnt.value.mountPoint == kStorageMountpointRoot)
                    item("Install system files to ${mnt.value.partition}")
                  else
                    item("Install required JappeOS files to ${mnt.value.partition}")
                ],
              ],
            ),
          ),
        ],
      ),
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

  void _showErrorDialog() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      leading: const Icon(Icons.error),
      title: const Text("Error"),
      content: const Text("Make sure that there is exactly one boot partition and exactly one root partition."),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Aknowledge"),
        ),
      ],
    ),
  );

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