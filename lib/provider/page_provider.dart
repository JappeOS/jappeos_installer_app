import 'dart:async';

import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Returns true if navigation should proceed (form valid / submitted),
/// false if navigation should be blocked.
typedef PageFormHandler = Future<bool> Function();

class PageProvider extends ChangeNotifier {
  static const Duration _kPageChangeDuration = Duration(milliseconds: 300);
  final PageController pageController = PageController();

  int _currentPage = 0;
  bool _allowBack = true;
  bool _allowAnyNavigation = true;
  bool _pageChanging = false;
  final Map<int, PageFormHandler> _formHandlers = {};

  int get currentPage => _currentPage;
  bool get allowBack => _allowBack;
  bool get allowAnyNavigation => _allowAnyNavigation;
  bool get pageChanging => _pageChanging;

  void registerFormHandler(int page, PageFormHandler handler) {
    _formHandlers[page] = handler;
  }

  void unregisterFormHandler(int page) {
    _formHandlers.remove(page);
  }

  bool currentPageHasForm() => _formHandlers.containsKey(_currentPage);

  Future<void> goToPage(int page, {bool runFormHandler = true}) async {
    if (!_allowAnyNavigation || _pageChanging) return;

    _pageChanging = true;
    notifyListeners();

    try {
      if (runFormHandler && page > _currentPage) {
        if (!await _runFormHandler(_currentPage)) {
          return;
        }
      }

      await pageController.animateToPage(
        page,
        duration: _kPageChangeDuration,
        curve: Curves.easeOutQuart,
      );

      _currentPage = page;
    } finally {
      _pageChanging = false;
      notifyListeners();
    }
  }

  Future<void> nextPage() => goToPage(_currentPage + 1);

  Future<void> previousPage() async {
    if (!_allowBack || !_allowAnyNavigation || _pageChanging) return;
    return goToPage(_currentPage - 1, runFormHandler: false);
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

  Future<bool> _runFormHandler(int page) async {
    final handler = _formHandlers[page];
    if (handler != null) {
      final canProceed = await handler();
      if (!canProceed) return false;
    }
    return true;
  }
}