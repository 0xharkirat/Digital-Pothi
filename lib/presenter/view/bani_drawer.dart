import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';

/// Leading drawer: the Sundar Gutka bani list (Japji, Jaap, Rehras, ...). Pick
/// one to load it as the shown sequence. Names show in Gurmukhi by default; the
/// header toggle switches to English.
class BaniDrawer extends StatelessWidget {
  const BaniDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<GurbaniDatabase>();
    final cubit = context.read<PresenterCubit>();
    final theme = Theme.of(context);
    final banis = db.banis();
    return Drawer(
      width: 320,
      child: SafeArea(
        child: BlocSelector<PresenterCubit, PresenterState, bool>(
          selector: (s) => s.englishBaniNames,
          builder: (context, english) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text('Banis', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    // Gurmukhi / English name toggle.
                    SegmentedButton<bool>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: false, label: Text('ਪੰ')),
                        ButtonSegment(value: true, label: Text('EN')),
                      ],
                      selected: {english},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        if (s.first != english) cubit.toggleBaniNames();
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 4),
                  itemCount: banis.length,
                  itemBuilder: (context, i) {
                    final b = banis[i];
                    return ListTile(
                      dense: true,
                      title: Text(
                        english ? b.english : b.gurmukhi,
                        style: english
                            ? theme.textTheme.bodyLarge
                            : context.gurbani.gurmukhi.copyWith(fontSize: 17),
                      ),
                      trailing: b.hasLengths
                          ? Tooltip(
                              message: 'Adjustable length',
                              child: Icon(
                                Icons.straighten,
                                size: 16,
                                color: context.gurbani.accent,
                              ),
                            )
                          : null,
                      onTap: () {
                        cubit.showBani(b);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
