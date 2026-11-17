/// 底部 5 Tab（PRD 第 4 节，M4 简报第 3 节）：首页 / 技能树 / AI 教练 / 记录 / 我的。
library;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

enum AppTab { home, skillTree, coach, records, me }

const _routes = {
  AppTab.home: '/home',
  AppTab.skillTree: '/skills',
  AppTab.coach: '/coach',
  AppTab.records: '/records',
  AppTab.me: '/me',
};

String routeOfTab(AppTab t) => _routes[t]!;

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final AppTab current;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      key: const Key('app_bottom_nav'),
      selectedIndex: current.index,
      onDestinationSelected: (i) {
        final tab = AppTab.values[i];
        if (tab == current) return;
        context.go(routeOfTab(tab));
      },
      destinations: const [
        NavigationDestination(
          key: Key('nav_home'),
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: '首页',
        ),
        NavigationDestination(
          key: Key('nav_skills'),
          icon: Icon(Icons.account_tree_outlined),
          selectedIcon: Icon(Icons.account_tree),
          label: '技能树',
        ),
        NavigationDestination(
          key: Key('nav_coach'),
          icon: Icon(Icons.chat_bubble_outline),
          selectedIcon: Icon(Icons.chat_bubble),
          label: 'AI 教练',
        ),
        NavigationDestination(
          key: Key('nav_records'),
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: '记录',
        ),
        NavigationDestination(
          key: Key('nav_me'),
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: '我的',
        ),
      ],
    );
  }
}
