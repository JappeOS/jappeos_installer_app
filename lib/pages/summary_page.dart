import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../disk_operation_stringifier.dart';
import '../provider/install_provider.dart';
import '../widgets/page_loading_indicator.dart';
import 'installer_page.dart';

class SummaryPage extends InstallerPage {
  SummaryPage() : super('Summary');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [Expanded(child: _SummaryPageWidget(pageIndex: index))];
  }
}

// TODO: Validate before moving to next page.
class _SummaryPageWidget extends StatefulWidget {
  final int pageIndex;

  const _SummaryPageWidget({required this.pageIndex});

  @override
  State<_SummaryPageWidget> createState() => _SummaryPageWidgetState();
}

class _SummaryPageWidgetState extends State<_SummaryPageWidget> {
  Future? _createPlanFuture;

  @override
  void initState() {
    super.initState();
    final installProvider = context.read<InstallProvider>();

    String? currentTimezone;
    String? currentLocale;
    (String, String)? currentKeyboardLayout;
    try {
      currentTimezone = installProvider.service.currentTimezone;
      currentLocale = installProvider.service.currentLocale;
      currentKeyboardLayout = installProvider.service.currentKeyboardLayout;
    } catch (e) {
      // Ignore, this can throw if the service isn't ready yet,
      // but it will be called again when it is.
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      installProvider.installPlan = installProvider.installPlan.copyWith(
        timezone: currentTimezone,
        locale: currentLocale,
        keyboardLayout: currentKeyboardLayout,
      );
      _createPlanFuture = installProvider.createPlan();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    return FutureBuilder(
      future: _createPlanFuture,
      builder: (context, snaphsot) {
        if (snaphsot.connectionState != ConnectionState.done) {
          return const Center(child: PageLoadingIndicator());
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Summary").h3(),
            Gap(2 * scaling),
            const Text("Here's a summary of your choices. You can not go back and change them after this step.").muted(),
            Gap(8 * scaling),
            if (snaphsot.hasError)
              ..._buildError(snaphsot)
            else
              ..._buildSuccess(),
          ],
        );
      },
    );
  }

  List<Widget> _buildError(AsyncSnapshot snapshot) {
    return [
      Alert.destructive(
        leading: const Icon(Icons.error),
        title: const Text("Error!"),
        content: Text("Installation cannot proceed: ${snapshot.error ?? "<empty>"}"),
      ),
    ];
  }

  List<Widget> _buildSuccess() {
    List<Widget> widgets = [];
    final installProvider = context.watch<InstallProvider>();
    final scaling = Theme.of(context).scaling;

    void title(String text) {
      widgets.add(Gap(8 * scaling));
      widgets.add(Text(text));
    }

    void container(Widget child) {
      widgets.add(
        OutlinedContainer(
          padding: EdgeInsets.all(8 * scaling),
          child: child,
        ),
      );
    }

    if (installProvider.planWarnings.isNotEmpty) {
      title("Warnings:");
      container(
        Text(() {
          String res = "";
          for (int i = 0; i < installProvider.planWarnings.length; i++) {
            final warn = installProvider.planWarnings[i];
            res += "* $warn";
            if (i < installProvider.planWarnings.length - 1) {
              res += "\n";
            }
          }
          return res;
        }()),
      );
    }

    String? currentTimezone;
    String? currentLocale;
    (String, String)? currentKeyboardLayout;
    try {
      currentTimezone = installProvider.service.currentTimezone;
      currentLocale = installProvider.service.currentLocale;
      currentKeyboardLayout = installProvider.service.currentKeyboardLayout;
    } catch (e) {
      // Ignore, this can throw if the service isn't ready yet,
      // but it will be called again when it is.
    }

    title("Localization:");
    container(
      Text("Timezone: $currentTimezone\nLocale: $currentLocale\nKeyboard Layout: ${currentKeyboardLayout?.$2}"),
    );

    title("User and this PC:");
    container(
      Text("Username: ${installProvider.installPlan.username}\nHostname: ${installProvider.installPlan.hostname}"),
    );

    title("Software:");
    container(
      Text("Install recommended proprietary software: ${installProvider.installPlan.installProprietary}\nInstall recommended drivers automatically: ${installProvider.installPlan.installRecommendedDrivers}"),
    );

    title("Install target and storage operations:");
    container(
      installProvider.storageInfo != null ? Text(stringifyDiskOperations(
        installProvider.storageInfo!,
        installProvider.installPlan.disk,
      )) : const Text("..."),
    );

    return widgets;
  }
}