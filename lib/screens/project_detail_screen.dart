import 'package:flutter/material.dart';
import '../models/save.dart';
import '../services/analytics_service.dart';
import '../services/magic_processing_service.dart';
import '../services/export_service.dart';
import '../magic_manager.dart';
import 'project_editor_screen.dart';
import 'page_builder_detail_screen.dart';

enum ExportType { pdf, images }

class ProjectDetailScreen extends StatefulWidget {
  final Save save;

  const ProjectDetailScreen({
    super.key,
    required this.save,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  ProcessingStatus? _processingStatus;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('project_detail');
    _loadProcessingStatus();
  }

  Future<void> _loadProcessingStatus() async {
    if (widget.save.path == null) {
      setState(() => _isLoadingStatus = false);
      return;
    }

    final status = await MagicProcessingService.getProcessingStatus(
      widget.save.path!,
      widget.save.magic,
    );

    if (mounted) {
      setState(() {
        _processingStatus = status;
        _isLoadingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.save.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editProject,
            tooltip: 'Edit Project',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareProject,
            tooltip: 'Share Project',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Preview Card
            _buildSimplePreviewCard(),
            const SizedBox(height: 24),

            // Project Information
            _buildInfoSection(
              title: 'Project Information',
              children: [
                _buildInfoRow('Name', widget.save.name),
                _buildInfoRow('Template', widget.save.magic),
                _buildInfoRow('Author', widget.save.author),
                _buildInfoRow('Created', _formatDate(widget.save.created)),
                _buildInfoRow('Updated', _formatDate(widget.save.updated)),
                if (widget.save.path != null)
                  _buildInfoRow('Path', widget.save.path!),
              ],
            ),
            const SizedBox(height: 16),

            // Processing Status
            _buildProcessingStatusSection(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingStatusSection() {
    if (_isLoadingStatus) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Processing Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading status...'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_processingStatus == null) {
      return const SizedBox.shrink();
    }

    final status = _processingStatus!;
    final isProcessed = status.isProcessed;
    final progress = status.progress;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Processing Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (isProcessed)
                  const Icon(Icons.check_circle, color: Colors.green)
                else if (status.error != null)
                  const Icon(Icons.error, color: Colors.red)
                else
                  const Icon(Icons.pending, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            if (status.error != null)
              Text(
                'Error: ${status.error}',
                style: const TextStyle(color: Colors.red),
              )
            else ...[
              Text(
                isProcessed
                    ? 'All slices processed successfully!'
                    : 'Processing needed: ${status.processedSlices}/${status.totalSlices} slices completed',
              ),
              if (status.totalSlices > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isProcessed ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).toInt()}% complete',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    // Allow processing if we have status and either:
    // 1. Project is not processed yet (first time)
    // 2. Project is already processed (reprocessing)
    // We always allow processing if status is available - the service will validate source images
    final canProcess = _processingStatus != null;
    final isProcessed = _processingStatus?.isProcessed ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _editProject,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Project'),
                ),
                ElevatedButton.icon(
                  onPressed: canProcess ? _processProject : null,
                  icon: Icon(isProcessed ? Icons.refresh : Icons.transform),
                  label:
                      Text(isProcessed ? 'Reprocess Images' : 'Process Images'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProcess ? Colors.blue : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessed ? () => _showProjectInfo() : null,
                  icon: const Icon(Icons.info),
                  label: const Text('Project Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessed ? Colors.green : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessed ? _buildPages : null,
                  icon: const Icon(Icons.article),
                  label: const Text('Build Pages'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessed ? Colors.purple : null,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isProcessed ? _exportProject : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareProject,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _editProject() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectEditorScreen(save: widget.save),
      ),
    );

    // If changes were made, refresh the screen
    if (result == true && mounted) {
      // Reload processing status in case images were changed
      await _loadProcessingStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _processProject() {
    if (widget.save.path == null) return;

    final isReprocessing = _processingStatus?.isProcessed == true;
    final actionText = isReprocessing ? 'Reprocess' : 'Process';
    final actionVerb = isReprocessing ? 'reprocess' : 'process';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionText Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will $actionVerb your cropped images according to the template specifications:',
            ),
            const SizedBox(height: 8),
            const Text('• Extract slices from source images'),
            const Text('• Apply perspective transformations'),
            const Text('• Generate all parts for the magic cube'),
            if (isReprocessing) ...[
              const SizedBox(height: 8),
              const Text(
                '• Overwrite existing processed slices',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_processingStatus != null && _processingStatus!.totalSlices > 0)
              Text(
                'This will ${isReprocessing ? 'regenerate' : 'generate'} ${_processingStatus!.totalSlices} slices for assembly.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startProcessing();
            },
            child:
                Text('Start ${isReprocessing ? 'Reprocessing' : 'Processing'}'),
          ),
        ],
      ),
    );
  }

  void _startProcessing() async {
    if (widget.save.path == null) return;

    // Determine if this is reprocessing
    final isReprocessing = _processingStatus?.isProcessed == true;
    final dialogTitle =
        isReprocessing ? 'Reprocessing Images' : 'Processing Images';

    // Show processing dialog
    String currentProgress = 'Initializing...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(currentProgress),
            ],
          ),
        ),
      ),
    );

    try {
      // Determine if this is reprocessing (project already has processed slices)
      final isReprocessing = _processingStatus?.isProcessed == true;

      // Start the processing
      final result = await MagicProcessingService.processProject(
        projectPath: widget.save.path!,
        templatePath: widget.save.magic,
        forceReprocess: isReprocessing,
        onProgress: (message) {
          // Update progress message in dialog
          if (mounted) {
            currentProgress = message;
            // Force dialog rebuild to show new progress
            setState(() {});
          }
        },
      );

      // Close processing dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show result
      if (result.success) {
        // Refresh processing status
        await _loadProcessingStatus();

        if (mounted) {
          final actionText = isReprocessing ? 'Reprocessing' : 'Processing';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$actionText completed! Generated ${result.processedSlices} slices.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Processing failed: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Close processing dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _exportProject() {
    if (widget.save.path == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose export format:'),
            const SizedBox(height: 16),
            const Text('📄 PDF Document'),
            const Text('  • All slices in one printable file'),
            const Text('  • Assembly instructions included'),
            const Text('  • Easy to share and print'),
            const SizedBox(height: 12),
            const Text('🖼️ Individual Images'),
            const Text('  • Each slice as separate PNG file'),
            const Text('  • For advanced editing'),
            const Text('  • Higher quality images'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exportToPDF();
            },
            child: const Text('Export PDF'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _exportToImages();
            },
            child: const Text('Export Images'),
          ),
        ],
      ),
    );
  }

  void _exportToPDF() async {
    if (widget.save.path == null) return;

    // Show export progress dialog
    String currentProgress = 'Initializing export...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Exporting to PDF'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(currentProgress),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await ExportService.exportToPDF(
        projectPath: widget.save.path!,
        templatePath: widget.save.magic,
        projectName: widget.save.name,
        onProgress: (message) {
          if (mounted) {
            currentProgress = message;
            setState(() {});
          }
        },
      );

      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result.success) {
        // Show success dialog with options
        if (mounted) {
          _showExportSuccessDialog(result, ExportType.pdf);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _exportToImages() async {
    if (widget.save.path == null) return;

    // Show export progress dialog
    String currentProgress = 'Initializing export...';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Exporting Images'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(currentProgress),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await ExportService.exportToImages(
        projectPath: widget.save.path!,
        templatePath: widget.save.magic,
        projectName: widget.save.name,
        onProgress: (message) {
          if (mounted) {
            currentProgress = message;
            setState(() {});
          }
        },
      );

      // Close export dialog
      if (mounted) {
        Navigator.pop(context);
      }

      if (result.success) {
        // Show success dialog
        if (mounted) {
          _showExportSuccessDialog(result, ExportType.images);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Export failed: ${result.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Close export dialog
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(ExportResult result, ExportType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Export Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (type == ExportType.pdf) ...[
              const Text('PDF exported successfully!'),
              const SizedBox(height: 8),
              Text('📄 File: ${result.filePath?.split('/').last ?? 'Unknown'}'),
            ] else ...[
              const Text('Images exported successfully!'),
              const SizedBox(height: 8),
              Text(
                  '📁 Folder: ${result.filePath?.split('/').last ?? 'Unknown'}'),
            ],
            Text('🔢 Slices: ${result.exportedSlices}'),
            Text('📐 Size: ${result.fileSizeFormatted}'),
            const SizedBox(height: 12),
            if (type == ExportType.pdf)
              const Text(
                'Your PDF is ready to print! Each page contains the slices for assembly.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              const Text(
                'All slice images are saved separately for advanced editing.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          if (type == ExportType.pdf && result.filePath != null)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final shared = await ExportService.sharePDF(result.filePath!);
                if (!shared && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not share file'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Share PDF'),
            ),
        ],
      ),
    );
  }

  void _shareProject() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Project'),
        content: const Text(
          'Share functionality is not yet implemented. '
          'This would allow you to share your project or processed images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showProjectInfo() {
    final processed = _processingStatus?.processedSlices ?? 0;
    final total = _processingStatus?.totalSlices ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Project Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project: ${widget.save.name}'),
            const SizedBox(height: 8),
            Text('Template: ${widget.save.magic}'),
            const SizedBox(height: 8),
            Text(
                'Status: ${_processingStatus?.isProcessed == true ? 'Processed' : 'Not processed'}'),
            if (processed > 0) ...[
              const SizedBox(height: 8),
              Text('Slices: $processed/$total processed'),
            ],
            if (widget.save.path != null) ...[
              const SizedBox(height: 8),
              Text('Path: ${widget.save.path}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePreviewCard() {
    final isProcessed = _processingStatus?.isProcessed ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade300,
              Colors.blue.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isProcessed ? Icons.check_circle : Icons.image,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                'Project Preview',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isProcessed
                    ? '${_processingStatus?.processedSlices ?? 0} slices processed'
                    : 'Process images to see preview',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _buildPages() async {
    if (widget.save.path == null) return;

    // Navigate to dedicated page builder screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PageBuilderDetailScreen(save: widget.save),
      ),
    );
  }
}
