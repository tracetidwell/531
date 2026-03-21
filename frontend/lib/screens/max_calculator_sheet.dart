import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showMaxCalculatorSheet(BuildContext context, String defaultUnit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MaxCalculatorSheet(defaultUnit: defaultUnit),
  );
}

class _MaxCalculatorSheet extends StatefulWidget {
  final String defaultUnit;

  const _MaxCalculatorSheet({required this.defaultUnit});

  @override
  State<_MaxCalculatorSheet> createState() => _MaxCalculatorSheetState();
}

class _MaxCalculatorSheetState extends State<_MaxCalculatorSheet> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  late String _unit;
  double? _result;

  @override
  void initState() {
    super.initState();
    _unit = widget.defaultUnit;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  double _calculate1RM(double weight, int reps) {
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }

  void _onCalculate() {
    final weight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);

    if (weight == null || reps == null || reps < 1) return;

    setState(() {
      _result = _calculate1RM(weight, reps);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Max Calculator',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimate your 1-rep max using the Epley formula.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Weight',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'lbs', child: Text('lbs')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _unit = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Reps',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _onCalculate,
              child: const Text('Calculate'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Estimated 1RM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_result!.toStringAsFixed(1)} $_unit',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
