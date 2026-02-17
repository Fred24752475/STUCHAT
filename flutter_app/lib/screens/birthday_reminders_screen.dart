import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BirthdayRemindersScreen extends StatefulWidget {
  final String userId;

  const BirthdayRemindersScreen({super.key, required this.userId});

  @override
  State<BirthdayRemindersScreen> createState() =>
      _BirthdayRemindersScreenState();
}

class _BirthdayRemindersScreenState extends State<BirthdayRemindersScreen> {
  List<dynamic> todayBirthdays = [];
  List<dynamic> upcomingBirthdays = [];
  bool isLoading = true;
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _loadBirthdays();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadBirthdays() async {
    try {
      final todayData = await ApiService.getTodayBirthdays();
      final upcomingData = await ApiService.getTodayBirthdays();

      setState(() {
        todayBirthdays = todayData;
        upcomingBirthdays = upcomingData;
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading birthdays: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> _sendBirthdayMessage(String userId) async {
    if (_messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a message')),
      );
      return;
    }

    try {
      await ApiService.sendBirthdayMessage(
        userId,
        widget.userId,
        message: _messageController.text,
      );
      _messageController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Birthday message sent! 🎉')),
      );
      _loadBirthdays();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showBirthdayMessageDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send Birthday Message to $userName'),
        content: TextField(
          controller: _messageController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Write your birthday message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _sendBirthdayMessage(userId),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pink),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Birthday Reminders 🎂'),
        backgroundColor: Colors.pink,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Today's Birthdays
                  if (todayBirthdays.isNotEmpty)
                    Container(
                      color: Colors.pink.withOpacity(0.1),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "🎉 Today's Birthdays",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayBirthdays.length,
                            itemBuilder: (context, index) {
                              final birthday = todayBirthdays[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: birthday[
                                                'profile_image_url'] !=
                                            null
                                        ? NetworkImage(
                                            birthday['profile_image_url'])
                                        : null,
                                    child: birthday['profile_image_url'] ==
                                            null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(
                                    birthday['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: ElevatedButton.icon(
                                    onPressed: () =>
                                        _showBirthdayMessageDialog(
                                      birthday['id'].toString(),
                                      birthday['name'] ?? 'User',
                                    ),
                                    icon: const Icon(Icons.cake),
                                    label: const Text('Wish'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.pink,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Upcoming Birthdays
                  if (upcomingBirthdays.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upcoming Birthdays 📅',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: upcomingBirthdays.length,
                            itemBuilder: (context, index) {
                              final birthday = upcomingBirthdays[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: birthday[
                                                'profile_image_url'] !=
                                            null
                                        ? NetworkImage(
                                            birthday['profile_image_url'])
                                        : null,
                                    child: birthday['profile_image_url'] ==
                                            null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(
                                    birthday['name'] ?? 'Unknown',
                                  ),
                                  subtitle: Text(
                                    'Birthday: ${birthday['birth_date'] ?? 'Unknown'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  if (todayBirthdays.isEmpty && upcomingBirthdays.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cake_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No birthdays coming up',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
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
}
