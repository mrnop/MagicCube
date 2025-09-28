import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import '../magic_manager.dart';
import '../services/image_crop_service.dart';
import '../services/analytics_service.dart';
import '../debug_templates.dart';
import '../widgets/magic_card.dart';
import '../widgets/save_card.dart';
import 'project_detail_screen.dart';
import 'project_editor_screen.dart';
import '../example/crop_example.dart';
import 'processing_test_screen.dart';
import 'export_test_screen.dart';
import 'page_builder_test_screen.dart';

class MagicCubeHome extends StatefulWidget {
  const MagicCubeHome({super.key});

  @override
  State<MagicCubeHome> createState() => _MagicCubeHomeState();
}

class _MagicCubeHomeState extends State<MagicCubeHome>
    with SingleTickerProviderStateMixin {
  List<Magic> magics = [];
  List<Save> saves = [];
  bool isLoading = true;
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeManager();
    AnalyticsService.instance.logScreenView('home');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeManager() async {
    try {
      await MagicManager.instance.initialize();
      await _loadData();
    } catch (e) {
      print('Failed to initialize: $e');
      _showErrorSnackBar('Failed to initialize app: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadData() async {
    try {
      final loadedMagics = await MagicManager.instance.listMagics();
      final loadedSaves = await MagicManager.instance.listSaves();

      if (mounted) {
        setState(() {
          magics = loadedMagics;
          saves = loadedSaves;
        });
      }
    } catch (e) {
      print('Failed to load data: $e');
      _showErrorSnackBar('Failed to load data: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/magic_cube_logo.png',
              height: 32,
              width: 32,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.apps, size: 32);
              },
            ),
            const SizedBox(width: 8),
            const Text('Magic Cube'),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebugTemplatesScreen(),
              ),
            ),
            tooltip: 'Debug Templates',
          ),
          if (MagicManager.instance.isVip)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.star, color: Colors.yellow),
            ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info),
                    SizedBox(width: 8),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.grid_view),
              text: 'Templates (${magics.length})',
            ),
            Tab(
              icon: const Icon(Icons.folder),
              text: 'Projects (${saves.length})',
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Magic Cube...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMagicsList(),
                _buildSavesList(),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "test_crop",
            onPressed: _testCropFunctionality,
            tooltip: 'Test Crop',
            child: const Icon(Icons.crop),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "test_processing",
            onPressed: _testProcessingFunctionality,
            tooltip: 'Test Processing',
            child: const Icon(Icons.transform),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "test_export",
            onPressed: _testExportFunctionality,
            tooltip: 'Test Export',
            child: const Icon(Icons.picture_as_pdf),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: "test_page_builder",
            onPressed: _testPageBuilderFunctionality,
            tooltip: 'Test Page Builder',
            child: const Icon(Icons.article),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: "new_project",
            onPressed: _createNewProject,
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildMagicsList() {
    if (magics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No templates found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Templates should be located in the assets/magics/ folder',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          itemCount: magics.length,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          itemBuilder: (context, index) {
            final magic = magics[index];
            return MagicCard(
              magic: magic,
              onTap: () => _selectMagic(magic),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSavesList() {
    if (saves.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first project using a template',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: saves.length,
          itemBuilder: (context, index) {
            final save = saves[index];
            return SaveCard(
              save: save,
              onTap: () => _openProject(save),
              onEdit: () => _editProject(save),
              onDelete: () => _deleteProject(save),
            );
          },
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _loadData();
        break;
      case 'about':
        _showAboutDialog();
        break;
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Magic Cube',
      applicationVersion: '1.0.4',
      applicationIcon: Image.asset(
        'assets/magic_cube_logo.png',
        height: 64,
        width: 64,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.apps, size: 64);
        },
      ),
      children: [
        const Text(
          'A Flutter port of the Magic Cube image processing app. '
          'Create amazing photo effects using various templates and transformations.',
        ),
      ],
    );
  }

  void _selectMagic(Magic magic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Template: ${magic.name}'),
            const SizedBox(height: 8),
            Text(magic.description, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text(
              'Choose how to create your project:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createProject(magic);
            },
            child: const Text('Create Empty'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showImagePickingOptionsDialog(magic);
            },
            child: const Text('Create + Add Image'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProject(Magic magic) async {
    try {
      final projectName = MagicManager.instance.nextFileName(magic.path!);
      await MagicManager.instance.createMagic(magic.path!, projectName);
      await _loadData();

      AnalyticsService.instance.logProjectCreated(magic.name);
      _showSuccessSnackBar('Project "$projectName" created!');
    } catch (e) {
      _showErrorSnackBar('Failed to create project: $e');
    }
  }

  Future<void> _showImagePickingOptionsDialog(Magic magic) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many images would you like to add?'),
            const SizedBox(height: 16),
            const Text(
              'Single Image: Pick one image that will be used for all template sources',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Multiple Images: Pick separate images for each template source (recommended for best results)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createProjectWithSingleImage(magic);
            },
            child: const Text('Single Image'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createProjectWithMultipleImages(magic);
            },
            child: const Text('Multiple Images'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProjectWithSingleImage(Magic magic) async {
    try {
      // Extract template name from path (e.g., "assets/magics/decagonal" -> "decagonal")
      final templateName = magic.path?.split('/').last ?? '';

      // Pick and crop a single image using the first source mask
      final croppedImage = templateName.isNotEmpty
          ? await ImageCropService.pickImageForMagicWithMask(
              context, templateName,
              sourceId: 1)
          : await ImageCropService.pickImageForMagic(context);

      if (croppedImage == null) {
        // User cancelled, create empty project
        await _createProject(magic);
        return;
      }

      // Create the project
      final projectName = MagicManager.instance.nextFileName(magic.path!);
      await MagicManager.instance.createMagic(magic.path!, projectName);

      // Copy the cropped image to the project directory as the main source
      final projectDir = MagicManager.instance.workDir;
      final sourceImagePath =
          '${projectDir.path}/$projectName/source_image.png';
      await croppedImage.copy(sourceImagePath);

      // Clean up the temporary cropped file
      await croppedImage.delete();

      await _loadData();

      AnalyticsService.instance.logProjectCreated(magic.name);
      AnalyticsService.instance.logImageCropped();
      _showSuccessSnackBar('Project "$projectName" created with single image!');

      // Open the created project and suggest processing
      final createdSave = await MagicManager.instance.loadSave(projectName);
      if (createdSave != null && mounted) {
        await _navigateToProjectAndSuggestProcessing(createdSave);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create project with single image: $e');
    }
  }

  Future<void> _createProjectWithMultipleImages(Magic magic) async {
    try {
      // Extract template name from path (e.g., "assets/magics/decagonal" -> "decagonal")
      final templateName = magic.path?.split('/').last ?? '';

      if (templateName.isEmpty) {
        _showErrorSnackBar('Invalid template path');
        return;
      }

      // Pick and crop images for all sources in the template
      // Try the advanced method first, fallback to simple method if it fails
      var croppedImages = await ImageCropService.pickImagesForAllSources(
        context: context,
        templatePath: templateName,
        source: ImageSource.gallery,
      );

      // If the advanced method fails, try the simpler approach
      if (croppedImages == null) {
        debugPrint(
            'Advanced multi-source picking failed, trying simplified approach');
        croppedImages = await ImageCropService.pickMultipleImagesSimple(
          context: context,
          templatePath: templateName,
          source: ImageSource.gallery,
        );
      }

      if (croppedImages == null || croppedImages.isEmpty) {
        // User cancelled, create empty project
        await _createProject(magic);
        return;
      }

      // Create the project
      final projectName = MagicManager.instance.nextFileName(magic.path!);
      await MagicManager.instance.createMagic(magic.path!, projectName);

      // Copy all cropped images to the project directory
      final projectDir = MagicManager.instance.workDir;
      final projectPath = '${projectDir.path}/$projectName';

      for (int i = 0; i < croppedImages.length; i++) {
        final sourceId = i + 1;
        final sourceImagePath = '$projectPath/source_image_$sourceId.png';
        await croppedImages[i].copy(sourceImagePath);

        // Clean up the temporary cropped file
        await croppedImages[i].delete();
      }

      await _loadData();

      AnalyticsService.instance.logProjectCreated(magic.name);
      AnalyticsService.instance.logImageCropped();
      _showSuccessSnackBar(
          'Project "$projectName" created with ${croppedImages.length} images!');

      // Open the created project and suggest processing
      final createdSave = await MagicManager.instance.loadSave(projectName);
      if (createdSave != null && mounted) {
        await _navigateToProjectAndSuggestProcessing(createdSave);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create project with multiple images: $e');
    }
  }

  void _createNewProject() {
    if (magics.isEmpty) {
      _showErrorSnackBar('No templates available');
      return;
    }

    // Switch to templates tab
    _tabController.animateTo(0);

    _showSuccessSnackBar('Select a template to create a new project');
  }

  void _testCropFunctionality() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropExample(),
      ),
    );
  }

  void _testProcessingFunctionality() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProcessingTestScreen(),
      ),
    );
  }

  void _testExportFunctionality() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ExportTestScreen(),
      ),
    );
  }

  void _testPageBuilderFunctionality() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PageBuilderTestScreen(),
      ),
    );
  }

  void _openProject(Save save) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(save: save),
      ),
    );
  }

  void _editProject(Save save) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectEditorScreen(save: save),
      ),
    );

    // If changes were made, refresh the saves list
    if (result == true && mounted) {
      await _loadData();
      _showSuccessSnackBar('Project updated successfully!');
    }
  }

  void _deleteProject(Save save) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${save.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await MagicManager.instance.deleteSave(save.path!);
                await _loadData();
                _showSuccessSnackBar('Project "${save.name}" deleted');
              } catch (e) {
                _showErrorSnackBar('Failed to delete project: $e');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToProjectAndSuggestProcessing(Save save) async {
    // Navigate to project detail screen
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectDetailScreen(save: save),
      ),
    );

    // Refresh the saves list when returning
    if (result == true || mounted) {
      await _loadData();
    }

    // Show processing suggestion
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      _showProcessingSuggestion();
    }
  }

  void _showProcessingSuggestion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.blue),
            SizedBox(width: 8),
            Text('Ready to Process!'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your images have been cropped and are ready for magic cube processing.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Processing will:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('• Extract slices from your cropped images'),
            Text('• Apply perspective transformations'),
            Text('• Generate all parts for assembly'),
            SizedBox(height: 12),
            Text(
              'Tip: You can process your images from the project detail screen.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}
