import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../features/guardian/data/guardian_repository.dart';

class FeaturePage extends StatelessWidget {
  const FeaturePage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.headerInBody = false,
    this.showAppBar = true,
    this.centerTitle = true,
    this.actions,
    this.bottomNavigationBar,
    this.controller,
  });
  final String title;
  final bool headerInBody, centerTitle, showAppBar;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9FBFD),
    appBar: !showAppBar
        ? null
        : AppBar(
            centerTitle: centerTitle,
            title: headerInBody
                ? null
                : Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
            backgroundColor: const Color(0xFFF9FBFD),
            actions: actions,
          ),
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      top: !showAppBar,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            children: [
              if (subtitle != null) ...[
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
              ],
              ...children,
            ],
          ),
        ),
      ),
    ),
  );
}

String failureMessage(Object error, AppLocalizations s) =>
    switch (error is AppFailure ? error.code : 'service') {
      'eventUnavailable' => s.eventUnavailable,
      'profilePending' => s.sessionUnavailable,
      'credentials' => s.invalidCredentials,
      'emailExists' => s.emailExists,
      'network' => s.networkError,
      'rateLimit' => s.rateLimit,
      'role' => s.roleError,
      'notFound' => s.notFoundError,
      'conflict' => s.activeCaseError,
      'activeCase' => s.activeCaseError,
      'caseClosed' => s.caseClosedActionError,
      'reportAlreadySubmitted' => s.reportAlreadySubmitted,
      'photoExpired' => s.photoExpiredError,
      'password' => s.passwordHelp,
      'validation' => s.validationError,
      'unauthorized' => s.sessionExpired,
      'accountInactive' => s.accountDeactivated,
      'retentionPassed' => s.retentionPassedError,
      'retentionInvalid' => s.retentionInvalidError,
      _ => s.serviceError,
    };

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: const TextStyle(color: AppColors.error)),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
        ],
      ),
    ),
  );
}
