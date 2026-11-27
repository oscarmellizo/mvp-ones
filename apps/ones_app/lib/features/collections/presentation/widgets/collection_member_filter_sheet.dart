import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../domain/collection.dart';

typedef CollectionMembersPageLoader = Future<CollectionMembersPage> Function(
  String? nextToken,
  int limit,
);

class CollectionMemberFilterSheet extends StatefulWidget {
  final String collectionOwnerId;
  final String? currentUserId;
  final Set<String> initialSelectedIds;
  final CollectionMembersPageLoader loadMembersPage;
  final String title;
  final String ownerLabel;
  final String youLabel;
  final String emptyLabel;
  final String errorLabel;
  final String retryLabel;
  final String loadMoreLabel;
  final String selectionLimitLabel;
  final String clearLabel;
  final String cancelLabel;
  final String applyLabel;

  const CollectionMemberFilterSheet({
    super.key,
    required this.collectionOwnerId,
    required this.currentUserId,
    required this.initialSelectedIds,
    required this.loadMembersPage,
    required this.title,
    required this.ownerLabel,
    required this.youLabel,
    required this.emptyLabel,
    required this.errorLabel,
    required this.retryLabel,
    required this.loadMoreLabel,
    required this.selectionLimitLabel,
    required this.clearLabel,
    required this.cancelLabel,
    required this.applyLabel,
  });

  @override
  State<CollectionMemberFilterSheet> createState() =>
      _CollectionMemberFilterSheetState();
}

class _CollectionMemberFilterSheetState
    extends State<CollectionMemberFilterSheet> {
  static const _pageSize = 50;
  static const _maxSelectedMembers = 100;

  final Map<String, CollectionMember> _membersById = {};
  late final Set<String> _selectedIds = {...widget.initialSelectedIds};
  String? _nextToken;
  Object? _error;
  bool _loading = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPage(reset: true);
    });
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (_loading || (!reset && _loaded && _nextToken == null)) return;
    final cursor = reset ? null : _nextToken;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await widget.loadMembersPage(cursor, _pageSize);
      if (!mounted) return;
      setState(() {
        if (reset) _membersById.clear();
        for (final member in page.items) {
          final id = member.userId?.trim() ?? '';
          if (id.isEmpty ||
              id == widget.collectionOwnerId ||
              member.status.trim().toUpperCase() != 'ACCEPTED') {
            continue;
          }
          _membersById[id] = member;
        }
        _nextToken = page.nextToken;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMember(String userId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(userId);
      } else {
        _selectedIds.remove(userId);
      }
    });
  }

  Widget _memberTile({
    required String userId,
    required String title,
    String? subtitle,
  }) {
    final selected = _selectedIds.contains(userId);
    final canSelect = selected || _selectedIds.length < _maxSelectedMembers;
    return CheckboxListTile(
      value: selected,
      onChanged:
          canSelect ? (value) => _toggleMember(userId, value == true) : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      activeColor: OnesColors.purpleMid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerTitle = widget.collectionOwnerId == widget.currentUserId
        ? '${widget.youLabel} · ${widget.ownerLabel}'
        : widget.ownerLabel;
    final ownerId = widget.collectionOwnerId.trim();
    final ownerAlreadySelected = _selectedIds.contains(ownerId);
    final canSelectOwner =
        ownerAlreadySelected || _selectedIds.length < _maxSelectedMembers;
    final members = _membersById.values.toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          color: OnesColors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: widget.cancelLabel,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.selectionLimitLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                if (_loading && !_loaded)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        if (ownerId.isNotEmpty)
                          CheckboxListTile(
                            value: ownerAlreadySelected,
                            onChanged: canSelectOwner
                                ? (value) =>
                                    _toggleMember(ownerId, value == true)
                                : null,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(ownerTitle),
                            activeColor: OnesColors.purpleMid,
                          ),
                        ...members.map(
                          (member) => _memberTile(
                            userId: member.userId!.trim(),
                            title: member.email?.trim().isNotEmpty == true
                                ? member.email!.trim()
                                : member.userId!.trim(),
                          ),
                        ),
                        if (_loaded && members.isEmpty && _nextToken == null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              widget.emptyLabel,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  widget.errorLabel,
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => _loadPage(
                                            reset: !_loaded,
                                          ),
                                  child: Text(widget.retryLabel),
                                ),
                              ],
                            ),
                          ),
                        if (_loading && _loaded)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        if (!_loading && _nextToken != null)
                          Center(
                            child: TextButton(
                              onPressed: () => _loadPage(),
                              child: Text(widget.loadMoreLabel),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(<String>{}),
                        child: Text(widget.clearLabel),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_selectedIds),
                        child: Text(widget.applyLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
