/// 2026-11-18 视觉与情感化：打卡庆祝、奖牌徽章、狗狗照片头像、小狗空状态。
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:puppy_trainer/core/dog_avatar.dart';
import 'package:puppy_trainer/core/mascot.dart';
import 'package:puppy_trainer/core/theme.dart';
import 'package:puppy_trainer/domain/models.dart';
import 'package:puppy_trainer/features/record/checkin_celebration.dart';
import 'package:puppy_trainer/features/shell/badge_icons.dart';

void main() {
  testWidgets('打卡庆祝：按评分给标题、显示连续天数，点完成关闭', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showCheckinCelebration(c,
                  score: Score.full, streakDays: 3, skillName: '坐下', autoClose: const Duration(seconds: 30)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('checkin_celebration')), findsOneWidget);
    expect(find.text('太棒了！'), findsOneWidget);
    expect(find.text('已连续打卡 3 天'), findsOneWidget);
    await t.tap(find.byKey(const Key('checkin_celebration_done')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('checkin_celebration')), findsNothing);
  });

  testWidgets('打卡庆祝到时自动关闭', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => showCheckinCelebration(c,
              score: Score.none, streakDays: 1, skillName: '坐下', autoClose: const Duration(milliseconds: 800)),
          child: const Text('go'),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('坚持就有收获'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('checkin_celebration')), findsNothing);
  });

  testWidgets('奖牌徽章：未获得显示小锁，获得的不显示', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Row(children: [
        BadgeMedal(conditionType: 'streak_days', earned: true),
        BadgeMedal(conditionType: 'streak_days', earned: false),
      ]),
    ));
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('狗狗头像：没有照片显示爪印；从相册选了之后保存到本机并显示照片', (t) async {
    final dir = Directory.systemTemp.createTempSync('avatar_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/pick.jpg')..writeAsBytesSync(_png);
    final store = DogAvatarStore(() async => dir);
    await t.pumpWidget(ProviderScope(
      overrides: [
        dogAvatarStoreProvider.overrideWithValue(store),
        avatarPickerProvider.overrideWithValue(() async => src.path),
      ],
      child: const MaterialApp(home: Scaffold(body: DogAvatar(dogId: 'd1', editable: true))),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(find.byIcon(Icons.pets), findsOneWidget);
    await t.tap(find.byKey(const Key('dog_avatar_edit')));
    for (var i = 0; i < 40 && find.byIcon(Icons.pets).evaluate().isNotEmpty; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await t.pump();
    }
    expect(File('${dir.path}/avatars/d1.jpg').existsSync(), isTrue);
    expect(find.byIcon(Icons.pets), findsNothing);
  });

  testWidgets('空状态：小狗 + 标题 + 说明', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyState(title: '还没有训练记录', hint: '跟练一次'))));
    expect(find.byType(PuppyMascot), findsOneWidget);
    expect(find.text('还没有训练记录'), findsOneWidget);
    expect(find.text('跟练一次'), findsOneWidget);
  });
}

// 1x1 透明 PNG
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
