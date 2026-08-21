import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_controller.dart';
import 'update_installer.dart';

class UpdateGate extends ConsumerStatefulWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> {
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(updateControllerProvider.notifier).checkOnLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateUiState>(updateControllerProvider, (_, next) {
      if (next.shouldPrompt && !_dialogOpen) _showDialog();
    });
    return widget.child;
  }

  Future<void> _showDialog() async {
    _dialogOpen = true;
    ref.read(updateControllerProvider.notifier).markPrompted();
    await showDialog<void>(
      context: context,
      barrierDismissible: !ref.read(updateControllerProvider).mandatory,
      builder: (_) => const _UpdateDialog(),
    );
    _dialogOpen = false;
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
