/// drift 表定义。字段与 docs/data-model.md 对应，snake_case 列名。
/// 时间统一存 UTC ISO 8601 文本。
library;

import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// 内容库（整体存 JSON 列，M1 简报第 5 节）
// ---------------------------------------------------------------------------

class ContentVersions extends Table {
  TextColumn get version => text()();
  TextColumn get loadedAt => text()();
  @override
  Set<Column> get primaryKey => {version};
}

class ContentSkills extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ContentIssues extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ContentBadges extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ContentCareItems extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

/// M3：AI 词表（ai_guard / ai_terms），id 为文件名去扩展名，整份存 JSON。
class ContentAiLexicons extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// M4：同步字段（简报第 5.3、6 节）
// ---------------------------------------------------------------------------

/// 所有同步表都带 client_updated_at（ISO 8601 UTC 毫秒）与 deleted（软删除）。
/// 本地写入时由 SQLite 触发器自动填 client_updated_at 并入发件箱（database.dart）。
mixin SyncColumns on Table {
  TextColumn get clientUpdatedAt => text().withDefault(const Constant(''))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}

// ---------------------------------------------------------------------------
// 账号与家庭
// ---------------------------------------------------------------------------

class Users extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get phoneOrEmail => text().nullable()();
  TextColumn get nickname => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class Households extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get creatorUserId => text()();
  TextColumn get inviteCode => text().nullable()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class HouseholdMembers extends Table with SyncColumns {
  TextColumn get householdId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text()(); // creator | member
  TextColumn get joinedAt => text()();
  @override
  Set<Column> get primaryKey => {householdId, userId};
}

// ---------------------------------------------------------------------------
// 狗与档案
// ---------------------------------------------------------------------------

class Dogs extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get householdId => text()();
  TextColumn get name => text()();
  TextColumn get birthDate => text()(); // yyyy-MM-dd
  TextColumn get breedId => text()();
  TextColumn get breedText => text()();
  TextColumn get sex => text()(); // male | female
  TextColumn get homeDate => text()(); // yyyy-MM-dd
  TextColumn get livingEnv => text()(); // apartment | house_with_yard
  IntColumn get dailyMinutes => integer()();
  IntColumn get trainerCount => integer()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();

  /// M4：建档时勾选"已经会"的技能（JSON 数组），随狗同步。
  /// DogSkillStatus 不同步，加入家庭的设备靠它 + 周报判定 + 训练记录本地重算掌握状态。
  TextColumn get initialMastered => text().withDefault(const Constant('[]'))();
  @override
  Set<Column> get primaryKey => {id};
}

class DogConcerns extends Table with SyncColumns {
  TextColumn get dogId => text()();
  TextColumn get issueId => text()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {dogId, issueId};
}

class DogCues extends Table with SyncColumns {
  TextColumn get dogId => text()();
  TextColumn get skillId => text()();
  TextColumn get cueWord => text()();
  TextColumn get gestureText => text()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {dogId, skillId};
}

class DogSkillStatuses extends Table {
  TextColumn get dogId => text()();
  TextColumn get skillId => text()();
  TextColumn get status => text()(); // locked | available | in_progress | mastered
  TextColumn get masteredAt => text().nullable()();
  IntColumn get fullSuccessCount => integer().withDefault(const Constant(0))();
  IntColumn get failCount => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {dogId, skillId};
}

// ---------------------------------------------------------------------------
// 计划
// ---------------------------------------------------------------------------

class WeeklyPlans extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get dogId => text()();
  TextColumn get weekStart => text()(); // yyyy-MM-dd，周一
  TextColumn get generatedBy => text()(); // system | user
  TextColumn get status => text()(); // active | completed
  TextColumn get createdAt => text()();

  /// M2 起：ON-7 在本周已有记录时改了出生日期 / 困扰 / 每日时长，
  /// 下周生成走"全新生成"而不是 WP-6 调整。
  BoolColumn get regenerateNext =>
      boolean().withDefault(const Constant(false))();

  /// M3 起：诊断方案"加入下周计划"的技能 ID，JSON 数组。
  /// 生成下周计划时优先放入（source = ai_diagnosis），见 nextWeekPlan()。
  TextColumn get pendingDiagnosisSkills =>
      text().withDefault(const Constant('[]'))();
  @override
  Set<Column> get primaryKey => {id};

  /// 同一只狗同一周只能有一份计划（M2 简报第 14 节）。
  @override
  List<Set<Column>> get uniqueKeys => [
        {dogId, weekStart},
      ];
}

class PlanGoals extends Table with SyncColumns {
  TextColumn get planId => text()();
  TextColumn get skillId => text()();
  IntColumn get position => integer()();
  IntColumn get targetSessions => integer()();
  IntColumn get completedSessions => integer().withDefault(const Constant(0))();
  TextColumn get source => text()();
  @override
  Set<Column> get primaryKey => {planId, skillId};
}

class DailyMiniTasks extends Table with SyncColumns {
  TextColumn get planId => text()();
  TextColumn get skillId => text()();
  IntColumn get scriptPart => integer()();
  @override
  Set<Column> get primaryKey => {planId};
}

// ---------------------------------------------------------------------------
// 建档断点（ON-6，P1）
// ---------------------------------------------------------------------------

class OnboardingDrafts extends Table {
  IntColumn get id => integer()(); // 恒为 1
  TextColumn get json => text()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// M2：训练记录、连续打卡、周报
// ---------------------------------------------------------------------------

class TrainingSessions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get dogId => text()();
  TextColumn get userId => text()();
  TextColumn get skillId => text()();

  /// 0 表示 mini_script；≥1 为正式脚本的 part。
  IntColumn get scriptPart => integer()();
  TextColumn get startedAt => text()(); // UTC ISO 8601
  TextColumn get endedAt => text()();
  IntColumn get durationSec => integer()();

  /// full | partial | none。记录页选定评分后才写库（跟练中途退出不写、不打卡）。
  TextColumn get score => text()();
  TextColumn get noteText => text().nullable()();
  TextColumn get noteVideoUrl => text().nullable()();

  /// 被跳过的步骤编号（ScriptStep.step），JSON 数组。
  TextColumn get skippedSteps => text().withDefault(const Constant('[]'))();
  IntColumn get clickerCount => integer().withDefault(const Constant(0))();
  TextColumn get syncedAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Streaks extends Table {
  TextColumn get dogId => text()();
  IntColumn get currentDays => integer().withDefault(const Constant(0))();
  IntColumn get longestDays => integer().withDefault(const Constant(0))();
  TextColumn get lastCheckinDate => text().nullable()(); // yyyy-MM-dd，本地日期
  @override
  Set<Column> get primaryKey => {dogId};
}

class WeeklyReports extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get dogId => text()();
  TextColumn get planId => text()();
  TextColumn get summaryJson => text()();
  TextColumn get aiComment => text()();
  TextColumn get nextPlanId => text().nullable()();
  TextColumn get createdAt => text()();

  /// 首页"上周周报已生成"入口用；数据模型文档没有这一列，M2 新增。
  TextColumn get readAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};

  /// 以 plan_id 去重：同一份计划只能有一份周报。
  @override
  List<Set<Column>> get uniqueKeys => [
        {planId},
      ];
}

// ---------------------------------------------------------------------------
// M3：AI 教练、诊断结果、提醒
// ---------------------------------------------------------------------------

class AiConversations extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get dogId => text()();
  TextColumn get type => text()(); // course_qa | diagnosis
  TextColumn get skillId => text().nullable()();
  TextColumn get issueId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class AiMessages extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get role => text()(); // user | assistant | system
  TextColumn get content => text()();

  /// 引用的内容 ID，JSON 数组。
  TextColumn get citedContentIds => text().withDefault(const Constant('[]'))();

  /// normal | guard_health | guard_no_hit | diagnosis_q | diagnosis_result
  TextColumn get kind => text()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class DiagnosisResults extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get dogId => text()();
  TextColumn get issueId => text()();
  TextColumn get resultKey => text()();

  /// JSON 数组。
  TextColumn get solutionSkillIds => text()();

  /// 加入本周计划时为该计划 id；加入下周或未加入为 null。
  TextColumn get addedToPlanId => text().nullable()();

  /// M4（FM-5）：做诊断的成员。M3 旧记录为空。
  TextColumn get userId => text().nullable()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class ReminderSettings extends Table {
  TextColumn get dogId => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get hour => integer().withDefault(const Constant(19))();
  IntColumn get minute => integer().withDefault(const Constant(0))();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {dogId};
}


// ---------------------------------------------------------------------------
// M4：养护、徽章（同步）
// ---------------------------------------------------------------------------

class CareReminders extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get dogId => text()();

  /// care_calendar.yaml 的条目 id；用户手动新增为空。
  TextColumn get templateId => text().nullable()();

  /// vaccine | deworm_internal | deworm_external
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get dueDate => text()(); // yyyy-MM-dd
  TextColumn get doneAt => text().nullable()();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();

  /// default | user（用户改过日期的默认条目也视为 user，修改出生日期时不动）
  TextColumn get source => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class DogBadges extends Table with SyncColumns {
  TextColumn get dogId => text()();
  TextColumn get badgeId => text()();
  TextColumn get earnedAt => text()();
  TextColumn get earnedByUserId => text()();
  @override
  Set<Column> get primaryKey => {dogId, badgeId};
}

// ---------------------------------------------------------------------------
// M4：本地账号与同步状态（不同步）
// ---------------------------------------------------------------------------

class LocalAccounts extends Table {
  IntColumn get id => integer()(); // 恒为 1
  TextColumn get userId => text()();
  TextColumn get token => text()();
  TextColumn get createdAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class SyncStates extends Table {
  TextColumn get householdId => text()();
  IntColumn get lastPullSeq => integer().withDefault(const Constant(0))();
  TextColumn get lastPushAt => text().nullable()();
  @override
  Set<Column> get primaryKey => {householdId};
}

/// 待推送的本地变更：(表名, 主键) 去重，version 每次本地写入 +1。
/// 推送成功后只删除 version 未变的条目（推送期间又改过的留到下一轮）。
class SyncOutbox extends Table {
  TextColumn get tbl => text().named('table_name')();
  TextColumn get pk => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(0))();

  /// 最近一次本地变更时刻（ISO 8601 UTC 毫秒）；墓碑上行时作为 client_updated_at。
  TextColumn get changedAt => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {tbl, pk};
}

/// 单行开关：applying = 1 时触发器不记录（应用下行数据、本地重算派生字段时用）。
class SyncFlags extends Table {
  IntColumn get id => integer()(); // 恒为 1
  BoolColumn get applying => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// 本机已弹过祝贺的徽章（同一徽章同一设备只弹一次）。
class BadgePopupsSeen extends Table {
  TextColumn get dogId => text()();
  TextColumn get badgeId => text()();
  TextColumn get seenAt => text()();
  @override
  Set<Column> get primaryKey => {dogId, badgeId};
}

/// M5（PRD AI-4）：视频纠错结果，本机保存、不同步。只存数字与判定，不存视频。
/// metrics_json = VideoMetrics.toJson；findings_json = [VideoFinding.toJson]（检测器、mistake 下标、证据数字）。
class VideoAnalyses extends Table {
  TextColumn get id => text()();
  TextColumn get dogId => text()();
  TextColumn get skillId => text()();
  TextColumn get createdAt => text()(); // ISO 8601 UTC
  TextColumn get status => text()(); // ok | retake
  TextColumn get metricsJson => text()();
  TextColumn get findingsJson => text()();
  TextColumn get contentVersion => text()();
  @override
  Set<Column> get primaryKey => {id};
}
