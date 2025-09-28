import 'package:flutter/material.dart';
import 'magic_manager.dart';

/// Debug widget to test if magic templates are loading from assets/magics
class DebugTemplatesScreen extends StatefulWidget {
  const DebugTemplatesScreen({super.key});

  @override
  State<DebugTemplatesScreen> createState() => _DebugTemplatesScreenState();
}

class _DebugTemplatesScreenState extends State<DebugTemplatesScreen> {
  List<Magic> magics = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMagics();
  }

  Future<void> _loadMagics() async {
    try {
      await MagicManager.instance.initialize();
      final loadedMagics = await MagicManager.instance.listMagics();
      setState(() {
        magics = loadedMagics;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug: Magic Templates'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading templates:', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(error!, textAlign: TextAlign.center),
                    ],
                  ),
                )
              : magics.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No magic templates found in assets/magics'),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.green.withOpacity(0.1),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Successfully loaded ${magics.length} magic templates from assets/magics',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: magics.length,
                            itemBuilder: (context, index) {
                              final magic = magics[index];
                              return Card(
                                margin: const EdgeInsets.all(8),
                                child: ListTile(
                                  title: Text(magic.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Description: ${magic.description}'),
                                      Text('Path: ${magic.path}'),
                                      Text('Sources: ${magic.sources.length}'),
                                      Text('Icon: ${magic.icon}'),
                                      Text('Version: ${magic.version}'),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  leading: CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                                  onTap: () => _showMagicDetails(magic),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  void _showMagicDetails(Magic magic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(magic.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Path: ${magic.path}'),
              Text('Description: ${magic.description}'),
              Text('Version: ${magic.version}'),
              Text('Icon: ${magic.icon}'),
              const SizedBox(height: 16),
              Text('Sources (${magic.sources.length}):'),
              ...magic.sources.map((source) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('• ID ${source.id}: ${source.width}x${source.height} (${source.slices.length} slices)'),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}