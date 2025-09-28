import 'package:flutter/material.dart' hide Page;
import '../services/page_builder_service.dart';
import '../services/magic_manager.dart';

class PageBuilderTestScreen extends StatefulWidget {
  const PageBuilderTestScreen({super.key});

  @override
  State<PageBuilderTestScreen> createState() => _PageBuilderTestScreenState();
}

class _PageBuilderTestScreenState extends State<PageBuilderTestScreen> {
  String _status = 'Ready to test page building';
  bool _isProcessing = false;
  List<PagePreview> _previews = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Builder Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Page Builder Test',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 16),
                    if (_isProcessing)
                      const LinearProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _testPageBuilding,
                        child: const Text('Test Page Building'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_previews.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generated ${_previews.length} Preview(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _previews.length,
                          itemBuilder: (context, index) {
                            final preview = _previews[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 150,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: RawImage(
                                        image: preview.image,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Page ${preview.page.id}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What This Tests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Page template loading'),
                    const Text('• Multiple page selection dialog'),
                    const Text('• Page building with faces and sections'),
                    const Text('• Text and watermark placement'),
                    const Text('• Image scaling and transformations'),
                    const Text('• Preview generation'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testPageBuilding() async {
    setState(() {
      _isProcessing = true;
      _status = 'Testing page building service...';
      _previews.clear();
    });

    try {
      // Test with a demo project
      setState(() => _status = 'Creating test project...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Check if we have any magic templates
      final magics = await MagicManager.instance.listMagics();
      if (magics.isEmpty) {
        setState(() {
          _status = 'Test failed: No magic templates found';
          _isProcessing = false;
        });
        return;
      }

      // Use the first available magic template
      final magic = magics.first;
      final testProjectName =
          'test_page_build_${DateTime.now().millisecondsSinceEpoch}';

      setState(() => _status = 'Building pages for ${magic.name}...');

      // Test the page building service
      final previews = await PageBuilderService.buildProjectPages(
        projectName: testProjectName,
        magicPath: magic.path!,
        context: context,
        onProgress: (message) {
          if (mounted) {
            setState(() => _status = message);
          }
        },
      );

      if (previews == null) {
        setState(() {
          _status = 'Page building was cancelled by user';
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _previews = previews;
        _status = 'Page building test completed!\n\n'
            'Template: ${magic.name}\n'
            'Generated ${previews.length} preview(s)\n'
            'Page selection dialog: ${previews.length > 1 ? "Shown" : "Skipped"}\n'
            'Page builder service is working!';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Test failed with error: $e';
        _isProcessing = false;
      });
    }
  }
}
