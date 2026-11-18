import 'package:material_ui/material_ui.dart';

/// 设计规范（2026-11-18 视觉打磨）。
///
/// 原则：一只手、两秒钟看懂。颜色只表达三种含义，不做装饰：
/// - 主色（暖橙棕）：可以点的主要动作，如"开始"按钮、当前 Tab；
/// - 成功色（草绿）：完成、已掌握；
/// - 打卡色（琥珀）：连续打卡、徽章等激励信息。
/// 页面底色是暖白，卡片是纯白加一圈细描边，靠留白和字重区分层级，不再整屏铺浅杏色。
class AppColors {
  const AppColors._();

  static const primary = Color(0xFFC2581A); // 白字对比度 ≥ 4.5
  static const primaryDeep = Color(0xFF8F3E0F);
  static const primarySoft = Color(0xFFFCE9DA);
  static const success = Color(0xFF3E8E5A);
  static const successSoft = Color(0xFFE3F2E8);
  static const streak = Color(0xFFF2A12E);
  static const streakSoft = Color(0xFFFFF1D9);
  static const background = Color(0xFFFFF9F4);
  static const surface = Colors.white;
  static const outline = Color(0xFFEFE3D8);
  static const textPrimary = Color(0xFF2B1D14);
  static const textSecondary = Color(0xFF7A6658);
}

/// 间距与圆角：4 的倍数。
class AppSpace {
  const AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const page = 20.0; // 页面左右留白
  static const radius = 16.0; // 卡片
  static const radiusSm = 12.0; // 按钮、小卡片
}

/// 主题与通用文案工具。
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primaryDeep,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.successSoft,
      onSecondaryContainer: const Color(0xFF1F5233),
      tertiary: AppColors.streak,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: AppColors.streakSoft,
      onTertiaryContainer: const Color(0xFF6B4300),
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFFFF4EB),
      surfaceContainerHigh: const Color(0xFFFBEEE3),
      surfaceContainerHighest: const Color(0xFFF6E8DC),
      outline: const Color(0xFFD9C6B6),
      outlineVariant: AppColors.outline,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    final textTheme = text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpace.radiusSm));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: AppSpace.xs + 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.radius),
          side: const BorderSide(color: AppColors.outline),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 2),
        iconColor: AppColors.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: Color(0xFFE2CFC0)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape, textStyle: textTheme.labelLarge),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.primarySoft,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => textTheme.labelSmall?.copyWith(
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
            )),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.outline),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
        circularTrackColor: AppColors.primarySoft,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpace.radiusSm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// 周龄 → 文案："10 周（约 2 个半月）"
String ageWeeksLabel(int weeks) {
  final months = weeks / 4.345;
  final rounded = (months * 2).round() / 2;
  final monthText = rounded == rounded.truncate()
      ? '${rounded.truncate()} 个月'
      : '${rounded.truncate()} 个半月';
  return '$weeks 周（约 $monthText）';
}

/// typical_age_weeks [8, 24] → "常见于 2-6 月"
String typicalAgeLabel(List<int> weeks) {
  int toMonth(int w) => (w / 4.345).round().clamp(1, 24);
  return '常见于 ${toMonth(weeks[0])}-${toMonth(weeks[1])} 月';
}

String difficultyStars(int difficulty) => '★' * difficulty + '☆' * (5 - difficulty);
