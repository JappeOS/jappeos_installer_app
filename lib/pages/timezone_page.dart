import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/timezone_map.dart';

class TimezonePage extends InstallerPage {
  TimezonePage() : super('Timezone');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const Expanded(child: _TimezonePageWidget())];
  }
}

class _TimezonePageWidget extends StatefulWidget {
  const _TimezonePageWidget();

  @override
  State<_TimezonePageWidget> createState() => _TimezonePageWidgetState();
}

class _TimezonePageWidgetState extends State<_TimezonePageWidget> {
  List<String> _timezones = [];
  final Map<String, List<String>> _regionMap = {};

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    String? currentTimezone;
    try {
      currentTimezone = installProvider.service.currentTimezone;
    } catch (e) {
      // Ignore, this can throw if the service isn't ready yet,
      // but it will be called again when it is.
    }

    final receivedTimezones = installProvider.localeInfo?.timezones ?? [];
    if (_timezones != receivedTimezones) {
      _timezones = receivedTimezones;
      _regionMap.clear();
      for (final tz in _timezones) {
        final index = tz.indexOf('/');

        if (index == -1) continue;

        final region = tz.substring(0, index);
        final zone = tz.substring(index + 1);

        _regionMap.putIfAbsent(region, () => []).add(zone);
      }
    }

    final index = currentTimezone?.indexOf('/');
    final currentRegion = currentTimezone?.substring(0, index);
    final currentZone = index == null
        ? null
        : currentTimezone?.substring(index + 1);

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
            selectedTimezone: currentTimezone,
            availableTimezones: _timezones,
            onTimezoneSelected: (tz) {
              installProvider.service.setCurrentTimezone(tz);
            },
          ),
        ),
        Gap(8 * scaling),
        Row(
          spacing: 16 * scaling,
          children: [
            const Text("Region"),
            Expanded(
              child: Select<String>(
                itemBuilder: (context, item) => Text(item),
                popup: SelectPopup.builder(
                  searchPlaceholder: const Text('Search regions'),
                  builder: (context, searchQuery) {
                    final filteredRegions = searchQuery == null
                        ? _regionMap.entries
                        : _regionMap.entries.where((entry)
                            => entry.key.toLowerCase().contains(
                                  searchQuery.toLowerCase().trim()));
                    return SelectItemList(
                      children: [
                        for (final entry in filteredRegions)
                          SelectItemButton(
                            value: entry.key,
                            child: Text(entry.key),
                          ),
                      ],
                    );
                  },
                ),
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  maxWidth: double.infinity,
                ),
                placeholder: const Text('Select a region'),
                value: currentRegion,
                onChanged: (value) {
                  installProvider.service.setCurrentTimezone("$value/$currentZone");
                },
              ),
            ),
            const Gap(0),
            const Text("Zone"),
            Expanded(
              child: Select<String>(
                itemBuilder: (context, item) => Text(item),
                popup: SelectPopup.builder(
                  searchPlaceholder: const Text('Search zones'),
                  builder: (context, searchQuery) {
                    final zones = _regionMap[currentRegion] ?? [];
                    final filteredZones = searchQuery == null
                        ? zones
                        : zones.where((entry)
                            => entry.toLowerCase().contains(
                                  searchQuery.toLowerCase().trim()));
                    return SelectItemList(
                      children: [
                        for (final entry in filteredZones)
                          SelectItemButton(
                            value: entry,
                            child: Text(entry),
                          ),
                      ],
                    );
                  },
                ),
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  maxWidth: double.infinity,
                ),
                placeholder: const Text('Select a zone'),
                value: currentZone,
                onChanged: (value) {
                  installProvider.service.setCurrentTimezone("$currentRegion/$value");
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
