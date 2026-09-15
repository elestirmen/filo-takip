// Arka uç seçimi. Panelin geri kalanı hangi uygulamayla çalıştığını bilmez;
// ikisi de aynı yüzeyi sunar:
//
//   vehicles / groups / users / adminUids / viewer   -> LatestValue
//   errors                                           -> EventChannel
//   nowMs()
//   signIn / register / signOut
//   setVehicleApproved / setVehicleGroup / deleteVehicle
//   saveGroupConfig / deleteGroup
//   setUserApproved / setUserGroup / setUserAdmin / deleteUser
//   loadHistory / dispose
//
// Firebase SDK'sı yalnızca gerçek kipte indirilir: yapılandırma boşken panel
// hiçbir dış isteğe çıkmadan demo veriyle açılır.

import { DemoBackend } from './backend-demo.js';
import { useDemoBackend } from './config.js';

export async function createBackend() {
  if (useDemoBackend) return new DemoBackend();
  const { FirebaseBackend } = await import('./backend-firebase.js');
  return new FirebaseBackend();
}
