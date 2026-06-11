import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class UpdatesAndSoftwarePage extends InstallerPage {
  UpdatesAndSoftwarePage() : super('Updates & Software');

  int installationTypeChoice = 0;
  bool installUpdatesNow = true;

  @override
  List<Widget> widget(BuildContext context) {
    return [
      const Text("Updates & Software").h3(),
      Gap(2 * Theme.of(context).scaling),
      /*ListTile(
        title: const Text('Minimal Installation'),
        subtitle: const Text('Web browser and system utilities.'),
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
        title: const Text('Normal Installation'),
        subtitle: const Text('Web browser, system utilities, media players, office apps...'),
        leading: Radio(
          value: 1,
          groupValue: installationTypeChoice,
          onChanged: (value) {
            setState(() {
              installationTypeChoice = value as int;
            });
          },
        ),
      ),
      Text("Updates", style: Theme.of(context).textTheme.titleLarge),
      ListTile(
        title: const Text('Install Updates While Installing JappeOS'),
        subtitle: const Text('This saves time after installation.'),
        leading: Checkbox(
          value: installUpdatesNow,
          onChanged: (value) {
            setState(() {
              installUpdatesNow = value as bool;
            });
          },
        ),
      ),*/
      //const Expanded(child: Placeholder()),
    ];
  }
}
