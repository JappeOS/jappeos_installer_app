import 'package:jappeos_services/jappeos_services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class InstallProvider extends ChangeNotifier {
  final InstallerService service;

  InstallPlan _installPlan = InstallPlan(
    hostname: "",
    username: "",
    password: "",
    timezone: "",
    locale: "",
    keyboardLayout: ("", ""),
    disk: InstallDiskInfo.erase(""),
    installProprietary: true,
    installRecommendedDrivers: true,
  );

  InstallPlan get installPlan => _installPlan;

  set installPlan(InstallPlan val) {
    if (_installPlan != val) {
      _installPlan = val;
      notifyListeners();
    }
  }

  LocaleInfo? _localeInfo;
  StorageInfo? _storageInfo;
  List<String> _planWarnings = [];
  InstallDiskMode _selectedDiskInstallMode = InstallDiskMode.erase;
  int _latestPlanId = 0;

  LocaleInfo? get localeInfo => _localeInfo;
  StorageInfo? get storageInfo => _storageInfo;
  List<String> get planWarnings => _planWarnings;
  InstallDiskMode get selectedDiskInstallMode => _selectedDiskInstallMode;

  set selectedDiskInstallMode(InstallDiskMode mode) {
    if (_selectedDiskInstallMode != mode) {
      _selectedDiskInstallMode = mode;
      notifyListeners();
    }
  }

  InstallProvider(this.service) {
    service.addListener(_onChanged);
  }

  @override
  void dispose() {
    service.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> loadInitial() async {
    _localeInfo = await service.getLocaleInfo();
    _storageInfo = await service.getStorageInfo();
    notifyListeners();
  }

  Future<void> createPlan() async {
    _planWarnings.clear();
    if (_latestPlanId != 0) {
      await service.cancelInstallPlan(_latestPlanId);
    }
    final res = await service.createInstallPlan(_installPlan);
    _latestPlanId = res.planId;
    _planWarnings = res.warnings;
    notifyListeners();
  }

  Future<void> beginInstallation() async {
    if (_latestPlanId == 0) {
      throw Exception("No install plan created yet");
    }
    await service.beginInstallation(_latestPlanId);
  }

  void _onChanged() {
    notifyListeners();
  }
}