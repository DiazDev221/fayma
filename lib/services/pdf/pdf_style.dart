import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/operation.dart';
import '../../utils/format.dart';

/// Palette et éléments communs aux documents PDF.
class PdfStyle {
  PdfStyle._();

  static const ink = PdfColor.fromInt(0xFF101828);
  static const inkSoft = PdfColor.fromInt(0xFF273247);
  static const textSecondary = PdfColor.fromInt(0xFF5D6675);
  static const border = PdfColor.fromInt(0xFFE1E5DF);
  static const surface = PdfColor.fromInt(0xFFFFFFFF);
  static const surfaceMuted = PdfColor.fromInt(0xFFF0F3EF);

  static const mint = PdfColor.fromInt(0xFF087A55);
  static const mintDark = PdfColor.fromInt(0xFF066B4A);
  static const mintBright = PdfColor.fromInt(0xFF5FE3B4);
  static const mintSoft = PdfColor.fromInt(0xFFE7F8F1);

  static const coral = PdfColor.fromInt(0xFFCC2418);
  static const coralSoft = PdfColor.fromInt(0xFFFEECEB);

  static const indigo = PdfColor.fromInt(0xFF4F5BD5);
  static const indigoSoft = PdfColor.fromInt(0xFFEEF0FF);
}

/// Polices embarquées dans les PDF pour conserver l'identité de l'application.
class PdfFonts {
  PdfFonts._();

  static Future<pw.Font>? _regular;
  static Future<pw.Font>? _bold;

  static Future<pw.Font> regular() =>
      _regular ??= _load('assets/fonts/Manrope-Regular.ttf');

  static Future<pw.Font> bold() =>
      _bold ??= _load('assets/fonts/Manrope-Bold.ttf');

  static Future<pw.Font> _load(String asset) async {
    final data = await rootBundle.load(asset);
    return pw.Font.ttf(data);
  }
}

/// Montant lisible dans un PDF (l'espace insécable est remplacé pour éviter
/// toute confusion avec un glyphe manquant).
String pdfFcfa(int amount) => formatFcfa(amount).replaceAll('\u00A0', ' ');

String pdfSignedFcfa(int amount) =>
    formatSignedFcfa(amount).replaceAll('\u00A0', ' ');

String pdfDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

String pdfDateTime(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${pdfDate(date)} à ${two(date.hour)}:${two(date.minute)}';
}

String operationTypeLabel(OperationType type) {
  return switch (type) {
    OperationType.credit => 'Achat à crédit',
    OperationType.repayment => 'Remboursement',
    OperationType.deposit => 'Dépôt',
  };
}

String operationLabel(Operation operation) {
  final base = operationTypeLabel(operation.type);
  final label = operation.isReversal ? 'Annulation · $base' : base;
  final method = operation.paymentMethod;
  return method == null ? label : '$label · ${method.label}';
}

/// En-tête sombre commun à tous les documents.
pw.Widget pdfBrandHeader({
  required String title,
  required String subtitle,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(18),
    decoration: pw.BoxDecoration(
      color: PdfStyle.ink,
      borderRadius: pw.BorderRadius.circular(14),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 42,
          height: 42,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: PdfStyle.inkSoft,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Text(
            'F',
            style: const pw.TextStyle(
              color: PdfStyle.mintBright,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FAYMA',
                style: const pw.TextStyle(
                  color: PdfStyle.surface,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Gestion de crédit · Boutique de quartier',
                style: const pw.TextStyle(
                  color: PdfColor(1, 1, 1, 0.66),
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              title,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(
                color: PdfStyle.surface,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(
                color: PdfStyle.mintBright,
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Petit rappel coloré (annulation, information, etc.).
pw.Widget pdfNotice({
  required String title,
  required String message,
  PdfColor color = PdfStyle.indigo,
  PdfColor background = PdfStyle.indigoSoft,
}) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: color, width: 0.6),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 14,
          height: 14,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
          child: pw.Text(
            '!',
            style: const pw.TextStyle(
              color: PdfStyle.surface,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                message,
                style: const pw.TextStyle(
                  color: PdfStyle.inkSoft,
                  fontSize: 8.5,
                  lineSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Bloc libellé / valeurs (client, document, etc.).
pw.Widget pdfInfoBlock({
  required String label,
  required List<String> lines,
  pw.CrossAxisAlignment alignment = pw.CrossAxisAlignment.start,
}) {
  return pw.Column(
    crossAxisAlignment: alignment,
    children: [
      pw.Text(
        label.toUpperCase(),
        textAlign: alignment == pw.CrossAxisAlignment.end
            ? pw.TextAlign.right
            : pw.TextAlign.left,
        style: const pw.TextStyle(
          color: PdfStyle.textSecondary,
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      pw.SizedBox(height: 4),
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) pw.SizedBox(height: 2),
        pw.Text(
          lines[i],
          textAlign: alignment == pw.CrossAxisAlignment.end
              ? pw.TextAlign.right
              : pw.TextAlign.left,
          style: pw.TextStyle(
            color: i == 0 ? PdfStyle.ink : PdfStyle.textSecondary,
            fontSize: i == 0 ? 11 : 9,
            fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ],
  );
}

/// Titre de section.
pw.Widget pdfSectionTitle(String title, {String? subtitle}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title,
        style: const pw.TextStyle(
          color: PdfStyle.ink,
          fontSize: 12.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      if (subtitle != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(
            color: PdfStyle.textSecondary,
            fontSize: 8.5,
          ),
        ),
      ],
    ],
  );
}

/// Cellule de tableau.
pw.Widget pdfCell(
  String text, {
  pw.TextAlign align = pw.TextAlign.left,
  bool bold = false,
  PdfColor color = PdfStyle.ink,
  double fontSize = 8.5,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Pied de page : génération et pagination.
pw.Widget pdfPageFooter(pw.Context context, DateTime generatedAt) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.only(top: 7),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfStyle.border, width: 0.6),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Fayma · Document généré le ${pdfDateTime(generatedAt)}',
          style: const pw.TextStyle(
            color: PdfStyle.textSecondary,
            fontSize: 7.5,
          ),
        ),
        pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(
            color: PdfStyle.textSecondary,
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

/// En-tête discret des pages suivantes.
pw.Widget pdfContinuationHeader(String title) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfStyle.border, width: 0.6),
      ),
    ),
    child: pw.Row(
      children: [
        pw.Text(
          'FAYMA',
          style: const pw.TextStyle(
            color: PdfStyle.mintDark,
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(
            title,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
              color: PdfStyle.textSecondary,
              fontSize: 8,
            ),
          ),
        ),
      ],
    ),
  );
}
