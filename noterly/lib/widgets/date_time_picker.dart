import 'package:flutter/material.dart';
import 'package:noterly/extensions/date_time_extensions.dart';
import 'package:noterly/extensions/time_of_day_extensions.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/theme/app_theme.dart';
import 'package:noterly/widgets/expressive.dart';

import '../managers/log.dart';

Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDateTime,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  firstDate = DateUtils.dateOnly(firstDate);
  lastDate = DateUtils.dateOnly(lastDate);
  assert(
    !lastDate.isBefore(firstDate),
    'lastDate $lastDate must be on or after firstDate $firstDate.',
  );
  assert(
    !initialDateTime.isBefore(firstDate),
    'initialDateTime $initialDateTime must be on or after firstDate $firstDate.',
  );
  assert(
    !initialDateTime.isAfter(lastDate),
    'initialDateTime $initialDateTime must be on or before lastDate $lastDate.',
  );

  var dialog = DateTimePicker(
    initialDate: initialDateTime,
    firstDate: firstDate,
    lastDate: lastDate,
  );

  return showDialog<DateTime>(
    context: context,
    builder: (context) => dialog,
  );
}

class DateTimePicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const DateTimePicker({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    super.key,
  });

  @override
  State<DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  late DateTime _dateTime;

  @override
  void initState() {
    super.initState();

    _dateTime = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExpressiveDialogHeader(
            icon: Icons.event,
            title: Strings.of(context).dialog_picker_dateTime_title,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(Strings.of(context).dialog_picker_dateTime_header_date, style: _getSectionStyle()),
          ),
          _getDatePicker(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(Strings.of(context).dialog_picker_dateTime_header_time, style: _getSectionStyle()),
          ),
          _getTimePicker(),
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
                  Navigator.of(context).pop(_dateTime);
                },
                child: Text(Strings.of(context).general_ok),
              ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _getSectionStyle() => Theme.of(context).textTheme.titleSmall!.copyWith(color: Theme.of(context).colorScheme.primary);

  /// The date or time between the step buttons, animated when it changes.
  Widget _getValue(String text) => Expanded(
        child: AnimatedSwitcher(
          duration: AppTheme.motionFast,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
          ),
          child: Text(
            text,
            key: ValueKey(text),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );

  Widget _getDatePicker() => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    var newDateTime = _dateTime.subtract(const Duration(days: 1));
                    if (newDateTime.isAfter(widget.firstDate)) {
                      _dateTime = newDateTime;
                    }
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              _getValue(_dateTime.toDateOnlyString()),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    var newDateTime = _dateTime.add(const Duration(days: 1));
                    if (newDateTime.isBefore(widget.lastDate)) {
                      _dateTime = newDateTime;
                    }
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 16),
            ],
          ),
          TextButton.icon(
            onPressed: () {
              showDatePicker(
                context: context,
                initialDate: _dateTime,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
              ).then((value) {
                if (value != null) {
                  setState(() {
                    _dateTime = value;
                  });
                }
              });
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(Strings.of(context).dialog_picker_dateTime_button_selectDate),
          ),
        ],
      );

  Widget _getTimePicker() => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    var newDateTime = _dateTime.subtract(const Duration(hours: 1));
                    if (!newDateTime.isAfter(widget.firstDate)) return;
                    if (newDateTime.isBefore(DateTime.now())) newDateTime = DateTime.now();

                    _dateTime = newDateTime;
                  });
                },
                icon: const Icon(Icons.remove),
              ),
              _getValue(_dateTime.toTimeOnlyString()),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() {
                    var newDateTime = _dateTime.add(const Duration(hours: 1));
                    if (!newDateTime.isBefore(widget.lastDate)) return;
                    _dateTime = newDateTime;
                  });
                },
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 16),
            ],
          ),
          TextButton.icon(
            onPressed: () {
              showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_dateTime),
                initialEntryMode: TimePickerEntryMode.input, // Type the time with the number keypad
              ).then((value) {
                if (value != null) {
                  setState(() {
                    if (_dateTime.isToday() && !value.isAfterNow()) {
                      Log.logger.d('Invalid time, ignoring.');
                      return;
                    }

                    _dateTime = DateTime(
                      _dateTime.year,
                      _dateTime.month,
                      _dateTime.day,
                      value.hour,
                      value.minute,
                    );
                  });
                }
              });
            },
            icon: const Icon(Icons.timer),
            label: Text(Strings.of(context).dialog_picker_dateTime_button_selectTime),
          ),
        ],
      );
}
