# Radd

Shared foundation for the existing portrait Android Flutter application.
The initial route is intentionally blank pending approved Stitch screens.

- lib/app/: application composition and optional locale override.
- lib/core/theme/: brand colors, locale-aware typography and control defaults.
- lib/core/localization/arb/: English and Arabic source strings.
- lib/core/localization/generated/: generated code; do not edit manually.
- lib/core/routing/: route factory and reserved feature paths.
- lib/shared/widgets/: buttons, form inputs, card, loading and spacing.
- lib/features/{onboarding,auth,guardian}/presentation/: future screens.
- assets/images/ and assets/icons/: approved assets only; no logo supplied.
- assets/fonts/: bundled Inter and Tajawal with SIL Open Font licenses.

Use 360 x 800 dp as a comparison reference, not a fixed canvas. Future screens
should use constraints, SafeArea, scrolling, directional padding/alignment and
support text scaling. Shared sizes/radii are provisional defaults to refine
against Stitch references. No feature screen design has been inferred.

RaddApp() follows the device locale, falling back to English. Pass
locale: Locale('ar') for Arabic, RTL and Tajawal; English uses LTR and Inter.
Add strings to both ARB files and run flutter gen-l10n.
Register approved screen builders in AppRouter.onGenerateRoute with AppRoutes.
Feature paths are reserved; unregistered routes show a localized fallback.

Inputs support Form validation. Owners dispose controllers and focus nodes.
Loading buttons reject taps. In a Row, wrap buttons in Expanded or set expand
false. No backend, Firebase, Volunteer or Admin is implemented.

Validation: flutter pub get, flutter gen-l10n, dart format lib test,
flutter analyze, flutter test.
# Raad
welcome to the club
hi gus this is tala trying to fix this 
test 12
hi again
LLLL
