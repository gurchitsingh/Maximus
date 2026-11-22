import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../placeholder_body.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Column(
        children: [
          MxTabTopBar(title: 'Study list'),
          Expanded(
            child: PlaceholderBody(title: 'Study list', session: 'S6'),
          ),
        ],
      ),
    );
  }
}
