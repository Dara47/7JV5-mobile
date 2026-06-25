import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:excel/excel.dart';

/// ข้อมูล 1 ชีต: ชื่อชีต + หัวคอลัมน์ + แถวข้อมูล
typedef SheetSpec = ({String name, List<String> headers, List<List<dynamic>> rows});

/// สร้างไฟล์ .xlsx ชีตเดียว แล้วสั่งดาวน์โหลดบนเว็บ
void exportXlsx({
  required String filename,
  required String sheetName,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) =>
    exportXlsxSheets(
      filename: filename,
      sheets: [(name: sheetName, headers: headers, rows: rows)],
    );

/// สร้างไฟล์ .xlsx หลายชีต แล้วสั่งดาวน์โหลดบนเว็บ
///
/// - ค่าที่เป็นตัวเลข (num) จะถูกเขียนเป็นตัวเลขจริงในเซลล์ (คำนวณต่อใน Excel ได้)
/// - ค่าที่เป็นอื่น ๆ เขียนเป็นข้อความ
void exportXlsxSheets({
  required String filename,
  required List<SheetSpec> sheets,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();

  for (final spec in sheets) {
    final sheet = excel[spec.name];
    sheet.appendRow(spec.headers.map<CellValue?>((h) => TextCellValue(h)).toList());
    for (final r in spec.rows) {
      sheet.appendRow(r.map<CellValue?>(_cell).toList());
    }
  }

  // ลบชีตว่างเริ่มต้น (Sheet1) ถ้าไม่ได้ใช้
  if (defaultSheet != null && !sheets.any((s) => s.name == defaultSheet)) {
    excel.delete(defaultSheet);
  }

  final bytes = excel.encode();
  if (bytes == null) return;
  _download(Uint8List.fromList(bytes), filename);
}

CellValue? _cell(dynamic c) {
  if (c == null) return null;
  if (c is num) return DoubleCellValue(c.toDouble());
  return TextCellValue(c.toString());
}

void _download(Uint8List bytes, String filename) {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}
