import 'package:shadcn_flutter/shadcn_flutter.dart';

class PageTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final CrossAxisAlignment alignment;

  const PageTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final scaling = Theme.of(context).scaling;
    final textAlign = alignment == CrossAxisAlignment.center
        ? TextAlign.center
        : TextAlign.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          title,
          textAlign: textAlign,
        ).h3(),
        Gap(2 * scaling),
        Text(
          subtitle,
          textAlign: textAlign,
        ).muted(),
        Gap(8 * scaling),
        const Divider(),
        Gap(16 * scaling),
      ],
    );
  }
}