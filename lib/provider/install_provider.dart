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
  StorageInfo? _storageInfo = StorageInfo(
    devices: {
      "/dev/sda": StorageDeviceInfo(
        device: "/dev/sda",
        sizeMiB: 488281,
        partitions: [
          StoragePartitionInfo(
            device: "/dev/sda1",
            filesystem: StorageFilesystemType.fat32,
            sizeMiB: 159,
            mountPoint: "/boot/efi",
          ),
          StoragePartitionInfo(
            device: "/dev/sda2",
            filesystem: StorageFilesystemType.ext4,
            sizeMiB: 488281 - 159 - 81380,
            mountPoint: "/",
          ),
          StoragePartitionInfo(
            device: "/dev/sda#free1",
            filesystem: StorageFilesystemType.freeSpace,
            sizeMiB: 81380,
            mountPoint: "",
          ),
        ],
      ),
    },
  );
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
    try {
      if (_latestPlanId != 0) {
        await service.cancelInstallPlan(_latestPlanId);
      }
      final res = await service.createInstallPlan(_installPlan);
      _latestPlanId = res.planId;
      _planWarnings = res.warnings;
    } finally {
      notifyListeners();
    }
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