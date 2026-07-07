import 'package:flutter/material.dart';

class AppFontFamilies extends ThemeExtension<AppFontFamilies> {
  const AppFontFamilies({
    required this.body,
    required this.heading,
    required this.decorative,
    required this.roundedDisplay,
    required this.playfulDisplay,
  });

  static const bodyFallback = <String>[
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const interFamily = 'Inter';
  static const bricolageGrotesqueFamily = 'Bricolage Grotesque';
  static const pacificoFamily = 'Pacifico';
  static const chironGoRoundTcFamily = 'Chiron GoRound TC';
  static const grandstanderFamily = 'Grandstander';

  static String get inter => interFamily;
  static String get bricolageGrotesque => bricolageGrotesqueFamily;
  static String get pacifico => pacificoFamily;
  static String get grandstander => grandstanderFamily;

  static AppFontFamilies get defaults => AppFontFamilies(
    body: inter,
    heading: bricolageGrotesque,
    decorative: pacifico,
    roundedDisplay: chironGoRoundTcFamily,
    playfulDisplay: grandstander,
  );

  final String body;
  final String heading;
  final String decorative;
  final String roundedDisplay;
  final String playfulDisplay;

  @override
  AppFontFamilies copyWith({
    String? body,
    String? heading,
    String? decorative,
    String? roundedDisplay,
    String? playfulDisplay,
  }) {
    return AppFontFamilies(
      body: body ?? this.body,
      heading: heading ?? this.heading,
      decorative: decorative ?? this.decorative,
      roundedDisplay: roundedDisplay ?? this.roundedDisplay,
      playfulDisplay: playfulDisplay ?? this.playfulDisplay,
    );
  }

  @override
  AppFontFamilies lerp(ThemeExtension<AppFontFamilies>? other, double t) {
    if (other is! AppFontFamilies) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}
