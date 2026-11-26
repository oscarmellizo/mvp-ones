import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../collections_controller.dart';

class CollectionJoinLinkPage extends StatefulWidget {
  final String collectionId;
  final String token;

  const CollectionJoinLinkPage({
    super.key,
    required this.collectionId,
    required this.token,
  });

  @override
  State<CollectionJoinLinkPage> createState() => _CollectionJoinLinkPageState();
}

class _CollectionJoinLinkPageState extends State<CollectionJoinLinkPage> {
  bool _loading = true;
  String _message = 'Uniéndote a la colección…';
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _message = 'Uniéndote a la colección…';
    });
    try {
      await context.read<CollectionsController>().joinByQr(
            collectionId: widget.collectionId,
            token: widget.token,
          );
      if (!mounted) return;
      setState(() {
        _joined = true;
        _message = 'Ya formas parte de esta colección.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _joined = false;
        _message = error.response?.statusCode == 404 ||
                error.response?.statusCode == 409
            ? 'Este QR ya no está activo o la colección alcanzó su límite.'
            : 'No pudimos completar la unión. Inténtalo de nuevo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _joined = false;
        _message = 'No pudimos completar la unión. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.surfaceWarm,
      appBar: AppBar(title: const Text('Unirse a una colección')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                Icon(
                  _joined ? Icons.check_circle_outline : Icons.info_outline,
                  size: 58,
                  color: _joined ? OnesColors.green : OnesColors.purpleMid,
                ),
              const SizedBox(height: 16),
              Text(_message, textAlign: TextAlign.center),
              if (!_loading && !_joined) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _join,
                  child: const Text('Intentar de nuevo'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
