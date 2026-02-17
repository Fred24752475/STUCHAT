import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';

class StudyResourcesScreen extends StatefulWidget {
  final String userId;

  const StudyResourcesScreen({super.key, required this.userId});

  @override
  State<StudyResourcesScreen> createState() => _StudyResourcesScreenState();
}

class _StudyResourcesScreenState extends State<StudyResourcesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> allResources = [];
  List<dynamic> myResources = [];
  List<dynamic> bookmarkedResources = [];
  bool isLoading = true;
  String selectedCourse = 'All';
  String selectedSubject = 'All';
  String searchQuery = '';

  final List<String> courses = [
    'All',
    'Computer Science',
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'Engineering',
    'Business',
    'Arts',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadResources();
  }

  Future<void> loadResources() async {
    setState(() => isLoading = true);
    try {
      final resources = await ApiService.getStudyResources(
        course: selectedCourse == 'All' ? null : selectedCourse,
        search: searchQuery.isEmpty ? null : searchQuery,
      );

      if (mounted) {
        setState(() {
          allResources = resources;
          myResources = resources
              .where((r) => r['user_id'].toString() == widget.userId)
              .toList();
          bookmarkedResources = [];
          isLoading = false;
        });
      }
    } catch (e) {
      LoggerService.error('Failed to load study resources', e);
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> uploadResource() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedCourseUpload = courses[1];
    String selectedSubjectUpload = 'General';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Study Resource'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Data Structures Notes',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the resource',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCourseUpload,
                decoration: const InputDecoration(labelText: 'Course'),
                items: courses.skip(1).map((course) {
                  return DropdownMenuItem(value: course, child: Text(course));
                }).toList(),
                onChanged: (value) {
                  selectedCourseUpload = value!;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Algorithms, Calculus',
                ),
                onChanged: (value) => selectedSubjectUpload = value,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _pickAndUploadFile(
                titleController.text,
                descController.text,
                selectedCourseUpload,
                selectedSubjectUpload,
              );
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose File'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadFile(
    String title,
    String description,
    String course,
    String subject,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);

      if (file != null) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );
        }

        // Upload file
        final fileUrl = await ApiService.uploadMediaWeb(file, widget.userId);

        // Create study resource
        await ApiService.createStudyResource(
          userId: widget.userId,
          title: title,
          description: description,
          fileUrl: fileUrl,
          course: course,
          resourceType: 'PDF',
        );

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resource uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          loadResources();
        }

        loadResources();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Study Resources'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Resources'),
            Tab(text: 'My Uploads'),
            Tab(text: 'Bookmarked'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: courses.map((course) {
                      return DropdownMenuItem(
                          value: course, child: Text(course));
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedCourse = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      loadResources();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildResourcesList(allResources),
                _buildResourcesList(myResources),
                _buildResourcesList(bookmarkedResources),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uploadResource,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
    );
  }

  Widget _buildResourcesList(List<dynamic> resources) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No resources yet'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: uploadResource,
              icon: const Icon(Icons.upload),
              label: const Text('Upload First Resource'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => _showResourceDetails(resource),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.picture_as_pdf, color: Colors.red),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              resource['description'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(resource['course']),
                        avatar: const Icon(Icons.school, size: 16),
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                      Chip(
                        label: Text(resource['subject']),
                        avatar: const Icon(Icons.book, size: 16),
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        child: Text(resource['user_name'][0]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        resource['user_name'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(Icons.download, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${resource['downloads']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${resource['rating']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showResourceDetails(Map<String, dynamic> resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resource['title'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  resource['description'],
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Text('Uploaded by ${resource['user_name']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text('${resource['downloads']} downloads'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star, size: 20, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text('${resource['rating']} rating'),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Downloading...')),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bookmarked!')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share coming soon!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
