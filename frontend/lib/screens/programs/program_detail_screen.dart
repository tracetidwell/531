import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/program_models.dart';
import '../../models/exercise_models.dart';
import '../../providers/program_provider.dart';
import '../../providers/exercise_provider.dart';

class ProgramDetailScreen extends ConsumerStatefulWidget {
  final String programId;

  const ProgramDetailScreen({
    super.key,
    required this.programId,
  });

  @override
  ConsumerState<ProgramDetailScreen> createState() =>
      _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  ProgramDetail? _programDetail;
  List<Map<String, dynamic>>? _templates;
  Map<String, Exercise> _exerciseMap = {};
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;
  bool _cycleReadyForAdvance = false;

  @override
  void initState() {
    super.initState();
    _loadProgramDetail();
  }

  Future<void> _loadProgramDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final detail = await apiService.getProgramById(widget.programId);
      final templates = await apiService.getProgramTemplates(widget.programId);

      // Load exercises for name lookup
      await ref.read(exerciseProvider.notifier).loadExercises();
      final exercises = ref.read(exerciseProvider).exercises;
      final exerciseMap = <String, Exercise>{};
      for (final e in exercises) {
        exerciseMap[e.id] = e;
      }

      // Check if all workouts for the current cycle are done
      bool cycleReady = false;
      if (detail.status == 'ACTIVE') {
        try {
          final scheduledThisCycle = await apiService.getWorkouts(
            programId: widget.programId,
            status: 'scheduled',
            cycleNumber: detail.currentCycle,
          );
          cycleReady = scheduledThisCycle.isEmpty;
        } catch (_) {
          // Non-fatal; leave cycleReady as false
        }
      }

      setState(() {
        _programDetail = detail;
        _templates = templates;
        _exerciseMap = exerciseMap;
        _cycleReadyForAdvance = cycleReady;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProgram(Map<String, dynamic> updates) async {
    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateProgram(widget.programId, updates);

      // Reload program detail to show updated values
      await _loadProgramDetail();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Program updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showEditEndDateDialog() async {
    final program = _programDetail!;
    final initialDate = program.endDate ?? DateTime.now().add(const Duration(days: 30));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: program.startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Select End Date',
    );

    if (selectedDate != null) {
      await _updateProgram({
        'end_date': selectedDate.toIso8601String().split('T')[0],
      });
    }
  }

  Future<void> _showEditTargetCyclesDialog() async {
    final program = _programDetail!;
    final controller = TextEditingController(
      text: program.targetCycles?.toString() ?? '',
    );

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Target Cycles'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Number of Cycles',
            hintText: 'e.g., 4',
            helperText: 'Leave empty for unlimited',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.pop(context, -1); // -1 means clear the value
              } else {
                final value = int.tryParse(text);
                if (value != null && value >= 1 && value <= 52) {
                  Navigator.pop(context, value);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a number between 1 and 52')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateProgram({
        'target_cycles': result == -1 ? null : result,
      });
    }
  }

  Future<void> _toggleDeload(bool enable) async {
    if (!enable) {
      // Warn the user that scheduled deload workouts will be deleted
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remove Deload Week?'),
          content: const Text(
            'This will delete all scheduled deload workouts from the current cycle. '
            'Completed deload workouts are kept. Future cycles will be 3 weeks long.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove Deload'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _updateProgram({'include_deload': enable});
  }

  Future<void> _showAdvanceCycleDialog() async {
    final program = _programDetail!;
    final cycleNumber = program.currentCycle;
    double pressIncrement = 5.0;
    double benchIncrement = 5.0;
    double squatIncrement = 10.0;
    double deadliftIncrement = 10.0;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {

          Widget incrementField(
            String label,
            double value,
            void Function(double) onChanged,
          ) {
            final controller = TextEditingController(text: value.toStringAsFixed(0));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(label, style: const TextStyle(fontSize: 14)),
                  ),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        suffixText: 'lbs',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (v) {
                        final parsed = double.tryParse(v);
                        if (parsed != null && parsed >= 0) onChanged(parsed);
                      },
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: Text('Cycle $cycleNumber Complete!'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your training maxes will increase for the next cycle. Adjust the increments below if desired.',
                  ),
                  const SizedBox(height: 16),
                  incrementField('Press', pressIncrement, (v) => setDialogState(() => pressIncrement = v)),
                  incrementField('Bench Press', benchIncrement, (v) => setDialogState(() => benchIncrement = v)),
                  incrementField('Squat', squatIncrement, (v) => setDialogState(() => squatIncrement = v)),
                  incrementField('Deadlift', deadliftIncrement, (v) => setDialogState(() => deadliftIncrement = v)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setDialogState(() => isLoading = true);
                        try {
                          final apiService = ref.read(apiServiceProvider);
                          await apiService.completeCycle(
                            widget.programId,
                            pressIncrement: pressIncrement,
                            benchPressIncrement: benchIncrement,
                            squatIncrement: squatIncrement,
                            deadliftIncrement: deadliftIncrement,
                          );
                          await apiService.generateNextCycle(widget.programId);

                          if (ctx.mounted) Navigator.of(ctx).pop();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Cycle ${cycleNumber + 1} started!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _loadProgramDetail();
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Start Next Cycle'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEndProgramDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Program'),
        content: const Text(
          'Are you sure you want to end this program? '
          'This will mark the program as completed. '
          'You can still view the workout history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('End Program'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateProgram({
        'status': 'COMPLETED',
        'end_date': DateTime.now().toIso8601String().split('T')[0],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Details'),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading program',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProgramDetail,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_programDetail == null) {
      return const Center(child: Text('Program not found'));
    }

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const Divider(),
              _buildProgressSection(),
              const Divider(),
              _buildTrainingMaxesSection(),
              const Divider(),
              _buildScheduleSection(),
              const Divider(),
              _buildAccessoriesSection(),
              const Divider(),
              _buildProgramSettingsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildAccessoriesSection() {
    if (_templates == null || _templates!.isEmpty) {
      return const SizedBox.shrink();
    }

    final liftNames = {
      'PRESS': 'Press',
      'DEADLIFT': 'Deadlift',
      'BENCH_PRESS': 'Bench Press',
      'SQUAT': 'Squat',
    };

    // Group templates by day number (for 2-day programs, multiple lifts share a day)
    final templatesByDay = <int, List<Map<String, dynamic>>>{};
    for (final template in _templates!) {
      final dayNum = template['day_number'] as int;
      templatesByDay.putIfAbsent(dayNum, () => []).add(template);
    }

    // Sort days
    final sortedDays = templatesByDay.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center),
              const SizedBox(width: 8),
              Text(
                'Accessories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedDays.map((dayNum) {
            final dayTemplates = templatesByDay[dayNum]!;
            // Get lift names for this day
            final lifts = dayTemplates
                .map((t) => liftNames[t['main_lift']] ?? t['main_lift'])
                .toList();
            final liftsDisplay = lifts.join(' + ');

            // Use the first template's accessories (they should be the same for all lifts on a day)
            final firstTemplate = dayTemplates.first;
            final accessories = firstTemplate['accessories'] as List<dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(
                  'Day $dayNum - $liftsDisplay',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${accessories.length} accessor${accessories.length == 1 ? 'y' : 'ies'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                children: [
                  if (accessories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No accessories configured'),
                    )
                  else
                    ...accessories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final acc = entry.value as Map<String, dynamic>;
                      final exerciseId = acc['exercise_id'] as String?;
                      final exerciseName = exerciseId != null
                          ? (_exerciseMap[exerciseId]?.name ?? exerciseId)
                          : 'Unknown Exercise';
                      return ListTile(
                        dense: true,
                        title: Text(
                          exerciseName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${acc['sets']} sets x ${acc['reps']} reps'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showEditAccessoryDialog(
                            dayNum,
                            index,
                            acc,
                            accessories.cast<Map<String, dynamic>>(),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showEditAccessoryDialog(
    int dayNumber,
    int accessoryIndex,
    Map<String, dynamic> accessory,
    List<Map<String, dynamic>> allAccessories,
  ) async {
    final setsController = TextEditingController(text: accessory['sets'].toString());
    final repsController = TextEditingController(text: accessory['reps'].toString());

    final exerciseId = accessory['exercise_id'] as String?;
    final exerciseName = exerciseId != null
        ? (_exerciseMap[exerciseId]?.name ?? 'Accessory')
        : 'Accessory';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $exerciseName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsController,
              decoration: const InputDecoration(
                labelText: 'Sets',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repsController,
              decoration: const InputDecoration(
                labelText: 'Reps',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      final newSets = int.tryParse(setsController.text) ?? accessory['sets'];
      final newReps = int.tryParse(repsController.text) ?? accessory['reps'];

      // Update the accessory in the list
      final updatedAccessories = allAccessories.map((acc) {
        if (acc == accessory) {
          return {
            ...acc,
            'sets': newSets,
            'reps': newReps,
          };
        }
        return acc;
      }).toList();

      // Save to backend
      setState(() => _isSaving = true);
      try {
        final apiService = ref.read(apiServiceProvider);
        await apiService.updateAccessories(
          widget.programId,
          dayNumber,
          updatedAccessories,
        );

        // Reload to show updated data
        await _loadProgramDetail();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accessory updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  Widget _buildProgramSettingsSection() {
    final program = _programDetail!;
    final dateFormat = DateFormat('MMM d, yyyy');
    final isActive = program.status == 'ACTIVE';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Program Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // End Date Setting
          InkWell(
            onTap: isActive ? _showEditEndDateDialog : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Date',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          program.endDate != null
                              ? dateFormat.format(program.endDate!)
                              : 'Not set (ongoing)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(
                      Icons.edit,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Target Cycles Setting
          InkWell(
            onTap: isActive ? _showEditTargetCyclesDialog : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.repeat,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Cycles',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          program.targetCycles != null
                              ? '${program.targetCycles} cycles'
                              : 'Not set (unlimited)',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(
                      Icons.edit,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),

          // Deload Week Toggle (not applicable to 3-day programs)
          if (program.templateType != '3_day') ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.hotel, color: Colors.grey.shade700),
                ),
                title: const Text(
                  'Deload Week',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  program.includeDeload
                      ? 'Week 4 is a deload (4-week cycles)'
                      : 'No deload — 3-week cycles',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                value: program.includeDeload,
                onChanged: isActive ? (value) => _toggleDeload(value) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],

          // End Program Button (only show for active programs)
          if (isActive) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showEndProgramDialog,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Program'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final program = _programDetail!;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  program.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              _buildStatusBadge(program.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            program.displayTemplateType,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '${dateFormat.format(program.startDate)} - ${program.endDate != null ? dateFormat.format(program.endDate!) : 'Ongoing'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.fitness_center, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Training Days: ${program.trainingDaysDisplay}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'ACTIVE':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 'COMPLETED':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      case 'PAUSED':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _programDetail!.displayStatus,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final program = _programDetail!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cycleReadyForAdvance) ...[
            Card(
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events, color: Colors.teal.shade700, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cycle ${program.currentCycle} Complete — Ready for Next Cycle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your training maxes and generate the next cycle\'s workouts.',
                            style: TextStyle(color: Colors.teal.shade800, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _showAdvanceCycleDialog,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.teal.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Start Next Cycle'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Progress',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.autorenew,
                  label: 'Current Cycle',
                  value: '${program.currentCycle}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_view_week,
                  label: 'Current Week',
                  value: '${program.currentWeek}',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  label: 'Workouts Scheduled',
                  value: '${program.workoutsGenerated}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    final startDate = program.startDate.toIso8601String();
                    context.push('/workouts?programId=${program.id}&startDate=$startDate');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'View\nWorkouts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTrainingMaxesDialog(int cycleNumber) async {
    final apiService = ref.read(apiServiceProvider);

    // Load current values first
    Map<String, dynamic> current;
    try {
      current = await apiService.getCycleTrainingMaxes(widget.programId, cycleNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading training maxes: $e')),
        );
      }
      return;
    }

    final liftKeys = ['squat', 'deadlift', 'bench_press', 'press'];
    final liftLabels = {
      'squat': 'Squat',
      'deadlift': 'Deadlift',
      'bench_press': 'Bench Press',
      'press': 'Overhead Press',
    };
    final controllers = {
      for (final k in liftKeys)
        k: TextEditingController(
          text: current[k] != null ? (current[k] as num).toInt().toString() : '',
        )
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Training Maxes — Cycle $cycleNumber'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in liftKeys) ...[
                TextField(
                  controller: controllers[k],
                  decoration: InputDecoration(
                    labelText: '${liftLabels[k]} (lbs)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) {
      for (final c in controllers.values) {
        c.dispose();
      }
      return;
    }

    final updates = <String, double>{};
    for (final k in liftKeys) {
      final parsed = double.tryParse(controllers[k]!.text);
      if (parsed != null && parsed > 0) {
        updates[k] = parsed;
      }
    }

    for (final c in controllers.values) {
      c.dispose();
    }

    if (updates.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await apiService.updateCycleTrainingMaxes(widget.programId, cycleNumber, updates);
      await _loadProgramDetail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training maxes updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTrainingMaxesSection() {
    final program = _programDetail!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Training Maxes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditTrainingMaxesDialog(program.currentCycle),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...program.trainingMaxes.entries.map((entry) {
            final liftName = program.getDisplayLiftName(entry.key);
            final tm = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          liftName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cycle ${tm.cycle}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${tm.value.toInt()} lbs',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final program = _programDetail!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training Schedule',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...program.trainingDays.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            final dayName = day.substring(0, 1).toUpperCase() + day.substring(1);

            // Map day to lift
            final lifts = ['Overhead Press', 'Deadlift', 'Bench Press', 'Squat'];
            final lift = lifts[index % 4];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lift,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
