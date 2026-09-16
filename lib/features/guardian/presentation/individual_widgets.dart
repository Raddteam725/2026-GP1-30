import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';

class IndividualPhoto extends StatefulWidget {
  const IndividualPhoto({
    super.key,
    required this.id,
    this.size = 64,
    this.revision = 0,
  });
  final String id;
  final double size;
  final int revision;
  @override
  State<IndividualPhoto> createState() => _IndividualPhotoState();
}

class _IndividualPhotoState extends State<IndividualPhoto> {
  Future<Uint8List>? _photo;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photo ??= AppServices.of(context).guardian.photo(widget.id);
  }

  @override
  void didUpdateWidget(IndividualPhoto old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.revision != widget.revision) {
      _photo = AppServices.of(context).guardian.photo(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: FutureBuilder<Uint8List>(
        future: _photo,
        builder: (context, state) {
          if (state.hasData) {
            return Image.memory(
              state.data!,
              fit: BoxFit.cover,
              gaplessPlayback: false,
            );
          }
          return ColoredBox(
            color: AppColors.lightBlue.withValues(alpha: .1),
            child: state.hasError
                ? IconButton(
                    tooltip: AppLocalizations.of(context)!.retry,
                    onPressed: () => setState(() {
                      _photo = AppServices.of(context).guardian
                          .photo(widget.id);
                    }),
                    icon: const Icon(Icons.refresh),
                  )
                : const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          );
        },
      ),
    ),
  );
}

class IndividualCard extends StatelessWidget {
  const IndividualCard({
    super.key,
    required this.individual,
    required this.onTap,
    required this.onChanged,
    this.activeCase,
    this.revision = 0,
  });
  final Individual individual;
  final MissingCase? activeCase;
  final VoidCallback onTap;
  final VoidCallback onChanged;
  final int revision;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IndividualPhoto(id: individual.id, revision: revision),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        individual.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.age}: ${individual.age}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ReportMissingAction(
            individual: individual,
            activeCase: activeCase,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

String genderLabel(String value, AppLocalizations s) =>
    value == 'female' ? s.female : s.male;
String relationshipLabel(String value, AppLocalizations s) => switch (value) {
  'child' => s.child,
  'parent' => s.parent,
  _ => s.other,
};

/// The relationship as shown to the Guardian: the real entered text when
/// `other` was selected, never just the generic "Other" label.
String relationshipDisplay(Individual individual, AppLocalizations s) =>
    individual.relationship == 'other' &&
        (individual.relationshipOther ?? '').isNotEmpty
    ? individual.relationshipOther!
    : relationshipLabel(individual.relationship, s);

class EmptyIndividuals extends StatelessWidget {
  const EmptyIndividuals({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.people_outline,
              size: 32,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              s.emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              s.emptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
