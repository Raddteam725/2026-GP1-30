import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../shared/widgets/feature_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/app_text_input.dart';
import '../../auth/presentation/form_validation.dart';
import '../data/guardian_repository.dart';
import 'guardian_components.dart';
import '../../../core/theme/app_colors.dart';

class EditGuardianProfileScreen extends StatefulWidget {
  const EditGuardianProfileScreen({super.key, required this.profile});
  final GuardianProfile profile;
  @override
  State<EditGuardianProfileScreen> createState() =>
      _EditGuardianProfileScreenState();
}

class _EditGuardianProfileScreenState extends State<EditGuardianProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName),
      _phone = TextEditingController(text: widget.profile.phone);
  bool _busy = false;
  Object? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.of(context).guardian
          .updateProfile(_name.text, _phone.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: FeaturePage(
        title: s.editProfile,
        bottomNavigationBar: GuardianNavigation(selected: 4, enabled: !_busy),
        children: [
          GuardianSummary(name: widget.profile.fullName),
          const SizedBox(height: 24),
          GuardianPanel(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.accountInformation,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppTextInput(
                    label: s.fullName,
                    prefixIcon: const Icon(Icons.person_outline),
                    controller: _name,
                    enabled: !_busy,
                    validator: (v) => FormValidation.name(v, s),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  AppTextInput(
                    label: s.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    controller: _phone,
                    enabled: !_busy,
                    validator: (v) => FormValidation.phone(v, s),
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.phoneHelp,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    s.email,
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.profile.email,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.emailReadOnly,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_error != null) ErrorNotice(message: failureMessage(_error!, s)),
          PrimaryButton(
            label: s.saveChanges,
            onPressed: _save,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}
