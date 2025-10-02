import 'package:flutter/material.dart';
import '../services/page_builder_service.dart';

/// Screen for testing slice debugging features
class SliceDebugTestScreen extends StatefulWidget {
  const SliceDebugTestScreen({super.key});

  @override
  State<SliceDebugTestScreen> createState() => _SliceDebugTestScreenState();
}

class _SliceDebugTestScreenState extends State<SliceDebugTestScreen> {
  bool _isProcessing = false;
  String _status = 'Ready to test slice debugging...';
  List<PagePreview>? _previews;

  @override
  void initState() {
    super.initState();
    // Enable debugging by default
    PageBuilderDebugConfig.enableAllDebugging();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slice Debug Test'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug configuration controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDebugSwitch(
                      'Enable Slice Debugging',
                      PageBuilderDebugConfig.enableSliceDebugging,
                      (value) => setState(() {
                        PageBuilderDebugConfig.enableSliceDebugging = value;
                      }),
                    ),
                    _buildDebugSwitch(
                      'Show Slice Boundaries',
                      PageBuilderDebugConfig.showSliceBoundaries,
                      (value) => setState(() {
                        PageBuilderDebugConfig.showSliceBoundaries = value;
                      }),
                    ),
                    _buildDebugSwitch(
                      'Show Slice Labels',
                      PageBuilderDebugConfig.showSliceLabels,
                      (value) => setState(() {
                        PageBuilderDebugConfig.showSliceLabels = value;
                      }),
                    ),
                    _buildDebugSwitch(
                      'Show Slice Centers',
                      PageBuilderDebugConfig.showSliceCenters,
                      (value) => setState(() {
                        PageBuilderDebugConfig.showSliceCenters = value;
                      }),
                    ),
                    _buildDebugSwitch(
                      'Show Corner Markers',
                      PageBuilderDebugConfig.showCornerMarkers,
                      (value) => setState(() {
                        PageBuilderDebugConfig.showCornerMarkers = value;
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => setState(() {
                            PageBuilderDebugConfig.enableAllDebugging();
                          }),
                          child: const Text('Enable All'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {
                            PageBuilderDebugConfig.disableAllDebugging();
                          }),
                          child: const Text('Disable All'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Slice Debug Test',
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
                        onPressed: _testSliceDebugging,
                        child: const Text('Test Kaleidocycle A4 Debugging'),
                      ),
                  ],
                ),
              ),
            ),

            // Preview area
            if (_previews != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Look for red boundaries, blue center markers, green corners, and yellow labels on each slice.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _previews!.length,
                          itemBuilder: (context, index) {
                            final preview = _previews![index];
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

            // Information card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What This Shows',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• 🔴 Red boundaries around each slice'),
                    const Text('• 🔵 Blue crosshairs marking slice centers'),
                    const Text('• 🟢 Green circles at slice corners'),
                    const Text('• 🟡 Yellow labels with slice information'),
                    const Text(
                        '• Source/slice IDs, angles, positions, and sizes'),
                    const SizedBox(height: 8),
                    const Text(
                      'This helps visualize exactly where each slice is positioned and how it\'s oriented on the final page layout.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _testSliceDebugging() async {
    setState(() {
      _isProcessing = true;
      _status = 'Testing slice debugging...';
      _previews = null;
    });

    try {
      // Print current debug configuration
      PageBuilderDebugConfig.printConfig();

      // Test with kaleidocycle A4 template
      setState(() => _status = 'Building debug preview for Kaleidocycle A4...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Build pages with debugging enabled
      final previews = await PageBuilderService.buildProjectPages(
        projectName: 'debug_test',
        magicPath: 'kaleidocycle',
        context: context,
      );

      setState(() {
        _previews = previews;
        _status = 'Debug visualization complete!\n\n'
            'Check the preview above to see slice debugging in action.\n'
            'Each slice should show:\n'
            '• Red boundaries\n'
            '• Blue center crosshairs\n'
            '• Green corner markers\n'
            '• Yellow info labels';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Debug test failed: $e';
        _isProcessing = false;
      });
    }
  }
}
