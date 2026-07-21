# Bench Manager — Flutter client

Mobile/desktop Flutter UI for the **local** Bench Manager ops console ([`Clients/web/bench-manager`](../../web/bench-manager)).

**Stack:** Material 3 · `http` · `shared_preferences`  
**Backend:** Next.js Bench Manager API (`http://127.0.0.1:3008` by default)  
**Auth:** `BENCH_MANAGER_TOKEN` (sent as `bm_auth` cookie)

Flutter does **not** run Docker/SSH itself. Start the web ops host first (or the Electron desktop shell), then connect this app to it.

## Run

```bash
# terminal 1 — ops host (SSH + Docker)
pnpm dev:bench-manager

# terminal 2 — Flutter
cd Clients/flutter/bench_manager
flutter pub get
flutter run -d linux \
  --dart-define=BENCH_MANAGER_URL=http://127.0.0.1:3008
```

Login: Bench Manager URL + token from `Clients/web/bench-manager/.env.local`.

## Screens

| Tab | Actions |
|-----|---------|
| Home | Env health, Local / Cloud switch, app count |
| Sites | List + select site (`erp.zatgo.online`) |
| Apps | Installed apps for active env/site |
| Auto | list-apps, migrate, clear-cache, clear-website-cache, build --app |

## Related

- Web: `Clients/web/bench-manager`
- Desktop (Electron): `Clients/desktop/bench-manager-desktop`
