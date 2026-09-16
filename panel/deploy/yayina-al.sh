#!/usr/bin/env bash
# filo-takip.perinet.org yayına alma: Cloudflare DNS kaydı + NPM proxy host.
#
# Konteyner zaten ayakta (docker compose ... up -d). Bu betik kalan iki adımı
# yapar. Sırlar betiğin dışına çıkmaz: Cloudflare token'ı dosyadan okunur, NPM
# şifresi ekranda görünmeden sorulur, ikisi de hiçbir yere yazılmaz.
#
# Kullanım:
#   bash /opt/filo-takip/panel/deploy/yayina-al.sh [cloudflare-token-dosyasi]
#
# Betik yeniden çalıştırılabilir: var olan kayıt ve proxy host'a dokunmaz.

set -euo pipefail

DOMAIN="filo-takip.perinet.org"
ZONE_NAME="perinet.org"
RECORD_NAME="filo-takip"
# Dinamik DNS düzeni: sabit IP yerine CNAME, genel IP değişince kayıt güncel kalır.
RECORD_TARGET="urgup.keenetic.link"
FORWARD_HOST="filo-takip-web"
FORWARD_PORT=80
NPM_URL="http://127.0.0.1:81"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# JSON okumak için python3; jq kurulu olmayabilir.
jget() { python3 -c 'import json,sys;d=json.load(sys.stdin);
p=sys.argv[1].split(".")
for k in p:
    if k=="": continue
    d = d[int(k)] if k.isdigit() else d.get(k)
    if d is None: break
print("" if d is None else (json.dumps(d) if isinstance(d,(dict,list)) else d))' "$1"; }

# ----------------------------------------------------------- 1. Cloudflare

say "1/3  Cloudflare DNS"

TOKEN_PATH="${1:-}"
if [ -z "$TOKEN_PATH" ]; then
  # Verilmediyse bilinen yerlerde ara.
  for candidate in "$HOME/.config/cloudflare" "$HOME/.config/cloudflare/token" \
                   "$HOME/.cloudflare" "$HOME/.cf-token"; do
    if [ -f "$candidate" ]; then TOKEN_PATH="$candidate"; break; fi
    if [ -d "$candidate" ]; then
      found=$(find "$candidate" -maxdepth 1 -type f | head -1)
      if [ -n "$found" ]; then TOKEN_PATH="$found"; break; fi
    fi
  done
fi
[ -n "$TOKEN_PATH" ] && [ -f "$TOKEN_PATH" ] \
  || die "Cloudflare token dosyası bulunamadı. Yolu argüman olarak verin."
ok "token dosyası: $TOKEN_PATH"

# Dosya düz token da olabilir, ANAHTAR=değer biçiminde de.
CF_TOKEN=$(
  grep -ioE '^[[:space:]]*(CLOUDFLARE_API_TOKEN|CF_API_TOKEN|API_TOKEN|TOKEN)[[:space:]]*[=:][[:space:]]*.*' "$TOKEN_PATH" 2>/dev/null \
    | head -1 | sed -E 's/^[^=:]*[=:][[:space:]]*//; s/^["'"'"']//; s/["'"'"'][[:space:]]*$//' \
    || true
)
[ -n "$CF_TOKEN" ] || CF_TOKEN=$(tr -d '[:space:]' < "$TOKEN_PATH")
[ -n "$CF_TOKEN" ] || die "Token dosyası boş görünüyor."

cf() { curl -sS -H "Authorization: Bearer $CF_TOKEN" -H 'Content-Type: application/json' "$@"; }

resp=$(cf "https://api.cloudflare.com/client/v4/user/tokens/verify")
[ "$(printf '%s' "$resp" | jget success)" = "True" ] || [ "$(printf '%s' "$resp" | jget success)" = "true" ] \
  || die "Token doğrulanamadı: $(printf '%s' "$resp" | jget errors.0.message)"
ok "token geçerli"

zone_id=$(cf "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" | jget result.0.id)
[ -n "$zone_id" ] || die "$ZONE_NAME bölgesi bulunamadı (token'ın bu bölgeye Zone:DNS:Edit yetkisi var mı?)."
ok "bölge bulundu"

existing=$(cf "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$DOMAIN" | jget result.0.id)
if [ -n "$existing" ]; then
  warn "$DOMAIN kaydı zaten var, dokunulmadı"
else
  body=$(python3 -c 'import json,sys;print(json.dumps({
    "type":"CNAME","name":sys.argv[1],"content":sys.argv[2],"proxied":True,"ttl":1}))' \
    "$RECORD_NAME" "$RECORD_TARGET")
  resp=$(cf -X POST --data "$body" "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records")
  case "$(printf '%s' "$resp" | jget success)" in
    True|true) ok "CNAME oluşturuldu: $DOMAIN -> $RECORD_TARGET (proxied)" ;;
    *) die "Kayıt oluşturulamadı: $(printf '%s' "$resp" | jget errors.0.message)" ;;
  esac
fi

# ------------------------------------------------------------ 2. DNS bekle

say "2/3  DNS yayılması"
for i in $(seq 1 30); do
  if getent hosts "$DOMAIN" >/dev/null 2>&1; then ok "$DOMAIN çözümleniyor"; break; fi
  [ "$i" -eq 30 ] && die "$DOMAIN 2,5 dakikada çözümlenmedi. Biraz sonra betiği tekrar çalıştırın."
  printf '  bekleniyor (%s/30)\r' "$i"; sleep 5
done

# ------------------------------------------------------------------ 3. NPM

say "3/3  Nginx Proxy Manager"
docker ps --filter name="$FORWARD_HOST" --format '{{.Names}}' | grep -qx "$FORWARD_HOST" \
  || die "$FORWARD_HOST konteyneri çalışmıyor. Önce: docker compose -f /opt/filo-takip/panel/deploy/docker-compose.yml up -d"
ok "$FORWARD_HOST ayakta"

printf '  NPM yönetici e-postası: '; read -r NPM_EMAIL
printf '  NPM şifresi (görünmez): '; read -rs NPM_PASS; printf '\n'

auth_body=$(python3 -c 'import json,sys;print(json.dumps({"identity":sys.argv[1],"secret":sys.argv[2]}))' "$NPM_EMAIL" "$NPM_PASS")
NPM_TOKEN=$(curl -sS -X POST -H 'Content-Type: application/json' --data "$auth_body" "$NPM_URL/api/tokens" | jget token)
unset NPM_PASS
[ -n "$NPM_TOKEN" ] || die "NPM girişi başarısız (e-posta/şifre)."
ok "NPM oturumu açıldı"

npm_api() { curl -sS -H "Authorization: Bearer $NPM_TOKEN" -H 'Content-Type: application/json' "$@"; }

# Aynı alan adı için proxy host zaten varsa hiçbir şey yapma.
if npm_api "$NPM_URL/api/nginx/proxy-hosts" | grep -q "\"$DOMAIN\""; then
  warn "$DOMAIN için proxy host zaten var, dokunulmadı"
else
  say "  Let's Encrypt sertifikası isteniyor (30-60 sn sürebilir)"
  cert_body=$(python3 -c 'import json,sys;print(json.dumps({
    "provider":"letsencrypt","nice_name":sys.argv[1],"domain_names":[sys.argv[1]],
    "meta":{"letsencrypt_email":sys.argv[2],"letsencrypt_agree":True,"dns_challenge":False}}))' \
    "$DOMAIN" "$NPM_EMAIL")
  resp=$(npm_api -X POST --data "$cert_body" "$NPM_URL/api/nginx/certificates")
  cert_id=$(printf '%s' "$resp" | jget id)
  if [ -z "$cert_id" ]; then
    warn "Sertifika alınamadı: $(printf '%s' "$resp" | jget error.message)"
    warn "Proxy host SSL'siz oluşturuluyor; sertifikayı NPM arayüzünden ekleyebilirsiniz."
    cert_id=0
  else
    ok "sertifika alındı (id: $cert_id)"
  fi

  ssl=$([ "$cert_id" != "0" ] && echo True || echo False)
  host_body=$(python3 -c 'import json,sys;
cert=int(sys.argv[4]); ssl = cert != 0
print(json.dumps({
  "domain_names":[sys.argv[1]],"forward_scheme":"http","forward_host":sys.argv[2],
  "forward_port":int(sys.argv[3]),"certificate_id":cert,
  "ssl_forced":ssl,"http2_support":ssl,"hsts_enabled":ssl,"hsts_subdomains":False,
  "block_exploits":True,"caching_enabled":False,"allow_websocket_upgrade":False,
  "access_list_id":0,"advanced_config":"","locations":[],"meta":{"letsencrypt_agree":ssl}}))' \
    "$DOMAIN" "$FORWARD_HOST" "$FORWARD_PORT" "$cert_id")
  resp=$(npm_api -X POST --data "$host_body" "$NPM_URL/api/nginx/proxy-hosts")
  [ -n "$(printf '%s' "$resp" | jget id)" ] \
    || die "Proxy host oluşturulamadı: $(printf '%s' "$resp" | jget error.message)"
  ok "proxy host oluşturuldu: $DOMAIN -> $FORWARD_HOST:$FORWARD_PORT"
fi

say "Bitti"
printf '  https://%s\n\n' "$DOMAIN"
