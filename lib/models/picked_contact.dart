import 'package:flutter/foundation.dart';

/// Contact choisi dans le répertoire du téléphone (écran 07).
/// Sert à pré-remplir le formulaire d'ajout de client.
@immutable
class PickedContact {
  const PickedContact({
    required this.nom,
    required this.prenom,
    required this.telephone,
  });

  final String nom;
  final String prenom;
  final String telephone;
}
