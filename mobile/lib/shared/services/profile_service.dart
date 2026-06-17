import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';
import 'local_storage.dart';

class ProfileService {
  final LocalStorage _storage;

  ProfileService(this._storage);

  UserProfile getProfile() {
    final data = _storage.getUserProfile();
    if (data == null) return const UserProfile();
    return UserProfile.fromJson(data);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _storage.saveUserProfile(profile.toJson());
  }

  Future<void> updateField(String field, String value) async {
    final profile = getProfile();
    UserProfile updated;
    switch (field) {
      case 'fullName':
        updated = profile.copyWith(fullName: value);
      case 'workplace':
        updated = profile.copyWith(workplace: value);
      case 'homeLocation':
        updated = profile.copyWith(homeLocation: value);
      case 'workLocation':
        updated = profile.copyWith(workLocation: value);
      case 'role':
        updated = profile.copyWith(role: value);
      case 'goals':
        updated = profile.copyWith(goals: value);
      case 'healthGoals':
        updated = profile.copyWith(healthGoals: value);
      case 'wakeTime':
        updated = profile.copyWith(wakeTime: value);
      case 'sleepTime':
        updated = profile.copyWith(sleepTime: value);
      default:
        return;
    }
    await saveProfile(updated);
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  final storage = ref.read(localStorageProvider);
  return ProfileService(storage);
});

final userProfileProvider = Provider<UserProfile>((ref) {
  final service = ref.read(profileServiceProvider);
  return service.getProfile();
});
