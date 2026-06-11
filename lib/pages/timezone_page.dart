import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/timezone_map.dart';

class TimezonePage extends InstallerPage {
  TimezonePage() : super('Timezone');

  @override
  List<Widget> widget(BuildContext context) {
    return [const Expanded(child: _TimezonePageWidget())];
  }
}

class _TimezonePageWidget extends StatefulWidget {
  const _TimezonePageWidget();

  @override
  State<_TimezonePageWidget> createState() => _TimezonePageWidgetState();
}

class _TimezonePageWidgetState extends State<_TimezonePageWidget> {
  final _regionKey = const SelectKey<String>('region');
  final _zoneKey = const SelectKey<String>('zone');
  String? _selectedTimezone;

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final timezones = installProvider.localeInfo?.timezones;
    final scaling = Theme.of(context).scaling;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Timezone Selection").h3(),
        Gap(2 * scaling),
        const Text("Please choose your timezone below.").muted(),
        Gap(8 * scaling),
        Expanded(
          child: TimezoneMap(
            selectedTimezone: _selectedTimezone,
            availableTimezones: timezones ?? [],
            onTimezoneSelected: (tz) {
              print("Selected timezone: $tz");
              setState(() {
                _selectedTimezone = tz;
              });
            },
          ),
        ),
        Gap(8 * scaling),
        Row(
          spacing: 16 * scaling,
          children: [
            Expanded(
              child: FormField<String>(
                key: _regionKey,
                label: const Text('Region'),
                child: Select<String>(
                  itemBuilder: (context, item) => Text(item),
                  popup: SelectPopup.builder(
                    searchPlaceholder: const Text('Search regions'),
                    builder: (context, searchQuery) {
                      return const SelectItemList(children: []);
                    },
                  ),
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    maxWidth: double.infinity,
                  ),
                ),
              ),
            ),
            Expanded(
              child: FormField<String>(
                key: _zoneKey,
                label: const Text('Zone'),
                child: Select<String>(
                  itemBuilder: (context, item) => Text(item),
                  popup: SelectPopup.builder(
                    searchPlaceholder: const Text('Search zones'),
                    builder: (context, searchQuery) {
                      return const SelectItemList(children: []);
                    },
                  ),
                  constraints: const BoxConstraints(
                    minWidth: double.infinity,
                    maxWidth: double.infinity,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
