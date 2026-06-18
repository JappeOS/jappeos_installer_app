import 'package:shadcn_flutter/shadcn_flutter.dart';

abstract class InstallerPage {
  String title;
  String? nextButtonText;
  List<Widget> widget(BuildContext context, int index);
  InstallerPage(this.title, [this.nextButtonText]);
}
