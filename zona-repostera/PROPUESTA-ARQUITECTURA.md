# ZONA REPOSTERA — Propuesta de Arquitectura

**Sistema integral de administración, rentabilidad, CRM de alumnas y crecimiento**

Documento de validación previa al desarrollo. No se escribe una línea de código de la app hasta aprobar este documento.

Versión 1.0 — Agosto 2026

---

## Resumen ejecutivo

| Punto | Decisión propuesta |
|---|---|
| Tipo de app | Móvil Android + iOS con un solo código (Flutter) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Edge Functions) |
| Modelo de datos | 14 tablas, todo lo calculable se calcula, nada se captura dos veces |
| MVP (Fase 1) | Cursos, alumnas, inscripciones, pagos, costeo, asistencia, dashboard, importación Excel, reportes |
| Tiempo estimado MVP | 8–10 semanas |
| Costo operativo mensual | $0 – $650 MXN/mes al inicio (infraestructura) |
| WhatsApp | NO en MVP; base de datos y arquitectura quedan preparadas desde el día 1 |

Principio rector de todo el sistema (tu regla 27):

> **SI UN DATO PUEDE CALCULARSE, NO DEBE CAPTURARSE.**

Por eso el modelo de datos no tiene campos "total pagado", "saldo", "ganancia", "número de cursos por alumna", "estado de alumna", etc. Todos son derivados.

---

## 1. Arquitectura propuesta

### 1.1 Diagrama general

```
┌─────────────────────────────────────────────────────┐
│                APP MÓVIL (Flutter)                  │
│   Android + iOS · un solo código · UI premium       │
│                                                     │
│  Dashboard · Cursos · Alumnas · Inscripciones       │
│  Pagos · Costeo · Reportes · Importación Excel      │
└──────────────────────┬──────────────────────────────┘
                       │ HTTPS (API + Realtime)
┌──────────────────────▼──────────────────────────────┐
│                 SUPABASE (Backend)                  │
│                                                     │
│  ► Auth: login, recuperación de contraseña, roles   │
│  ► PostgreSQL: base de datos relacional             │
│  ► Vistas SQL: métricas calculadas (KPIs, márgenes) │
│  ► Storage: fotos de cursos, respaldos de Excel     │
│  ► Edge Functions: importación Excel, exportación   │
│    PDF/Excel, alertas… y en Fase 3: webhook de      │
│    WhatsApp Business API                            │
│  ► Backups automáticos diarios                      │
│  ► Row Level Security: nadie ve datos sin sesión    │
└──────────────────────┬──────────────────────────────┘
                       │ (Fase 3)
┌──────────────────────▼──────────────────────────────┐
│         WhatsApp Business Cloud API (Meta)          │
│   Mensajes entrantes → webhook → interpretación →   │
│   registro/actualización de inscripciones y pagos   │
└─────────────────────────────────────────────────────┘
```

### 1.2 Decisiones de arquitectura y por qué

| Decisión | Alternativa descartada | Razón |
|---|---|---|
| **Flutter** (un código para Android + iOS) | Apps nativas separadas | Nativas duplican costo y tiempo ×2; Flutter da UI premium idéntica en ambas plataformas |
| **Supabase** como backend | Servidor propio / Firebase | Servidor propio = mantenimiento y costo fijo; Firebase no es relacional y complica los análisis financieros. Supabase es PostgreSQL: los cálculos de rentabilidad, retención y horarios se hacen con SQL, que es exactamente lo que este negocio necesita |
| **La inteligencia vive en la base de datos** (vistas SQL) | Calcular todo en el teléfono | Los KPIs se calculan una sola vez, siempre igual, y cualquier cliente futuro (web, WhatsApp, IA) lee las mismas métricas |
| **Pagos como tabla de movimientos** | Campos "anticipo" y "liquidación" en la inscripción | Una tabla de pagos soporta 1, 2 o N pagos, cada uno con su método y fecha; anticipo/liquidación se derivan (primer pago = anticipo). Es la pieza que hace viable el registro automático desde WhatsApp en Fase 3 |
| **Curso separado de "curso programado"** | Una sola tabla de cursos | "Cheesecake Gourmet" es un producto; "Cheesecake Gourmet, sábado 10:00 am" es una edición. Separarlos es lo que permite comparar horarios, repetir cursos ganadores y medir recompra por producto |
| **Offline-first con caché local** | Solo online | La app abre y muestra el dashboard aunque falle el internet del local; sincroniza al reconectar |

### 1.3 Seguridad (tu punto 29)

- Login con email + contraseña, recuperación de contraseña por correo (incluido en Supabase Auth).
- Toda la comunicación cifrada (HTTPS/TLS).
- Row Level Security en PostgreSQL: ninguna tabla es legible sin sesión válida.
- Backups automáticos diarios de la base de datos.
- Roles preparados: `admin` (tú) desde el MVP; `staff` con permisos limitados queda contemplado en el modelo para el futuro.
- Datos personales de alumnas (teléfono, cumpleaños) solo visibles para cuentas autorizadas.

### 1.4 Preparado para crecer (tu punto 28)

- **APIs externas:** Supabase expone API REST automática sobre el modelo → integrable con lo que sea.
- **WhatsApp:** entra por Edge Function (webhook) sin tocar la app (sección 10).
- **IA:** las vistas SQL de métricas son el insumo directo para recomendaciones con IA en Fase 3.
- **10× volumen:** PostgreSQL maneja sin despeinarse cientos de miles de inscripciones; el cuello de botella nunca será la tecnología.

---

## 2. Modelo de base de datos

### 2.1 Diagrama entidad-relación (simplificado)

```
ALUMNA ──────┬──────────────< INSCRIPCION >──────────── CURSO_PROGRAMADO >─────── CURSO
             │                    │                        │      (edición)        (producto)
             │                    │< PAGO                  │< COSTO_CURSO
             │                    │                        │
             └──< LISTA_ESPERA >──┘                        └── COSTO_FIJO (prorrateo mensual)

FUENTE_ADQUISICION ── ALUMNA          META (mensual)          ALERTA (generadas)
MENSAJE_ENTRANTE (Fase 3, WhatsApp)   USUARIO (auth)          CATEGORIA_CURSO
```

### 2.2 Tablas

**`curso`** — el producto (catálogo)
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| nombre | texto | "Cheesecake Gourmet" |
| categoria_id | ref | Pasteles, gelatinas, cupcakes… |
| descripcion, materiales_incluidos | texto | |
| precio_base | dinero | Precio sugerido; cada edición puede ajustarlo |
| duracion_horas | decimal | |
| fotos | array | En Storage |
| activo | bool | Para "dejar de ofrecer" sin borrar historial |

**`curso_programado`** — la edición con fecha (lo que se vende)
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| curso_id | ref | |
| fecha | date | El día de la semana se deriva de la fecha |
| hora_inicio | time | Clave para el análisis de horarios |
| precio | dinero | Hereda `precio_base`, editable |
| cupo_maximo, cupo_minimo | entero | |
| estatus | enum | planeado · abierto · realizado · cancelado |
| observaciones | texto | |

> "Casi lleno" y "Lleno" **no se capturan**: se calculan con inscripciones vs cupo. Solo se captura el estatus del ciclo de vida.

**`alumna`**
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| nombre | texto | |
| telefono | texto | Normalizado E.164 → llave de identificación para WhatsApp en Fase 3 |
| whatsapp_igual_telefono | bool | + campo whatsapp opcional |
| email | texto | opcional |
| fecha_nacimiento | date | Cumpleaños |
| fuente_id | ref | Cómo llegó |
| referida_por_alumna_id | ref | Si la fuente es "alumna anterior" |
| observaciones | texto | |

> **No se capturan:** primera compra, última compra, número de cursos, total gastado, promedio, estado (nueva/activa/recurrente/inactiva/VIP). Todo se deriva de sus inscripciones y pagos mediante la vista `alumna_metricas`.

**`inscripcion`** — relaciona ALUMNA + CURSO PROGRAMADO + DINERO
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| alumna_id, curso_programado_id | ref | Única por pareja |
| fecha_inscripcion | timestamp | |
| precio_acordado | dinero | Por si diste descuento |
| estatus | enum | apartado · cancelada · reprogramada |
| asistencia | enum | pendiente · asistio · no_asistio |
| motivo_cancelacion | texto | |
| reprogramada_a_id | ref | Liga a la nueva inscripción |
| origen | enum | manual · **whatsapp** · importacion — preparado para Fase 3 |

> "Parcialmente pagado" y "Pagado" **se calculan** con los pagos vs `precio_acordado`.

**`pago`** — movimientos de dinero
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| inscripcion_id | ref | |
| monto | dinero | |
| metodo | enum | efectivo · transferencia · tarjeta · otro |
| fecha | timestamp | |
| origen | enum | manual · whatsapp · importacion |
| nota | texto | |

> Anticipo = primer pago. Liquidación = pagos posteriores. Total pagado = SUM(pagos). Saldo = precio − pagos. **Nada de eso se captura.**

**`costo_curso`** — costeo por edición (tu punto 9)
| Campo | Tipo | Nota |
|---|---|---|
| id | uuid | |
| curso_programado_id | ref | |
| tipo | enum | ingrediente · material · otro |
| concepto | texto | "Queso crema", "Cajas", "Gas" |
| cantidad, unidad | | Para ingredientes |
| costo | dinero | Costo utilizado |
| es_por_alumna | bool | Cajas escalan por alumna; el gas no |

> Costo total, costo por alumna, utilidad y margen: **calculados**. Los conceptos de una edición anterior se pueden **duplicar** a la siguiente edición del mismo curso (captura mínima).

**`costo_fijo`** — mensuales (tu punto 10)
| Campo | Tipo |
|---|---|
| concepto (renta, luz, agua, internet, gas, sueldos, publicidad, software, otro) | texto |
| monto_mensual | dinero |
| activo desde / hasta | date |

> El prorrateo entre cursos del mes es un cálculo (por curso realizado, ponderado por alumnas). Da la diferencia entre **utilidad bruta** (ventas − costos directos) y **utilidad operativa** (− proporción de fijos).

**Tablas restantes**

| Tabla | Para qué |
|---|---|
| `categoria_curso` | Agrupar análisis (gelatinas vs pasteles) |
| `fuente_adquisicion` | Instagram, Facebook, TikTok, recomendación, evento, otro (catálogo editable) |
| `lista_espera` | alumna/nombre + teléfono + curso_programado + fecha + prioridad + estatus (esperando · convertida · descartada) |
| `meta` | mes + ventas objetivo, utilidad, cursos, alumnas, nuevas, recompra, ocupación (Fase 2; la tabla nace en MVP) |
| `alerta` | tipo, severidad, mensaje, entidad relacionada, leída (Fase 2 la genera automático) |
| `mensaje_entrante` | **Fase 3:** payload de WhatsApp, teléfono, interpretación, estado de revisión — la tabla se crea desde el MVP, vacía |
| `usuario` | Cuentas (Supabase Auth) + rol |
| `importacion` | Bitácora de cada importación de Excel: archivo, filas leídas, aceptadas, rechazadas — nada se borra automáticamente |

### 2.3 Vistas SQL (la inteligencia del sistema)

| Vista | Responde |
|---|---|
| `inscripcion_estado` | pagado / parcial / apartado, total pagado, saldo |
| `curso_programado_metricas` | inscritas, ocupación %, ventas, cobrado, pendiente, costo total, utilidad bruta y operativa, margen %, ticket, costo por alumna, clasificación 🟢🟡🟠🔴 |
| `alumna_metricas` | cursos tomados, total gastado, promedio, primera/última compra, frecuencia, asistencias, clasificación NUEVA · ACTIVA · RECURRENTE · INACTIVA · VIP |
| `dashboard_mes` | ventas, gastos, utilidad, margen, cursos, alumnas, nuevas, recurrentes, ticket, ocupación — mes actual vs anterior vs mismo mes año anterior |
| `analisis_horarios` | por día+hora: ediciones, ocupación, asistencia, cancelaciones, ventas, utilidad promedio |
| `analisis_cursos` | ranking por utilidad, margen, ventas, ocupación, recompra, alumnas nuevas |
| `analisis_fuentes` | por canal: # alumnas y **gasto promedio por alumna** (qué canal trae alumnas que gastan más) |
| `retencion` (Fase 2) | tasa de recompra, días entre cursos, cursos por alumna, LTV |

**Umbrales configurables** (no números mágicos en código): días para considerar INACTIVA (default 60), criterios VIP (≥4 cursos o gasto ≥ $4,000), umbral "casi lleno" (80%), márgenes de la clasificación 🟢🔴. Editables desde Ajustes.

---

## 3. Flujo de usuario

### 3.1 Flujo diario (el corazón: < 30 segundos)

```
Abrir app → [HOY]
  ├─ Cursos de hoy, alumnas esperadas, lugares disponibles
  ├─ Cobrado hoy · pagos pendientes de hoy
  ├─ Alertas (cumpleaños, curso con pocas inscritas, lugar liberado)
  └─ Próximos cursos (7 días)
        → Tocar un curso → lista de alumnas → pasar asistencia (1 tap por alumna)
        → Tocar pago pendiente → registrar liquidación (monto + método, 2 taps)
```

### 3.2 Nueva inscripción (el flujo más frecuente — objetivo: < 20 segundos)

```
[+] → Buscar alumna (por nombre o teléfono)
        ├─ Existe → seleccionar
        └─ No existe → alta rápida: nombre + teléfono + fuente (3 campos)
    → Elegir curso programado (muestra cupo 8/10)
        └─ Si LLENO → ofrecer lista de espera
    → Anticipo: monto + método
    → Guardar ✓  (estado, saldo y ocupación se actualizan solos)
```

### 3.3 Otros flujos clave

- **Crear curso programado:** elegir curso del catálogo (o crearlo) → fecha, hora, cupo, precio → opcional: "copiar costeo de la edición anterior".
- **Cancelación con lista de espera:** cancelar inscripción → motivo → si hay lista de espera, alerta "Hay un lugar disponible: [primera de la lista]" → convertir a inscripción con un tap.
- **Cierre de curso:** el día del curso → pasar lista → al marcarlo realizado, la app muestra su rentabilidad final.
- **Importación Excel:** subir archivo → mapeo de columnas → **vista previa con semáforo** (duplicados, fechas inválidas, vacíos, inconsistencias) → decides fila por fila o en bloque → importar → bitácora. Nunca borra nada.
- **Mensual:** capturar/ajustar costos fijos → revisar dashboard y rankings → (Fase 2: fijar meta del mes).

---

## 4. Pantallas

### MVP — 12 pantallas

| # | Pantalla | Contenido |
|---|---|---|
| 1 | Login / recuperación | Email + contraseña |
| 2 | **HOY** (inicio) | Cursos de hoy, esperadas, lugares, cobrado hoy, pendientes, alertas, próximos |
| 3 | **Dashboard mes** | Ventas, gastos, utilidad, margen %, cursos, alumnas, nuevas/recurrentes, ticket, ocupación; comparativo vs mes anterior y año anterior |
| 4 | Calendario de cursos | Mes/semana/lista; chips de estado y ocupación (8/10, LLENO) |
| 5 | Detalle de curso programado | Info + inscritas + asistencia + **pestaña rentabilidad** (ventas, costos, utilidad, margen, clasificación 🟢🔴) + lista de espera |
| 6 | Costeo del curso | Ingredientes / materiales / otros; totales y margen en vivo mientras capturas |
| 7 | Alumnas (lista) | Búsqueda, filtros por clasificación y fuente |
| 8 | Perfil de alumna | Datos + métricas + historial de cursos (tu tabla del punto 8) + saldos |
| 9 | Nueva inscripción | El flujo 3.2 |
| 10 | Registrar pago | Monto, método, fecha |
| 11 | Costos fijos | Captura mensual + total |
| 12 | Reportes + Importar/Exportar | Reporte mensual, por curso, por alumna, financiero → Excel/CSV/PDF; asistente de importación |

### Fase 2 — se agregan

| Pantalla | Contenido |
|---|---|
| Cursos ganadores | Ranking multi-criterio |
| Mejores horarios | Matriz día × hora con ocupación/utilidad y recomendaciones |
| Retención | Recompra, tiempo entre cursos, LTV |
| Metas | Progreso gráfico mensual |
| ¿Qué debería hacer? | Recomendaciones accionables |
| Crecimiento 10× | Variable limitante del crecimiento |

### Diseño visual (tu punto 26)

Identidad Zona Repostera: fondos crema/beige, tipografía elegante, acentos dorado suave, toques rosa pastel muy discretos, tarjetas con esquinas redondeadas y mucho aire. Los números financieros grandes y legibles; los semáforos 🟢🟡🔴 como único color fuerte. Sensación: herramienta premium de una escuela de repostería, no un sistema contable.

---

## 5. Tecnología recomendada

| Capa | Tecnología | Por qué |
|---|---|---|
| App móvil | **Flutter (Dart)** | Un código → Android + iOS; UI premium consistente; rendimiento nativo; gran ecosistema |
| Estado/offline | Riverpod + Drift (SQLite local) | La app abre sin internet y sincroniza |
| Backend | **Supabase** | PostgreSQL + Auth + Storage + Edge Functions + backups, sin administrar servidores |
| Métricas | Vistas SQL en PostgreSQL | Cálculos consistentes, reutilizables por web/WhatsApp/IA |
| Exportación | Edge Function (Excel/CSV/PDF) | Reportes generados en servidor |
| Importación | Parser de .xlsx + asistente de mapeo en la app | Tu CALENDARIO(1).xlsx entra con vista previa |
| Gráficas | fl_chart | Dashboard visual |
| WhatsApp (Fase 3) | WhatsApp Business Cloud API (Meta) + Edge Function webhook | Sección 10 |
| IA (Fase 3) | API de Claude sobre las vistas de métricas | Recomendaciones en lenguaje natural |

---

## 6. Costos aproximados

### 6.1 Infraestructura mensual

| Concepto | Inicio | Al crecer (10×) |
|---|---:|---:|
| Supabase | $0 (plan free) | ~$470/mes (Pro, USD $25) |
| Dominio (opcional) | $0 | ~$25/mes |
| **TOTAL mensual** | **$0** | **~$495/mes** |

### 6.2 Cuentas de tienda (una vez / anual)

| Concepto | Monto | Frecuencia |
|---|---:|---|
| Google Play (Android) | ~$470 | única vez (USD $25) |
| Apple Developer (iOS) | ~$1,870/año | anual (USD $99) |
| **TOTAL primer año** | **~$2,340** | |

### 6.3 Fase 3 — WhatsApp e IA (referencia, no ahora)

| Concepto | Estimado |
|---|---:|
| WhatsApp Cloud API | Conversaciones de servicio iniciadas por la clienta: gratis; plantillas salientes ~$0.50–$1.00 c/u |
| API de IA (recomendaciones) | ~$200–$500/mes según uso |

> Supuesto: tipo de cambio $18.70 MXN/USD. Todos los montos de esta sección son estimaciones, no cotizaciones.
>
> Nota: este esquema asume desarrollo dentro del ecosistema actual (Claude Code + tu cuenta). No incluye honorarios de terceros; si se contratara un desarrollador externo, un MVP de este alcance rondaría $150,000–$300,000 MXN en el mercado — ese es el valor que se está construyendo internamente.

### 6.4 Costos operativos que la app te ahorra

Captura manual duplicada, errores de saldos, cursos no rentables sin detectar, horarios muertos, alumnas inactivas sin recontactar. El retorno esperado no es el ahorro de software: es **decidir con datos qué cursos repetir y cuáles eliminar**.

---

## 7. Tiempo estimado

| Fase | Contenido | Duración |
|---|---|---|
| Semana 0 | Validación de este documento + revisión del CALENDARIO(1).xlsx real para afinar el mapeo de importación | 1 semana |
| Fase 1a | Base de datos, auth, cursos, alumnas, inscripciones, pagos | 3 semanas |
| Fase 1b | Costeo, costos fijos, asistencia, dashboard HOY + mes | 2–3 semanas |
| Fase 1c | Importación Excel con vista previa, exportación, reportes, pulido visual | 2 semanas |
| Beta | Tú usando la app con datos reales, ajustes | 1–2 semanas |
| Publicación | Google Play + App Store (revisión de Apple: 1–7 días) | 1 semana |
| **TOTAL MVP** | | **8–10 semanas** |
| Fase 2 | Retención, LTV, rankings, horarios, metas, alertas, recomendaciones | +4–6 semanas |
| Fase 3 | WhatsApp, automatización, IA | +6–8 semanas (cuando el volumen lo justifique) |

> El MVP se construye sobre las vistas SQL desde el día 1, por lo que Fase 2 es en gran parte "ponerle pantalla" a métricas que ya existen.

---

## 8. Qué incluirá el MVP (Fase 1)

| Módulo | Incluye |
|---|---|
| Cursos | Catálogo + ediciones programadas, estados, cupos 8/10, LLENO, lista de espera básica |
| Alumnas | Perfil completo, fuente de adquisición, historial, clasificación automática (NUEVA/ACTIVA/RECURRENTE/INACTIVA/VIP como etiqueta calculada) |
| Inscripciones | Flujo de 20 segundos, estados calculados, cancelación/reprogramación con motivo |
| Pagos | Movimientos con método; anticipo/saldo/liquidación calculados; pendientes de cobro |
| Costeo | Ingredientes, materiales, otros; costo por alumna, utilidad bruta y margen en vivo; duplicar costeo entre ediciones |
| Costos fijos | Captura mensual + prorrateo → utilidad operativa |
| Asistencia | Pase de lista de 1 tap; alimenta estadísticas |
| Dashboard | HOY + mes actual con comparativos |
| Rentabilidad por curso | Ventas, costos, utilidad, margen, ocupación, ticket, clasificación 🟢🟡🟠🔴 |
| Importación | CALENDARIO(1).xlsx con vista previa, detección de duplicados/errores, sin borrado automático |
| Exportación | Reporte mensual, por curso, por alumna y financiero → Excel/CSV/PDF |
| Seguridad | Login, recuperación, RLS, backups diarios |

## 9. Qué se deja para fases posteriores

| Fase 2 | Fase 3 |
|---|---|
| Rankings "Cursos ganadores" | Integración WhatsApp Business API |
| Análisis "Mejores horarios" con recomendación | Interpretación automática de mensajes → inscripciones/pagos |
| Retención: recompra, tiempo entre cursos, LTV | Mensajes automáticos (recordatorios, cumpleaños, reactivación) |
| Metas mensuales con progreso gráfico | IA: recomendaciones avanzadas y predicción de demanda |
| Alertas inteligentes automáticas | Módulo crecimiento 10× con variable limitante |
| Sección "¿Qué debería hacer?" (v1 por reglas) | Multi-usuario staff con permisos |

**Por qué así:** el MVP captura datos limpios durante 2–3 meses; Fase 2 explota esos datos (sin datos acumulados, los análisis de retención y horarios no dicen nada); Fase 3 automatiza cuando el volumen lo justifica. Es exactamente tu regla 30: no sobreconstruir.

---

## 10. Cómo se integraría WhatsApp posteriormente

**Fase 3, sin re-arquitectura.** El diseño del MVP ya deja listo lo necesario:

1. **Teléfono normalizado** (E.164) en `alumna` → es la llave con la que WhatsApp identifica a la persona.
2. **`pago.origen` y `inscripcion.origen`** ya aceptan el valor `whatsapp`.
3. **Tabla `mensaje_entrante`** ya existe (vacía) para guardar el mensaje crudo + interpretación.
4. Toda la lógica de negocio vive en el backend (no en la app) → un webhook puede crear inscripciones igual que la app.

**Flujo futuro:**

```
"Quiero apartar el curso de cheesecake, soy Mariana y te deposito $300"
        │
        ▼
WhatsApp Cloud API → webhook (Edge Function)
        │  guarda en mensaje_entrante
        ▼
Interpretación con IA (Claude): {alumna: Mariana, curso: cheesecake, monto: $300}
        │  cruza teléfono vs alumnas · curso vs ediciones abiertas
        ▼
BORRADOR de inscripción (estado: por confirmar)
        │
        ▼
Alerta en la app: "Nueva inscripción por WhatsApp: Mariana → Cheesecake, $300"
   [✓ Confirmar]  [✎ Corregir]  [✗ Rechazar]
```

**Regla de oro:** WhatsApp **propone**, tú **confirmas** con un tap. Nada entra solo a la base de datos. Mensajes posteriores (liquidaciones, cancelaciones, reprogramaciones) siguen el mismo circuito: borrador → confirmación.

Requisitos cuando llegue el momento: cuenta WhatsApp Business API (Meta Business), número dedicado o migración del actual, verificación del negocio.

---

## Siguientes pasos

1. **Tu validación de este documento** (ajustes que quieras: nombres de módulos, umbrales VIP/inactiva, prioridades del MVP).
2. Compartir el **CALENDARIO(1).xlsx** real → afinar el mapeo de importación con tus columnas exactas.
3. Definir dónde vivirá el código (repositorio propio `zona-repostera-app`).
4. Arrancar Fase 1a.
