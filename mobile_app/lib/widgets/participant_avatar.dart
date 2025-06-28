import 'package:flutter/material.dart';
import '../models/participant.dart';
import '../core/utils.dart';

/// Widget for displaying participant avatar with color and initials
class ParticipantAvatar extends StatelessWidget {
  final Participant participant;
  final double size;
  final bool showOnlineIndicator;
  final VoidCallback? onTap;

  const ParticipantAvatar({
    super.key,
    required this.participant,
    this.size = 40,
    this.showOnlineIndicator = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Avatar circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppUtils.hexToColor(participant.avatarColor),
              shape: BoxShape.circle,
              border: Border.all(
                color: participant.isOnline
                    ? Colors.green
                    : Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                participant.initials,
                style: TextStyle(
                  color: AppUtils.hexToColor(participant.avatarColor).contrastingColor,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Online indicator
          if (showOnlineIndicator && participant.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.25,
                height: size * 0.25,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget for displaying a list of participant avatars
class ParticipantAvatarList extends StatelessWidget {
  final List<Participant> participants;
  final double avatarSize;
  final double spacing;
  final int maxVisible;
  final VoidCallback? onMoreTap;

  const ParticipantAvatarList({
    super.key,
    required this.participants,
    this.avatarSize = 32,
    this.spacing = -8,
    this.maxVisible = 5,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleParticipants = participants.take(maxVisible).toList();
    final remainingCount = participants.length - visibleParticipants.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleParticipants.asMap().entries.map((entry) {
          final index = entry.key;
          final participant = entry.value;
          
          return Container(
            margin: EdgeInsets.only(left: index > 0 ? spacing : 0),
            child: ParticipantAvatar(
              participant: participant,
              size: avatarSize,
              showOnlineIndicator: true,
            ),
          );
        }),
        
        if (remainingCount > 0)
          GestureDetector(
            onTap: onMoreTap,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              margin: EdgeInsets.only(left: spacing),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: avatarSize * 0.3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget for creating a custom avatar with color picker
class AvatarEditor extends StatefulWidget {
  final String initialColor;
  final String initialName;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<String> onNameChanged;

  const AvatarEditor({
    super.key,
    required this.initialColor,
    required this.initialName,
    required this.onColorChanged,
    required this.onNameChanged,
  });

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  late String _selectedColor;
  late TextEditingController _nameController;

  final List<String> _availableColors = [
    '#FF5733', '#33A1FF', '#33FF57', '#FF33F1', '#FFD133',
    '#A133FF', '#33FFF1', '#FF8F33', '#8FFF33', '#3357FF',
    '#FF3333', '#33FF33', '#3333FF', '#FFFF33', '#FF33FF',
    '#33FFFF', '#808080', '#800000', '#008000', '#000080',
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Preview
        Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppUtils.hexToColor(_selectedColor),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  AppUtils.generateInitials(_nameController.text.isEmpty 
                      ? 'User' 
                      : _nameController.text),
                  style: TextStyle(
                    color: AppUtils.hexToColor(_selectedColor).contrastingColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  widget.onNameChanged(value);
                  setState(() {}); // Update preview
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Color picker
        Text(
          'Choose Avatar Color',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableColors.map((color) {
            final isSelected = _selectedColor == color;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
                widget.onColorChanged(color);
              },
              child: Container(
                width: 48,
                height: 48,
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
                        size: 24,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 16),
        
        // Random color button
        TextButton.icon(
          onPressed: () {
            final randomColor = AppUtils.generateRandomAvatarColor();
            setState(() {
              _selectedColor = randomColor;
            });
            widget.onColorChanged(randomColor);
          },
          icon: const Icon(Icons.shuffle),
          label: const Text('Random Color'),
        ),
      ],
    );
  }
}

/// Extension for participant avatar utilities
extension ParticipantAvatarExtension on Participant {
  /// Get contrast color for text on avatar
  Color get textColor {
    return AppUtils.hexToColor(avatarColor).contrastingColor;
  }

  /// Get avatar background color
  Color get backgroundColor {
    return AppUtils.hexToColor(avatarColor);
  }
}