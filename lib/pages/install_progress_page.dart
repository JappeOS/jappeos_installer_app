import 'package:flutter/foundation.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../provider/install_provider.dart';
import '../provider/page_provider.dart';
import '../widgets/centered_page_content.dart';
import '../widgets/page_loading_indicator.dart';
import 'installer_page.dart';

class InstallProgressPage extends InstallerPage {
  InstallProgressPage() : super('Install Progress');

  @override
  List<Widget> widget(BuildContext context, int index) {
    return [Expanded(child: _InstallProgressPageWidget(pageIndex: index))];
  }
}

class _InstallProgressPageWidget extends StatefulWidget {
  final int pageIndex;

  const _InstallProgressPageWidget({required this.pageIndex});

  @override
  State<_InstallProgressPageWidget> createState() => _InstallProgressPageWidgetState();
}

class _InstallProgressPageWidgetState extends State<_InstallProgressPageWidget> {
  late PageProvider _pageProvider;
  Future? _beginInstallFuture;
  bool _canContinue = false;
  bool _rebootSystem = true;

  @override
  void initState() {
    super.initState();
    final installProvider = context.read<InstallProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _beginInstallFuture = installProvider.beginInstallation();
    });

    final nav = context.read<PageProvider>();
    nav.registerFormHandler(widget.pageIndex, _handleSubmit);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.setAllowAnyNavigation(false);
    });
  }

  Future<bool> _handleSubmit() async {
    bool cond = _canContinue;
    if (cond && !kDebugMode && _rebootSystem) {
      final powerManager = context.read<PowerManagerService>();
      try {
        await powerManager.reboot();
      } catch (e) {
        // Ignore for now
      }
    }
    return cond;
  }

  @override
  void didChangeDependencies() {
    _pageProvider = context.read<PageProvider>();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _pageProvider.unregisterFormHandler(widget.pageIndex);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final installProvider = context.watch<InstallProvider>();
    final installState = installProvider.service.state;
    final installProgress = installProvider.service.progress;
    final scaling = Theme.of(context).scaling;
    return FutureBuilder(
      future: _beginInstallFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: PageLoadingIndicator());
        }
        if (installState != InstallState.running &&
            installState != InstallState.idle) {
          _canContinue = true;
          context.read<PageProvider>().setAllowAnyNavigation(true);
        }
        return CenteredPageContent(
          spacing: 12 * scaling,
          children: [
            if (snapshot.hasError)
              ..._buildAsyncError(snapshot)
            else if (installState == InstallState.failed)
              ..._buildInstallError(installProvider.service.errorMessage)
            else if (installState == InstallState.cancelled)
              ..._buildInstallCanceled()
            else if (installState == InstallState.succeeded)
              ..._buildInstallComplete()
            else
              ..._buildInstallProgress(
                installState == InstallState.idle,
                installProgress,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildAsyncError(AsyncSnapshot snapshot) {
    return [
      Alert.destructive(
        leading: const Icon(Icons.error),
        title: const Text("Error!"),
        content: Text("Installation cannot begin: ${snapshot.error ?? "<empty>"}"),
      ),
    ];
  }

  List<Widget> _buildInstallError(String errorMessage) {
    return [
      Alert.destructive(
        leading: const Icon(Icons.error),
        title: const Text("Error!"),
        content: Text("Installation could not be completed: ${errorMessage.isEmpty ? "<empty>" : errorMessage}"),
      ),
    ];
  }

  List<Widget> _buildInstallCanceled() {
    return [
      const Text("Installation canceled."),
    ];
  }

  List<Widget> _buildInstallComplete() {
    return [
      const Text("Install complete!").x3Large(),
      const Text("Please remove the installation media (Disk or USB-drive) and restart to the newly installed OS."),
      const Text("If you choose to not restart now, you will remain in the live-environment and no files or changes will be saved on this computer.").muted().italic(),
      const Gap(0),
      Checkbox(
        state: _rebootSystem ? CheckboxState.checked : CheckboxState.unchecked,
        onChanged: (value) {
          setState(() {
            _rebootSystem = value == CheckboxState.checked;
          });
        },
        trailing: const Text('I have removed the installation media. Restart the PC now.'),
      ),
    ];
  }

  List<Widget> _buildInstallProgress(bool isIdle, InstallProgress progress) {
    return [
      Text(
        isIdle || progress.step.isEmpty ? "Installing..." : progress.step,
      ).x3Large(),
      Text(
        isIdle || progress.message.isEmpty
            ? "Waiting for installation to begin..."
            : progress.message,
      ),
      Progress(
        progress: isIdle ? null : progress.percentage.clamp(0, 1),
        min: 0,
        max: 1,
      ),
    ];
  }
}