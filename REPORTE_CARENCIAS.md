# Reporte de Carencias — Auditoría del Backend `mascotas_backend`

> Documentación de opciones, configuraciones, controles de seguridad y buenas prácticas
> que le faltaron a la IA en su respuesta conceptual y técnica.

---

## HALLAZGO CRÍTICO: La migración está incompleta

Antes de listar mejoras, hay un bug severo que la IA no detectó ni reportó:

**`server.cjs` línea 2 importa `supabase` desde `conexion.cjs`**, pero `conexion.cjs` ya no lo exporta. Las siguientes rutas seguirían usando la sintaxis de Supabase y lanzarían un `ReferenceError` en tiempo de ejecución:

| Ruta | Línea | Problema |
|---|---|---|
| `GET /mascotas/:id` | 47 | `supabase.from('mascotas')` |
| `POST /auth/login` | 65 | `supabase.from('usuarios')` |
| `GET /auth/perfil` | 100 | `supabase.from('usuarios')` |
| `GET /publicaciones` | 124 | `supabase.from('publicaciones')` |
| `GET /publicaciones/:id/imagenes` | 158 | `supabase.from('imagenes_publicacion')` |

La IA solo migró `testConnection` e `insertaMascota` en `conexion.cjs` pero dejó el resto de las rutas sin tocar.

Además, `schema.sql` no incluye las tablas `publicaciones` ni `imagenes_publicacion` que sí usa el servidor.

---

## 1. Seguridad (OWASP Top 10)

### 1.1 CORS abierto sin restricción de origen

```js
// Actual — acepta peticiones de CUALQUIER dominio
app.use(cors());

// Correcto
app.use(cors({ origin: ['https://tuapp.com'], credentials: true }));
```

### 1.2 Sin rate limiting

No hay protección contra fuerza bruta en `/auth/login`. Un atacante puede probar millones de contraseñas sin restricción.

```js
// Faltó agregar
const rateLimit = require('express-rate-limit');
app.use('/auth/login', rateLimit({ windowMs: 15 * 60 * 1000, max: 10 }));
```

### 1.3 Sin helmet.js (cabeceras de seguridad HTTP)

Sin `helmet`, el servidor expone `X-Powered-By: Express` y carece de `Content-Security-Policy`, `X-Frame-Options`, `X-XSS-Protection`, entre otras.

```js
// Faltó agregar
const helmet = require('helmet');
app.use(helmet());
```

### 1.4 JWT_SECRET no validado al arrancar

Si `.env` no existe o la variable está vacía, `jwt.sign()` firma tokens con `undefined` como secreto sin lanzar error inmediato.

```js
// Faltó agregar al inicio
if (!process.env.JWT_SECRET) throw new Error('JWT_SECRET no definido en .env');
```

### 1.5 Mensajes de error exponen detalles internos

```js
// Actual — expone stack trace o mensaje del motor de BD al cliente
res.status(503).json({ message: 'Error del servidor: ' + e.message });

// Correcto — log interno, respuesta genérica al cliente
console.error(e);
res.status(500).json({ message: 'Error interno del servidor' });
```

### 1.6 `SELECT *` en `getUsuarioByEmail` expone `password_hash`

La función devuelve toda la fila, incluyendo el hash. Si en algún refactor ese objeto se enviara al cliente por error, se filtraría información sensible.

### 1.7 Sin límite de tamaño en el body

```js
// Actual
app.use(express.json());

// Correcto — previene ataques de payload gigante
app.use(express.json({ limit: '10kb' }));
```

---

## 2. Validación de Entradas

### 2.1 Sin validación de tipos ni formato en ninguna ruta

`POST /mascotas` acepta cualquier valor sin validar que `nombre` sea string, `edad` sea número positivo, `foto_url` sea una URL válida, etc.

### 2.2 `insertaMascota` no valida que `nombre` (campo obligatorio) esté presente

La función filtra campos permitidos pero no verifica que los campos `NOT NULL` de la BD estén presentes. Si se omite `nombre`, MySQL lanzará un error y el mensaje al cliente será genérico sin orientación.

### 2.3 `GET /mascotas/:id` no valida que el parámetro sea un número

```js
// Actual — pasa el string directamente a la query
const { id } = req.params;

// Correcto
const id = parseInt(req.params.id, 10);
if (isNaN(id)) return res.status(400).json({ message: 'ID inválido' });
```

---

## 3. Arquitectura y Estructura

### 3.1 Sin separación de responsabilidades

Todo el código vive en dos archivos. La estructura correcta sería:

```
backend/
├── routes/         mascotas.js, auth.js, publicaciones.js
├── controllers/    mascotasController.js, authController.js
├── services/       mascotasService.js
├── db/             conexion.cjs, schema.sql
└── server.cjs      solo configuración y arranque
```

### 3.2 Sin middleware centralizado de errores

Cada ruta repite el mismo bloque `catch`. Express permite un handler global:

```js
// Faltó agregar al final de server.cjs
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ ok: false, message: 'Error interno del servidor' });
});
```

### 3.3 `pool` exportado desde `conexion.cjs`

Exportar el pool directamente rompe la encapsulación. Cualquier archivo podría ejecutar queries arbitrarias sin pasar por las funciones validadas.

---

## 4. Base de Datos

### 4.1 `schema.sql` incompleto

Faltan las tablas `publicaciones` e `imagenes_publicacion` que el servidor usa activamente.

### 4.2 Sin índices en columnas de búsqueda frecuente

```sql
-- Faltó agregar
CREATE INDEX idx_mascotas_dueno      ON mascotas(dueno_id);
CREATE INDEX idx_usuarios_dueno      ON usuarios(dueno_id);
CREATE INDEX idx_imagenes_publicacion ON imagenes_publicacion(publicacion_id);
```

### 4.3 `createUsuario` asigna `ultimo_login` al momento de creación

```js
// Semántica incorrecta — el usuario nunca ha hecho login al crearse
[dueno_id, email, password_hash, true, ahora, ahora]

// Correcto
[dueno_id, email, password_hash, true, null, ahora]
```

### 4.4 Sin sistema de migraciones

No hay forma controlada de evolucionar el esquema en producción (no usa Flyway, Liquibase, ni siquiera scripts numerados).

---

## 5. Diseño de API

### 5.1 Código HTTP semánticamente incorrecto

```js
// Actual — devuelve 200 cuando no se encuentra el recurso
res.status(200).json({ ok: true, message: 'Mascota no encontrada' });

// Correcto
res.status(404).json({ ok: false, message: 'Mascota no encontrada' });
```

### 5.2 Sin paginación en endpoints de lista

`GET /publicaciones` devuelve todos los registros sin límite. Con suficientes datos, esto agota memoria.

### 5.3 Sin versionado de API

No hay prefijo `/api/v1/`. Si se rompe compatibilidad en el futuro, todos los clientes Flutter se rompen simultáneamente.

---

## 6. Calidad y Mantenibilidad

### 6.1 Sin script de inicio en `package.json`

```json
"scripts": {
  "start": "node backend/server.cjs",
  "dev": "nodemon backend/server.cjs"
}
```

### 6.2 Sin sistema de logging estructurado

Solo usa `console.log` / `console.error`. En producción se necesita un logger como `pino` o `winston` que incluya timestamps, niveles y correlación de peticiones.

### 6.3 Sin apagado ordenado (graceful shutdown)

```js
// Faltó agregar
process.on('SIGTERM', async () => {
  await pool.end();
  process.exit(0);
});
```

---

## 7. Testing y Documentación

| Carencia | Impacto |
|---|---|
| Sin ninguna prueba (unitaria, integración o e2e) | No hay forma de verificar regresiones |
| Sin documentación de API (Swagger/OpenAPI) | El equipo Flutter no sabe qué espera cada endpoint |
| Sin README con instrucciones de instalación | Otro desarrollador no puede levantar el proyecto |

---

## Resumen de severidad

| # | Carencia | Severidad |
|---|---|---|
| 1 | Migración incompleta — rutas siguen usando Supabase | **Crítico** |
| 2 | Sin rate limiting en `/auth/login` | **Alto** |
| 3 | CORS abierto | **Alto** |
| 4 | Sin helmet.js | **Alto** |
| 5 | Mensajes de error exponen detalles internos | **Alto** |
| 6 | `schema.sql` incompleto (faltan 2 tablas) | **Alto** |
| 7 | Sin validación de entradas | **Medio** |
| 8 | Sin separación de responsabilidades | **Medio** |
| 9 | Código HTTP semánticamente incorrecto | **Medio** |
| 10 | Sin pruebas ni documentación | **Medio** |
| 11 | Sin índices de BD | **Bajo** |
| 12 | Sin graceful shutdown | **Bajo** |
