import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class InstallationTypePage extends InstallerPage {
  InstallationTypePage() : super('Installation Type');

  int installationTypeChoice = 0;
  bool encryptForSecurity = true;
  bool useLVM = false;

  @override
  List<Widget> widget(BuildContext context) {
    return [
      const Text("Installation Type").h3(),
      Gap(2 * Theme.of(context).scaling),
      const Text("This device currently has no detected operating systems, what would you like to do?"),
      /*ListTile(
        title: const Text('Erase disk and install JappeOS'),
        subtitle: const Row(children: [Text('Warning: ', style: TextStyle(color: Colors.red)), Text('this will delete any files on the disk.')]),
        leading: Radio(
          value: 0,
          groupValue: installationTypeChoice,
          onChanged: (value) {
            setState(() {
              installationTypeChoice = value as int;
            });
          },
        ),
      ),
      ListTile(
        enabled: installationTypeChoice == 0,
        title: const Text('Encrypt the new JappeOS installation for security'),
        subtitle: const Text('You will choose a security key in the next step.'),
        leading: Checkbox(
          value: encryptForSecurity,
          onChanged: installationTypeChoice == 0 ? (value) {
            setState(() {
              encryptForSecurity = value as bool;
            });
          } : null,
        ),
      ),
      ListTile(
        enabled: installationTypeChoice == 0,
        title: const Text('Use LVM with the new JappeOS installation.'),
        subtitle: const Text('This will set-up Logical Volume Management. It allows taking snapshots and easier partition resizing.'),
        leading: Checkbox(
          value: useLVM,
          onChanged: installationTypeChoice == 0 ? (value) {
            setState(() {
              useLVM = value as bool;
            });
          } : null,
        ),
      ),
      SizedBox(height: 32 * Theme.of(context).scaling),
      ListTile(
        title: const Text('Something else'),
        subtitle: const Text('You can create or resize partitions yourself, or choose multiple partitions for JappeOS.'),
        leading: Radio(
          value: 1,
          groupValue: installationTypeChoice,
          onChanged: (value) {
            setState(() {
              installationTypeChoice = value as int;
            });
          },
        ),
      ),*/
    ];
  }
}
