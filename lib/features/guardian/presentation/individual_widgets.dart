import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/guardian_repository.dart';
import 'case_widgets.dart';
import 'guardian_components.dart';

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
                    padding: EdgeInsets.zero,
                    onPressed: () => setState(() {
                      _photo = AppServices.of(context).guardian
                          .photo(widget.id);
                    }),
                    icon: Icon(
                      Icons.person_outline,
                      size: widget.size * .5,
                      color: const Color(0xFF94A3B8),
                    ),
                  )
                : Center(
                    child: SizedBox.square(
                      dimension: widget.size * .3,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          );
        },
      ),
    ),
  );
}

/// Circular photo with the small amber "active case" badge from the approved
/// My Individuals design.
class IndividualAvatar extends StatelessWidget {
  const IndividualAvatar({
    super.key,
    required this.individual,
    this.activeCase,
    this.size = 64,
    this.revision = 0,
  });
  final Individual individual;

  /// The individual's active case, when known -- the badge takes that
  /// case's semantic status colour.
  final MissingCase? activeCase;
  final double size;
  final int revision;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IndividualPhoto(id: individual.id, size: size, revision: revision),
      if (individual.activeCaseId != null)
        PositionedDirectional(
          end: 0,
          bottom: 2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: activeCase == null
                  ? AppColors.primary
                  : caseStatusColor(activeCase!.status),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
    ],
  );
}

/// My Individuals list card: photo, name, age and a chevron open the profile;
/// below the divider, the individual's current state -- a filled red Report
/// Missing action, or the amber Active Case indicator with its real case id.
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
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return GuardianPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IndividualAvatar(
                    individual: individual,
                    activeCase: activeCase,
                    size: 64,
                    revision: revision,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          individual.fullName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${s.age}: ${individual.age}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: mutedText,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
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
}

/// Compact Home grid card: centered photo, name, age chip and one
/// state-dependent control (Report Missing / Active Case).
class HomeIndividualCard extends StatelessWidget {
  const HomeIndividualCard({
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
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return GuardianPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
          child: Column(
            children: [
              IndividualAvatar(
                individual: individual,
                activeCase: activeCase,
                size: 76,
                revision: revision,
              ),
              const SizedBox(height: 12),
              Text(
                individual.fullName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${s.age}: ${individual.age}',
                  style: const TextStyle(fontSize: 12, color: mutedText),
                ),
              ),
              const SizedBox(height: 10),
              ReportMissingAction(
                individual: individual,
                activeCase: activeCase,
                onChanged: onChanged,
                variant: ReportMissingVariant.chip,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    return GuardianPanel(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 28,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.emptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5, color: mutedText),
          ),
        ],
      ),
    );
  }
}
