// Kimin hangi aracı göreceğini belirleyen kurallar.
//
// lib/core/visibility_rules.dart dosyasının panel karşılığıdır. Uygulamada
// "bakan kişi" her zaman bir araçtır (sürücünün uid'i aynı zamanda aracın
// kimliğidir); panelde ise bakan kişi araçsız bir hesaptır, grubu
// `/webUsers/{uid}.groupId` alanından gelir. Grup çözümü ve alan gizleme
// mantığı ikisinde de aynıdır.
//
// Not: bu kurallar bir **arayüz** filtresidir, güvenlik sınırı değildir.
// Veritabanı kuralları `vehicles` düğümünü giriş yapmış herkese okutur.

import { Role } from './models.js';

// Bakanın görebileceği grup kimlikleri: kendi grubu + ayarındaki gruplar.
export function allowedGroupIdsFor(viewerGroupId, groups) {
  const allowed = new Set([viewerGroupId]);
  const config = findGroupById(groups, viewerGroupId);
  if (config !== null) for (const id of config.visibleGroups) allowed.add(id);
  return allowed;
}

// Bu kullanıcıya görünecek araçlar. Giriş sırası korunur.
//
// * Yönetici: tüm araçlar.
// * İzleyici: kendi grubu + grubunun visibleGroups listesindeki grupların
//   **onaylı** araçları. Onay bekleyen araçlar yalnızca yöneticiye görünür.
// * Grubu olmayan izleyici ve onay bekleyen hesap: hiçbir araç.
export function visibleVehiclesFor(allVehicles, groups, viewer) {
  if (viewer.role === Role.admin) return [...allVehicles];
  if (viewer.role !== Role.viewer) return [];

  const viewerGroupId = viewer.groupId;
  if (viewerGroupId === null || viewerGroupId.length === 0) return [];

  const allowed = allowedGroupIdsFor(viewerGroupId, groups);
  return allVehicles.filter(
    (vehicle) => vehicle.approved && vehicle.hasGroup && allowed.has(vehicle.groupId),
  );
}

// Bir aracın hangi alanlarının gösterileceği.
const FULL_VISIBILITY = Object.freeze({ showSpeed: true, showDriverName: true });

// Alan gizleme, **bakılan aracın** grup ayarına göre yapılır: bir grup kendi
// araçlarının hızını ya da sürücü adını başkalarından gizleyebilir.
//
// Yönetici filoyu yönetebilmesi için her zaman tam görür.
export function fieldVisibilityFor(vehicle, groups, viewer) {
  if (viewer.role === Role.admin) return FULL_VISIBILITY;
  if (!vehicle.hasGroup) return FULL_VISIBILITY;

  const config = findGroupById(groups, vehicle.groupId);
  if (config === null) return FULL_VISIBILITY;
  return { showSpeed: config.showSpeed, showDriverName: config.showDriverName };
}

// Haritadaki grup filtresi çipleri.
export const GroupFilterKind = Object.freeze({
  all: 'all',
  ungrouped: 'ungrouped',
  specific: 'specific',
});

export function groupFilterAll() {
  return { kind: GroupFilterKind.all, groupId: null };
}

export function groupFilterUngrouped() {
  return { kind: GroupFilterKind.ungrouped, groupId: null };
}

export function groupFilterFor(groupId) {
  return { kind: GroupFilterKind.specific, groupId };
}

export function filterMatches(filter, vehicle) {
  switch (filter.kind) {
    case GroupFilterKind.all:
      return true;
    case GroupFilterKind.ungrouped:
      return !vehicle.hasGroup;
    case GroupFilterKind.specific:
      return vehicle.groupId === filter.groupId;
    default:
      return true;
  }
}

export function filtersEqual(a, b) {
  return a.kind === b.kind && a.groupId === b.groupId;
}

export function findGroupById(groups, groupId) {
  return groups.find((group) => group.groupId === groupId) ?? null;
}
