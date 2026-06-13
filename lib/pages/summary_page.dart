import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

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

class _SummaryPageWidget extends StatefulWidget {
  final int pageIndex;

  const _SummaryPageWidget({required this.pageIndex});

  @override
  State<_SummaryPageWidget> createState() => _SummaryPageWidgetState();
}

class _SummaryPageWidgetState extends State<_SummaryPageWidget> {
  late Future _createPlanFuture;

  @override
  void initState() {
    super.initState();
    final installProvider = context.read<InstallProvider>();
    installProvider.installPlan = installProvider.installPlan.copyWith(
      timezone: installProvider.service.currentTimezone,
      locale: installProvider.service.currentLocale,
      keyboardLayout: installProvider.service.currentKeyboardLayout,
    );
    _createPlanFuture = installProvider.createPlan();
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

  // TODO: Build full summary and validate before moving to next page.
  List<Widget> _buildSuccess() {
    List<Widget> widgets = [];
    final installProvider = context.watch<InstallProvider>();
    final scaling = Theme.of(context).scaling;
    if (installProvider.planWarnings.isNotEmpty) {
      widgets.add(const Text("Warnings:"));
      widgets.add(
        OutlinedContainer(
          padding: EdgeInsets.all(8 * scaling),
          child: Text(() {
            String res = "";
            for (int i = 0; i < installProvider.planWarnings.length; i++) {
              final warn = installProvider.planWarnings[i];
              res += "* $warn";
              if (i < installProvider.planWarnings.length - 1) {
                res += "\n";
              }
            }
            return res;
          }())
        ),
      );
      widgets.add(Gap(8 * scaling));
    }
    return widgets;
  }
}