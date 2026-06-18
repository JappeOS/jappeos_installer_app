import 'package:shadcn_flutter/shadcn_flutter.dart';

class CenteredPageContent extends StatelessWidget {
  final double spacing;
  final List<Widget> children;

  const CenteredPageContent({
    super.key,
    this.spacing = 0.0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: Theme.of(context).scaling * 410,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: children,
        ),
      ),
    );
  }
}