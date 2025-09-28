import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/save.dart';
import '../services/analytics_service.dart';
import '../services/page_builder_service.dart';

class PageBuilderDetailScreen extends StatefulWidget {
  final Save save;

  const PageBuilderDetailScreen({
    super.key,
    required this.save,
  });

  @override
  State<PageBuilderDetailScreen> createState() =>
      _PageBuilderDetailScreenState();
}

class _PageBuilderDetailScreenState extends State<PageBuilderDetailScreen> {
  List<PagePreview>? _previews;
  bool _isLoading = false;
  String _currentProgress = '';
  int _selectedPageIndex = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('page_builder_detail');
    _buildPages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Build Pages - ${widget.save.name}'),
        actions: [
          if (_previews != null && _previews!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareCurrentPage,
              tooltip: 'Share Page',
            ),
          if (_previews != null && _previews!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _saveCurrentPage,
              tooltip: 'Save Page',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_currentProgress),
            const SizedBox(height: 8),
            const Text(
              'This may take a few moments...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_previews == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Failed to build pages'),
            SizedBox(height: 8),
            Text(
              'Please try again or check if the project is processed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_previews!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No pages generated'),
            const SizedBox(height: 8),
            const Text(
              'No page templates were found for this magic template.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _buildPages,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Page navigation
        if (_previews!.length > 1) _buildPageNavigation(),

        // Main page viewer
        Expanded(
          child: _buildPageViewer(),
        ),

        // Bottom info and actions
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildPageNavigation() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _previews!.length,
        itemBuilder: (context, index) {
          final preview = _previews![index];
          final isSelected = index == _selectedPageIndex;

          return GestureDetector(
            onTap: () => setState(() => _selectedPageIndex = index),
            child: Container(
              width: 100,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  width: isSelected ? 3 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: RawImage(
                  image: preview.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageViewer() {
    final preview = _previews![_selectedPageIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Card(
          elevation: 8,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InteractiveViewer(
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: RawImage(
                image: preview.image,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final preview = _previews![_selectedPageIndex];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Page ${preview.page.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Template: ${preview.page.file}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      'Faces: ${preview.page.faces.length} | Sections: ${preview.page.sections.length}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Text(
                '${_selectedPageIndex + 1}/${_previews!.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _buildPages,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rebuild'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveCurrentPage,
                  icon: const Icon(Icons.download),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareCurrentPage,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _buildPages() async {
    if (widget.save.path == null) return;

    setState(() {
      _isLoading = true;
      _currentProgress = 'Loading page templates...';
    });

    try {
      // Build pages using PageBuilderService
      final previews = await PageBuilderService.buildProjectPages(
        projectName: widget.save.path!,
        magicPath: widget.save.magic,
        context: context,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _currentProgress = message;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _previews = previews;
          _selectedPageIndex = 0;
        });

        if (previews != null && previews.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully built ${previews.length} page(s)!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (previews != null && previews.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pages were generated'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _previews = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to build pages: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveCurrentPage() async {
    if (_previews == null || _selectedPageIndex >= _previews!.length) return;

    try {
      final preview = _previews![_selectedPageIndex];

      // Convert ui.Image to bytes
      final byteData =
          await preview.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'page_${preview.page.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');

      // Write image bytes
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page saved as $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                // You can add functionality to open file manager here
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareCurrentPage() async {
    if (_previews == null || _selectedPageIndex >= _previews!.length) return;

    try {
      final preview = _previews![_selectedPageIndex];

      // Convert ui.Image to bytes
      final byteData =
          await preview.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final fileName = 'page_${preview.page.id}.png';
      final file = File('${directory.path}/$fileName');

      // Write image bytes
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Page ${preview.page.id} from ${widget.save.name}',
        subject: 'Magic Cube Page',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share page: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
