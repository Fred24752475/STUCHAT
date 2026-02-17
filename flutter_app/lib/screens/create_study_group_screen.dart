import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/logger_service.dart';
import '../widgets/glass_scaffold.dart';
import '../widgets/glass_text_field.dart';

class CreateStudyGroupScreen extends StatefulWidget {
  final String userId;

  const CreateStudyGroupScreen({super.key, required this.userId});

  @override
  State<CreateStudyGroupScreen> createState() => _CreateStudyGroupScreenState();
}

class _CreateStudyGroupScreenState extends State<CreateStudyGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courseController = TextEditingController();
  final _scheduleController = TextEditingController();
  int _maxMembers = 50;
  bool _isPrivate = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _courseController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      // TODO: Add create study group API endpoint
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        LoggerService.info('Study group created successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Study group created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      LoggerService.error('Failed to create study group', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: 'Create Study Group',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassTextField(
                controller: _nameController,
                labelText: 'Group Name',
                prefixIcon: Icons.group,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _descriptionController,
                labelText: 'Description',
                prefixIcon: Icons.description,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _courseController,
                labelText: 'Course/Subject',
                prefixIcon: Icons.book,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a course';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: _scheduleController,
                labelText: 'Meeting Schedule (Optional)',
                prefixIcon: Icons.schedule,
                hintText: 'e.g., Mondays 3-5 PM',
              ),
              const SizedBox(height: 24),
              Text(
                'Max Members: $_maxMembers',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Slider(
                value: _maxMembers.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                label: _maxMembers.toString(),
                onChanged: (value) {
                  setState(() => _maxMembers = value.toInt());
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Private Group'),
                subtitle: const Text('Only invited members can join'),
                value: _isPrivate,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _isPrivate = value);
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.purple,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create Group',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
