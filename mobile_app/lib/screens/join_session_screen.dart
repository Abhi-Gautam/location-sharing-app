import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils.dart';
import '../core/constants.dart';
import '../providers/session_provider.dart';
import '../services/storage_service.dart';

/// Screen for joining an existing location sharing session
class JoinSessionScreen extends ConsumerStatefulWidget {
  const JoinSessionScreen({super.key});

  @override
  ConsumerState<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends ConsumerState<JoinSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sessionIdController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  String _selectedAvatarColor = AppConstants.defaultAvatarColor;
  bool _isJoining = false;
  
  @override
  void initState() {
    super.initState();
    _loadSavedDisplayName();
    _generateRandomColor();
  }

  @override
  void dispose() {
    _sessionIdController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedDisplayName() async {
    final storage = StorageService.instance;
    final savedName = await storage.getDisplayName();
    if (savedName != null && mounted) {
      _displayNameController.text = savedName;
    }
  }

  void _generateRandomColor() {
    _selectedAvatarColor = AppUtils.generateRandomAvatarColor();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Session'),
        actions: [
          TextButton(
            onPressed: _isJoining ? null : _joinSession,
            child: _isJoining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Join'),
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
                
                // Session ID Field
                _buildSessionIdField(),
                
                const SizedBox(height: 24),
                
                // Display Name Field
                _buildDisplayNameField(),
                
                const SizedBox(height: 24),
                
                // Avatar Color Selection
                _buildAvatarColorSelection(),
                
                const SizedBox(height: 32),
                
                // Join Button
                _buildJoinButton(),
                
                const SizedBox(height: 24),
                
                // Alternative Options
                _buildAlternativeOptions(),
                
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
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.group_add,
            size: 40,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Join Location Session',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the session details to start sharing your location',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSessionIdField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session ID or Link',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _sessionIdController,
          decoration: InputDecoration(
            hintText: 'Enter session ID or paste link',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: _pasteFromClipboard,
            ),
            helperText: 'Get this from the session creator',
          ),
          validator: (value) => _validateSessionId(value),
          enabled: !_isJoining,
          onChanged: _onSessionIdChanged,
        ),
      ],
    );
  }

  Widget _buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Display Name',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _displayNameController,
          decoration: InputDecoration(
            hintText: 'Enter your name',
            prefixIcon: const Icon(Icons.person),
            helperText: 'This is how others will see you',
          ),
          maxLength: AppConstants.maxDisplayNameLength,
          validator: (value) => AppUtils.validateDisplayName(value),
          enabled: !_isJoining,
        ),
      ],
    );
  }

  Widget _buildAvatarColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Avatar Color',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a color for your avatar',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            // Current color preview
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppUtils.hexToColor(_selectedAvatarColor),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  AppUtils.generateInitials(_displayNameController.text.isEmpty 
                      ? 'User' 
                      : _displayNameController.text),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppUtils.hexToColor(_selectedAvatarColor).contrastingColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Color grid
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.defaultAvatarColors.map((color) {
                  final isSelected = _selectedAvatarColor == color;
                  return GestureDetector(
                    onTap: _isJoining ? null : () {
                      setState(() {
                        _selectedAvatarColor = color;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppUtils.hexToColor(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: AppUtils.hexToColor(color).contrastingColor,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isJoining ? null : () {
            setState(() {
              _generateRandomColor();
            });
          },
          icon: const Icon(Icons.shuffle, size: 16),
          label: const Text('Random Color'),
        ),
      ],
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton(
      onPressed: _isJoining ? null : _joinSession,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isJoining
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
                  'Joining Session...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            )
          : Text(
              'Join Session',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildAlternativeOptions() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _isJoining ? null : _scanQRCode,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Code'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
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
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Joining a Session',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('• You\'ll be able to see other participants on the map'),
          _buildInfoItem('• Your location will be shared with all participants'),
          _buildInfoItem('• You can leave the session at any time'),
          _buildInfoItem('• Session data is not stored after the session ends'),
          const SizedBox(height: 8),
          Text(
            'Make sure you trust the session creator and other participants before sharing your location.',
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

  String? _validateSessionId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Session ID or link is required';
    }
    
    final sessionId = _extractSessionId(value.trim());
    if (sessionId == null) {
      return 'Invalid session ID or link format';
    }
    
    return null;
  }

  String? _extractSessionId(String input) {
    // Check if it's a direct session ID
    if (AppUtils.isValidSessionId(input)) {
      return input;
    }
    
    // Try to extract from link
    return AppUtils.extractSessionIdFromLink(input);
  }

  void _onSessionIdChanged(String value) {
    // Auto-extract session ID from links
    final sessionId = _extractSessionId(value);
    if (sessionId != null && sessionId != value) {
      _sessionIdController.text = sessionId;
      _sessionIdController.selection = TextSelection.fromPosition(
        TextPosition(offset: sessionId.length),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _sessionIdController.text = clipboardData!.text!;
        _onSessionIdChanged(clipboardData.text!);
      }
    } catch (e) {
      AppUtils.showErrorSnackbar(context, 'Failed to paste from clipboard');
    }
  }

  void _scanQRCode() {
    // TODO: Implement QR code scanning
    AppUtils.showInfoSnackbar(context, 'QR code scanning not implemented yet');
  }

  Future<void> _joinSession() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final sessionId = _extractSessionId(_sessionIdController.text.trim());
      if (sessionId == null) {
        throw Exception('Invalid session ID');
      }

      final sessionNotifier = ref.read(sessionProvider.notifier);
      
      await sessionNotifier.joinSession(
        sessionId: sessionId,
        displayName: _displayNameController.text.trim(),
        avatarColor: _selectedAvatarColor,
      );

      if (mounted) {
        // Navigate back to home (which will show the map)
        Navigator.of(context).pop();
        AppUtils.showSuccessSnackbar(context, 'Successfully joined session!');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to join session';
        
        if (e.toString().contains('not found')) {
          errorMessage = 'Session not found or has expired';
        } else if (e.toString().contains('full')) {
          errorMessage = 'Session is full';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied';
        }
        
        AppUtils.showErrorSnackbar(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }
}