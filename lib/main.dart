import 'package:jappeos_installer/pages/summary_page.dart';
import 'package:jappeos_installer/pages/user_setup_page.dart';
import 'package:jappeos_services/jappeos_services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

import 'pages/installation_type_page.dart';
import 'pages/installer_page.dart';
import 'pages/keyboard_layout_page.dart';
import 'pages/partitioning_page.dart';
import 'pages/timezone_page.dart';
import 'pages/updates_and_software_page.dart';
import 'pages/welcome_page.dart';
import 'provider/install_provider.dart';
import 'provider/page_provider.dart';

const kIsWindowedDesktopApp = true;

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return JappeosServiceProvider(
      child: ShadcnApp(
        builder: (context, child) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => InstallProvider(context.read<InstallerService>())),
            ChangeNotifierProvider(create: (_) => PageProvider()),
          ],
          child: child,
        ),
        debugShowCheckedModeBanner: false,
        theme: const ThemeData(
          colorScheme: ColorSchemes.lightBlue,
          radius: 0.5,
        ),
        home: const _RootWrapper(),
      ),
    );
  }
}

class SetupInfo {
  int language = 0;
  int keyboardLayout = 0;
}

class _AppMain extends StatefulWidget {
  const _AppMain();

  @override
  State<_AppMain> createState() => _AppMainState();
}

class _AppMainState extends State<_AppMain> {
  late final List<InstallerPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      WelcomePage(),
      KeyboardLayoutPage(),
      TimezonePage(),
      UserSetupPage(),
      UpdatesAndSoftwarePage(),
      //WifiPage(),
      InstallationTypePage(),
      PartitioningPage(),
      SummaryPage(),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<PageProvider>();

    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: nav.pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: nav.setCurrentPage,
            children: _pages
                .map((e) => Padding(
                  padding: EdgeInsets.all(16 * Theme.of(context).scaling),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: nav.currentPage == 0
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      ...e.widget(context, _pages.indexOf(e)),
                    ],
                  ),
                ))
                .toList(),
          ),
        ),
        SizedBox(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Gap(16 * Theme.of(context).scaling),
              SecondaryButton(
                onPressed: nav.currentPage > 0 &&
                    nav.allowBack &&
                    nav.allowAnyNavigation &&
                    !nav.pageChanging ? () => nav.previousPage() : null,
                child: const Text("Previous"),
              ),
              const Spacer(flex: 1),
              PrimaryButton(
                onPressed: nav.currentPage < _pages.length - 1 &&
                    nav.allowAnyNavigation &&
                    !nav.pageChanging ? () => nav.nextPage() : null,
                child: const Text("Next"),
              ),
              Gap(16 * Theme.of(context).scaling),
            ],
          ),
        ),
        Gap(16 * Theme.of(context).scaling),
      ]
    );
  }
}

class _RootWrapper extends StatelessWidget {
  const _RootWrapper();

  @override
  Widget build(BuildContext context) {
    final pad = 16 * Theme.of(context).scaling;
    return Scaffold(
      // headers: kIsWindowedDesktopApp ? [HeaderBar(title: currentPageTitle, isClosable: true, onClose: (p0) {}, isMaximizable: true, onMaximize: (p0) {}, isMinimizable: true, onMinimize: (p0) {}, isActive: true)] : [],
      backgroundColor: !kIsWindowedDesktopApp ? Colors.blue : null,
      child: kIsWindowedDesktopApp ? const _AppMain() : Stack(
        children: [
          Positioned.fill(
            top: pad,
            left: pad,
            bottom: pad,
            right: pad,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
                child: WidgetAnimator(
                  incomingEffect: WidgetTransitionEffects.incomingScaleUp(
                    curve: Curves.easeOutExpo,
                    opacity: 0,
                    delay: const Duration(seconds: 1),
                    duration: const Duration(seconds: 1),
                  ),
                  child: ModalContainer(
                    fillColor: Theme.of(context).colorScheme.background,
                    padding: EdgeInsets.zero,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(150),
                        offset: const Offset(0, 2),
                      ),
                    ],
                    borderRadius: Theme.of(context).borderRadiusXxl,
                    child: const _AppMain(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 1,
            bottom: 1,
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.done:
                    return Text("JappeOS Installer v.${snapshot.data!.version}");
                  default:
                    return const SizedBox();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
