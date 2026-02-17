import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final String userId;

  const AnalyticsDashboardScreen({super.key, required this.userId});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  int _selectedPeriod = 7;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getAnalyticsDashboard(
        widget.userId,
        period: _selectedPeriod,
      );
      setState(() {
        _dashboard = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today),
            onSelected: (period) {
              setState(() => _selectedPeriod = period);
              _loadDashboard();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('Last 7 days')),
              const PopupMenuItem(value: 30, child: Text('Last 30 days')),
              const PopupMenuItem(value: 90, child: Text('Last 90 days')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Selector
                    Text(
                      'Last $_selectedPeriod days',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Overview Stats
                    _buildOverviewSection(),
                    const SizedBox(height: 24),

                    // Engagement Rate
                    _buildEngagementCard(),
                    const SizedBox(height: 24),

                    // Popular Posts
                    if (_dashboard?['popularPosts'] != null &&
                        (_dashboard!['popularPosts'] as List).isNotEmpty) ...[
                      const Text(
                        'Top Performing Posts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildPopularPosts(),
                    ],

                    const SizedBox(height: 24),

                    // Activity Chart
                    if (_dashboard?['activityByDay'] != null) ...[
                      const Text(
                        'Activity Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildActivityChart(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewSection() {
    final overview = _dashboard?['overview'] ?? {};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Posts',
          '${overview['totalPosts'] ?? 0}',
          Icons.article,
          Colors.blue,
        ),
        _buildStatCard(
          'Likes',
          '${overview['totalLikes'] ?? 0}',
          Icons.favorite,
          Colors.red,
        ),
        _buildStatCard(
          'Comments',
          '${overview['totalComments'] ?? 0}',
          Icons.comment,
          Colors.green,
        ),
        _buildStatCard(
          'Profile Views',
          '${overview['profileViews'] ?? 0}',
          Icons.visibility,
          Colors.purple,
        ),
        _buildStatCard(
          'Followers',
          '${overview['followers'] ?? 0}',
          Icons.people,
          Colors.orange,
        ),
        _buildStatCard(
          'Following',
          '${overview['following'] ?? 0}',
          Icons.person_add,
          Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard() {
    final overview = _dashboard?['overview'] ?? {};
    final rate = overview['engagementRate'] ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Engagement Rate',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'interactions\nper post',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (rate / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPopularPosts() {
    final posts = _dashboard!['popularPosts'] as List;
    return posts.take(5).map((post) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: post['image_url'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post['image_url'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article),
                ),
          title: Text(
            post['content'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Text('${post['likes']}'),
              const SizedBox(width: 12),
              const Icon(Icons.comment, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Text('${post['comments']}'),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActivityChart() {
    final activityData = _dashboard!['activityByDay'] as List;
    if (activityData.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No activity data available'),
        ),
      );
    }

    final maxCount = activityData.fold<int>(
      0,
      (max, item) => item['count'] > max ? item['count'] as int : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: activityData.map((item) {
            final count = item['count'] as int;
            final date = DateTime.parse(item['date']);
            final percentage = maxCount > 0 ? count / maxCount : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: Colors.grey[200],
                      minHeight: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$count',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
