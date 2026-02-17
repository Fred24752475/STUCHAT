import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SearchEnhancedScreen extends StatefulWidget {
  final String userId;

  const SearchEnhancedScreen({super.key, required this.userId});

  @override
  State<SearchEnhancedScreen> createState() => _SearchEnhancedScreenState();
}

class _SearchEnhancedScreenState extends State<SearchEnhancedScreen> {
  late TextEditingController _searchController;
  List<dynamic> searchHistory = [];
  List<dynamic> savedSearches = [];
  List<dynamic> searchResults = [];
  bool isLoading = false;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadSearchHistory();
    _loadSavedSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final data = await ApiService.getSearchHistory(widget.userId);
      setState(() => searchHistory = data);
    } catch (e) {
      print('Error loading search history: $e');
    }
  }

  Future<void> _loadSavedSearches() async {
    try {
      final data = await ApiService.getSavedSearches(widget.userId);
      setState(() => savedSearches = data);
    } catch (e) {
      print('Error loading saved searches: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    setState(() => isLoading = true);

    try {
      // Add to search history
      await ApiService.addToSearchHistory(widget.userId, query);

      // Perform search
      final results = await ApiService.searchUsers(query);

      setState(() {
        searchResults = results;
        _selectedTab = 2;
      });

      _loadSearchHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveSearch(String query) async {
    try {
      await ApiService.saveSearch(widget.userId, query, name: query);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search saved! 💾')),
      );
      _loadSavedSearches();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteSavedSearch(String searchId) async {
    try {
      await ApiService.deleteSavedSearch(searchId);
      _loadSavedSearches();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      await ApiService.clearSearchHistory(widget.userId);
      _loadSearchHistory();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search history cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search 🔍'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.blue.withOpacity(0.1),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search users, posts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          // Tabs
          Container(
            color: Colors.blue.withOpacity(0.05),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 0
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Text(
                        'History',
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 1
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Saved',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTab == 2
                                ? Colors.blue
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Results',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildHistoryTab()
                    : _selectedTab == 1
                        ? _buildSavedTab()
                        : _buildResultsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No search history',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Searches',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _clearSearchHistory,
              child: const Text('Clear All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...searchHistory.map((query) {
          return ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: Text(query['query'] ?? query),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                // Remove individual search
              },
            ),
            onTap: () {
              _searchController.text = query['query'] ?? query;
              _performSearch(query['query'] ?? query);
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (savedSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No saved searches',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Saved Searches',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...savedSearches.map((search) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.blue),
              title: Text(search['name'] ?? search['query']),
              subtitle: Text(search['query']),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () =>
                    _deleteSavedSearch(search['id'].toString()),
              ),
              onTap: () {
                _searchController.text = search['query'];
                _performSearch(search['query']);
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildResultsTab() {
    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Results (${searchResults.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_searchController.text.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () =>
                    _saveSearch(_searchController.text),
                icon: const Icon(Icons.bookmark_border),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...searchResults.map((result) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: result['profile_image_url'] != null
                    ? NetworkImage(result['profile_image_url'])
                    : null,
                child: result['profile_image_url'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(result['name'] ?? 'Unknown'),
              subtitle: Text(result['email'] ?? ''),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                // Navigate to user profile
              },
            ),
          );
        }).toList(),
      ],
    );
  }
}
