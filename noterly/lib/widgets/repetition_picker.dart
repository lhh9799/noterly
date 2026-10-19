import 'package:flutter/material.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/models/repetition_data.dart';

Future<RepetitionData?> showRepetitionPicker({
  required BuildContext context,
  required RepetitionData initialRepetitionData,
}) async {
  var dialog = RepetitionPicker(
    initialRepetitionData: initialRepetitionData,
  );

  return showDialog<RepetitionData>(
    context: context,
    builder: (context) => dialog,
  );
}

class RepetitionPicker extends StatefulWidget {
  final RepetitionData initialRepetitionData;

  const RepetitionPicker({
    required this.initialRepetitionData,
    super.key,
  });

  @override
  State<RepetitionPicker> createState() => _RepetitionPickerState();
}

class _RepetitionPickerState extends State<RepetitionPicker> {
  late RepetitionData _repetitionData;

  late TextEditingController _intervalController;

  @override
  void initState() {
    super.initState();

    _intervalController = TextEditingController(text: widget.initialRepetitionData.number.toString());

    _repetitionData = widget.initialRepetitionData.copy(); // Copy so that Cancel leaves the original unchanged
  }

  @override
  void dispose() {
    _intervalController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // The header should use the primary color in light themes and surface color in dark
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final Color primarySurfaceColor = isDark ? colorScheme.surface : colorScheme.primary;
    final Color onPrimarySurfaceColor = isDark ? colorScheme.onSurface : colorScheme.onPrimary;

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              color: primarySurfaceColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.of(context).dialog_picker_repetition_title,
                  style: Theme.of(context).textTheme.titleLarge!.copyWith(color: onPrimarySurfaceColor),
                ),
                Text(
                  Strings.of(context).dialog_picker_repetition_subtitle(_repetitionData.toReadableString()),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(color: onPrimarySurfaceColor),
                ),
              ],
            ),
          ),
          _getMainSection(),
          if (_repetitionData.type == Repetition.weekly) _getWeekdaySection(),
          ButtonBar(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(Strings.of(context).general_cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(_repetitionData);
                },
                child: Text(Strings.of(context).general_ok),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getMainSection() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Flexible(
              flex: 1,
              child: TextField(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: Strings.of(context).dialog_picker_repetition_field_number_label,
                ),
                controller: _intervalController,
                onChanged: (value) {
                  if (value.isEmpty) return;

                  var number = int.tryParse(value);
                  if (number == null) return;
                  if (number < 1) number = 1;

                  setState(() {
                    _repetitionData.number = number!;
                  });
                },
                onSubmitted: (value) {
                  var number = int.tryParse(value) ?? 1;
                  if (number < 1) number = 1;

                  setState(() {
                    _repetitionData.number = number;
                    _intervalController.text = number.toString();
                  });
                },
                onEditingComplete: () {},
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              flex: 2,
              child: DropdownButtonFormField(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: Strings.of(context).dialog_picker_repetition_field_period_label,
                ),
                items: [
                  DropdownMenuItem(value: Repetition.hourly, child: Text(Strings.of(context).time_hours(_repetitionData.number))),
                  DropdownMenuItem(value: Repetition.daily, child: Text(Strings.of(context).time_days(_repetitionData.number))),
                  DropdownMenuItem(value: Repetition.weekly, child: Text(Strings.of(context).time_weeks(_repetitionData.number))),
                  DropdownMenuItem(value: Repetition.monthly, child: Text(Strings.of(context).time_months(_repetitionData.number))),
                  DropdownMenuItem(value: Repetition.yearly, child: Text(Strings.of(context).time_years(_repetitionData.number))),
                ],
                value: _repetitionData.type,
                onChanged: (value) {
                  setState(() {
                    _repetitionData.type = value!;
                  });
                },
              ),
            ),
          ],
        ),
      );

  /// Day-of-week toggles for weekly repetition, like the alarms in a clock app.
  Widget _getWeekdaySection() {
    final localisations = MaterialLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final firstDay = localisations.firstDayOfWeekIndex; // 0 = Sunday

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final index = (firstDay + i) % 7;
              final weekday = RepetitionData.weekdayFromIndex(index);
              final selected = _repetitionData.weekdays.contains(weekday);

              return SizedBox(
                width: 36,
                height: 36,
                child: Semantics(
                  label: localisations.narrowWeekdays[index],
                  selected: selected,
                  child: Material(
                    shape: CircleBorder(side: BorderSide(color: selected ? colorScheme.primary : colorScheme.outline)),
                    color: selected ? colorScheme.primary : Colors.transparent,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(() {
                        if (selected) {
                          _repetitionData.weekdays.remove(weekday);
                        } else {
                          _repetitionData.weekdays.add(weekday);
                        }
                      }),
                      child: Center(
                        child: Text(
                          localisations.narrowWeekdays[index],
                          style: TextStyle(color: selected ? colorScheme.onPrimary : colorScheme.onSurface),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
