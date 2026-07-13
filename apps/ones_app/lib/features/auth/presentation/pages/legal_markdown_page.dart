import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/ui/ones_colors.dart';

class LegalMarkdownPage extends StatefulWidget {
  final String title;
  final String assetPath;

  const LegalMarkdownPage({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<LegalMarkdownPage> createState() => _LegalMarkdownPageState();
}

class _LegalMarkdownPageState extends State<LegalMarkdownPage> {
  String _content = '';
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final content = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(
        backgroundColor: OnesColors.background,
        elevation: 0,
        foregroundColor: OnesColors.black,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error al cargar el documento: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: OnesColors.danger),
                    ),
                  )
                : Markdown(
                    data: _content,
                    padding: const EdgeInsets.all(20),
                    styleSheet: MarkdownStyleSheet(
                      h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: OnesColors.black,
                          ),
                      h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: OnesColors.black,
                          ),
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: OnesColors.black.withOpacity(0.85),
                            height: 1.4,
                          ),
                      listBullet: const TextStyle(color: OnesColors.black),
                    ),
                  ),
      ),
    );
  }
}
