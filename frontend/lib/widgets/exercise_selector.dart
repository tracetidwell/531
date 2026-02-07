import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_models.dart';
import '../providers/exercise_provider.dart';

/// A dialog for selecting an exercise from the list
class ExerciseSelectorDialog extends ConsumerStatefulWidget {
  final ExerciseCategory? filterCategory;
  final String title;

  const ExerciseSelectorDialog({
    Key? key,
    this.filterCategory,
    this.title = 'Select Exercise',
  }) : super(key: key);

  @override
  ConsumerState<ExerciseSelectorDialog> createState() =>
      _ExerciseSelectorDialogState();
}

class _ExerciseSelectorDialogState
    extends ConsumerState<ExerciseSelectorDialog> {
  ExerciseCategory? _selectedCategory;
  String _searchQuery = '';
  bool _showPredefinedOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.filterCategory;
    // Load exercises on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(exerciseProvider.notifier).loadExercises(
            category: _selectedCategory,
            isPredefined: _showPredefinedOnly ? true : null,
          );
    });
  }

  void _filterExercises() {
    ref.read(exerciseProvider.notifier).loadExercises(
          category: _selectedCategory,
          isPredefined: _showPredefinedOnly ? true : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final exerciseState = ref.watch(exerciseProvider);

    // Filter exercises based on search query
    final filteredExercises = exerciseState.exercises.where((exercise) {
      if (_searchQuery.isEmpty) return true;
      return exercise.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Filters
            Row(
              children: [
                // Category filter dropdown
                if (widget.filterCategory == null)
                  Expanded(
                    child: DropdownButtonFormField<ExerciseCategory?>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...ExerciseCategory.values.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category.displayName),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        _filterExercises();
                      },
                    ),
                  ),
                const SizedBox(width: 8),

                // Predefined filter
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Book exercises only'),
                    value: _showPredefinedOnly,
                    onChanged: (value) {
                      setState(() {
                        _showPredefinedOnly = value;
                      });
                      _filterExercises();
                    },
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Exercise list
            Expanded(
              child: exerciseState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : exerciseState.error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: ${exerciseState.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _filterExercises,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filteredExercises.isEmpty
                          ? const Center(child: Text('No exercises found'))
                          : ListView.builder(
                              itemCount: filteredExercises.length,
                              itemBuilder: (context, index) {
                                final exercise = filteredExercises[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      child: Text(
                                        exercise.category.name[0].toUpperCase(),
                                      ),
                                    ),
                                    title: Text(exercise.name),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(exercise.category.displayName),
                                        if (exercise.description != null)
                                          Text(
                                            exercise.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                      ],
                                    ),
                                    trailing: exercise.isPredefined
                                        ? const Chip(
                                            label: Text(
                                              'Book',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 4),
                                          )
                                        : const Chip(
                                            label: Text(
                                              'Custom',
                                              style: TextStyle(fontSize: 10),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 4),
                                          ),
                                    onTap: () {
                                      Navigator.of(context).pop(exercise);
                                    },
                                  ),
                                );
                              },
                            ),
            ),

            // Create custom exercise button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create Custom Exercise'),
                onPressed: () async {
                  final result = await _showCreateExerciseDialog();
                  if (result != null && mounted) {
                    Navigator.of(context).pop(result);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Exercise?> _showCreateExerciseDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    ExerciseCategory? selectedCategory = _selectedCategory;

    return showDialog<Exercise>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Custom Exercise'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  hintText: 'e.g., Cable Flyes',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ExerciseCategory>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                ),
                items: ExerciseCategory.values.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedCategory = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'How to perform this exercise...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || selectedCategory == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter name and select category'),
                  ),
                );
                return;
              }

              try {
                final exercise =
                    await ref.read(exerciseProvider.notifier).createExercise(
                          ExerciseCreateRequest(
                            name: nameController.text,
                            category: selectedCategory!,
                            description: descriptionController.text.isEmpty
                                ? null
                                : descriptionController.text,
                          ),
                        );
                if (context.mounted) {
                  Navigator.of(context).pop(exercise);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
