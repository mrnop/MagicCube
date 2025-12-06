import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/save.dart';
import '../models/magic.dart';
import '../services/analytics_service.dart';
import '../services/image_crop_service.dart';
import '../services/mask_crop_service.dart';
import '../services/magic_manager.dart';

class ProjectEditorScreen extends StatefulWidget {
  final Save save;

  const ProjectEditorScreen({
    super.key,
    required this.save,
  });

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _authorController;
  Magic? _magic;
  bool _isLoading = true;
  bool _hasChanges = false;
  List<File> _sourceImages = [];
  final Map<String, int> _imageVersions = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.save.name);
    _authorController = TextEditingController(text: widget.save.author);

    _nameController.addListener(_markChanged);
    _authorController.addListener(_markChanged);

    _loadProjectData();
    AnalyticsService.instance.logScreenView('project_editor');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _loadProjectData() async {
    try {
      // Load magic template
      _magic = await MagicManager.instance.loadMagic(widget.save.magic);

      // Load existing source images
      await _loadSourceImages();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load project data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSourceImages() async {
    if (widget.save.path == null) return;

    final projectDir =
        Directory('${MagicManager.instance.workDir.path}/${widget.save.path}');
    if (!projectDir.existsSync()) return;

    final List<File> images = [];

    // Look for source images
    final files = projectDir.listSync();
    for (final file in files) {
      if (file is File && file.path.toLowerCase().contains('source_image')) {
        images.add(file);
      }
    }

    // Sort by name to maintain order
    images.sort((a, b) => a.path.compareTo(b.path));

    setState(() {
      _sourceImages = images;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Project'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _saveChanges,
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectInfoSection(),
                    const SizedBox(height: 24),
                    _buildTemplateInfoSection(),
                    const SizedBox(height: 24),
                    _buildSourceImagesSection(),
                    const SizedBox(height: 24),
                    _buildActionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProjectInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name',
                border: OutlineInputBorder(),
                helperText: 'Enter a descriptive name for your project',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Author',
                border: OutlineInputBorder(),
                helperText: 'Your name or the creator of this project',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Created: ${_formatDate(widget.save.created)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.update, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Updated: ${_formatDate(widget.save.updated)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateInfoSection() {
    if (_magic == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Template Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const Text('Template information could not be loaded.'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Template', _magic!.name),
            _buildInfoRow('Type', _magic!.path ?? 'Unknown'),
            _buildInfoRow('Description', _magic!.description),
            _buildInfoRow('Sources Required', '${_magic!.sources.length}'),
            if (_magic!.sources.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Source Types:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              ...(_magic!.sources.map((source) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                        '• Source ${source.id} (${source.slices.length} slices)'),
                  ))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceImagesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Source Images',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _addSourceImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  tooltip: 'Add Image',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_sourceImages.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.image, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No source images yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add images to start processing',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: _sourceImages.length,
                itemBuilder: (context, index) {
                  final image = _sourceImages[index];
                  final sourceId = index + 1;

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: Image.file(
                            image,
                            key: ValueKey(
                                '${image.path}_${_imageVersions[image.path] ?? 0}'),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image,
                                        color: Colors.grey[400]),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Error loading',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Source $sourceId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: PopupMenuButton<String>(
                            icon: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.more_vert,
                                  color: Colors.white, size: 16),
                            ),
                            onSelected: (action) =>
                                _handleImageAction(action, index),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'replace',
                                child: Row(
                                  children: [
                                    Icon(Icons.swap_horiz),
                                    SizedBox(width: 8),
                                    Text('Replace'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remove'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
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
                  onPressed: _addSourceImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add Image'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _sourceImages.isNotEmpty ? _replaceAllImages : null,
                  icon: const Icon(Icons.swap_horizontal_circle),
                  label: const Text('Replace All'),
                ),
                ElevatedButton.icon(
                  onPressed: _hasChanges ? _saveChanges : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasChanges ? Colors.green : null,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _resetProject,
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset Project'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addSourceImage() async {
    if (_magic == null) return;

    try {
      final templateName = _magic!.path ?? '';
      if (templateName.isEmpty) {
        _showErrorSnackBar('Invalid template path');
        return;
      }

      // Determine which source ID to use
      // Find the first available ID to avoid collisions
      final existingIds = <int>{};
      final RegExp idRegex = RegExp(r'source_image_(\d+)\.png$');

      for (final image in _sourceImages) {
        final match = idRegex.firstMatch(image.path);
        if (match != null) {
          existingIds.add(int.parse(match.group(1)!));
        }
      }

      int sourceId = 1;
      while (existingIds.contains(sourceId)) {
        sourceId++;
      }

      // Show dialog to choose single or multiple images
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Source Image'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add image for Source $sourceId'),
              const SizedBox(height: 16),
              const Text('Choose how to add the image:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'camera'),
              child: const Text('Camera'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'gallery'),
              child: const Text('Gallery'),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      final imageSource =
          result == 'camera' ? ImageSource.camera : ImageSource.gallery;

      // Pick and crop image using MaskCropService directly
      final croppedImage = await MaskCropService.cropForMagicTemplate(
        context: context,
        templatePath: templateName,
        title: 'Crop for Template',
        source: imageSource,
        sourceId: sourceId,
      );

      if (croppedImage == null) return;

      // Save the image to project directory
      if (widget.save.path != null) {
        final projectDir = MagicManager.instance.workDir;
        final sourceImagePath =
            '${projectDir.path}/${widget.save.path}/source_image_$sourceId.png';

        // Ensure parent directory exists (just in case)
        final destInfo = File(sourceImagePath);
        if (!destInfo.parent.existsSync()) {
          destInfo.parent.createSync(recursive: true);
        }

        await croppedImage.copy(sourceImagePath);
        await croppedImage.delete();

        // Evict from cache to ensure UI updates
        await FileImage(File(sourceImagePath)).evict();
        _imageVersions[sourceImagePath] =
            (_imageVersions[sourceImagePath] ?? 0) + 1;

        // Reload source images
        await _loadSourceImages();
        _markChanged();

        _showSuccessSnackBar('Source image $sourceId added successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to add source image: $e');
    }
  }

  Future<void> _handleImageAction(String action, int index) async {
    if (action == 'replace') {
      await _replaceImage(index);
    } else if (action == 'remove') {
      await _removeImage(index);
    }
  }

  Future<void> _replaceImage(int index) async {
    if (_magic == null || index >= _sourceImages.length) return;

    try {
      final sourceId = index + 1;
      final templateName = _magic!.path ?? '';

      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Replace Source $sourceId'),
          content: const Text('Choose new image source:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'camera'),
              child: const Text('Camera'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'gallery'),
              child: const Text('Gallery'),
            ),
          ],
        ),
      );

      if (result == null || !mounted) return;

      final imageSource =
          result == 'camera' ? ImageSource.camera : ImageSource.gallery;

      // Pick and crop new image using MaskCropService directly
      final croppedImage = await MaskCropService.cropForMagicTemplate(
        context: context,
        templatePath: templateName,
        title: 'Replace Image for Template',
        source: imageSource,
        sourceId: sourceId,
      );

      if (croppedImage == null) return;

      // Replace the existing image
      if (widget.save.path != null) {
        final projectDir = MagicManager.instance.workDir;
        final sourceImagePath =
            '${projectDir.path}/${widget.save.path}/source_image_$sourceId.png';

        // Delete old image if it exists
        final oldImage = File(sourceImagePath);
        if (oldImage.existsSync()) {
          await oldImage.delete();
        }

        // Copy new image
        await croppedImage.copy(sourceImagePath);
        await croppedImage.delete();

        // Evict from cache to ensure UI updates
        await FileImage(File(sourceImagePath)).evict();
        _imageVersions[sourceImagePath] =
            (_imageVersions[sourceImagePath] ?? 0) + 1;

        // Reload source images
        await _loadSourceImages();
        _markChanged();

        _showSuccessSnackBar('Source image $sourceId replaced successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to replace image: $e');
    }
  }

  Future<void> _removeImage(int index) async {
    if (index >= _sourceImages.length) return;

    final sourceId = index + 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Source $sourceId'),
        content: const Text(
            'Are you sure you want to remove this image? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the image file
      final imageFile = _sourceImages[index];
      if (imageFile.existsSync()) {
        await imageFile.delete();
        // Evict from cache
        await FileImage(imageFile).evict();
      }

      // Reload source images
      await _loadSourceImages();
      _markChanged();

      _showSuccessSnackBar('Source image $sourceId removed successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to remove image: $e');
    }
  }

  Future<void> _replaceAllImages() async {
    if (_magic == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace All Images'),
        content: const Text('This will replace all existing source images. '
            'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final templateName = _magic!.path ?? '';

      // Pick multiple images for all sources
      final croppedImages = await ImageCropService.pickImagesForAllSources(
        context: context,
        templatePath: templateName,
        source: ImageSource.gallery,
      );

      if (croppedImages == null || croppedImages.isEmpty) return;

      if (widget.save.path != null) {
        final projectDir = MagicManager.instance.workDir;

        // Remove all existing source images
        for (final image in _sourceImages) {
          if (image.existsSync()) {
            await image.delete();
            await FileImage(image).evict();
          }
        }

        // Copy new images
        for (int i = 0; i < croppedImages.length; i++) {
          final sourceId = i + 1;
          final sourceImagePath =
              '${projectDir.path}/${widget.save.path}/source_image_$sourceId.png';
          await croppedImages[i].copy(sourceImagePath);
          await croppedImages[i].delete();
          await FileImage(File(sourceImagePath)).evict();
          _imageVersions[sourceImagePath] =
              (_imageVersions[sourceImagePath] ?? 0) + 1;
        }

        // Reload source images
        await _loadSourceImages();
        _markChanged();

        _showSuccessSnackBar('All source images replaced successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to replace all images: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    try {
      // Update the save object
      final updatedSave = widget.save.copyWith(
        name: _nameController.text.trim(),
        author: _authorController.text.trim(),
        updated: DateTime.now(),
      );

      // Save to disk
      await MagicManager.instance.updateSave(updatedSave);

      setState(() {
        _hasChanges = false;
      });

      if (!mounted) return;

      _showSuccessSnackBar('Project changes saved successfully!');

      // Return true to indicate changes were saved
      Navigator.pop(context, true);
    } catch (e) {
      _showErrorSnackBar('Failed to save changes: $e');
    }
  }

  Future<void> _resetProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Project'),
        content:
            const Text('This will remove all source images and processed data. '
                'The project will be reset to its initial empty state. '
                'This action cannot be undone.\n\n'
                'Are you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (widget.save.path != null) {
        // Remove all files except meta.json
        final projectDir = Directory(
            '${MagicManager.instance.workDir.path}/${widget.save.path}');
        if (projectDir.existsSync()) {
          final files = projectDir.listSync();
          for (final file in files) {
            if (file is File && !file.path.endsWith('meta.json')) {
              await FileImage(file).evict();
              await file.delete();
            } else if (file is Directory) {
              await file.delete(recursive: true);
            }
          }
        }

        // Reload source images
        await _loadSourceImages();
        _markChanged();

        _showSuccessSnackBar('Project reset successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to reset project: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
