import 'package:flutter/material.dart';
import '../models/models.dart';

/// ช่องเลือกผู้ใช้ที่ค้นหาได้ — แตะเพื่อเปิดแผ่นค้นหา (พิมพ์ชื่อ/รหัส)
///
/// แสดงค่าที่เลือกอยู่จาก [currentName]/[currentCode] (ถ้ามี) ไม่ผูกกับ UserModel
/// โดยตรง เพื่อให้ใช้ได้ทั้งหน้าที่เก็บ UserModel และหน้าที่เก็บแค่ชื่อเป็น String
class UserSearchField extends StatelessWidget {
  final List<UserModel> users;
  final String? currentName;
  final String? currentCode;
  final String hint;
  final String title;
  final bool enabled;
  final Color color;
  final ValueChanged<UserModel> onSelected;
  const UserSearchField({
    super.key,
    required this.users,
    required this.hint,
    required this.title,
    required this.color,
    required this.onSelected,
    this.currentName,
    this.currentCode,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = currentName != null && currentName!.isNotEmpty;
    return GestureDetector(
      onTap: enabled
          ? () async {
              final picked = await showModalBottomSheet<UserModel>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => UserPickerSheet(
                    users: users, title: title, color: color, selectedName: currentName),
              );
              if (picked != null) onSelected(picked);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(children: [
          if (hasValue) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
              child: Center(child: Text(
                  (currentCode != null && currentCode!.isNotEmpty)
                      ? currentCode!.substring(0, 1)
                      : currentName!.substring(0, 1),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(currentName!, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
            if (currentCode != null && currentCode!.isNotEmpty)
              Text(currentCode!, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(width: 6),
          ] else
            Expanded(child: Text(hint, style: const TextStyle(fontSize: 14, color: Colors.grey))),
          Icon(enabled ? Icons.search : Icons.lock_outline, size: 18, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}

/// แผ่นค้นหา + เลือกผู้ใช้
class UserPickerSheet extends StatefulWidget {
  final List<UserModel> users;
  final String title;
  final Color color;
  final String? selectedName;
  const UserPickerSheet({super.key, required this.users, required this.title, required this.color, this.selectedName});
  @override
  State<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<UserPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserModel> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return widget.users
        .where((u) => u.name.toLowerCase().contains(q) || u.code.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final list = _filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              Icon(Icons.search, color: widget.color),
              const SizedBox(width: 10),
              Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'พิมพ์ชื่อ หรือ รหัส...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() { _searchCtrl.clear(); _q = ''; }),
                      )
                    : null,
                filled: true, fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('พบ ${list.length} คน', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
          Flexible(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('ไม่พบรายชื่อที่ค้นหา', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) {
                      final u = list[i];
                      final isSel = widget.selectedName != null && widget.selectedName == u.name;
                      return ListTile(
                        leading: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: widget.color.withAlpha(30), shape: BoxShape.circle),
                          child: Center(child: Text(u.code.isNotEmpty ? u.code.substring(0, 1) : '?',
                              style: TextStyle(fontSize: 13, color: widget.color, fontWeight: FontWeight.bold))),
                        ),
                        title: Text(u.name, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(u.code, style: TextStyle(fontSize: 12, color: widget.color)),
                        trailing: isSel ? Icon(Icons.check_circle, color: widget.color, size: 20) : null,
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
