import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';
import '../routing/app_navigator.dart';
import '../routing/routes.dart';
import 'update_controller.dart';
import 'update_installer.dart';

class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  late final GoRouter _router;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _router = ref.read(goRouterProvider);
    _router.routerDelegate.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updateControllerProvider.notifier).checkOnLaunch();
    });
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateUiState>(updateControllerProvider, (_, next) {
      if (next.shouldPrompt) _showWhenAppIsReady();
    });
    return widget.child;
  }

  void _onRouteChanged() => _showWhenAppIsReady();

  /// The update check can finish while GoRouter is still on the boot route.
  /// Showing a root dialog then races the session redirect, which replaces that
  /// route and can remove the dialog. Wait until the first real destination is
  /// active; the route listener retries as soon as that redirect completes.
  void _showWhenAppIsReady() {
    if (!mounted || _dialogOpen) return;
    if (!ref.read(updateControllerProvider).shouldPrompt) return;
    if (_router.routerDelegate.currentConfiguration.uri.path == Routes.splash) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDialog();
    });
  }

  Future<void> _showDialog() async {
    if (!mounted || _dialogOpen) return;
    final update = ref.read(updateControllerProvider);
    if (!update.shouldPrompt) return;
    if (_router.routerDelegate.currentConfiguration.uri.path == Routes.splash) {
      return;
    }

    final navigator = appRootNavigatorKey.currentState;
    if (navigator == null || !navigator.mounted) return;

    _dialogOpen = true;
    ref.read(updateControllerProvider.notifier).markPrompted();
    try {
      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const _UpdateDialog(),
      );
    } finally {
      _dialogOpen = false;
    }
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final release = state.availability?.release;
    final controller = ref.read(updateControllerProvider.notifier);
    final installing = state.isInstalling;
    final failed = state.progress.phase == InstallPhase.failed;
    final completed = state.progress.phase == InstallPhase.completed;

    return PopScope(
      canPop: !state.mandatory && !installing,
      child: AlertDialog(
        title: Text(state.mandatory ? 'Update required' : 'Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bites Box ${release?.version ?? ''} is ready.'),
            if ((release?.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(release!.notes!, style: const TextStyle(height: 1.4)),
            ],
            if (installing || failed || completed) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: state.progress.phase == InstallPhase.downloading
                    ? state.progress.fraction
                    : null,
              ),
              const SizedBox(height: 8),
              Text(_progressLabel(state.progress)),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 10),
              Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          if (!state.mandatory && !installing)
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Later')),
          if (completed)
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))
          else if (!installing)
            FilledButton.icon(
              onPressed: controller.install,
              icon: const Icon(Icons.download_rounded),
              label: Text(failed ? 'Retry' : 'Update now'),
            )
          else
            const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Updating…')),
        ],
      ),
    );
  }

  String _progressLabel(UpdateProgress progress) => switch (progress.phase) {
        InstallPhase.preparing => 'Preparing download…',
        InstallPhase.downloading => progress.fraction == null
            ? 'Downloading…'
            : 'Downloading ${(progress.fraction! * 100).toStringAsFixed(0)}%',
        InstallPhase.verifying => 'Verifying download…',
        InstallPhase.installing => 'Opening Android installer…',
        InstallPhase.completed => 'Installer opened.',
        InstallPhase.failed => 'Update failed.',
        InstallPhase.idle => '',
      };
}
