import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/page_loading_indicator.dart';

class WelcomePage extends InstallerPage {
  WelcomePage() : super('Welcome');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const Expanded(child: _WelcomePageWidget())];
  }
}

class _WelcomePageWidget extends StatelessWidget {
  const _WelcomePageWidget();

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final locales = installProvider.localeInfo?.locales;
    String? currentLocale;
    try {
      currentLocale = installProvider.service.currentLocale;
    } catch (e) {
      // Ignore, this can throw if the service isn't ready yet,
      // but it will be called again when it is.
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Spacer(flex: 1),
        const Text("Welcome, please choose your language below:").h3(),
        SizedBox(height: 32 * Theme.of(context).scaling),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.border),
            borderRadius: BorderRadius.circular(16 * Theme.of(context).scaling),
          ),
          width: 400,
          height: 300,
          child: locales == null
              ? const Center(child: PageLoadingIndicator())
              : _buildLocaleList(
                  context,
                  locales,
                  currentLocale,
                  (locale) => installProvider.service.setCurrentLocale(locale)
              )),
        const Spacer(flex: 1),
      ],
    );
  }

  Widget _buildLocaleList(
    BuildContext context,
    Map<String, String> locales,
    String? currentLocale,
    void Function(String) onLocaleSelected,
  ) {
    final sortedLocales = locales.keys.toList()
      ..sort((a, b) => locales[a]!.compareTo(locales[b]!));
    return ListView.builder(
      padding: EdgeInsets.all(16 * Theme.of(context).scaling),
      itemCount: sortedLocales.length,
      itemBuilder: (context, index) {
        final item = sortedLocales[index];
        final displayName = locales[item] ?? item;

        return NavigationItem(
          selected: currentLocale == item,
          onChanged: (b) {
            if (!b) return;
            onLocaleSelected(item);
          },
          child: Text(displayName),
        );
      },
    );
  }
}