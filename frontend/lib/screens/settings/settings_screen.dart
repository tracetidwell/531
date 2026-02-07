import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/auth_models.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  String _weightUnit = 'LBS';
  double _roundingIncrement = 5.0;
  String _missedWorkoutPreference = 'ASK';

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;

    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _weightUnit = user?.weightUnitPreference ?? 'LBS';
    _roundingIncrement = user?.roundingIncrement ?? 5.0;
    _missedWorkoutPreference = user?.missedWorkoutPreference ?? 'ASK';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final user = ref.read(authProvider).user;

      // Check if anything changed
      final hasChanges = _firstNameController.text != user?.firstName ||
          _lastNameController.text != user?.lastName ||
          _weightUnit != user?.weightUnitPreference ||
          _roundingIncrement != user?.roundingIncrement ||
          _missedWorkoutPreference != user?.missedWorkoutPreference;

      if (!hasChanges) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No changes to save')),
          );
        }
        setState(() {
          _isSaving = false;
        });
        return;
      }

      final request = UpdateUserRequest(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        weightUnitPreference: _weightUnit,
        roundingIncrement: _roundingIncrement,
        missedWorkoutPreference: _missedWorkoutPreference,
      );

      final updatedUser = await apiService.updateUser(request);

      // Update auth provider with new user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _isSaving = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _firstNameController,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: user.email,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              enabled: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Workout Preferences Section
                    Text(
                      'Workout Preferences',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Weight Unit
                            Text(
                              'Weight Unit',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'LBS',
                                  label: Text('Pounds (lbs)'),
                                ),
                                ButtonSegment(
                                  value: 'KG',
                                  label: Text('Kilograms (kg)'),
                                ),
                              ],
                              selected: {_weightUnit},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() {
                                  _weightUnit = newSelection.first;
                                });
                              },
                            ),
                            const SizedBox(height: 24),

                            // Rounding Increment
                            Text(
                              'Rounding Increment',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Round calculated weights to the nearest:',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _roundingIncrement,
                                    min: 1.0,
                                    max: 10.0,
                                    divisions: 18,
                                    label: '${_roundingIncrement.toStringAsFixed(1)} $_weightUnit',
                                    onChanged: (value) {
                                      setState(() {
                                        _roundingIncrement = value;
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    '${_roundingIncrement.toStringAsFixed(1)} $_weightUnit',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Missed Workout Preference
                            Text(
                              'Missed Workout Handling',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'What should happen when you miss a scheduled workout?',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _buildMissedWorkoutOption(
                              value: 'SKIP',
                              title: 'Skip',
                              description: 'Automatically skip missed workouts',
                              icon: Icons.skip_next,
                            ),
                            const SizedBox(height: 8),
                            _buildMissedWorkoutOption(
                              value: 'RESCHEDULE',
                              title: 'Reschedule',
                              description: 'Automatically reschedule to next available day',
                              icon: Icons.schedule,
                            ),
                            const SizedBox(height: 8),
                            _buildMissedWorkoutOption(
                              value: 'ASK',
                              title: 'Ask Me',
                              description: 'Ask me what to do each time',
                              icon: Icons.help_outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save Settings'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMissedWorkoutOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _missedWorkoutPreference == value;

    return InkWell(
      onTap: () {
        setState(() {
          _missedWorkoutPreference = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.shade50 : null,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _missedWorkoutPreference,
              onChanged: (val) {
                setState(() {
                  _missedWorkoutPreference = val!;
                });
              },
            ),
            Icon(
              icon,
              color: isSelected ? Colors.blue.shade700 : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue.shade900 : null,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
