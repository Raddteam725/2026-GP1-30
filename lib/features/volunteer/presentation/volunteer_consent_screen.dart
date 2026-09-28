import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/api_volunteer_repository.dart';
import 'volunteer_components.dart';

// These versions identify the full, reviewed bilingual documents bundled here.
// A server version change cannot cause acceptance of unseen document content.
const volunteerTermsVersion = 'draft-2026-09';
const volunteerPrivacyVersion = 'draft-2026-09';

class VolunteerConsentGate extends StatelessWidget {
  const VolunteerConsentGate({
    super.key,
    required this.repository,
    required this.onLogout,
    required this.childBuilder,
  });
  final ApiVolunteerRepository repository;
  final Future<void> Function() onLogout;
  final WidgetBuilder childBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repository,
    builder: (context, _) => repository.consentCurrent
        ? childBuilder(context)
        : VolunteerConsentScreen(repository: repository, onLogout: onLogout),
  );
}

class VolunteerConsentScreen extends StatefulWidget {
  const VolunteerConsentScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });
  final ApiVolunteerRepository repository;
  final Future<void> Function() onLogout;
  @override
  State<VolunteerConsentScreen> createState() => _VolunteerConsentScreenState();
}

class _VolunteerConsentScreenState extends State<VolunteerConsentScreen> {
  bool _accepted = false, _busy = false, _failed = false;

  Future<void> _accept() async {
    if (!_accepted || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.repository.acceptConsent(
        volunteerTermsVersion,
        volunteerPrivacyVersion,
      );
    } catch (error) {
      debugPrint('Radd Volunteer consent failed (${error.runtimeType})');
      // Refresh required versions after a stale-version response, without
      // recording acceptance or granting any event/location access.
      try {
        await widget.repository.loadProfile();
      } catch (_) {}
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    final supported =
        widget.repository.requiredTermsVersion == volunteerTermsVersion &&
        widget.repository.requiredPrivacyVersion == volunteerPrivacyVersion;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: volunteerCanvas,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              VolunteerHeading(s.vConsentTitle, large: true),
              const SizedBox(height: 16),
              Text(s.vConsentIntro),
              const SizedBox(height: 16),
              Text(
                s.vDevelopmentPolicy,
                style: const TextStyle(color: AppColors.text),
              ),
              const SizedBox(height: 24),
              VolunteerCard(child: Text(s.vConsentConditions)),
              const VolunteerPolicyLinks(),
              const SizedBox(height: 12),
              if (!supported) Text(s.vConsentUnavailable),
              CheckboxListTile(
                key: const Key('volunteer-consent-checkbox'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _accepted,
                onChanged: _busy || !supported
                    ? null
                    : (value) => setState(() => _accepted = value == true),
                title: Text(s.vConsentCheckbox),
              ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(s.vActionFailed),
                ),
              FilledButton(
                key: const Key('volunteer-consent-continue'),
                onPressed: !_accepted || _busy || !supported ? null : _accept,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.vConsentContinue),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : widget.onLogout,
                child: Text(s.vConsentNotNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VolunteerPolicyLinks extends StatelessWidget {
  const VolunteerPolicyLinks({super.key});
  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    return VolunteerCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final terms in [true, false])
            ListTile(
              title: Text(terms ? s.vTermsTitle : s.vPrivacyTitle),
              subtitle: Text(
                terms ? volunteerTermsVersion : volunteerPrivacyVersion,
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.secondary,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VolunteerPolicyScreen(terms: terms),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VolunteerPolicyScreen extends StatelessWidget {
  const VolunteerPolicyScreen({super.key, required this.terms});
  final bool terms;
  @override
  Widget build(BuildContext context) {
    final s = stringsOf(context);
    final text = terms ? s.vTermsDocument : s.vPrivacyDocument;
    return Scaffold(
      appBar: AppBar(title: Text(terms ? s.vTermsTitle : s.vPrivacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(s.vDevelopmentPolicy),
            const SizedBox(height: 8),
            Text(terms ? volunteerTermsVersion : volunteerPrivacyVersion),
            const SizedBox(height: 24),
            for (final paragraph in text.split('\n\n'))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: paragraph.startsWith('### ')
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          VolunteerHeading(
                            paragraph.split('\n').first.substring(4),
                          ),
                          const SizedBox(height: 8),
                          Text(paragraph.split('\n').skip(1).join(' ')),
                        ],
                      )
                    : Text(paragraph.replaceAll('\n', ' ')),
              ),
          ],
        ),
      ),
    );
  }
}
