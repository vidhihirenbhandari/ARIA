import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person_context.dart';
import '../services/local_storage.dart';

class PeopleNotifier extends StateNotifier<List<PersonContext>> {
  final LocalStorage _storage;
  static const _storageKey = 'people_list';

  PeopleNotifier(this._storage) : super([]) {
    loadFromStorage();
  }

  void loadFromStorage() {
    final raw = _storage.getList(_storageKey);
    if (raw.isEmpty) {
      // Seed with realistic example contacts on first load
      final now = DateTime.now();
      state = [
        PersonContext(
          id: '1',
          name: 'Raj Sharma',
          relationship: 'client',
          email: 'raj@example.com',
          phone: '+91 98765 43210',
          notes: 'Key client for the Q4 campaign. Very detail-oriented.',
          preferences: 'Prefers email over calls. Best time to reach: mornings before 11am.',
          lastContact: now.subtract(const Duration(days: 3)),
          followUpDate: now.add(const Duration(days: 2)),
          followUpNote: 'Follow up on the proposal sent last week',
          createdAt: now.subtract(const Duration(days: 30)),
        ),
        PersonContext(
          id: '2',
          name: 'Priya Mehta',
          relationship: 'colleague',
          email: 'priya@company.com',
          notes: 'Lead designer. Working together on the product relaunch.',
          preferences: 'Prefers Slack over email. No meetings before 10am.',
          lastContact: now.subtract(const Duration(days: 1)),
          createdAt: now.subtract(const Duration(days: 60)),
        ),
        PersonContext(
          id: '3',
          name: 'Arun Kumar',
          relationship: 'friend',
          phone: '+91 90000 11111',
          notes: 'Old college friend. Now runs a startup in Bangalore.',
          preferences: 'WhatsApp only. Evenings after 7pm.',
          lastContact: now.subtract(const Duration(days: 10)),
          followUpDate: now.subtract(const Duration(days: 3)),
          followUpNote: 'Catch up about his new startup',
          createdAt: now.subtract(const Duration(days: 90)),
        ),
      ];
      saveToStorage();
    } else {
      state = raw.map(PersonContext.fromJson).toList();
    }
  }

  Future<void> saveToStorage() async {
    await _storage.putList(_storageKey, state.map((p) => p.toJson()).toList());
  }

  Future<void> addPerson(PersonContext person) async {
    state = [...state, person];
    await saveToStorage();
  }

  Future<void> updatePerson(PersonContext updated) async {
    state = state.map((p) => p.id == updated.id ? updated : p).toList();
    await saveToStorage();
  }

  Future<void> deletePerson(String id) async {
    state = state.where((p) => p.id != id).toList();
    await saveToStorage();
  }
}

final peopleProvider =
    StateNotifierProvider<PeopleNotifier, List<PersonContext>>(
  (ref) => PeopleNotifier(ref.read(localStorageProvider)),
);
