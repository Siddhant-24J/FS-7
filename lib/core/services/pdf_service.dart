import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/client_model.dart';
import '../../data/models/assessment_model.dart';
import '../../data/models/plan_model.dart';

class PdfService {
  PdfService._();

  static Future<Uint8List> generateConsentPdf({
    required ClientModel client,
    required String consentText,
    required Uint8List memberSignature,
    required Uint8List trainerSignature,
  }) async {
    final pdf = pw.Document();

    final memberSigImage = pw.MemoryImage(memberSignature);
    final trainerSigImage = pw.MemoryImage(trainerSignature);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FS-7 FITNESS',
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    pw.Text('Informed Consent & Waiver',
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.orange800),
                pw.SizedBox(height: 14),
                pw.Text('Member Details:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Name: ${client.fullName}'),
                pw.Text('Phone: ${client.phonePrimary}'),
                pw.Text('Program: ${client.programType}'),
                pw.SizedBox(height: 16),
                pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text(
                  consentText.replaceAll('{CLIENT_NAME}', client.fullName),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 50,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                          child: pw.Image(memberSigImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Member Signature', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                          width: 140,
                          height: 50,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                          child: pw.Image(trainerSigImage, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text('Trainer Signature', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text('FS-7 Fitness — Signed on ${DateTime.now().toString().split(' ')[0]}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateTransformationReportPdf({
    required ClientModel client,
    required SubscriptionModel subscription,
    required AssessmentModel baseline,
    required AssessmentModel? finalAssessment,
    required int completedSessions,
    required double attendancePercent,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FS-7 TRANSFORMATION REPORT',
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    pw.Text(client.fullName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColors.orange800),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Attendance: $completedSessions / ${subscription.totalSessions} sessions (${attendancePercent.toStringAsFixed(0)}%)'),
                    pw.Text('Goal: ${baseline.goal ?? "General Fitness"}'),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Text('Baseline FS-7 Score', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('${baseline.fs7Score?.toStringAsFixed(0) ?? "—"} / 100',
                              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                        ],
                      ),
                      if (finalAssessment != null)
                        pw.Column(
                          children: [
                            pw.Text('Final FS-7 Score', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('${finalAssessment.fs7Score?.toStringAsFixed(0) ?? "—"} / 100',
                                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                          ],
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Metrics Comparison', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: ['Metric', 'Baseline', 'Final', 'Change'],
                  data: [
                    ['Weight (kg)', '${baseline.weightKg ?? "—"}', '${finalAssessment?.weightKg ?? "—"}',
                      finalAssessment?.weightKg != null && baseline.weightKg != null
                        ? '${(finalAssessment!.weightKg! - baseline.weightKg!).toStringAsFixed(1)} kg'
                        : '—'],
                    ['Waist (cm)', '${baseline.waistWidest ?? "—"}', '${finalAssessment?.waistWidest ?? "—"}',
                      finalAssessment?.waistWidest != null && baseline.waistWidest != null
                        ? '${(finalAssessment!.waistWidest! - baseline.waistWidest!).toStringAsFixed(1)} cm'
                        : '—'],
                    ['Push-ups (60s)', '${baseline.pushupsCount ?? "—"}', '${finalAssessment?.pushupsCount ?? "—"}',
                      finalAssessment?.pushupsCount != null && baseline.pushupsCount != null
                        ? '${finalAssessment!.pushupsCount! - baseline.pushupsCount!}'
                        : '—'],
                  ],
                ),
                pw.Spacer(),
                pw.Text('Trainer Remarks: ${finalAssessment?.trainerRemarks ?? baseline.trainerRemarks ?? "Great progress!"}',
                    style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text('FS-7 Fitness — Transformation Report (Non-medical evaluation)',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}

