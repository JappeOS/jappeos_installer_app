import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class WifiPage extends InstallerPage {
  WifiPage() : super('WIFI');

  int wifiConnectRadioChoice = 0;

  @override
  List<Widget> widget(BuildContext context) {
    return [
      const Text("Connect to the internet").h3(),
      Gap(2 * Theme.of(context).scaling),
      const Text("Connecting this device to a WIFI network allows you to install third-party-software, download updates, automatically detect your timezone, and install full support for your language.").muted(),
      SizedBox(height: 8 * Theme.of(context).scaling),
      /*ListTile(
        title: const Text('Do not connect me to a WIFI network.'),
        leading: Radio(
          value: 0,
          groupValue: wifiConnectRadioChoice,
          onChanged: (value) {
            setState(() {
              wifiConnectRadioChoice = value as int;
            });
          },
        ),
      ),
      ListTile(
        title: const Text('Connect to this network:'),
        leading: Radio(
          value: 1,
          groupValue: wifiConnectRadioChoice,
          onChanged: (value) {
            setState(() {
              wifiConnectRadioChoice = value as int;
            });
          },
        ),
      ),*/
      const Expanded(child: Placeholder()),
    ];
  }
}
