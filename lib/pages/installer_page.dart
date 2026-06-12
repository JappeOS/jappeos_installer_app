import 'package:shadcn_flutter/shadcn_flutter.dart';

abstract class InstallerPage {
  String title;
  List<Widget> widget(BuildContext context, int index);
  InstallerPage(this.title);
}
