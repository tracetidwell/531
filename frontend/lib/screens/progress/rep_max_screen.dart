import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/rep_max_models.dart';
import '../../services/api_service.dart';
import '../../providers/program_provider.dart';

class RepMaxScreen extends ConsumerStatefulWidget {
  const RepMaxScreen({super.key});

  @override
  ConsumerState<RepMaxScreen> createState() => _RepMaxScreenState();
}

class _RepMaxScreenState extends ConsumerState<RepMaxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _liftTypes = ['squat', 'deadlift', 'bench_press', 'press'];

  AllRepMaxes? _allRepMaxes;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRepMaxes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRepMaxes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final repMaxes = await apiService.getAllRepMaxes();

      setState(() {
        _allRepMaxes = repMaxes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Records'),
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
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 20),
                        const SizedBox(height: 4),
                        Text('Squat', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 20),
                        const SizedBox(height: 4),
                        Text('Deadlift', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 20),
                        const SizedBox(height: 4),
                        Text('Bench', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fitness_center, size: 20),
                        const SizedBox(height: 4),
                        Text('Press', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
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
              'Error loading records',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRepMaxes,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_allRepMaxes == null || !_allRepMaxes!.hasAnyRecords) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Personal Records Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete workouts with AMRAP sets to start tracking your personal records!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: _liftTypes
          .map((liftType) => _buildLiftRepMaxes(liftType))
          .toList(),
    );
  }

  Widget _buildLiftRepMaxes(String liftType) {
    final repMaxes = _allRepMaxes?.getLiftRepMaxes(liftType);

    if (repMaxes == null || repMaxes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 48,
                color: _getLiftColor(liftType).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No records for ${_getLiftDisplayName(liftType)} yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete AMRAP sets to set your first PR!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRepMaxes,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getLiftColor(liftType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getLiftColor(liftType).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 32,
                    color: _getLiftColor(liftType),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_getLiftDisplayName(liftType)} PRs',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getLiftColor(liftType),
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${repMaxes.length} record${repMaxes.length != 1 ? 's' : ''}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Table
            _buildRepMaxTable(liftType, repMaxes),
          ],
        ),
      ),
    );
  }

  Widget _buildRepMaxTable(
    String liftType,
    Map<String, RepMaxRecord> repMaxes,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy');

    // Build list of all rep counts 1-12
    final allReps = List.generate(12, (index) => index + 1);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _getLiftColor(liftType).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    'Reps',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _getLiftColor(liftType),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Weight',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _getLiftColor(liftType),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Calc 1RM',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _getLiftColor(liftType),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Date',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _getLiftColor(liftType),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Table rows
          ...allReps.map((reps) {
            final repMax = repMaxes[reps.toString()];
            final hasRecord = repMax != null;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: hasRecord
                    ? Colors.white
                    : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      '$reps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasRecord ? FontWeight.w600 : FontWeight.normal,
                        color: hasRecord ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      hasRecord
                          ? '${repMax.weight.toInt()} ${repMax.weightUnit}'
                          : '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasRecord
                            ? _getLiftColor(liftType)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      hasRecord ? '${repMax.calculated1rm.toInt()}' : '—',
                      style: TextStyle(
                        fontSize: 14,
                        color: hasRecord ? Colors.black87 : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      hasRecord ? dateFormat.format(repMax.achievedDate) : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasRecord ? Colors.grey[700] : Colors.grey.shade400,
                      ),
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

  Color _getLiftColor(String liftType) {
    switch (liftType) {
      case 'squat':
        return Colors.green;
      case 'deadlift':
        return Colors.red;
      case 'bench_press':
        return Colors.blue;
      case 'press':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getLiftDisplayName(String liftType) {
    switch (liftType) {
      case 'squat':
        return 'Squat';
      case 'deadlift':
        return 'Deadlift';
      case 'bench_press':
        return 'Bench Press';
      case 'press':
        return 'Press';
      default:
        return liftType;
    }
  }
}
