import 'package:flutter/material.dart';

import '../utils/prompt_decks.dart';

class AppColors {
  static const Color ground = Color(0xFF14110E);          // Warm soot
  static const Color groundRaised = Color(0xFF1C1712);    // Card dark background
  static const Color oxblood = Color(0xFF8B0000);         // Primary accent/wrong/forgery
  static const Color brass = Color(0xFFC9A24B);           // Secondary accent/gold/brand
  static const Color verdigris = Color(0xFF2E6E5B);       // Tertiary/truth/correct
  static const Color parchment = Color(0xFFF4EBD8);       // Surface/paper
  static const Color ink = Color(0xFF2C1E16);             // Text on parchment
  static const Color ivory = Color(0xFFF5EEDB);           // Text on ground

  // ---------------------------------------------------------------------
  // Deck rating seals.
  //
  // WHICH rating a deck carries is data and lives in the deck definition
  // (functions/src/prompt_decks.ts). Only the COLOUR is a presentation
  // choice, so only the colour lives here.
  //
  // Adding a deck needs no change to this file. Adding a whole new rating
  // TIER needs exactly one line below — and the enum will not compile until
  // you add it, so it cannot be forgotten silently.
  // ---------------------------------------------------------------------
  static const Color sealPg = Color(0xFF7A6A3A);
  static const Color sealR = oxblood;
  static const Color sealX = Color(0xFF2A2226);

  static Color sealColorFor(DeckRating rating) {
    switch (rating) {
      case DeckRating.pg:
        return sealPg;
      case DeckRating.r:
        return sealR;
      case DeckRating.x:
        return sealX;
    }
  }

  /// The letter stamped on the seal, derived from the rating token so a new
  /// tier needs no label table.
  static String sealLabelFor(DeckRating rating) => rating.name.toUpperCase();
}
