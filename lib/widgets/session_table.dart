import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/date_format.dart';

class SessionTable extends StatelessWidget {
  final List<SessionModel> sessions;
  final void Function(SessionModel)? onEdit;
  final void Function(SessionModel) onDelete;

  const SessionTable({super.key, required this.sessions, required this.onEdit, required this.onDelete});

  static const _cols = ['#', 'วันที่ / เวลา', 'ช่วง', 'ภาษา/ทักษะ', 'ลา', 'สาย', 'สถานะ', '', ''];
  static const _widths = [30.0, 200.0, 60.0, 100.0, 36.0, 36.0, 76.0, 38.0, 38.0];

  static const _thStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white);
  static const _tdStyle = TextStyle(fontSize: 12);

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'in_progress': return Colors.orange;
      default: return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: const Color(0xFFF97316),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(_cols.length, (i) => SizedBox(
            width: _widths[i],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Text(_cols[i], style: _thStyle, textAlign: TextAlign.center),
            ),
          ))),
        ),
      ),
      // Rows
      Expanded(
        child: ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (_, i) {
            final s = sessions[i];
            final bgColor = i.isOdd ? Colors.grey.shade50 : Colors.white;

            return Container(
              color: bgColor,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _cell(_widths[0], Text('${i + 1}', style: _tdStyle.copyWith(color: Colors.grey), textAlign: TextAlign.center)),

                  // วันที่ + เวลา รวมกัน
                  _cell(_widths[1], Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      thaiDateFromStr(s.date),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF97316)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.startTime} - ${s.endTime} น.',
                      style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ])),

                  _cell(_widths[2], Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Text(s.durationLabel, style: _tdStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  )),

                  _cell(_widths[3], Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (s.language != null)
                      Text(s.language!, style: _tdStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFF97316)), overflow: TextOverflow.ellipsis),
                    if (s.skill != null)
                      Text(s.skill!, style: _tdStyle.copyWith(fontSize: 10, color: Colors.green.shade700), overflow: TextOverflow.ellipsis),
                    if (s.language == null && s.skill == null)
                      Text('-', style: _tdStyle.copyWith(color: Colors.grey)),
                  ])),

                  _cell(_widths[4], _boolIcon(s.isAbsent, trueColor: Colors.red, icon: Icons.event_busy)),
                  _cell(_widths[5], _boolIcon(s.isLate, trueColor: Colors.orange, icon: Icons.alarm_off)),

                  _cell(_widths[6], Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: _statusColor(s.status).withAlpha(28), borderRadius: BorderRadius.circular(8)),
                    child: Text(SessionModel.statusLabel(s.status), style: TextStyle(fontSize: 10, color: _statusColor(s.status), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  )),

                  if (onEdit != null) _cell(_widths[7], IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFF97316)),
                    onPressed: () => onEdit!(s),
                  )) else _cell(_widths[7], const SizedBox()),
                  _cell(_widths[8], IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => onDelete(s),
                  )),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _cell(double w, Widget child) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Center(child: child),
    ),
  );

  Widget _boolIcon(bool val, {required Color trueColor, required IconData icon}) {
    if (!val) return const Icon(Icons.remove, size: 14, color: Colors.grey);
    return Icon(icon, size: 16, color: trueColor);
  }
}
