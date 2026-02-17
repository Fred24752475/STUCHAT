import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'create_study_group_screen.dart';

class StudyGroupsListScreen extends StatefulWidget {
  final String userId;

  const StudyGroupsListScreen({super.key, required this.userId});

  @override
  State<StudyGroupsListScreen> createState() => _StudyGroupsListScreenState();
}

class _StudyGroupsListScreenState extends State<StudyGroupsListScreen> {
  List<dynamic> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadGroups();
  }

  Future<void> loadGroups() async {
    setState(() => isLoading = true);
    final data = await ApiService.getStudyGroups();
    setState(() {
      groups = data;
      isLoading = false;
    });
  }

  Future<void> joinGroup(String groupId) async {
    try {
      await ApiService.joinStudyGroup(groupId, widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined study group!')),
        );
      }
      loadGroups();
    } catch (e) {
      if (mounted) {
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
        title: const Text('Study Groups'),
        backgroundColor: Colors.purple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? const Center(child: Text('No study groups yet'))
              : ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Text(
                            group['name'][0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(group['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group['description'] ?? ''),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.school,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  group['course'] ?? 'General',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.people,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${group['member_count']} members',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => joinGroup(group['id'].toString()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                          ),
                          child: const Text('Join'),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CreateStudyGroupScreen(userId: widget.userId),
            ),
          ).then((result) {
            if (result == true) {
              loadGroups();
            }
          });
        },
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add),
      ),
    );
  }
}
