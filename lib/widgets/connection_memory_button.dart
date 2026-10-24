import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/saved_connection.dart';
import '../providers/connections_provider.dart';
import '../theme/metcue_theme.dart';
import 'voice_capture_dialog.dart';

/// Memory capture always enriches the selected card, never creates a contact.
class ConnectionMemoryButton extends StatelessWidget {
  final SavedConnection connection;
  const ConnectionMemoryButton({super.key, required this.connection});

  @override
  Widget build(BuildContext context) {
    final hasMemory =
        connection.rawCue.trim().isNotEmpty ||
        connection.distinctiveMemory.trim().isNotEmpty ||
        connection.futureSelfNote.trim().isNotEmpty ||
        connection.cueConversation.any(
          (turn) => (turn['answer'] ?? '').trim().isNotEmpty,
        );
    return IconButton(
      tooltip: 'Add memory for ${connection.fullName}',
      icon: Badge(
        isLabelVisible: !hasMemory,
        smallSize: 6,
        backgroundColor: MetCueTheme.purple,
        child: const Icon(
          Icons.mic_none_rounded,
          color: MetCueTheme.purple,
          size: 21,
        ),
      ),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => VoiceCaptureDialog(
          guided: true,
          connection: connection,
          onCaptured: (updated) => context
              .read<ConnectionsProvider>()
              .updateConnection(updated, expectedVersion: connection.updatedAt),
        ),
      ),
    );
  }
}
