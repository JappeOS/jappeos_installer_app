import 'package:jappeos_installer/pages/installer_page.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("Updates & Software").h3(),
        Gap(2 * scaling),
        const Text("Choose you preferred settings for installing software, or keep recommended settings.").muted(),
        Gap(8 * scaling),
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
    );
  }
}