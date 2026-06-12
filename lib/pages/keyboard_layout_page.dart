import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/page_loading_indicator.dart';

class KeyboardLayoutPage extends InstallerPage {
  KeyboardLayoutPage() : super('Keyboard Layout');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const Expanded(child: _KeyboardLayoutPageWidget())];
  }
}

class _KeyboardLayoutPageWidget extends StatefulWidget {
  const _KeyboardLayoutPageWidget();

  @override
  State<_KeyboardLayoutPageWidget> createState() => _KeyboardLayoutPageWidgetState();
}

class _KeyboardLayoutPageWidgetState extends State<_KeyboardLayoutPageWidget> {
  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final keyboardLayouts = installProvider.localeInfo?.keyboardLayouts;
    (String, String)? currentKeyboardLayout;
    try {
      currentKeyboardLayout = installProvider.service.currentKeyboardLayout;
    } catch (e) {
      // Ignore, this can throw if the service isn't ready yet,
      // but it will be called again when it is.
    }

    final scaling = Theme.of(context).scaling;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Keyboard Layout Selection").h3(),
        Gap(2 * scaling),
        const Text("Please choose your keyboard layout below, and a variant on the right. You can also test your keyboard on the text field below.").muted(),
        Gap(8 * scaling),
        Expanded(child: keyboardLayouts == null
            ? const Center(child: PageLoadingIndicator())
            : _buildKeyboardLayoutPicker(
                context,
                keyboardLayouts,
                currentKeyboardLayout,
                (tuple) => installProvider.service.setCurrentKeyboardLayout(tuple)
            )),
        Gap(8 * scaling),
        const Divider(),
        Gap(8 * scaling),
        const TextField(hintText: "Test your keyboard here"),
      ],
    );
  }

  Widget _buildKeyboardLayoutPicker(
    BuildContext context,
    KeyboardLayoutInfo keyboardLayouts,
    (String, String)? currentKeyboardLayout,
    void Function((String, String)) onKeyboardLayoutSelected) {
    final sortedLayouts = keyboardLayouts.layouts.keys.toList()
      ..sort((a, b) => keyboardLayouts.layouts[a]!.compareTo(keyboardLayouts.layouts[b]!));

    final currentLayout = keyboardLayouts.layouts[currentKeyboardLayout?.$1];
    final currentVariants = currentLayout?.variants;
    var sortedCurrentVariants = currentVariants?.keys.toList()
      ?..sort((a, b) => a.compareTo(b));

    sortedCurrentVariants ??= [];

    final scaling = Theme.of(context).scaling;
    return Row(children: [
      Expanded(child: ListView.builder(
        itemCount: sortedLayouts.length,
        itemBuilder: (context, index) {
          final item = sortedLayouts[index];
          final layoutInfo = keyboardLayouts.layouts[item]!;
          return NavigationItem(
            selected: currentKeyboardLayout?.$1 == item,
            onChanged: (b) {
              if (!b) return;
              onKeyboardLayoutSelected((item, layoutInfo.variants.keys.first));
            },
            child: Text(layoutInfo.id),
          );
        },
      )),
      Gap(8 * scaling),
      const VerticalDivider(),
      Gap(8 * scaling),
      Expanded(child: ListView.builder(
        itemCount: sortedCurrentVariants.length,
        itemBuilder: (context, index) {
          final item = sortedCurrentVariants![index];
          return NavigationItem(
            selected: currentKeyboardLayout?.$2 == item,
            onChanged: (b) {
              if (!b || currentKeyboardLayout == null) return;
              onKeyboardLayoutSelected((currentKeyboardLayout.$1, item));
            },
            child: Text(currentVariants![item]!),
          );
        },
      )),
    ]);
  }
}

extension on KeyboardLayout {
  int compareTo(KeyboardLayout keyboardLayout) => keyboardLayout.id.compareTo(id);
}