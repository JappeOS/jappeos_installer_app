import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../widgets/centered_page_content.dart';
import '../widgets/page_title.dart';
import 'installer_page.dart';

class UpdatesAndSoftwarePage extends InstallerPage {
  UpdatesAndSoftwarePage() : super('Updates & Software');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [const _UpdatesAndSoftwarePageWidget()];
  }
}

class _UpdatesAndSoftwarePageWidget extends StatelessWidget {
  const _UpdatesAndSoftwarePageWidget();

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final installProprietary = installProvider.installPlan.installProprietary;
    final installRecommendedDrivers = installProvider.installPlan.installRecommendedDrivers;
    final scaling = Theme.of(context).scaling;
    return Expanded(
      child: CenteredPageContent(
        children: [
          const PageTitle(
            title: "Updates & Software",
            subtitle: "Choose your preferred settings for installing software, or keep recommended settings.",
            alignment: CrossAxisAlignment.center,
          ),
          Checkbox(
            state: installProprietary
                ? CheckboxState.checked
                : CheckboxState.unchecked,
            onChanged: (s) => installProvider.installPlan
                = installProvider.installPlan.copyWith(
              installProprietary: s == CheckboxState.checked,
            ),
            trailing: const Text('Install recommended proprietary software'),
          ),
          Gap(8 * scaling),
          Checkbox(
            state: installRecommendedDrivers
                ? CheckboxState.checked
                : CheckboxState.unchecked,
            onChanged: (s) => installProvider.installPlan
                = installProvider.installPlan.copyWith(
              installRecommendedDrivers: s == CheckboxState.checked,
            ),
            trailing: const Text('Install recommended drivers automatically'),
          ),
        ],
      ),
    );
  }
}