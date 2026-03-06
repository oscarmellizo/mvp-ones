import 'package:flutter/material.dart';

class PhotoViewerPage extends StatelessWidget {
  final String imageUrl;
  final String? sharedByName;
  final String? ownerName;

  const PhotoViewerPage({
    super.key,
    required this.imageUrl,
    this.sharedByName,
    this.ownerName,
  });

  @override
  Widget build(BuildContext context) {
    final sharedLabel = (sharedByName != null && sharedByName!.isNotEmpty)
        ? 'Compartida por $sharedByName'
        : (ownerName != null && ownerName!.isNotEmpty)
            ? '$ownerName'
            : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stack) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error cargando imagen: $error',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (sharedLabel != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Colors.black.withOpacity(0.55),
                  child: Text(
                    sharedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
