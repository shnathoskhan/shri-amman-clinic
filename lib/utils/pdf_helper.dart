import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfHelper {
  static Future<void> printReport(DocumentSnapshot doc) async {
    final pdf = await _generateReportPdf(doc);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Report_${doc['report_id']}.pdf',
    );
  }

  static Future<void> printBill(DocumentSnapshot doc) async {
    final pdf = await _generateBillPdf(doc);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bill_${doc['report_id']}.pdf',
    );
  }

  static Future<void> shareReport(DocumentSnapshot doc, String mobile) async {
    final pdf = await _generateReportPdf(doc);
    final bytes = await pdf.save();
    
    // Web: Share will trigger a download
    await Printing.sharePdf(bytes: bytes, filename: 'Report_${doc['report_id']}.pdf');
    
    _openWhatsApp(mobile, "Hello, please find your attached medical report. (Please attach the downloaded PDF file)");
  }

  static Future<void> shareBill(DocumentSnapshot doc, String mobile) async {
    final pdf = await _generateBillPdf(doc);
    final bytes = await pdf.save();
    
    // Web: Share will trigger a download
    await Printing.sharePdf(bytes: bytes, filename: 'Bill_${doc['report_id']}.pdf');
    
    _openWhatsApp(mobile, "Hello, please find your attached medical bill. (Please attach the downloaded PDF file)");
  }

  static Future<void> _openWhatsApp(String mobile, String text) async {
    if (mobile.isEmpty) return;
    // Clean mobile number
    final number = mobile.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse('https://wa.me/91$number?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  static Future<pw.Document> _generateReportPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final dateStr = data['createdAt'] != null 
        ? DateFormat('dd MMM yyyy').format((data['createdAt'] as Timestamp).toDate())
        : '';

    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildHeader(data, 'MEDICAL REPORT'),
        build: (context) => [
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Test Name', 'Result', 'Unit', 'Reference Range'],
            data: tests.map((t) {
              final params = List<Map<String, dynamic>>.from(t['parameters'] ?? []);
              if (params.isEmpty) {
                 return [t['testName'] ?? '', '', '', ''];
              }
              // For simplicity, just showing the first parameter if there are multiple, or we can expand them.
              // A better way is to list parameters under the test name.
              return [
                t['testName'] ?? '',
                params[0]['value'] ?? '',
                params[0]['unit'] ?? '',
                params[0]['refRange'] ?? ''
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return pdf;
  }

  static Future<pw.Document> _generateBillPdf(DocumentSnapshot doc) async {
    final pdf = pw.Document();
    final data = doc.data() as Map<String, dynamic>;
    
    final tests = List<Map<String, dynamic>>.from(data['tests'] ?? []);
    final dateStr = data['createdAt'] != null 
        ? DateFormat('dd MMM yyyy').format((data['createdAt'] as Timestamp).toDate())
        : '';

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(data, 'INVOICE / BILL'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Description', 'Amount (Rs)'],
              data: tests.map((t) {
                return [
                  t['testName'] ?? '',
                  t['price']?.toString() ?? '0.0',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Grand Total: Rs ${data['totalPrice'] ?? 0.0}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Payment Status: ${data['paymentStatus'] ?? 'Pending'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ]
        ),
      ),
    );
    return pdf;
  }

  static pw.Widget _buildHeader(Map<String, dynamic> data, String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text('SHRI AMMAN CLINIC', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient Name: ${data['patientName'] ?? ''}'),
                pw.Text('Patient ID: ${data['patientId'] ?? ''}'),
              ]
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Report ID: ${data['report_id'] ?? ''}'),
                pw.Text('Date: ${data['createdAt'] != null ? DateFormat('dd MMM yyyy').format((data['createdAt'] as Timestamp).toDate()) : ''}'),
              ]
            ),
          ]
        ),
        pw.Divider(),
      ]
    );
  }
}
