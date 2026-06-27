# Cutover Checklist — V5.1 go-live (เสาร์ 2026-06-27, 22:00)

ย้าย **7JEngMobile V5.1** เข้าแทน **V4.1.2** ที่ 7jenglishcenter.org
Firebase prod = `jenglishcenter-v4` · deploy = Firebase Hosting

---

## ✅ เตรียมไว้แล้ว (วันนี้ ก่อน 22:00)
- [x] เพิ่ม `hosting` section ใน `firebase.json` (public: `build/web`, SPA rewrite)
- [x] Build prod web เสร็จ → `build/web` (ไม่ใส่ APP_ENV = ชี้ jenglishcenter-v4)
- [x] ร่าง `firestore.rules` เฟส 1 (payroll/auditLogs require auth)
- [x] ตรวจ CSV: `C:\7JEnglishCenter\export_v5\` users 616 / relations 2,483 ✓

---

## 🚀 ขั้นตอนตอน 22:00 (เรียงลำดับ)

### 1) ยืนยัน Firebase login + project
```
firebase login:list
firebase use jenglishcenter-v4
```

### 2) (ออปชัน) Build ใหม่ให้สดก่อน deploy
```
flutter build web --release
```
> ไม่ใส่ `--dart-define=APP_ENV` = prod เสมอ. ตรวจว่าไม่มีป้าย "TEST" แดงมุมขวาบน

### 3) Deploy hosting (ทับ V4 ที่ 7jenglishcenter.org)
```
firebase deploy --only hosting
```
- เปิด https://7jenglishcenter.org → เห็น V5.1 (เมนู iPhone, footer 5.1.1)
- **Rollback ได้** ถ้าพัง: `firebase hosting:rollback` หรือ Console > Hosting > release history

### 4) Import ข้อมูลจริง (ผ่านเมนู "นำเข้าข้อมูล" ในแอป — ทำในเบราว์เซอร์)
> ⚠️ ทำ **รอบเดียว** ลำดับห้ามสลับ — bulkAddPackages ไม่กันซ้ำ
- [ ] Login แอดมิน (jen@7j.com)
- [ ] โหมด **ผู้ใช้** → อัปโหลด `v5_users.csv` → preview ควร ✅616 → ยืนยัน
- [ ] โหมด **ความสัมพันธ์** → อัปโหลด `v5_relations.csv` → ยืนยัน (→ 473 แพ็กเกจ)
- [ ] สุ่มเช็ค: ครู/นักเรียน login ด้วยรหัส (S/T) เห็นตาราง/แพ็กเกจถูก

### 5) Firestore Rules เฟส 1 (Console > Firestore > Rules)
- [ ] **ยืนยันก่อน:** payroll/auditLogs จะให้ "ใครมี Firebase Auth ก็เข้าได้" (= แอดมินทุกคน ~19)
      หรือจะล็อกเฉพาะอีเมลที่กำหนด? (ถ้าล็อกอีเมล ต้องมีรายชื่อแอดมินครบ ไม่งั้นล็อกเอาต์)
- [ ] paste เนื้อหา `firestore.rules` → **Publish**
- [ ] ทดสอบ: แอดมินเปิดบัญชีค่าจ้างได้ / (เปิด incognito ไม่ login) อ่าน payroll ไม่ได้
- [ ] ครู/นักเรียน (ไม่มี auth) ยังใช้งาน users/packages/sessions ได้ตามปกติ

### 6) ปิดงาน
- [ ] commit: `firebase.json` (hosting) + `firestore.rules`
- [ ] อัปเดต memory: go-live เสร็จ

---

## ⚠️ ความเสี่ยง / จุดต้องระวัง
- **Import ยิงซ้ำ = ข้อมูลซ้ำ** — ทำรอบเดียว ถ้าพลาดต้องลบ collection ก่อนยิงใหม่
- **Deploy ทับ V4** — แต่ rollback ได้ทันที (`firebase hosting:rollback`)
- **โดเมน 7jenglish.com = V3 (Namecheap) ห้ามแตะ** — คนละโดเมนกับ 7jenglishcenter.org
- Rules เฟส 1 **ยังไม่ล็อก** users/packages/sessions (ครู/นักเรียนไม่มี auth) — เฟส 2 ทีหลัง
