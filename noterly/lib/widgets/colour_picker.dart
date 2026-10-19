import 'package:flutter/material.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/theme/app_theme.dart';
import 'package:noterly/widgets/expressive.dart';

Future<Color?> showColourPicker({
  required BuildContext context,
  required Color initialColour,
}) async {
  var dialog = ColourPicker(
    initialColour: initialColour,
  );

  return showDialog<Color>(
    context: context,
    builder: (context) => dialog,
  );
}

Map<String, Color> colours = {
  'red': Colors.red,
  'green': Colors.green,
  'blue': Colors.blue,
  'purple': Colors.purple,
  'pink': Colors.pink,
  'orange': Colors.orange,
  'yellow': Colors.yellow,
  'teal': Colors.teal,
  'cyan': Colors.cyan,
  'indigo': Colors.indigo,
  'brown': Colors.brown,
  'grey': Colors.grey,
};

class ColourPicker extends StatefulWidget {
  static const Map<String, Color> colours = {
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'orange': Colors.orange,
    'yellow': Colors.yellow,
    'teal': Colors.teal,
    'cyan': Colors.cyan,
    'indigo': Colors.indigo,
    'brown': Colors.brown,
    'grey': Colors.grey,
  };

  final Color initialColour;

  const ColourPicker({
    required this.initialColour,
    super.key,
  });

  @override
  State<ColourPicker> createState() => _ColourPickerState();
}

class _ColourPickerState extends State<ColourPicker> {
  late Color _colour;

  @override
  void initState() {
    super.initState();

    _colour = widget.initialColour;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExpressiveDialogHeader(
              icon: Icons.palette,
              title: Strings.of(context).dialog_picker_colour_title,
            ),
            GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 64,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: colours.length,
              itemBuilder: (context, index) {
                var colour = colours.values.elementAt(index);
                var selected = _colour == colour;
                // The selected colour morphs from a circle into a rounded square, the Material 3 Expressive way of
                // showing a selection through shape.
                var shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(selected ? 18 : 32));

                return Semantics(
                  label: colours.keys.elementAt(index),
                  selected: selected,
                  button: true,
                  child: AnimatedContainer(
                    duration: AppTheme.motionMedium,
                    curve: AppTheme.springBouncyCurve,
                    decoration: ShapeDecoration(color: colour, shape: shape),
                    child: Material(
                      type: MaterialType.transparency,
                      shape: shape,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          setState(() => _colour = colour);
                          Navigator.of(context).pop(colour);
                        },
                        child: selected
                            ? Icon(Icons.check, color: ThemeData.estimateBrightnessForColor(colour) == Brightness.dark ? Colors.white : Colors.black)
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
            ExpressiveDialogActions(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(Strings.of(context).general_cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
