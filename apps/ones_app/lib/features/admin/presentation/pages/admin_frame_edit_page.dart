import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../admin_frames_controller.dart';
import '../widgets/admin_gate.dart';

class AdminFrameEditPage extends StatefulWidget {
  final String frameId;
  const AdminFrameEditPage({super.key, required this.frameId});

  @override
  State<AdminFrameEditPage> createState() => _AdminFrameEditPageState();
}

class _AdminFrameEditPageState extends State<AdminFrameEditPage> {
  bool _loading = false;
  String? _verticalUrl;
  String? _horizontalUrl;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPreviewUrls();
  }

  Future<void> _loadPreviewUrls() async {
    final ctrl = context.read<AdminFramesController>();
    final repo = ctrl.repository;
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final vertical =
          await repo.getAssetUrl(frameId: widget.frameId, variant: 'vertical');
      final horizontal = await repo.getAssetUrl(
          frameId: widget.frameId, variant: 'horizontal');
      if (mounted) {
        setState(() {
          _verticalUrl = vertical;
          _horizontalUrl = horizontal;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickAndUpload(String variant) async {
    final ctrl = context.read<AdminFramesController>();
    final repo = ctrl.repository;
    final ctx = context;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (!ctx.mounted) return;
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No bytes available for selected file')),
      );
      return;
    }

    final ext = (file.extension ?? '').toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

    try {
      final presign = await repo.presignPutAsset(
        frameId: widget.frameId,
        contentType: contentType,
        variant: variant,
      );
      await repo.uploadBytesToPresignedUrl(
        putUrl: presign.putUrl,
        bytes: bytes,
        contentType: contentType,
      );
      await _loadPreviewUrls();

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
            content: Text(
                'Asset ${variant == 'vertical' ? 'vertical' : 'horizontal'} subido')),
      );
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        title: Text('Editar frame: ${widget.frameId}'),
      ),
      body: AdminGate(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Text(
                    'Error: $_error',
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.w700),
                  ),
                if (_loading) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _AssetSection(
                          title: 'Vertical',
                          url: _verticalUrl,
                          onTap: () => _pickAndUpload('vertical'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _AssetSection(
                          title: 'Horizontal',
                          url: _horizontalUrl,
                          onTap: () => _pickAndUpload('horizontal'),
                        ),
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

class _AssetSection extends StatelessWidget {
  final String title;
  final String? url;
  final VoidCallback onTap;

  const _AssetSection({
    required this.title,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: url != null
                ? Image.network(
                    url!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Center(child: Icon(Icons.broken_image)),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Sin imagen',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.upload_file),
            label: Text('Subir $title'),
            style: FilledButton.styleFrom(
              backgroundColor: OnesColors.purpleMid,
              foregroundColor: OnesColors.white,
            ),
          ),
        ),
      ],
    );
  }
}
