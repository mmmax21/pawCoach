/// 建档表单状态（Riverpod Notifier）。三步共用一个状态对象，
/// 每步修改时写一次草稿（ON-6）。
library;

import 'package:flutter/widgets.dart' show StringCharacters;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breeds.dart';
import '../../core/providers.dart';
import 'package:drift/drift.dart' show Value;

import '../../data/db/database.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/models.dart';

class OnboardingForm {
  const OnboardingForm({
    this.step = 0,
    this.dogName = '',
    required this.birthDate,
    this.breedId,
    this.sex,
    required this.homeDate,
    this.concerns = const [],
    this.dailyMinutes,
    this.trainerCount,
    this.livingEnv,
    this.masteredSkills = const {},
  });

  factory OnboardingForm.initial(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return OnboardingForm(
      birthDate: today.subtract(const Duration(days: 70)), // 默认 10 周前
      homeDate: today,
    );
  }

  final int step;
  final String dogName;
  final DateTime birthDate;
  final String? breedId;
  final Sex? sex;
  final DateTime homeDate;
  final List<String> concerns;
  final int? dailyMinutes;
  final int? trainerCount;
  final LivingEnv? livingEnv;
  final Set<String> masteredSkills;

  bool get step1Valid =>
      dogName.trim().isNotEmpty &&
      dogName.trim().characters.length <= 10 &&
      breedId != null &&
      sex != null;

  bool get step3Valid =>
      dailyMinutes != null && trainerCount != null && livingEnv != null;

  OnboardingForm copyWith({
    int? step,
    String? dogName,
    DateTime? birthDate,
    String? breedId,
    Sex? sex,
    DateTime? homeDate,
    List<String>? concerns,
    int? dailyMinutes,
    int? trainerCount,
    LivingEnv? livingEnv,
    Set<String>? masteredSkills,
  }) {
    return OnboardingForm(
      step: step ?? this.step,
      dogName: dogName ?? this.dogName,
      birthDate: birthDate ?? this.birthDate,
      breedId: breedId ?? this.breedId,
      sex: sex ?? this.sex,
      homeDate: homeDate ?? this.homeDate,
      concerns: concerns ?? this.concerns,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      trainerCount: trainerCount ?? this.trainerCount,
      livingEnv: livingEnv ?? this.livingEnv,
      masteredSkills: masteredSkills ?? this.masteredSkills,
    );
  }

  Map<String, Object?> toJson() => {
        'step': step,
        'dog_name': dogName,
        'birth_date': dateOnly(birthDate),
        'breed_id': breedId,
        'sex': sex == null ? null : sexToDb(sex!),
        'home_date': dateOnly(homeDate),
        'concerns': concerns,
        'daily_minutes': dailyMinutes,
        'trainer_count': trainerCount,
        'living_env': livingEnv == null ? null : envToDb(livingEnv!),
        'mastered_skills': masteredSkills.toList(),
      };

  static OnboardingForm fromJson(Map<String, Object?> j, DateTime now) {
    final base = OnboardingForm.initial(now);
    DateTime? d(String k) {
      final v = j[k];
      if (v is! String) return null;
      final p = parseDateOnly(v);
      return DateTime(p.year, p.month, p.day);
    }

    return base.copyWith(
      step: j['step'] as int? ?? 0,
      dogName: j['dog_name'] as String? ?? '',
      birthDate: d('birth_date'),
      breedId: j['breed_id'] as String?,
      sex: j['sex'] == null ? null : sexFromDb(j['sex'] as String),
      homeDate: d('home_date'),
      concerns: (j['concerns'] as List?)?.cast<String>() ?? const [],
      dailyMinutes: j['daily_minutes'] as int?,
      trainerCount: j['trainer_count'] as int?,
      livingEnv:
          j['living_env'] == null ? null : envFromDb(j['living_env'] as String),
      masteredSkills:
          (j['mastered_skills'] as List?)?.cast<String>().toSet() ?? const {},
    );
  }

  OnboardingResult toResult() {
    final breed = breedById(breedId!)!;
    return OnboardingResult(
      dogName: dogName.trim(),
      birthDate: birthDate,
      breedId: breed.id,
      breedText: breed.name,
      sex: sex!,
      homeDate: homeDate,
      concerns: concerns,
      dailyMinutes: dailyMinutes!,
      trainerCount: trainerCount!,
      livingEnv: livingEnv!,
      masteredSkills: masteredSkills,
    );
  }
}

class OnboardingController extends Notifier<OnboardingForm> {
  @override
  OnboardingForm build() => OnboardingForm.initial(DateTime.now());

  /// ON-6：从草稿恢复。
  Future<void> restoreDraft() async {
    final draft = await ref.read(onboardingRepositoryProvider).loadDraft();
    if (draft != null) {
      state = OnboardingForm.fromJson(draft, DateTime.now());
    }
  }

  void _update(OnboardingForm next) {
    state = next;
    // 草稿写入失败不阻塞 UI。
    ref.read(onboardingRepositoryProvider).saveDraft(next.toJson()).ignore();
  }

  void setStep(int step) => _update(state.copyWith(step: step));
  void setDogName(String v) => _update(state.copyWith(dogName: v));
  void setBirthDate(DateTime v) => _update(state.copyWith(birthDate: v));
  void setBreed(String id) => _update(state.copyWith(breedId: id));
  void setSex(Sex v) => _update(state.copyWith(sex: v));
  void setHomeDate(DateTime v) => _update(state.copyWith(homeDate: v));
  void setDailyMinutes(int v) => _update(state.copyWith(dailyMinutes: v));
  void setTrainerCount(int v) => _update(state.copyWith(trainerCount: v));
  void setLivingEnv(LivingEnv v) => _update(state.copyWith(livingEnv: v));

  /// 最多 3 项；超出时返回 false。
  bool toggleConcern(String issueId) {
    final list = List<String>.from(state.concerns);
    if (list.contains(issueId)) {
      list.remove(issueId);
    } else {
      if (list.length >= 3) return false;
      list.add(issueId);
    }
    _update(state.copyWith(concerns: list));
    return true;
  }

  void toggleMastered(String skillId) {
    final set = Set<String>.from(state.masteredSkills);
    if (!set.add(skillId)) set.remove(skillId);
    _update(state.copyWith(masteredSkills: set));
  }

  /// 写库并生成计划，返回 planId。
  Future<String> complete() async {
    final content = await ref.read(contentLibraryProvider.future);
    await ref.read(householdRepositoryProvider).ensureLocalUser();
    // M4：建档时填写一次昵称（简报 5.1），之后可在家庭成员页改。
    final nick = ref.read(onboardingNicknameProvider).trim();
    if (nick.isNotEmpty) {
      final db = ref.read(databaseProvider);
      await (db.update(db.users)..where((t) => t.id.equals(HouseholdRepository.localUserId)))
          .write(UsersCompanion(nickname: Value(nick)));
    }
    final r = await ref.read(onboardingRepositoryProvider).complete(
          form: state.toResult(),
          content: content,
        );
    return r.planId;
  }
}

/// 建档第三步填写的昵称（不进草稿）。
final onboardingNicknameProvider = StateProvider<String>((ref) => '');

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingForm>(
        OnboardingController.new);
