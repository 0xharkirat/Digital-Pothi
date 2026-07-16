import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../data/preferences.dart';
import '../../overlay/overlay_cubit.dart';
import '../../overlay/overlay_server.dart';
import '../../tracking/cubit/tracking_cubit.dart';
import '../cubit/presenter_cubit.dart';
import 'presenter_view.dart';

/// Provides the presenter's two cubits over the app-scoped corpus: the
/// [PresenterCubit] (search + the shown line) and the [TrackingCubit] (the AI
/// mic/file follow that feeds it).
class PresenterPage extends StatelessWidget {
  const PresenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.read<GurbaniDatabase>();
    final prefs = context.read<Preferences>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => PresenterCubit(db, prefs)),
        BlocProvider(create: (_) => TrackingCubit(database: db)),
        BlocProvider(create: (_) => OverlayCubit(OverlayServer())),
      ],
      child: const PresenterView(),
    );
  }
}
