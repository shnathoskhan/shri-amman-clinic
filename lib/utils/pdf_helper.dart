import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Clinic constants ─────────────────────────────────────────────────────────
const _clinicName = 'SHRI AMMAN CLINIC & LAB';
const _clinicTagline = 'Diagnostic & Medical Laboratory';
const _clinicAddress = '123, Main Street, Salem – 636 001, Tamil Nadu';
const _clinicContact = 'Ph: +91 98765 43210  |  shriamman@clinic.com';
// ─────────────────────────────────────────────────────────────────────────────

// ── Brand colours (from theme.dart AppColors) ─────────────────────────────────
const _brand = PdfColor.fromInt(0xFF1F6A61); // primary teal
const _brandDark = PdfColor.fromInt(0xFF155248); // darker teal for contrast
const _brandLight = PdfColor.fromInt(0xFFE6F4F2); // very light teal tint
const _accent = PdfColor.fromInt(0xFF4B645F); // secondary muted teal
const _error = PdfColor.fromInt(0xFFD32F2F); // AppColors.error
const _info = PdfColor.fromInt(0xFF0288D1); // AppColors.info
const _grey = PdfColor.fromInt(0xFF555555);
const _lightGrey = PdfColor.fromInt(0xFFF4F4F4);
const _divLine = PdfColor.fromInt(0xFFCCCCCC);
// ─────────────────────────────────────────────────────────────────────────────

final _fmt = DateFormat('dd MMM yyyy');
final _fmtT = DateFormat('dd/MM/yyyy hh:mm a');

String _fd(dynamic ts) {
  if (ts == null) return '—';
  try {
    return _fmt.format((ts as Timestamp).toDate());
  } catch (_) {
    return ts.toString();
  }
}

String _fdt(dynamic ts) {
  if (ts == null) return '—';
  try {
    return _fmtT.format((ts as Timestamp).toDate());
  } catch (_) {
    return ts.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class PdfHelper {
  // ── Public API ─────────────────────────────────────────────────────────────
  static Future<void> printReport(DocumentSnapshot doc) async {
    final pdf = await _generateReportPdf(doc);
    await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'Report_${doc['report_id']}.pdf');
  }

  static Future<void> printBill(DocumentSnapshot doc) async {
    final pdf = await _generateBillPdf(doc);
    await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'Bill_${doc['report_id']}.pdf');
  }

  static Future<void> shareReport(DocumentSnapshot doc, String mobile) async {
    final pdf = await _generateReportPdf(doc);
    final bytes = await pdf.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'Report_${doc['report_id']}.pdf');
    _wa(mobile,
        'Hello, please find your attached medical report. (Attach the downloaded PDF)');
  }

  static Future<void> shareBill(DocumentSnapshot doc, String mobile) async {
    final pdf = await _generateBillPdf(doc);
    final bytes = await pdf.save();
    await Printing.sharePdf(
        bytes: bytes, filename: 'Bill_${doc['report_id']}.pdf');
    _wa(mobile,
        'Hello, please find your attached medical bill. (Attach the downloaded PDF)');
  }

  static Future<void> _wa(String mobile, String text) async {
    if (mobile.isEmpty) return;
    final n = mobile.replaceAll(RegExp(r'[^\d]'), '');
    final url =
        Uri.parse('https://wa.me/91$n?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ── Load shared assets ─────────────────────────────────────────────────────
  static Future<(pw.MemoryImage, pw.Font, pw.Font, pw.Font)>
      _loadAssets() async {
    final logoData = await rootBundle.load('assets/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItal = await PdfGoogleFonts.notoSansItalic();
    return (logo, font, fontBold, fontItal);
  }

  // ── Report PDF ─────────────────────────────────────────────────────────────
  static Future<pw.Document> _generateReportPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final (logo, font, bold, ital) = await _loadAssets();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 18, 28, 30),
      header: (ctx) => _header(data, 'MEDICAL LAB REPORT', logo, font, bold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        pw.SizedBox(height: 6),
        _infoSection(data, font, bold),
        pw.SizedBox(height: 5),
        _thin(),
        pw.SizedBox(height: 5),
        ..._reportTests(tests, font, bold),
        _endSection(font, bold, ital),
      ],
    ));
    return pdf;
  }

  // ── Bill PDF ───────────────────────────────────────────────────────────────
  static Future<pw.Document> _generateBillPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final (logo, font, bold, ital) = await _loadAssets();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 18, 28, 30),
      header: (ctx) => _header(data, 'INVOICE / BILL', logo, font, bold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        pw.SizedBox(height: 6),
        _infoSection(data, font, bold),
        pw.SizedBox(height: 5),
        _thin(),
        pw.SizedBox(height: 5),
        ..._billTests(tests, data, font, bold),
        _endSection(font, bold, ital),
      ],
    ));
    return pdf;
  }

  // ── Page Header ────────────────────────────────────────────────────────────
  static pw.Widget _header(
    Map<String, dynamic> data,
    String docType,
    pw.MemoryImage logo,
    pw.Font font,
    pw.Font bold,
  ) {
    return pw.Column(children: [
      // ── Main clinic bar ──
      pw.Container(
        width: double.infinity,
        color: _brand,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Real logo
            pw.Container(
              width: 44,
              height: 44,
              decoration: const pw.BoxDecoration(
                  color: PdfColors.white, shape: pw.BoxShape.circle),
              child: pw.ClipOval(child: pw.Image(logo, fit: pw.BoxFit.contain)),
            ),
            pw.SizedBox(width: 8),
            // Clinic name + address
            pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_clinicName,
                        style: pw.TextStyle(
                            font: bold,
                            fontSize: 15,
                            color: PdfColors.white,
                            letterSpacing: 0.8)),
                    pw.SizedBox(height: 1),
                    pw.Text(_clinicTagline,
                        style: pw.TextStyle(
                            font: font, fontSize: 7.5, color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text(_clinicAddress,
                        style: pw.TextStyle(
                            font: font, fontSize: 7, color: PdfColors.white)),
                    pw.Text(_clinicContact,
                        style: pw.TextStyle(
                            font: font, fontSize: 7, color: PdfColors.white)),
                  ]),
            ),
          ],
        ),
      ),
      // ── Document-type accent strip ──
      pw.Container(
        width: double.infinity,
        color: _brandDark,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(docType,
                style: pw.TextStyle(
                    font: bold,
                    fontSize: 8.5,
                    color: PdfColors.white,
                    letterSpacing: 1.5)),
            pw.Text('Report ID: ${data['report_id'] ?? ''}',
                style: pw.TextStyle(
                    font: font, fontSize: 7.5, color: PdfColors.white)),
          ],
        ),
      ),
      pw.SizedBox(height: 3),
    ]);
  }

  // ── Patient / Report Info with barcode ─────────────────────────────────────
  static pw.Widget _infoSection(
      Map<String, dynamic> data, pw.Font font, pw.Font bold) {
    String _s(String k, [String fb = '—']) =>
        data[k]?.toString().trim().isNotEmpty == true ? data[k].toString() : fb;

    // Referral
    String ref = 'Self';
    final dr = _s('referralDr', '');
    final hosp = _s('referralHospital', '');
    final lab = _s('referralLab', '');
    if (dr.isNotEmpty && dr != '— None —')
      ref = 'Dr. $dr';
    else if (hosp.isNotEmpty && hosp != '— None —')
      ref = hosp;
    else if (lab.isNotEmpty && lab != '— None —') ref = lab;

    pw.Widget lbl(String t) => pw.SizedBox(
        width: 72,
        child: pw.Text(t,
            style: pw.TextStyle(font: bold, fontSize: 7.5, color: _grey)));
    pw.Widget val(String t) => pw.Expanded(
        child: pw.Text(t, style: pw.TextStyle(font: font, fontSize: 7.5)));
    pw.Widget row(String l, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(children: [
          lbl(l),
          pw.Text(': ',
              style: pw.TextStyle(font: font, fontSize: 7.5, color: _grey)),
          val(v),
        ]));

    // ── Left: patient ──
    final patientCol =
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
          width: double.infinity,
          color: _brandLight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: pw.Text('PATIENT DETAILS',
              style: pw.TextStyle(font: bold, fontSize: 7.5, color: _brand))),
      pw.SizedBox(height: 4),
      row('Patient ID', _s('patientId')),
      row('Name', _s('patientName')),
      row('Age / Gender',
          '${_s('patientAge', '—')}  /  ${_s('patientGender', '—')}'),
      row('Contact', _s('patientMobile', '—')),
      row('Address', _s('patientAddress', '—')),
      row('City / PIN',
          '${_s('patientCity', '—')} – ${_s('patientPincode', '')}'),
      pw.SizedBox(height: 5),
      pw.Container(
        alignment: pw.Alignment.centerLeft,
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: _s('patientId', 'PATIENT'),
          width: 130,
          height: 28,
          drawText: true,
          textStyle: pw.TextStyle(font: font, fontSize: 6),
          color: _brand,
        ),
      ),
      pw.SizedBox(height: 5),
    ]);

    // ── Right: report meta + barcode ──
    final reportId = _s('report_id', 'REPORT');
    final metaCol =
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
          width: double.infinity,
          color: _brandLight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: pw.Text('REPORT DETAILS',
              style: pw.TextStyle(font: bold, fontSize: 7.5, color: _brand))),
      pw.SizedBox(height: 4),
      row('Report ID', reportId),
      row('Sample Type', _s('sampleType', '—')),
      row('SID', _s('sid', '—')),
      row('Referred By', ref),
      row('Generated On', _fd(data['createdAt'])),
      row('Updated On', _fdt(data['updatedAt'] ?? data['createdAt'])),
      pw.SizedBox(height: 5),
      // Barcode of the Report ID
      pw.Container(
        alignment: pw.Alignment.centerLeft,
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: reportId,
          width: 130,
          height: 28,
          drawText: true,
          textStyle: pw.TextStyle(font: font, fontSize: 6),
          color: _brand,
        ),
      ),
    ]);

    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: patientCol),
      pw.SizedBox(width: 14),
      pw.Expanded(child: metaCol),
    ]);
  }

  // ── Report Tests ───────────────────────────────────────────────────────────
  static List<pw.Widget> _reportTests(
      List<Map<String, dynamic>> tests, pw.Font font, pw.Font bold) {
    final out = <pw.Widget>[];
    for (final test in tests) {
      final title =
          test['title']?.toString() ?? test['testName']?.toString() ?? '';
      final params = List<Map<String, dynamic>>.from(test['parameters'] ?? []);

      // Section header with left border
      out.add(pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          color: _brandLight,
          border: pw.Border(left: pw.BorderSide(color: _brand, width: 3)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: pw.Text(title,
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
      ));
      out.add(pw.SizedBox(height: 1));

      // Column header
      out.add(_paramHdr(font, bold));

      // Param rows
      bool alt = false;
      for (final p in params) {
        out.add(_paramRow(p, font, alt));
        alt = !alt;
      }
      out.add(pw.SizedBox(height: 5));
    }
    return out;
  }

  // ── Bill Tests ─────────────────────────────────────────────────────────────
  // Bill Tests – simplified for billing PDFs (no units, ranges, values)
  static List<pw.Widget> _billTests(List<Map<String, dynamic>> tests,
      Map<String, dynamic> data, pw.Font font, pw.Font bold) {
    final out = <pw.Widget>[];
    // Header row for billing: Test name and Price
    out.add(pw.Container(
      width: double.infinity,
      color: _brandLight,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: pw.Row(children: [
        pw.Expanded(
            flex: 7,
            child: pw.Text('Test',
                style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand))),
        pw.SizedBox(width: 8),
        pw.Text('Price',
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
      ]),
    ));
    out.add(pw.SizedBox(height: 2));
    for (final test in tests) {
      final title =
          test['title']?.toString() ?? test['testName']?.toString() ?? '';
      final price = test['price']?.toString() ?? '0';
      out.add(pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          color: _brandLight,
          border: pw.Border(left: pw.BorderSide(color: _brand, width: 3)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(title,
                  style:
                      pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
              pw.Text('₹ $price',
                  style:
                      pw.TextStyle(font: bold, fontSize: 8.5, color: _error)),
            ]),
      ));
      out.add(pw.SizedBox(height: 1));
      // No parameter rows for billing PDF
    }
    // Grand total remains unchanged
    out.add(_thin());
    out.add(pw.SizedBox(height: 4));
    out.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: _brand,
        child: pw.Text('GRAND TOTAL :  ₹ ${data['totalPrice'] ?? '0'}',
            style:
                pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white)),
      ),
    ]));
    out.add(pw.SizedBox(height: 3));
    out.add(pw.SizedBox(height: 3));
    out.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text('Payment Status: ${data['paymentStatus'] ?? 'Pending'}',
          style: pw.TextStyle(font: bold, fontSize: 8, color: _grey)),
    ]));
    out.add(pw.SizedBox(height: 6));
    return out;
  }

  // ── End of Report ──────────────────────────────────────────────────────────
  static pw.Widget _endSection(pw.Font font, pw.Font bold, pw.Font ital) {
    return pw.Column(children: [
      _thin(),
      pw.SizedBox(height: 6),
      pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prepared by:',
                      style:
                          pw.TextStyle(font: bold, fontSize: 8, color: _grey)),
                  pw.SizedBox(height: 18),
                  pw.Container(width: 110, height: 0.8, color: _divLine),
                  pw.SizedBox(height: 2),
                  pw.Text('Authorised Signatory',
                      style:
                          pw.TextStyle(font: ital, fontSize: 7, color: _grey)),
                ]),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _brand, width: 0.8),
              ),
              child: pw.Text('★  END OF REPORT  ★',
                  style:
                      pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
            ),
            pw.SizedBox(width: 12),
          ]),
      pw.SizedBox(height: 6),
    ]);
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, pw.Font font) {
    return pw.Column(children: [
      pw.Divider(color: _brand, thickness: 0.6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('$_clinicName  ·  Medical Lab Report',
            style: pw.TextStyle(font: font, fontSize: 6.5, color: _grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 6.5, color: _grey)),
      ]),
    ]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static pw.Widget _paramHdr(pw.Font font, pw.Font bold) {
    pw.Widget h(String t, int flex) => pw.Expanded(
        flex: flex,
        child: pw.Text(t,
            style: pw.TextStyle(font: bold, fontSize: 7.5, color: _grey)));
    return pw.Container(
      color: _lightGrey,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Row(children: [
        h('Parameter', 3),
        h('Unit', 2),
        h('Ref. Range', 3),
        h('Result', 2)
      ]),
    );
  }

  static pw.Widget _paramRow(Map<String, dynamic> p, pw.Font font, bool alt) {
    pw.Widget c(String t, int flex, {bool bold = false, PdfColor? color}) =>
        pw.Expanded(
            flex: flex,
            child: pw.Text(t,
                style: pw.TextStyle(
                    font: font,
                    fontSize: 7.5,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? PdfColors.black)));
    final val = (p['value']?.toString().isEmpty == true || p['value'] == null)
        ? '—'
        : p['value'].toString();
    return pw.Container(
      color: alt ? _lightGrey : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Row(children: [
        c(p['name']?.toString() ?? '', 3),
        c(p['unit']?.toString() ?? '', 2, color: _grey),
        c(p['referenceRange']?.toString() ?? '', 3, color: _grey),
        c(val, 2, bold: true, color: _brand),
      ]),
    );
  }

  static pw.Widget _billParamRow(
      Map<String, dynamic> p, pw.Font font, bool alt) {
    return pw.Container(
      color: alt ? _lightGrey : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: 7,
              child: pw.Text(p['name']?.toString() ?? '',
                  style: pw.TextStyle(font: font, fontSize: 7.5))),
        ],
      ),
    );
  }

  static pw.Widget _thin() => pw.Divider(color: _divLine, thickness: 0.6);
}
