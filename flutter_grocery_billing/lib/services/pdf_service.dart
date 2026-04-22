import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import '../models/app_settings.dart';

class PdfService {
  static const double _pageWidth = 80 * PdfPageFormat.mm;

  static Future<Uint8List> generateBillPdf(
    Bill bill,
    AppSettings settings,
  ) async {
    final pdf = pw.Document();

    pw.Font? bengaliFont;
    pw.Font? bengaliFontBold;
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansBengali-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/NotoSansBengali-Bold.ttf');
      bengaliFont = pw.Font.ttf(fontData);
      bengaliFontBold = pw.Font.ttf(boldData);
    } catch (_) {}

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/shop_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    final baseTheme = pw.ThemeData.withFont(
      base: bengaliFont,
      bold: bengaliFontBold,
    );

    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(bill.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_pageWidth, double.infinity,
            marginAll: 6 * PdfPageFormat.mm),
        theme: baseTheme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (logoImage != null)
                pw.Center(
                  child: pw.Image(logoImage,
                      width: 40 * PdfPageFormat.mm, height: 20 * PdfPageFormat.mm,
                      fit: pw.BoxFit.contain),
                ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(settings.shopName,
                    style: pw.TextStyle(
                        font: bengaliFontBold, fontSize: 14,
                        fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Center(
                child: pw.Text(settings.shopAddress,
                    style: pw.TextStyle(font: bengaliFont, fontSize: 8),
                    textAlign: pw.TextAlign.center),
              ),
              pw.Center(
                child: pw.Text('Tel: ${settings.shopPhone}',
                    style: pw.TextStyle(font: bengaliFont, fontSize: 8)),
              ),
              if (settings.gstNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text('GST: ${settings.gstNumber}',
                      style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                ),
              _divider(),
              pw.Center(
                child: pw.Text('CASH MEMO / ক্যাশ মেমো',
                    style: pw.TextStyle(
                        font: bengaliFontBold, fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill#: ${bill.billNumber}',
                      style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                  pw.Text(dateStr,
                      style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                ],
              ),
              if (bill.customerName != null && bill.customerName!.isNotEmpty)
                pw.Text('Customer: ${bill.customerName}',
                    style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
              if (bill.customerPhone != null && bill.customerPhone!.isNotEmpty)
                pw.Text('Phone: ${bill.customerPhone}',
                    style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
              _divider(),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text('পণ্য',
                        style: pw.TextStyle(
                            font: bengaliFontBold, fontSize: 8,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(
                    width: 25,
                    child: pw.Text('পরিমাণ',
                        style: pw.TextStyle(font: bengaliFontBold, fontSize: 7)),
                  ),
                  pw.SizedBox(
                    width: 22,
                    child: pw.Text('দাম',
                        style: pw.TextStyle(font: bengaliFontBold, fontSize: 7)),
                  ),
                  pw.SizedBox(
                    width: 24,
                    child: pw.Text('মোট',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: bengaliFontBold, fontSize: 7)),
                  ),
                ],
              ),
              _divider(),
              ...bill.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(item.nameBn ?? item.name,
                              style: pw.TextStyle(font: bengaliFont, fontSize: 8)),
                        ),
                        pw.SizedBox(
                          width: 25,
                          child: pw.Text('${item.quantity} ${item.unit}',
                              style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                        ),
                        pw.SizedBox(
                          width: 22,
                          child: pw.Text(
                              '${settings.currency}${item.price.toStringAsFixed(0)}',
                              style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                        ),
                        pw.SizedBox(
                          width: 24,
                          child: pw.Text(
                              '${settings.currency}${item.total.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
                        ),
                      ],
                    ),
                  )),
              _divider(),
              _summaryRow('Subtotal:',
                  '${settings.currency}${bill.subtotal.toStringAsFixed(2)}',
                  font: bengaliFont),
              if (bill.discount > 0)
                _summaryRow('Discount:',
                    '-${settings.currency}${bill.discount.toStringAsFixed(2)}',
                    font: bengaliFont),
              if (bill.tax > 0)
                _summaryRow('Tax:',
                    '+${settings.currency}${bill.tax.toStringAsFixed(2)}',
                    font: bengaliFont),
              _divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('সর্বমোট / TOTAL',
                      style: pw.TextStyle(
                          font: bengaliFontBold, fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text('${settings.currency}${bill.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                          font: bengaliFontBold, fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('Payment: ${bill.paymentMode.label}',
                  style: pw.TextStyle(font: bengaliFont, fontSize: 7)),
              _divider(),
              pw.Center(
                child: pw.Text(settings.tagline1,
                    style: pw.TextStyle(
                        font: bengaliFontBold, fontSize: 9,
                        fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(settings.tagline2,
                    style: pw.TextStyle(
                        font: bengaliFontBold, fontSize: 9,
                        fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center),
              ),
              _divider(),
              pw.Center(
                child: pw.Text(settings.footerNote,
                    style: pw.TextStyle(font: bengaliFont, fontSize: 6.5),
                    textAlign: pw.TextAlign.center),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<File> savePdfToFile(Uint8List bytes, String billNumber) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Bill_$billNumber.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> sharePdf(Uint8List bytes, String billNumber, String shopName) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Bill_$billNumber.pdf',
      subject: '$shopName - Bill $billNumber',
    );
  }

  static Future<void> printPdf(Uint8List bytes) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static pw.Widget _divider() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Divider(thickness: 0.5),
      );

  static pw.Widget _summaryRow(String label, String value, {pw.Font? font}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 8)),
        ],
      );
}
