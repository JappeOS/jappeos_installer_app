import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

class PageProvider extends ChangeNotifier {
  static const Duration _kPageChangeDuration = Duration(milliseconds: 300);
  final PageController pageController = PageController();

  int _currentPage = 0;
  bool _allowBack = true;
  bool _allowAnyNavigation = true;
  bool _pageChanging = false;

  int get currentPage => _currentPage;
  bool get allowBack => _allowBack;
  bool get allowAnyNavigation => _allowAnyNavigation;
  bool get pageChanging => _pageChanging;

  Future<void> goToPage(int page) async {
    if (!_allowAnyNavigation || _pageChanging) return;

    _pageChanging = true;
    notifyListeners();

    await pageController.animateToPage(
      page,
      duration: _kPageChangeDuration,
      curve: Curves.easeOutQuart,
    );

    _currentPage = page;
    _pageChanging = false;
    notifyListeners();
  }

  Future<void> nextPage() => goToPage(_currentPage + 1);

  Future<void> previousPage() async {
    if (!_allowBack || !_allowAnyNavigation || _pageChanging) return;
    return goToPage(_currentPage - 1);
  }

  void setCurrentPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void setAllowBack(bool value) {
    _allowBack = value;
    notifyListeners();
  }

  void setAllowAnyNavigation(bool value) {
    _allowAnyNavigation = value;
    notifyListeners();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}