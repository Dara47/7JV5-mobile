import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:excel/excel.dart';

/// สร้างไฟล์ .xlsx จากตาราง (หัวคอลัมน์ + แถวข้อมูล) แล้วสั่งดาวน์โหลดบนเว็บ
///
/// - ค่าที่เป็นตัวเลข (num) จะถูกเขียนเป็นตัวเลขจริงในเซลล์ (คำนวณต่อใน Excel ได้)
/// - ค่าที่เป็นอื่น ๆ เขียนเป็นข้อความ
void exportXlsx({
  required String filename,
  required String sheetName,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();

  final sheet = excel[sheetName];
  sheet.appendRow(headers.map<CellValue?>((h) => TextCellValue(h)).toList());
  for (final r in rows) {
    sheet.appendRow(r.map<CellValue?>((c) {
      if (c == null) return null;
      if (c is num) return DoubleCellValue(c.toDouble());
      return TextCellValue(c.toString());
    }).toList());
  }

  // ลบชีตว่างเริ่มต้น (Sheet1) ถ้าไม่ใช่ชีตที่เราใช้
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.delete(defaultSheet);
  }

  final bytes = excel.encode();
  if (bytes == null) return;
  _download(Uint8List.fromList(bytes), filename);
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
