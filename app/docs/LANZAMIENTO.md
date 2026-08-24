# Guía de lanzamiento a tiendas

Estado actual: la app compila, pasa análisis y pruebas. El APK de Android se
genera en GitHub Actions y es instalable HOY en cualquier teléfono Android
(instalación directa, sin tienda). La publicación en tiendas tiene tiempos
que dependen de Google y Apple, no del desarrollo.

## Tiempos reales (no negociables por las tiendas)

| Paso | Quién | Tiempo |
|---|---|---|
| Cuenta Google Play Console ($25 USD única vez) | Tú | 15 min + verificación de identidad 1–3 días |
| Prueba cerrada obligatoria (cuenta personal nueva): 12 testers durante 14 días | Google | **14 días** antes de poder publicar en producción |
| Revisión de Google al publicar | Google | 1–7 días |
| Apple Developer Program ($99 USD/año) | Tú | Inscripción + verificación 1–2 días |
| Revisión de App Store | Apple | 1–7 días |

**Ruta rápida real:**

- **Hoy:** instalar el APK directo en tu teléfono y usarlo con datos reales.
- **Esta semana:** crear ambas cuentas de desarrollador; subir el AAB a la
  prueba cerrada de Google Play e invitar 12 testers (alumnas/familia).
- **Semana 3:** producción en Google Play. iOS entra a revisión en cuanto
  Apple apruebe la cuenta y exista el build firmado.

> Nota: si la cuenta de Google Play se registra como **organización**
> (requiere D-U-N-S), el requisito de 14 días de prueba cerrada no aplica.
> Con RFC de una de las empresas del grupo puede tramitarse el D-U-N-S.

## Android — pasos

1. Crear keystore de firma (guardar en lugar seguro, NUNCA en el repo):
   ```bash
   keytool -genkey -v -keystore zona-repostera.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias zona
   ```
2. Crear `android/key.properties` (está en .gitignore):
   ```
   storePassword=***
   keyPassword=***
   keyAlias=zona
   storeFile=/ruta/zona-repostera.jks
   ```
3. Configurar signingConfig release en `android/app/build.gradle.kts`
   (bloque estándar de Flutter docs) y en GitHub Actions subir el keystore
   como secret si se quiere firmar en CI.
4. Play Console → crear app → prueba cerrada → subir el AAB del workflow.

## iOS — pasos

1. Apple Developer Program con el Apple ID del negocio.
2. En un Mac (o con Codemagic/GitHub Actions con certificados):
   `flutter build ipa` con el certificado de distribución y el
   provisioning profile.
3. App Store Connect → nueva app → subir con Transporter → TestFlight →
   revisión.

Identificador de paquete en ambas tiendas: `com.grupoajr.zona_repostera`.

## Checklist de ficha de tienda

- Nombre: Zona Repostera
- Descripción corta: Administra tus cursos de repostería: alumnas, pagos,
  costos y ganancias.
- Capturas: pantalla HOY, curso con cupo, rentabilidad con semáforo,
  perfil de alumna, dashboard del mes.
- Icono: logotipo Zona Repostera 1024×1024 (pendiente de diseño final).
- Política de privacidad: publicar URL (puede hospedarse junto a
  numera-legal o en dominio propio).
- Clasificación de contenido: Todos.
- La app funciona 100% offline; declarar "no recopila datos" mientras no
  exista sincronización en la nube.
