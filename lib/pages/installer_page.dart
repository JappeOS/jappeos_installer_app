import 'package:shadcn_flutter/shadcn_flutter.dart';

abstract class InstallerPage {
  String title;
  List<Widget> widget(BuildContext context);
  InstallerPage(this.title);
}
