import 'package:flutter/material.dart';
import 'package:noterly/widgets/expressive.dart';

class ItemListDecoration extends StatelessWidget {
  final Color colour;

  const ItemListDecoration({required this.colour, super.key});

  @override
  Widget build(BuildContext context) => ExpressiveColourBadge(colour: colour);
}
