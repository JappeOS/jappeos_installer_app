import 'package:shadcn_flutter/shadcn_flutter.dart';

class PageLoadingIndicator extends StatelessWidget {
  const PageLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      size: 64,
    );
  }
}