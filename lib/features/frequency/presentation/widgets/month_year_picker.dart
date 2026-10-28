import 'package:flutter/material.dart';

Future<DateTime?> showMonthYearPicker({
  required BuildContext context,
  required DateTime initialMonth,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return _MonthYearPickerDialog(initialMonth: initialMonth);
    },
  );
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({required this.initialMonth});

  final DateTime initialMonth;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  static const int _firstYear = 1900;

  static const List<String> _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static const List<String> _fullMonths = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  late final int _lastYear;
  late int _selectedYear;

  bool _showYearGrid = false;

  @override
  void initState() {
    super.initState();

    // Se determina al abrir el selector, no en función
    // de un año fijo escrito en el código.
    _lastYear = DateTime.now().year;

    _selectedYear = widget.initialMonth.year;

    if (_selectedYear < _firstYear) {
      _selectedYear = _firstYear;
    }

    if (_selectedYear > _lastYear) {
      _selectedYear = _lastYear;
    }
  }

  void _changeYear(int offset) {
    final nextYear = _selectedYear + offset;

    if (nextYear < _firstYear || nextYear > _lastYear) {
      return;
    }

    setState(() {
      _selectedYear = nextYear;
    });
  }

  void _selectMonth(int month) {
    Navigator.of(context).pop(DateTime(_selectedYear, month));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      key: const Key('month-year-picker-dialog'),
      title: const Text('Seleccionar mes y año'),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      content: SizedBox(
        width: 320,
        height: 290,
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('month-year-picker-previous-year'),
                  tooltip: 'Año anterior',
                  onPressed: _selectedYear > _firstYear
                      ? () => _changeYear(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('month-year-picker-select-year'),
                    onPressed: () {
                      setState(() {
                        _showYearGrid = !_showYearGrid;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_selectedYear',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          _showYearGrid
                              ? Icons.arrow_drop_up_rounded
                              : Icons.arrow_drop_down_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('month-year-picker-next-year'),
                  tooltip: 'Año siguiente',
                  onPressed: _selectedYear < _lastYear
                      ? () => _changeYear(1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _showYearGrid
                  ? YearPicker(
                      key: const Key('month-year-picker-year-grid'),
                      firstDate: DateTime(_firstYear),
                      lastDate: DateTime(_lastYear, 12, 31),
                      selectedDate: DateTime(
                        _selectedYear,
                        widget.initialMonth.month,
                      ),
                      onChanged: (selectedDate) {
                        setState(() {
                          _selectedYear = selectedDate.year;
                          _showYearGrid = false;
                        });
                      },
                    )
                  : _buildMonthGrid(colors),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('month-year-picker-cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(ColorScheme colors) {
    return Column(
      key: const Key('month-year-picker-month-grid'),
      children: [
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 3; column++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _buildMonthButton(colors, row * 3 + column + 1),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMonthButton(ColorScheme colors, int month) {
    final isSelected =
        _selectedYear == widget.initialMonth.year &&
        month == widget.initialMonth.month;

    return Semantics(
      label: '${_fullMonths[month - 1]} de $_selectedYear',
      child: OutlinedButton(
        key: Key('month-year-picker-month-$month'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          backgroundColor: isSelected ? colors.primaryContainer : null,
          foregroundColor: isSelected
              ? colors.onPrimaryContainer
              : colors.onSurface,
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
          ),
        ),
        onPressed: () {
          _selectMonth(month);
        },
        child: Text(
          _months[month - 1],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
