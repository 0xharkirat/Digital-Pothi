import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../cubit/tracking_cubit.dart';
import 'tracking_view.dart';

/// Provides the [TrackingCubit] over the app-scoped corpus. No bani is chosen
/// up front - the cubit discovers what's being recited.
class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrackingCubit(database: context.read<GurbaniDatabase>()),
      child: const TrackingView(),
    );
  }
}
