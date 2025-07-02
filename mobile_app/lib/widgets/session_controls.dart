import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../models/participant.dart';
import '../providers/session_provider.dart';
import '../providers/location_provider.dart';

/// Widget containing session control buttons
class SessionControls extends ConsumerWidget {
  final VoidCallback? onLeaveSession;
  final VoidCallback? onEndSession;
  final VoidCallback? onToggleLocationSharing;

  const SessionControls({
    super.key,
    this.onLeaveSession,
    this.onEndSession,
    this.onToggleLocationSharing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);
    final locationState = ref.watch(locationProvider);

    return Column(
      children: [
        // Location sharing toggle
        FloatingActionButton(
          heroTag: 'location_toggle',
          mini: true,
          onPressed: onToggleLocationSharing,
          backgroundColor: locationState.isTracking
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          foregroundColor: locationState.isTracking
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          child: Icon(locationState.isTracking ? Icons.location_on : Icons.location_off),
        ),
        
        const SizedBox(height: 8),
        
        // Session menu
        FloatingActionButton(
          heroTag: 'session_menu',
          mini: true,
          onPressed: () => _showSessionMenu(context, sessionState),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          child: const Icon(Icons.more_vert),
        ),
      ],
    );
  }

  void _showSessionMenu(BuildContext context, SessionState sessionState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Options',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Session info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    'Name',
                    sessionState.sessionDisplayName,
                    Icons.label,
                  ),
                  _buildInfoRow(
                    context,
                    'Status',
                    _getStatusText(sessionState.status),
                    Icons.signal_cellular_alt,
                  ),
                  if (sessionState.session != null)
                    _buildInfoRow(
                      context,
                      'Expires',
                      sessionState.session!.remainingTimeFormatted,
                      Icons.schedule,
                    ),
                  _buildInfoRow(
                    context,
                    'Role',
                    sessionState.isCreator ? 'Creator' : 'Participant',
                    Icons.person,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            _buildActionButton(
              context,
              'Share Session',
              Icons.share,
              () => _shareSession(context, sessionState),
            ),
            
            const SizedBox(height: 8),
            
            _buildActionButton(
              context,
              'Session Details',
              Icons.info_outline,
              () => _showSessionDetails(context, sessionState),
            ),
            
            const SizedBox(height: 16),
            
            // Danger zone
            if (sessionState.isCreator) ...[
              _buildActionButton(
                context,
                'End Session',
                Icons.stop,
                () {
                  Navigator.of(context).pop();
                  onEndSession?.call();
                },
                isDestructive: true,
              ),
            ] else ...[
              _buildActionButton(
                context,
                'Leave Session',
                Icons.exit_to_app,
                () {
                  Navigator.of(context).pop();
                  onLeaveSession?.call();
                },
                isDestructive: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed, {
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          foregroundColor: isDestructive
              ? Theme.of(context).colorScheme.error
              : null,
          side: isDestructive
              ? BorderSide(color: Theme.of(context).colorScheme.error)
              : null,
        ),
      ),
    );
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.connected:
        return 'Connected';
      case SessionStatus.connecting:
        return 'Connecting';
      case SessionStatus.reconnecting:
        return 'Reconnecting';
      case SessionStatus.error:
        return 'Error';
      case SessionStatus.disconnected:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  void _shareSession(BuildContext context, SessionState sessionState) {
    if (sessionState.session == null) return;

    final session = sessionState.session!;
    final shareText = 'Join my location sharing session!\n\n'
        'Session: ${session.displayName}\n'
        'ID: ${session.id}\n\n'
        'Copy the ID to join the session.';

    // TODO: Implement proper sharing
    // For now, copy to clipboard
    Clipboard.setData(ClipboardData(text: shareText));
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session details copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSessionDetails(BuildContext context, SessionState sessionState) {
    Navigator.of(context).pop();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sessionState.session != null) ...[
              _buildDetailItem('Session ID', sessionState.session!.id),
              _buildDetailItem('Name', sessionState.session!.displayName),
              _buildDetailItem('Created', sessionState.session!.createdAt.toString()),
              _buildDetailItem('Expires', sessionState.session!.expiresAt.toString()),
              _buildDetailItem('Remaining', sessionState.session!.remainingTimeFormatted),
              _buildDetailItem('Active', sessionState.session!.isActive.toString()),
            ],
            _buildDetailItem('Status', _getStatusText(sessionState.status)),
            _buildDetailItem('Role', sessionState.isCreator ? 'Creator' : 'Participant'),
            _buildDetailItem('Participants', sessionState.participants.count.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Quick action button for common session controls
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FloatingActionButton(
        mini: true,
        heroTag: tooltip.toLowerCase().replaceAll(' ', '_'),
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
        foregroundColor: foregroundColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        child: Icon(icon),
      ),
    );
  }
}

/// Session status indicator widget
class SessionStatusIndicator extends ConsumerWidget {
  const SessionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(sessionState.status, context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(sessionState.status, context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(sessionState.status, context),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusText(sessionState.status),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getStatusColor(sessionState.status, context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SessionStatus status, BuildContext context) {
    switch (status) {
      case SessionStatus.connected:
        return Colors.green;
      case SessionStatus.connecting:
      case SessionStatus.reconnecting:
        return Colors.orange;
      case SessionStatus.error:
        return Theme.of(context).colorScheme.error;
      case SessionStatus.disconnected:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusText(SessionStatus status) {
    switch (status) {
      case SessionStatus.connected:
        return 'Connected';
      case SessionStatus.connecting:
        return 'Connecting';
      case SessionStatus.reconnecting:
        return 'Reconnecting';
      case SessionStatus.error:
        return 'Error';
      case SessionStatus.disconnected:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }
}