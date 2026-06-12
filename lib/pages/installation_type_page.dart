import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';

class InstallationTypePage extends InstallerPage {
  InstallationTypePage() : super('Installation Type');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const _InstallationTypePage()];
  }
}

class _InstallationTypePage extends StatefulWidget {
  const _InstallationTypePage();

  @override
  State<_InstallationTypePage> createState() => _InstallationTypePageState();
}

class _InstallationTypePageState extends State<_InstallationTypePage> {
  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final scaling = Theme.of(context).scaling;
    return RadioGroup(
      value: installProvider.selectedDiskInstallMode,
      onChanged: (v) => installProvider.selectedDiskInstallMode = v,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Installation Type").h3(),
          Gap(2 * scaling),
          const Text("Please select an installation type below.").muted(),
          Gap(8 * scaling),
          const RadioCard(
            value: InstallDiskMode.erase,
            child: Basic(
              title: Text('Erase'),
              content: Text('Erase an existing installation or empty hard drive completely, and install JappeOS.'),
            ),
          ),
          Gap(8 * scaling),
          const RadioCard(
            value: InstallDiskMode.manual,
            child: Basic(
              title: Text('Manual'),
              content: Text('If partitions are already set-up, pick mountpoints and install. This only overwrites selected partitions on the selected hard drive.'),
            ),
          ),
          Gap(8 * scaling),
          const RadioCard(
            value: InstallDiskMode.custom,
            child: Basic(
              title: Text('Custom'),
              content: Text('Edit partitions on a hard drive, then install JappeOS on the selected ones.'),
            ),
          ),
        ],
      ),
    );
  }
}