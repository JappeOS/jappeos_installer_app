import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/page_loading_indicator.dart';

class PartitioningPage extends InstallerPage {
  PartitioningPage() : super('Partitioning');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const Expanded(child: _PartitioningPageWidget())];
  }
}

class _PartitioningPageWidget extends StatefulWidget {
  const _PartitioningPageWidget();

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
        const Text("Edit your partitions below.").muted(),
        Gap(8 * scaling),
        Expanded(
          child: () {
            switch (mode) {
              case InstallDiskMode.erase:
                return _buildErase(installProvider);
              case InstallDiskMode.manual:
                return _buildManual();
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
      onDeviceSelected: (p0) {
        if (installProvider.storageInfo?.devices.containsKey(p0) ?? false) {
          setState(() => _selectedDevice = p0);
        }
      },
    );
  }

  Widget _buildManual() {
    return const Placeholder();
  }

  Widget _buildCustom() {
    return const Placeholder();
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
        spacing: 8 * scaling,
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