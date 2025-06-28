import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import '../providers/session_provider.dart';
import '../models/session.dart';

/// Screen for creating a new location sharing session
class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sessionNameController = TextEditingController();
  
  int _selectedDuration = 24; // hours
  bool _isCreating = false;

  final List<int> _durationOptions = [1, 2, 4, 8, 12, 24, 48, 72]; // hours

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Session'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createSession,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(),
                
                const SizedBox(height: 32),
                
                // Session Name Field
                _buildSessionNameField(),
                
                const SizedBox(height: 24),
                
                // Duration Selection
                _buildDurationSelection(),
                
                const SizedBox(height: 32),
                
                // Session Preview
                _buildSessionPreview(),
                
                const SizedBox(height: 32),
                
                // Create Button
                _buildCreateButton(),
                
                const SizedBox(height: 16),
                
                // Info Section
                _buildInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_location,
            size: 40,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Create Location Session',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Set up a new session to share your location with others',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSessionNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Name (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _sessionNameController,
          decoration: InputDecoration(
            hintText: 'e.g., Weekend Trip, Family Gathering',
            prefixIcon: const Icon(Icons.label_outline),
            helperText: 'Give your session a memorable name',
          ),
          maxLength: AppConstants.maxSessionNameLength,
          validator: (value) => AppUtils.validateSessionName(value),
          enabled: !_isCreating,
        ),
      ],
    );
  }

  Widget _buildDurationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Duration',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'How long should the session remain active?',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durationOptions.map((hours) {
            final isSelected = _selectedDuration == hours;
            return FilterChip(
              label: Text(_formatDuration(hours)),
              selected: isSelected,
              onSelected: _isCreating ? null : (selected) {
                if (selected) {
                  setState(() {
                    _selectedDuration = hours;
                  });
                }
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatDuration(int hours) {
    if (hours < 24) {
      return '${hours}h';
    } else {
      final days = hours ~/ 24;
      return '${days}d';
    }
  }

  Widget _buildSessionPreview() {
    final sessionName = _sessionNameController.text.trim();
    final displayName = sessionName.isEmpty 
        ? 'Unnamed Session' 
        : sessionName;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Session Preview',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPreviewItem(
            'Name',
            displayName,
            Icons.label,
          ),
          _buildPreviewItem(
            'Duration',
            _formatDuration(_selectedDuration),
            Icons.schedule,
          ),
          _buildPreviewItem(
            'Expires',
            _getExpirationTime(),
            Icons.event,
          ),
          _buildPreviewItem(
            'Max Participants',
            '${AppConstants.maxParticipantsPerSession}',
            Icons.group,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon) {
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

  String _getExpirationTime() {
    final expirationTime = DateTime.now().add(Duration(hours: _selectedDuration));
    return AppUtils.formatDateTime(expirationTime);
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isCreating ? null : _createSession,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isCreating
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Creating Session...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            )
          : Text(
              'Create Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('1. Create your session with a custom name and duration'),
          _buildInfoItem('2. Share the join link or session ID with others'),
          _buildInfoItem('3. Everyone can see each other\'s real-time location'),
          _buildInfoItem('4. Session automatically expires after the set duration'),
          const SizedBox(height: 8),
          Text(
            'Privacy Note: Your location is only shared during active sessions and is not stored permanently.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final sessionNotifier = ref.read(sessionProvider.notifier);
      
      await sessionNotifier.createSession(
        name: _sessionNameController.text.trim().isEmpty 
            ? null 
            : _sessionNameController.text.trim(),
        expiresInMinutes: _selectedDuration * 60,
      );

      if (mounted) {
        // Show success dialog with session details
        _showSessionCreatedDialog();
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackbar(
          context, 
          'Failed to create session: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showSessionCreatedDialog() {
    final sessionState = ref.read(sessionProvider);
    final session = sessionState.session;
    
    if (session == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your location sharing session has been created successfully.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Details:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text('Name: ${session.displayName}'),
                  Text('ID: ${session.id}'),
                  Text('Expires: ${session.remainingTimeFormatted}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share the session ID with others so they can join.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: session.id));
              AppUtils.showSuccessSnackbar(context, 'Session ID copied!');
            },
            child: const Text('Copy ID'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to home
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}