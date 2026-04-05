import 'package:flutter/material.dart';

class FrameMultiSelector extends StatefulWidget {
  final List<FrameOption> availableFrames;
  final List<String> selectedFrameIds;
  final ValueChanged<List<String>> onSelectionChanged;

  const FrameMultiSelector({
    super.key,
    required this.availableFrames,
    required this.selectedFrameIds,
    required this.onSelectionChanged,
  });

  @override
  State<FrameMultiSelector> createState() => _FrameMultiSelectorState();
}

class _FrameMultiSelectorState extends State<FrameMultiSelector> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedFrameIds);
  }

  void _toggleFrame(String frameId) {
    setState(() {
      if (_selectedIds.contains(frameId)) {
        _selectedIds.remove(frameId);
      } else {
        _selectedIds.add(frameId);
      }
    });
    widget.onSelectionChanged(_selectedIds.toList());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableFrames.isEmpty) {
      return const Center(
        child: Text('No frames available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Frames (${_selectedIds.length} selected)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableFrames.map((frame) {
            final isSelected = _selectedIds.contains(frame.id);
            return FilterChip(
              label: Text(frame.name),
              selected: isSelected,
              onSelected: (_) => _toggleFrame(frame.id),
              backgroundColor: Colors.grey.shade200,
              selectedColor: Colors.blue.shade100,
              checkmarkColor: Colors.blue.shade700,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class FrameOption {
  final String id;
  final String name;

  const FrameOption({
    required this.id,
    required this.name,
  });
}
