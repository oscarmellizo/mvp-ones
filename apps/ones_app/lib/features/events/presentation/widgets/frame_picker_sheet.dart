import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../adapters/api/frames_api_repository.dart';
import '../frames_catalog_controller.dart';

class FramePickerSheet extends StatefulWidget {
  final List<String> initialSelectedFrameIds;

  const FramePickerSheet({
    super.key,
    required this.initialSelectedFrameIds,
  });

  static Future<List<String>?> open(
    BuildContext context, {
    required List<String> initialSelectedFrameIds,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangeNotifierProvider(
          create: (ctx) {
            final repo = ctx.read<FramesApiRepository>();
            final ctrl = FramesCatalogController(repository: repo);
            ctrl.refresh();
            return ctrl;
          },
          child: FramePickerSheet(initialSelectedFrameIds: initialSelectedFrameIds),
        );
      },
    );
  }

  @override
  State<FramePickerSheet> createState() => _FramePickerSheetState();
}

class _FramePickerSheetState extends State<FramePickerSheet> {
  late final ScrollController _scrollController;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelectedFrameIds.toSet();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final ctrl = context.read<FramesCatalogController>();
    if (!ctrl.hasMore || ctrl.loading) return;

    final pos = _scrollController.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return;

    const threshold = 400.0;
    if (pos.maxScrollExtent - pos.pixels <= threshold) {
      ctrl.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<FramesCatalogController>();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scroll) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Seleccionar marcos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${_selected.length} seleccionados',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: catalog.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error cargando marcos: ${catalog.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: catalog.refresh,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: catalog.items.length + 1,
                            itemBuilder: (context, index) {
                              if (index >= catalog.items.length) {
                                if (catalog.loading && catalog.items.isNotEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (!catalog.hasMore && catalog.items.isNotEmpty) {
                                  return const SizedBox(height: 12);
                                }
                                if (catalog.items.isEmpty && catalog.loading) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return const SizedBox(height: 12);
                              }

                              final item = catalog.items[index];
                              final isSelected = _selected.contains(item.frameId);
                              final title = (item.name != null && item.name!.trim().isNotEmpty)
                                  ? item.name!.trim()
                                  : item.frameId;

                              final previewUrl = item.verticalUrl ?? item.horizontalUrl;

                              return ListTile(
                                leading: previewUrl == null
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        color: Colors.black.withOpacity(0.05),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          previewUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, st) {
                                            return Container(
                                              width: 44,
                                              height: 44,
                                              color: Colors.black.withOpacity(0.05),
                                            );
                                          },
                                        ),
                                      ),
                                title: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  item.frameId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) {
                                        _selected.remove(item.frameId);
                                      } else {
                                        _selected.add(item.frameId);
                                      }
                                    });
                                  },
                                ),
                                onTap: () {
                                  setState(() {
                                    if (isSelected) {
                                      _selected.remove(item.frameId);
                                    } else {
                                      _selected.add(item.frameId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final out = _selected.toList(growable: false);
                            out.sort();
                            Navigator.of(context).pop(out);
                          },
                          child: const Text('Listo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
