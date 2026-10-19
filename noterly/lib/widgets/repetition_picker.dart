import 'package:flutter/material.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/models/repetition_data.dart';
import 'package:noterly/theme/app_theme.dart';
import 'package:noterly/widgets/expressive.dart';

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
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpressiveDialogHeader(
            icon: Icons.repeat,
            title: Strings.of(context).dialog_picker_repetition_title,
            subtitle: Strings.of(context).dialog_picker_repetition_subtitle(_repetitionData.toReadableString()),
          ),
          _getMainSection(),
          if (_repetitionData.type == Repetition.weekly) _getWeekdaySection(),
          ExpressiveDialogActions(
            children: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(Strings.of(context).general_cancel),
              ),
              FilledButton(
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
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Row(
          children: [
            Flexible(
              flex: 1,
              child: TextField(
                decoration: InputDecoration(
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
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                dropdownColor: Theme.of(context).colorScheme.surfaceContainer,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
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
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final index = (firstDay + i) % 7;
              final weekday = RepetitionData.weekdayFromIndex(index);
              final selected = _repetitionData.weekdays.contains(weekday);

              // Selected days morph from a circle into a rounded square, the Material 3 Expressive way of showing a
              // selection through shape.
              final shape = RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(selected ? 12 : 20),
                side: selected ? BorderSide.none : BorderSide(color: colorScheme.outlineVariant),
              );

              // Seven toggles share the dialog's width; on narrow screens they shrink instead of overflowing.
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Semantics(
                      label: localisations.narrowWeekdays[index],
                      selected: selected,
                      button: true,
                      child: AnimatedContainer(
                        duration: AppTheme.motionMedium,
                        curve: AppTheme.springBouncyCurve,
                        decoration: ShapeDecoration(shape: shape, color: selected ? colorScheme.primary : Colors.transparent),
                        child: Material(
                          type: MaterialType.transparency,
                          shape: shape,
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
                                style: AppTheme.weighted(
                                  Theme.of(context).textTheme.labelLarge!.copyWith(color: selected ? colorScheme.onPrimary : colorScheme.onSurface),
                                  selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
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
