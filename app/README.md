# Zona Repostera — App

Sistema de administración, rentabilidad y CRM de alumnas para Zona Repostera.
Flutter (Android + iOS, un solo código). Datos locales en SQLite; arquitectura
preparada para sincronización con Supabase y WhatsApp Business (ver
`docs/` y la propuesta de arquitectura).

## Dos versiones en una sola app

| | GRATIS | PRO |
|---|---|---|
| Cursos programados | 2 abiertos a la vez | Ilimitados |
| Alumnas | 30 | Ilimitadas |
| Inscripciones, pagos, asistencia | ✔ | ✔ |
| Dashboard HOY | ✔ | ✔ |
| Dashboard del mes | Ventas y cobrado | Los 10 indicadores + comparativos |
| Costeo y rentabilidad (semáforo) | — | ✔ |
| Costos fijos y utilidad operativa | — | ✔ |
| Reportes CSV (mensual, curso, alumnas) | — | ✔ |

PRO se activa con un código offline (`lib/services/pro.dart`). Genera códigos:

```bash
dart run tool/genera_codigos.dart CAKE ROSA
```

La compra dentro de la app (Google Play Billing / Apple IAP) está planeada
para v1.1; el gating ya está centralizado en `ProService`.

## Desarrollo

```bash
flutter pub get
flutter analyze && flutter test
flutter run
```

## Compilación

Cada push a `main` compila en GitHub Actions (`.github/workflows/build.yml`):

- **APK** instalable directo en Android (artefacto `zona-repostera-apk`).
- **AAB** para subir a Google Play (artefacto `zona-repostera-aab`).
- Build de iOS sin firma, para validar compilación.

Para publicar en tiendas: `docs/LANZAMIENTO.md`.

## Estructura

```
lib/
  theme.dart            Identidad visual + formato de dinero + semáforo
  db/database.dart      Esquema SQLite (espejo del futuro esquema Supabase)
  models/models.dart    Modelos y TODOS los derivados calculados
  services/repo.dart    Consultas SQL (saldos, ocupación, KPIs del mes)
  services/pro.dart     Freemium: límites GRATIS y activación PRO
  services/export.dart  Reportes CSV
  screens/              HOY · Cursos · Detalle · Costeo · Alumnas · Perfil ·
                        Inscripción · Negocio · Costos fijos · PRO
```

Regla del sistema: **si un dato puede calcularse, no se captura.**
Saldo, total pagado, estado de pago, ocupación, clasificación de alumna,
utilidad y margen son siempre derivados.
