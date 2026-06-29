import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Clinic constants ─────────────────────────────────────────────────────────
const _clinicName = 'SHRI AMMAN CLINIC & LAB';
// ─────────────────────────────────────────────────────────────────────────────

// ── Brand colours (from theme.dart AppColors) ─────────────────────────────────
const _brand = PdfColor.fromInt(0xFF147782); // primary teal
const _brandDark = PdfColor.fromInt(0xFF147782); // darker teal for contrast
const _brandLight = PdfColor.fromInt(0xFF97d4c5); // very light teal tint
const _grey = PdfColor.fromInt(0xFF555555);
const _lightGrey = PdfColor.fromInt(0xFFF4F4F4);
const _divLine = PdfColor.fromInt(0xFFCCCCCC);
const _error = PdfColor.fromInt(0xFFD32F2F);
// ─────────────────────────────────────────────────────────────────────────────

final _fmt = DateFormat('dd MMM yyyy');

String _fd(dynamic ts) {
  if (ts == null) return '—';
  try {
    return _fmt.format((ts as Timestamp).toDate());
  } catch (_) {
    return ts.toString();
  }
}

class PdfHelper {
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

  // ── Load shared assets (Now includes header banner) ────────────────────────
  static Future<(pw.MemoryImage, pw.MemoryImage, pw.Font, pw.Font, pw.Font)>
      _loadAssets() async {
    final logoData = await rootBundle.load('assets/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());

    // Loading your custom header image asset banner
    final headerImgData = await rootBundle.load('assets/header.png');
    final headerImg = pw.MemoryImage(headerImgData.buffer.asUint8List());

    final font = await PdfGoogleFonts.latoRegular();
    final fontBold = await PdfGoogleFonts.latoBold();
    final fontItal = await PdfGoogleFonts.latoItalic();
    return (logo, headerImg, font, fontBold, fontItal);
  }

  // ── Report PDF ─────────────────────────────────────────────────────────────
  static Future<pw.Document> _generateReportPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final (_, headerImg, font, bold, ital) = await _loadAssets();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // Page margins are zero so header can go edge-to-edge
      margin: const pw.EdgeInsets.fromLTRB(0, 0, 0, 0),
      header: (ctx) =>
          _header(data, 'MEDICAL LAB REPORT', headerImg, font, bold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        // Wrap everything else inside an overall inner padding widget
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 6),
              _infoSection(data, font, bold),
              pw.SizedBox(height: 5),
              _thin(),
              pw.SizedBox(height: 5),
              ..._reportTests(tests, font, bold),
              _endSection('END OF REPORT', font, bold, ital),
            ],
          ),
        ),
      ],
    ));
    return pdf;
  }

  // ── Bill PDF ───────────────────────────────────────────────────────────────
  static Future<pw.Document> _generateBillPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final (_, headerImg, font, bold, ital) = await _loadAssets();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // Page margins are zero so header can go edge-to-edge
      margin: const pw.EdgeInsets.fromLTRB(0, 0, 0, 0),
      header: (ctx) => _header(data, 'INVOICE / BILL', headerImg, font, bold),
      footer: (ctx) => _footer(ctx, font),
      build: (ctx) => [
        // Wrap everything else inside an overall inner padding widget
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 6),
              _infoSection(data, font, bold),
              pw.SizedBox(height: 5),
              _thin(),
              pw.SizedBox(height: 5),
              ..._billTests(tests, data, font, bold),
              _endSection('END OF BILL', font, bold, ital),
            ],
          ),
        ),
      ],
    ));
    return pdf;
  }

// ── Page Header (Image edge-to-edge with Report Details on the Right) ──────
  static pw.Widget _header(
    Map<String, dynamic> data,
    String docType,
    pw.MemoryImage headerImg,
    pw.Font font,
    pw.Font bold,
  ) {
    String _s(String k, [String fb = '—']) =>
        data[k]?.toString().trim().isNotEmpty == true ? data[k].toString() : fb;

    final reportId = _s('report_id', 'REPORT');

    pw.Widget row(String l, String v) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 75,
                child: pw.Text(
                  l,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 6.5,
                    color: _grey,
                  ),
                ),
              ),
              pw.Text(
                ': ',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 6.5,
                  color: _grey,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  v,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 6.5,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        );

    String ref = 'Self';
    final dr = _s('referralDr', '');
    final hosp = _s('referralHospital', '');
    final lab = _s('referralLab', '');

    if (dr.isNotEmpty && dr != '— None —') {
      ref = 'Dr. $dr';
    } else if (hosp.isNotEmpty && hosp != '— None —') {
      ref = hosp;
    } else if (lab.isNotEmpty && lab != '— None —') {
      ref = lab;
    }

    return pw.Column(
      children: [
        pw.Stack(
          children: [
            // Header Banner
            pw.Container(
              height: 120,
              width: double.infinity,
              child: pw.Image(
                headerImg,
                fit: pw.BoxFit.fill,
              ),
            ),

            // Report Details Box
            pw.Positioned(
              right: 28,
              top: 10,
              bottom: 10,
              child: pw.Container(
                width: 190,
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                  border: pw.Border.all(
                    color: _divLine,
                    width: 0.5,
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Spacer(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'REPORT DETAILS',
                                style: pw.TextStyle(
                                  font: bold,
                                  fontSize: 7,
                                  color: _brand,
                                ),
                              ),
                              if (reportId != 'REPORT')
                                pw.SizedBox(
                                  width: 55,
                                  height: 12,
                                  child: pw.BarcodeWidget(
                                    barcode: pw.Barcode.code128(),
                                    data: reportId,
                                    drawText: false,
                                  ),
                                ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          row('Report ID', reportId),
                          row('Sample Type', _s('sampleType')),
                          row('Sample ID (SID)', _s('sid')),
                          row('Referred By', ref),
                          row('Sample Collected', _fd(data['sampleCollected'])),
                          row('Report Generated', _fd(data['createdAt'])),
                        ],
                      ),
                    ),
                    pw.Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Bottom Accent Strip
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 28),
          child: pw.Container(
            width: double.infinity,
            color: _brandDark,
            padding: const pw.EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 10,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  docType,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 8.5,
                    color: PdfColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.Text(
                  'Report ID: $reportId',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 7.5,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        pw.SizedBox(height: 3),
      ],
    );
  }

// ── Patient Info Section Only (Full Width Layout) ──────────────────────────
  static pw.Widget _infoSection(
      Map<String, dynamic> data, pw.Font font, pw.Font bold) {
    String _s(String k, [String fb = '—']) =>
        data[k]?.toString().trim().isNotEmpty == true ? data[k].toString() : fb;

    pw.Widget lbl(String t) => pw.SizedBox(
        width: 72,
        child: pw.Text(t,
            style: pw.TextStyle(font: bold, fontSize: 7.5, color: _grey)));

    pw.Widget val(String t) =>
        pw.Text(t, style: pw.TextStyle(font: font, fontSize: 7.5));

    pw.Widget row(String l, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(children: [
          lbl(l),
          pw.Text(': ',
              style: pw.TextStyle(font: font, fontSize: 7.5, color: _grey)),
          val(v),
        ]));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
            width: double.infinity,
            color: _brandLight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: pw.Text('PATIENT DETAILS',
                style: pw.TextStyle(font: bold, fontSize: 7.5, color: _brand))),
        pw.SizedBox(height: 4),

        // Two column layout inside Patient Details for clean structural scanning
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                row('Patient ID', _s('patientId')),
                row('Name', _s('patientName')),
                row('Age / Gender',
                    '${_s('patientAge', '—')}  /  ${_s('patientGender', '—')}'),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                row('Contact', _s('patientMobile', '—')),
                row('Address', _s('patientAddress', '—')),
                row('City / PIN',
                    '${_s('patientCity', '—')} – ${_s('patientPincode', '')}'),
              ],
            ),
          ),
        ]),
        pw.SizedBox(height: 4),

        // Patient ID Barcode
        pw.Container(
          alignment: pw.Alignment.centerLeft,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: _s('patientId', 'PATIENT'),
            width: 130,
            height: 24,
            drawText: true,
            textStyle: pw.TextStyle(font: font, fontSize: 6),
            color: _brand,
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _reportTests(
      List<Map<String, dynamic>> tests, pw.Font font, pw.Font bold) {
    final out = <pw.Widget>[];
    for (final test in tests) {
      final title =
          test['title']?.toString() ?? test['testName']?.toString() ?? '';
      final params = List<Map<String, dynamic>>.from(test['parameters'] ?? []);

      out.add(pw.Container(
        width: double.infinity,
        decoration: const pw.BoxDecoration(
          color: _brandLight,
          border: pw.Border(left: pw.BorderSide(color: _brand, width: 3)),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: pw.Text(title,
            style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
      ));
      out.add(pw.SizedBox(height: 1));
      out.add(_paramHdr(font, bold));

      bool alt = false;
      for (final p in params) {
        out.add(_paramRow(p, font, alt));
        alt = !alt;
      }
      out.add(pw.SizedBox(height: 5));
    }
    return out;
  }

  static List<pw.Widget> _billTests(List<Map<String, dynamic>> tests,
      Map<String, dynamic> data, pw.Font font, pw.Font bold) {
    final out = <pw.Widget>[];
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
              pw.Text('Rs. $price',
                  style:
                      pw.TextStyle(font: bold, fontSize: 8.5, color: _error)),
            ]),
      ));
      out.add(pw.SizedBox(height: 1));
    }
    out.add(_thin());
    out.add(pw.SizedBox(height: 4));
    out.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: _brand,
        child: pw.Text('GRAND TOTAL :  Rs. ${data['totalPrice'] ?? '0'}',
            style:
                pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.white)),
      ),
    ]));
    out.add(pw.SizedBox(height: 3));
    out.add(pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
      pw.Text('Payment Status: ${data['paymentStatus'] ?? 'Pending'}',
          style: pw.TextStyle(font: bold, fontSize: 8, color: _grey)),
    ]));
    out.add(pw.SizedBox(height: 6));
    return out;
  }

  // ── End Section (Dynamic for Reports and Bills) ────────────────────────────
  static pw.Widget _endSection(
      String label, pw.Font font, pw.Font bold, pw.Font ital) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _thin(),
        pw.SizedBox(height: 10),

        // 1. Prepared by / Authorised Signatory Block
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Prepared by:',
                    style: pw.TextStyle(font: bold, fontSize: 8, color: _grey)),
                pw.SizedBox(height: 25),
                pw.Container(width: 110, height: 0.8, color: _divLine),
                pw.SizedBox(height: 3),
                pw.Text('Authorised Signatory',
                    style: pw.TextStyle(font: ital, fontSize: 7, color: _grey)),
              ],
            ),
          ),
        ),

        pw.SizedBox(height: 20),

        // 2. Dynamic End Badge
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _brand, width: 0.8),
          ),
          child: pw.Text('--  $label  --',
              style: pw.TextStyle(font: bold, fontSize: 8.5, color: _brand)),
        ),

        pw.SizedBox(height: 10),
      ],
    );
  }

// ── Footer ─────────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, pw.Font font) {
    return pw.Container(
      // 28 horizontal matches your body padding; 10 top and 20 bottom gives clean separation
      margin: const pw.EdgeInsets.fromLTRB(28, 10, 28, 20),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Divider(color: _brand, thickness: 0.6),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$_clinicName  ·  Medical Lab Report',
                  style: pw.TextStyle(font: font, fontSize: 6.5, color: _grey)),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: pw.TextStyle(font: font, fontSize: 6.5, color: _grey)),
            ],
          ),
        ],
      ),
    );
  }

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

  static pw.Widget _thin() => pw.Divider(color: _divLine, thickness: 0.6);
}
