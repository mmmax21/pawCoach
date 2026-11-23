/// 狗的状态（身体信号）的共用部件：判断卡片、转介卡片、节奏建议、"该停一停"提示。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/body/body_api.dart';
import '../../domain/body_signals.dart';
import 'body_strings.dart';

Color bodyStateColor(BodyState s) => switch (s) {
      BodyState.calm => AppColors.success,
      BodyState.excited => AppColors.streak,
      BodyState.stressed => AppColors.primary,
      BodyState.unclear => AppColors.textSecondary,
    };

IconData bodyStateIcon(BodyState s) => switch (s) {
      BodyState.calm => Icons.spa_outlined,
      BodyState.excited => Icons.bolt_outlined,
      BodyState.stressed => Icons.warning_amber_rounded,
      BodyState.unclear => Icons.help_outline,
    };

/// 一次判断：状态 + 内容库建议原文 + 观察到的信号（名称 / 次数 / 含义原文）+ 转介。
class BodyAssessmentCard extends StatelessWidget {
  const BodyAssessmentCard({
    super.key,
    required this.assessment,
    required this.config,
    this.isPhoto = false,
    this.showAdvice = true,
  });
  final BodyAssessment assessment;
  final BodySignalsConfig config;
  final bool isPhoto;
  final bool showAdvice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = assessment;
    final color = bodyStateColor(a.state);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('body_assessment'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(bodyStateIcon(a.state), color: color),
                  const SizedBox(width: 8),
                  Text(BodyStrings.stateName(a.state),
                      key: const Key('body_state'), style: t.titleMedium?.copyWith(color: color)),
                ]),
                if (showAdvice) ...[
                  const SizedBox(height: 8),
                  Text(config.advice[a.state]!, key: const Key('body_advice'), style: t.bodyMedium),
                ],
                if (a.state != BodyState.unclear) ...[
                  const SizedBox(height: 12),
                  Text(BodyStrings.observed, style: t.labelLarge),
                  if (a.evidence.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(BodyStrings.noSignals, style: t.bodySmall),
                    ),
                  for (final e in a.evidence.entries)
                    Padding(
                      key: Key('body_signal_${e.key}'),
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isPhoto ? config.signals[e.key]!.name : BodyStrings.signalCount(config.signals[e.key]!.name, e.value),
                              style: t.bodyMedium?.copyWith(
                                  color: config.signals[e.key]!.isStress ? AppColors.primary : AppColors.textPrimary)),
                          Text(config.signals[e.key]!.meaning,
                              style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                ],
                if (isPhoto) ...[
                  const SizedBox(height: 8),
                  Text(BodyStrings.photoNote, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 10),
                Text(BodyStrings.disclaimer, style: t.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        if (a.referral) ...[
          const SizedBox(height: 8),
          BodyReferralCard(text: config.referralAdvice),
        ],
      ],
    );
  }
}

class BodyReferralCard extends StatelessWidget {
  const BodyReferralCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      key: const Key('body_referral'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.support_agent),
            const SizedBox(width: 8),
            Text(BodyStrings.referralTitle, style: t.titleSmall),
          ]),
          const SizedBox(height: 6),
          Text(text),
        ]),
      ),
    );
  }
}

/// "该停一停了"提示（实时计时、视频结果）。
class BodyStopNotice extends StatelessWidget {
  const BodyStopNotice({super.key, required this.text, this.detail});
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('body_stop'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.streakSoft,
        borderRadius: BorderRadius.circular(AppSpace.radiusSm),
        border: Border.all(color: AppColors.streak.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pause_circle_outline, color: AppColors.streak),
          const SizedBox(width: 6),
          Text(BodyStrings.stopTitle, style: t.titleSmall),
        ]),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail!, style: t.bodySmall),
        ],
        const SizedBox(height: 4),
        Text(text, style: t.bodyMedium),
      ]),
    );
  }
}

/// 最近几次练前检查 → 训练节奏建议（内容库原文）。没有建议时不显示。
class BodyPacingTip extends ConsumerWidget {
  const BodyPacingTip({super.key, required this.dogId});
  final String dogId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(contentLibraryProvider).valueOrNull?.bodySignals;
    if (cfg == null) return const SizedBox.shrink();
    return StreamBuilder(
      stream: ref.watch(bodyRepositoryProvider).watchRecent(dogId, limit: cfg.pacingLookback * 2),
      builder: (context, snap) {
        final recs = snap.data ?? const [];
        final state = pacingState([for (final r in recs) r.state], cfg);
        if (state == null) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        return Card(
          key: const Key('body_pacing'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.tune, color: bodyStateColor(state)),
                const SizedBox(width: 8),
                Text(BodyStrings.pacingTitle, style: t.titleSmall),
              ]),
              const SizedBox(height: 6),
              Text(cfg.pacingAdvice[state]!, style: t.bodyMedium),
            ]),
          ),
        );
      },
    );
  }
}

/// 周报里的"狗的状态"：这一周各状态的检查次数、出现最多的信号（名称取内容库）。没有记录时不显示。
class BodyWeeklySection extends ConsumerWidget {
  const BodyWeeklySection({super.key, required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(contentLibraryProvider).valueOrNull?.bodySignals;
    final dog = ref.watch(currentDogProvider).valueOrNull;
    if (cfg == null || dog == null) return const SizedBox.shrink();
    final from = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return FutureBuilder(
      future: ref.read(bodyRepositoryProvider).between(dog.id, from, from.add(const Duration(days: 7))),
      builder: (context, snap) {
        final recs = snap.data ?? const [];
        if (recs.isEmpty) return const SizedBox.shrink();
        final t = Theme.of(context).textTheme;
        final byState = weeklyCounts([for (final r in recs) r.state]);
        final sig = <String, int>{};
        for (final r in recs) {
          for (final s in r.summary.signals) {
            if (cfg.signals.containsKey(s.id)) sig[s.id] = (sig[s.id] ?? 0) + 1;
          }
        }
        final top = sig.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final pace = pacingState([for (final r in recs.reversed) r.state], cfg);
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            key: const Key('report_body'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(BodyStrings.weeklyTitle, style: t.titleSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 12, children: [
                  for (final s in [BodyState.calm, BodyState.excited, BodyState.stressed])
                    if ((byState[s] ?? 0) > 0)
                      Text(BodyStrings.weeklyLine(s, byState[s]!),
                          style: t.bodyMedium?.copyWith(color: bodyStateColor(s))),
                ]),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(BodyStrings.observed, style: t.labelMedium),
                  for (final e in top.take(3))
                    Text(BodyStrings.signalCount(cfg.signals[e.key]!.name, e.value), style: t.bodySmall),
                ],
                if (pace != null) ...[
                  const SizedBox(height: 8),
                  Text(BodyStrings.pacingTitle, style: t.labelMedium),
                  Text(cfg.pacingAdvice[pace]!, style: t.bodySmall),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }
}
