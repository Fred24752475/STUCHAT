import 'package:flutter/material.dart';
import 'group_chat_screen.dart';
import 'group_call_screen.dart';

class GroupsScreen extends StatelessWidget {
  final String userId;
  
  const GroupsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () => _showStartGroupCallDialog(context),
            tooltip: 'Start Group Call',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create group coming soon!')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildGroupTile(
              context, 'Computer Science Club', '234 members', Icons.computer),
          _buildGroupTile(context, 'Basketball Team', '45 members',
              Icons.sports_basketball),
          _buildGroupTile(
              context, 'Study Group - Math 101', '12 members', Icons.calculate),
          _buildGroupTile(
              context, 'Photography Society', '89 members', Icons.camera_alt),
          _buildGroupTile(context, 'Debate Club', '56 members', Icons.forum),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartGroupCallDialog(context),
        icon: const Icon(Icons.video_call),
        label: const Text('Group Call'),
      ),
    );
  }

  void _showStartGroupCallDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Group Call'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select participants for group call:'),
            const SizedBox(height: 16),
            _buildParticipantOption(context, 'Alice', '1'),
            _buildParticipantOption(context, 'Bob', '2'),
            _buildParticipantOption(context, 'Charlie', '3'),
            _buildParticipantOption(context, 'David', '4'),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupCallScreen(
                    userId: userId,
                    userName: 'You',
                    roomId: 'room_${DateTime.now().millisecondsSinceEpoch}',
                    participants: [
                      {'id': '1', 'name': 'Alice'},
                      {'id': '2', 'name': 'Bob'},
                    ],
                    isHost: true,
                  ),
                ),
              );
            },
            child: const Text('Start Call'),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantOption(BuildContext context, String name, String id) {
    return CheckboxListTile(
      title: Text(name),
      value: true,
      onChanged: (value) {},
    );
  }

  Widget _buildGroupTile(
      BuildContext context, String name, String members, IconData icon) {
    return ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(name),
      subtitle: Text(members),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              groupId: '1',
              groupName: name,
              userId: '1',
            ),
          ),
        );
      },
    );
  }
}
