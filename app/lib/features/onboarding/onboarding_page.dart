import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../domain/models.dart';
import 'onboarding_controller.dart';
import 'step1_dog_info.dart';
import 'step2_concerns.dart';
import 'step3_owner.dart';

/// 三步建档容器（ON-1）。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  bool _submitting = false;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    // ON-6：从草稿恢复。
    Future.microtask(() async {
      await ref.read(onboardingControllerProvider.notifier).restoreDraft();
      if (mounted) setState(() => _restored = true);
    });
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      final planId =
          await ref.read(onboardingControllerProvider.notifier).complete();
      if (!mounted) return;
      context.go('/plan-preview/$planId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('建档失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final content = ref.watch(contentLibraryProvider);

    if (!_restored) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return content.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('内容库加载失败：$e'))),
      data: (lib) => _buildSteps(context, form, ctrl, lib),
    );
  }

  Widget _buildSteps(BuildContext context, OnboardingForm form,
      OnboardingController ctrl, ContentLibrary lib) {
    const titles = ['狗的基本信息', '当前困扰', '主人条件'];
    final step = form.step.clamp(0, 2);

    Widget body;
    bool canNext;
    switch (step) {
      case 0:
        body = const Step1DogInfo();
        canNext = form.step1Valid;
      case 1:
        body = Step2Concerns(issues: lib.issues);
        canNext = true;
      default:
        body = Step3Owner(skills: lib.skills);
        canNext = form.step3Valid;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('建档 ${step + 1}/3 · ${titles[step]}'),
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => ctrl.setStep(step - 1),
              )
            : null,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (step + 1) / 3),
          Expanded(child: body),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  // M4：只在尚未建档时出现（简报 5.2），加入后不走狗的建档。
                  if (step == 0)
                    TextButton.icon(
                      key: const Key('onboarding_join'),
                      onPressed: () => context.push('/join'),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('加入已有家庭'),
                    ),
                  if (step == 1)
                    TextButton(
                      key: const Key('onboarding_skip'),
                      onPressed: () => ctrl.setStep(2),
                      child: const Text('跳过'),
                    ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('onboarding_next'),
                    onPressed: !canNext || _submitting
                        ? null
                        : () {
                            if (step < 2) {
                              ctrl.setStep(step + 1);
                            } else {
                              _finish();
                            }
                          },
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(step < 2 ? '下一步' : '完成建档'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
