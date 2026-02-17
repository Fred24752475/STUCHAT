import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/api_service.dart';
import '../services/logger_service.dart';
import '../widgets/glass_button.dart';
import '../widgets/glass_text_field.dart';
import '../widgets/glass_card.dart';

class UnifiedAIScreen extends StatefulWidget {
  final String userId;
  
  const UnifiedAIScreen({super.key, required this.userId});

  @override
  State<UnifiedAIScreen> createState() => _UnifiedAIScreenState();
}

class _UnifiedAIScreenState extends State<UnifiedAIScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _homeworkController = TextEditingController();
  final TextEditingController _conceptController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _summarizeController = TextEditingController();
  final TextEditingController _flashcardController = TextEditingController();
  
  bool _isLoading = false;
  String _aiResponse = '';
  String _selectedMode = 'general';
  List<Map<String, dynamic>> _conversationHistory = [];
  List<Map<String, dynamic>> _flashcards = [];
  File? _selectedImage;
  
  // AI Modes
  final List<Map<String, dynamic>> _aiModes = [
    {'icon': Icons.chat, 'label': 'Chat', 'mode': 'general', 'color': Colors.blue},
    {'icon': Icons.school, 'label': 'Homework', 'mode': 'homework', 'color': Colors.green},
    {'icon': Icons.psychology, 'label': 'Concept', 'mode': 'concept', 'color': Colors.purple},
    {'icon': Icons.quiz, 'label': 'Questions', 'mode': 'questions', 'color': Colors.orange},
    {'icon': Icons.summarize, 'label': 'Summarize', 'mode': 'summarize', 'color': Colors.teal},
    {'icon': Icons.style, 'label': 'Flashcards', 'mode': 'flashcards', 'color': Colors.red},
    {'icon': Icons.camera_alt, 'label': 'Camera OCR', 'mode': 'camera', 'color': Colors.indigo},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConversationHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _homeworkController.dispose();
    _conceptController.dispose();
    _questionController.dispose();
    _summarizeController.dispose();
    _flashcardController.dispose();
    super.dispose();
  }

  Future<void> _loadConversationHistory() async {
    try {
      final history = await ApiService.getAIConversations(widget.userId);
      setState(() {
        _conversationHistory = history.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      LoggerService.error('Failed to load conversation history', e);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty && _selectedImage == null) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> response;
      
      switch (_selectedMode) {
        case 'homework':
          response = await ApiService.solveHomework(
            _messageController.text,
            subject: 'General',
          );
          break;
        case 'concept':
          response = await ApiService.explainConcept(
            _messageController.text,
            level: 'college',
          );
          break;
        case 'questions':
          response = await ApiService.generateQuestions(
            _messageController.text,
            count: 5,
            difficulty: 'medium',
          );
          break;
        case 'summarize':
          response = await ApiService.summarizeText(
            _messageController.text,
            length: 'medium',
          );
          break;
        case 'flashcards':
          response = await ApiService.generateFlashcards(
            _messageController.text,
            count: 10,
          );
          _flashcards = response['flashcards'] ?? [];
          break;
        default:
          response = await ApiService.chatWithAI(
            userId: widget.userId,
            message: _messageController.text,
            mode: _selectedMode,
          );
      }

      setState(() {
        _aiResponse = response['response'] ?? response['error'] ?? 'No response';
        _isLoading = false;
        
        // Add to conversation history
        _conversationHistory.add({
          'user_message': _messageController.text,
          'ai_response': _aiResponse,
          'mode': _selectedMode,
          'timestamp': DateTime.now().toIso8601String(),
        });
      });

      _messageController.clear();
    } catch (e) {
      setState(() {
        _aiResponse = 'Error: ${e.toString()}';
        _isLoading = false;
      });
      LoggerService.error('AI request failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue, Colors.purple]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'STUCHAT AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'AI Assistant', icon: Icon(Icons.smart_toy)),
            Tab(text: 'Study Tools', icon: Icon(Icons.school)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAIAssistantTab(),
          _buildStudyToolsTab(),
        ],
      ),
    );
  }

  Widget _buildAIAssistantTab() {
    return Column(
      children: [
        // AI Mode Selector
        Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _aiModes.length,
            itemBuilder: (context, index) {
              final mode = _aiModes[index];
              final isSelected = _selectedMode == mode['mode'];
              
              return GestureDetector(
                onTap: () => setState(() => _selectedMode = mode['mode']),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected 
                        ? [mode['color'], mode['color'].withOpacity(0.7)]
                        : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? mode['color'] : Colors.grey.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(mode['icon'], 
                        color: isSelected ? Colors.white : Colors.white70,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mode['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        
        // Chat Area
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                // Conversation History
                if (_conversationHistory.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: _conversationHistory.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversationHistory[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  conversation['user_message'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.2)],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  conversation['ai_response'] ?? '',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // AI Response Area
                if (_aiResponse.isNotEmpty && _conversationHistory.isEmpty)
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _aiResponse,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),

                // Flashcards Display
                if (_selectedMode == 'flashcards' && _flashcards.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: ListView.builder(
                      itemCount: _flashcards.length,
                      itemBuilder: (context, index) {
                        final flashcard = _flashcards[index];
                        return GlassCard(
                          child: ExpansionTile(
                            title: Text(
                              flashcard['question'] ?? 'Question',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  flashcard['answer'] ?? 'Answer',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Input Area
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassTextField(
                          controller: _messageController,
                          hintText: _getHintText(),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassButton(
                        text: '',
                        icon: _isLoading ? Icons.hourglass_empty : Icons.send,
                        onPressed: _isLoading ? null : () async {
                          await _sendMessage();
                        },
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudyToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Study Tools',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Camera OCR Section
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Camera OCR Scanner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Take a picture of text, equations, or diagrams to get instant AI help.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        text: '📷 Open Camera',
                        icon: Icons.camera_alt,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    // TODO: Implement camera OCR with ML Kit
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('📷 Camera OCR coming soon!')),
                                    );
                                  },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        text: '🖼️ Gallery',
                        icon: Icons.photo_library,
                        onPressed: () {
                                    HapticFeedback.lightImpact();
                                    // TODO: Implement gallery OCR with image picker
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('🖼️ Gallery OCR coming soon!')),
                                    );
                                  },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Tools Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildToolCard(
                icon: Icons.summarize,
                title: 'Text Summarizer',
                subtitle: 'Quickly summarize any text',
                color: Colors.teal,
                onTap: () => _showToolDialog('summarize'),
              ),
              _buildToolCard(
                icon: Icons.quiz,
                title: 'Question Generator',
                subtitle: 'Generate practice questions',
                color: Colors.orange,
                onTap: () => _showToolDialog('questions'),
              ),
              _buildToolCard(
                icon: Icons.style,
                title: 'Flashcard Maker',
                subtitle: 'Create study flashcards',
                color: Colors.red,
                onTap: () => _showToolDialog('flashcards'),
              ),
              _buildToolCard(
                icon: Icons.psychology,
                title: 'Concept Explainer',
                subtitle: 'Understand complex topics',
                color: Colors.purple,
                onTap: () => _showToolDialog('concept'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    void Function()? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 10,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToolDialog(String tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getToolTitle(tool)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _getToolController(tool),
              maxLines: tool == 'summarize' ? 5 : 3,
              decoration: InputDecoration(
                hintText: _getToolHint(tool),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _selectedMode = tool;
                _messageController.text = _getToolController(tool).text;
              });
              await _sendMessage();
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  TextEditingController _getToolController(String tool) {
    switch (tool) {
      case 'summarize': return _summarizeController;
      case 'questions': return _questionController;
      case 'concept': return _conceptController;
      case 'flashcards': return _flashcardController;
      default: return _messageController;
    }
  }

  String _getToolTitle(String tool) {
    switch (tool) {
      case 'summarize': return 'Text Summarizer';
      case 'questions': return 'Question Generator';
      case 'concept': return 'Concept Explainer';
      case 'flashcards': return 'Flashcard Maker';
      default: return 'AI Tool';
    }
  }

  String _getToolHint(String tool) {
    switch (tool) {
      case 'summarize': return 'Paste the text you want to summarize...';
      case 'questions': return 'Enter a topic to generate questions...';
      case 'concept': return 'What concept do you want explained?';
      case 'flashcards': return 'Enter topic for flashcards...';
      default: return 'Enter your request...';
    }
  }

  String _getHintText() {
    switch (_selectedMode) {
      case 'homework': return 'Ask me to solve your homework...';
      case 'concept': return 'What concept do you want explained?';
      case 'questions': return 'Generate questions for any topic...';
      case 'summarize': return 'Paste text to summarize...';
      case 'flashcards': return 'Create flashcards from any topic...';
      case 'camera': return 'Take a photo for OCR analysis...';
      default: return 'Ask me anything...';
    }
  }
}