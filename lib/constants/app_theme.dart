import 'package:flutter/material.dart';
import '../models/relationship.dart';

// ----------------------------------------------------------------
// Palette
// ----------------------------------------------------------------
const Color kBg           = Color(0xFF0D0F14);
const Color kSurface      = Color(0xFF161922);
const Color kSurface2     = Color(0xFF1E2330);
const Color kBorder       = Color(0xFF2A3045);
const Color kAccent       = Color(0xFF4F9EFF);
const Color kAccentRed    = Color(0xFFFF6B6B);
const Color kAccentGreen  = Color(0xFF6BFFB8);
const Color kAccentOrange = Color(0xFFFFAA4F);
const Color kAccentPurple = Color(0xFFB56BFF);
const Color kText         = Color(0xFFE8ECF0);
const Color kText2        = Color(0xFF8892A4);
const Color kText3        = Color(0xFF4A5568);

const Color kMaleColor    = Color(0xFF4F9EFF);
const Color kFemaleColor  = Color(0xFFFF6B9D);
const Color kUnknownColor = Color(0xFFA0AEC0);

// ----------------------------------------------------------------
// Node sizing
// ----------------------------------------------------------------
const double kNodeSize   = 52.0;
const double kNodeRadius = kNodeSize / 2;
const double kGenHeight  = 150.0;
const double kHSpacing   = 100.0;

// ----------------------------------------------------------------
// Relationship line colors
// ----------------------------------------------------------------
const Map<RelationshipType, Color> kRelationshipColors = {
  RelationshipType.married:         Color(0xFFE8ECF0),
  RelationshipType.partnership:     Color(0xFFE8ECF0),
  RelationshipType.separated:       Color(0xFFE8ECF0),
  RelationshipType.divorced:        Color(0xFFE8ECF0),
  RelationshipType.engaged:         Color(0xFFE8ECF0),
  RelationshipType.parentChild:     Color(0xFF8892A4),
  RelationshipType.sibling:         Color(0xFF8892A4),
  RelationshipType.close:           Color(0xFF4F9EFF),
  RelationshipType.veryClose:       Color(0xFF4F9EFF),
  RelationshipType.enmeshed:        Color(0xFFFFAA4F),
  RelationshipType.distant:         Color(0xFF4A5568),
  RelationshipType.conflicted:      Color(0xFFFF6B6B),
  RelationshipType.estranged:       Color(0xFFFF6B6B),
  RelationshipType.fusedConflicted: Color(0xFFFF9D4F),
  RelationshipType.abusive:         Color(0xFFCC2222),
};

// ----------------------------------------------------------------
// Flutter ThemeData
// ----------------------------------------------------------------
ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      secondary: kAccentGreen,
      surface: kSurface,
      error: kAccentRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kSurface,
      foregroundColor: kText,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kAccent,
        letterSpacing: 2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kSurface2,
        foregroundColor: kText,
        side: const BorderSide(color: kBorder),
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: kAccent),
      ),
      labelStyle: const TextStyle(color: kText2, fontSize: 12),
      hintStyle: const TextStyle(color: kText3, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dividerColor: kBorder,
    fontFamily: 'sans-serif',
  );
}
