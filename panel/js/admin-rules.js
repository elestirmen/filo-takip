// Yönetim ekranlarının saf mantığı: sıralama, sayım ve ad doğrulama.
// lib/core/admin_rules.dart dosyasının karşılığı, panel kullanıcıları için
// genişletilmiştir.

import { turkishUpperCase } from './normalize.js';

// Araç listesinin sırası: **onay bekleyenler üstte**, sonra plakaya göre.
// Plakalar eşitse kimliğe göre; böylece sıra her yenilemede aynı kalır.
export function sortVehiclesForAdmin(vehicles) {
  return [...vehicles].sort((a, b) => {
    if (a.approved !== b.approved) return a.approved ? 1 : -1;
    const byPlate = compareText(a.plate, b.plate);
    if (byPlate !== 0) return byPlate;
    return compareText(a.id, b.id);
  });
}

// Panel kullanıcıları: onay bekleyenler üstte, sonra ada göre.
export function sortUsersForAdmin(users, adminUids) {
  return [...users].sort((a, b) => {
    const aPending = !a.approved && !adminUids.has(a.uid);
    const bPending = !b.approved && !adminUids.has(b.uid);
    if (aPending !== bPending) return aPending ? -1 : 1;
    const byLabel = compareText(a.label, b.label);
    if (byLabel !== 0) return byLabel;
    return compareText(a.uid, b.uid);
  });
}

// Türkçe sıralama: 'İstanbul' ile 'Isparta' doğru sırada çıksın.
export function compareText(a, b) {
  return a.localeCompare(b, 'tr');
}

// Özet kartlarının sayıları.
export function adminSummaryOf(vehicles, groups) {
  let total = 0;
  let pending = 0;
  for (const vehicle of vehicles) {
    total++;
    if (!vehicle.approved) pending++;
  }
  return { total, pending, approved: total - pending, groupCount: groups.length };
}

// Bir gruba atanmış araç sayısı; silmeden önce uyarmak için de kullanılır.
export function vehicleCountInGroup(vehicles, groupId) {
  return vehicles.filter((vehicle) => vehicle.groupId === groupId).length;
}

// Bir gruba atanmış izleyici sayısı.
export function viewerCountInGroup(users, groupId) {
  return users.filter((user) => user.groupId === groupId).length;
}

// Yeni grup adı kabul edilebilir mi.
//
// Boş olamaz ve var olan bir grupla çakışamaz. Grup adı aynı zamanda
// veritabanı anahtarı olduğu için büyük/küçük harf farkı ayrı grup sayılır;
// yine de karışıklığı önlemek için yalnızca harf farkıyla ayrılan adlar da
// reddedilir.
export function isGroupNameAvailable(name, groups) {
  if (name.length === 0) return false;
  const upper = turkishUpperCase(name);
  return !groups.some((group) => turkishUpperCase(group.groupId) === upper);
}

// Araç tablosundaki arama kutusu: plaka, sürücü adı ve grup üzerinde eşleşir.
export function matchesVehicleSearch(vehicle, query) {
  const needle = turkishUpperCase(query.trim());
  if (needle.length === 0) return true;
  const haystack = turkishUpperCase(
    `${vehicle.plate} ${vehicle.driverName} ${vehicle.groupId ?? ''}`,
  );
  return haystack.includes(needle);
}

// Kullanıcı tablosundaki arama kutusu.
export function matchesUserSearch(user, query) {
  const needle = turkishUpperCase(query.trim());
  if (needle.length === 0) return true;
  const haystack = turkishUpperCase(
    `${user.displayName} ${user.email} ${user.groupId ?? ''}`,
  );
  return haystack.includes(needle);
}
