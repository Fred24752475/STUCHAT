import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/new_features.dart';

class CallHistoryScreen extends StatefulWidget {
  final String userId;

  const CallHistoryScreen({super.key, required this.userId});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  List<CallLog> callHistory = [];
  List<CallLog> missedCalls = [];
  bool isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    try {
      final historyData = await ApiService.getCallHistory(widget.userId);
      final missedData = await ApiService.getMissedCalls(widget.userId);

      setState(() {
        callHistory = historyData
            .map((json) => CallLog.fromJson(json))
            .toList();
        missedCalls = missedData
            .map((json) => CallLog.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading call history: $e')),
      );
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History 📞'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.teal.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0
                                ? Colors.teal
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Text(
                        'All Calls',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1
                                ? Colors.teal
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Missed',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          if (missedCalls.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                missedCalls.length.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Call List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildCallList(callHistory)
                    : _buildCallList(missedCalls),
          ),
        ],
      ),
    );
  }

  Widget _buildCallList(List<CallLog> calls) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_disabled, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 0 ? 'No calls yet' : 'No missed calls',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: calls.length,
      itemBuilder: (context, index) {
        final call = calls[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: call.isMissed ? Colors.red : Colors.teal,
              child: Icon(
                call.callType == 'video' ? Icons.videocam : Icons.call,
                color: Colors.white,
              ),
            ),
            title: Text(
              call.callerId == int.parse(widget.userId)
                  ? 'Outgoing ${call.callType} call'
                  : 'Incoming ${call.callType} call',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  call.status,
                  style: TextStyle(
                    color: call.isMissed ? Colors.red : Colors.green,
                    fontSize: 12,
                  ),
                ),
                if (call.duration > 0)
                  Text(
                    'Duration: ${_formatDuration(call.duration)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(call.startedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                if (call.isMissed)
                  const Icon(Icons.call_missed, color: Colors.red, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes == 0) {
      return '${secs}s';
    } else if (minutes < 60) {
      return '${minutes}m ${secs}s';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
