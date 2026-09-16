// CSV üretimi ve indirme.
//
// Ayraç olarak noktalı virgül kullanılır ve dosyanın başına BOM konur: Excel
// Türkçe yerelde virgülü ondalık ayracı sayar, virgülle ayrılmış dosyayı tek
// sütuna yığar ve BOM olmadan Türkçe karakterleri bozuk gösterir.

const SEPARATOR = ';';
const BOM = '﻿';

// Bir hücreyi kaçırır. Ayraç, tırnak ya da satır sonu içeren değer tırnağa
// alınır; içindeki tırnak ikilenir.
function escapeCell(value) {
  const text = value === null || value === undefined ? '' : String(value);
  if (!/[";\r\n]/.test(text)) return text;
  return `"${text.replaceAll('"', '""')}"`;
}

// rows: dizi dizisi. İlk satır başlık olabilir, ayrımı çağıran yapar.
export function toCsv(rows) {
  return BOM + rows.map((row) => row.map(escapeCell).join(SEPARATOR)).join('\r\n');
}

// Tarayıcıya dosya indirtir. Sunucuya hiçbir şey gitmez; içerik bellekte
// üretilir ve geçici bir nesne URL'i üzerinden verilir.
export function downloadCsv(filename, rows) {
  const blob = new Blob([toCsv(rows)], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.append(link);
  link.click();
  link.remove();
  // Bırakılmazsa nesne URL'i sekme kapanana kadar bellekte kalır.
  URL.revokeObjectURL(url);
}

// Dosya adında kullanılamayacak karakterleri temizler.
export function safeFilename(name) {
  return name.replace(/[^\p{L}\p{N}._-]+/gu, '-').replace(/-+/g, '-').replace(/^-|-$/g, '');
}
