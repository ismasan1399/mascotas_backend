# Reporte de Carencias — Auditoría de Migración Supabase → MySQL

> **Alcance:** La única responsabilidad evaluada es la migración de la capa de base de datos
> de Supabase (supabase-js v2 / PostgreSQL) a MySQL usando mysql2 con promesas.
> El resto del proyecto (rutas, autenticación, lógica de negocio) queda fuera del alcance.

---

## Lo que se pedía

| Entregable | Estado |
|---|---|
| Reemplazar conexión Supabase por pool mysql2/promise con variables de entorno | Completado |
| Reescribir `testConnection` con SQL puro | Completado |
| Reescribir `insertaMascota` con SQL puro | Completado |
| Script SQL para crear tablas en MySQL (AUTO_INCREMENT, backticks) | Parcial |
| Archivo `.env.example` con variables para MySQL | Completado |
| Actualizar `package.json` (quitar supabase-js, agregar mysql2) | Completado |

---

## Carencias dentro del alcance de la migración

### 1. La migración de funciones quedó incompleta

El prompt pedía migrar las funciones existentes. Además de `testConnection` e `insertaMascota`, el servidor también usaba funciones de Supabase para otras operaciones que no fueron reescritas con SQL puro. La IA añadió `getMascotaById`, `getUsuarioByEmail` y `createUsuario` a `conexion.cjs`, pero las rutas en `server.cjs` que consumían Supabase directamente no fueron actualizadas para usar esas nuevas funciones, dejando el servidor en un estado inconsistente.

### 2. `schema.sql` no cubre todas las tablas que usa el proyecto

El script SQL entregado solo incluye las tablas `duenos`, `usuarios` y `mascotas`. El servidor también referencia las tablas `publicaciones` e `imagenes_publicacion`, las cuales no fueron incluidas en el script de migración, por lo que el esquema entregado no es suficiente para levantar el proyecto desde cero.

```sql
-- Faltó incluir en schema.sql
CREATE TABLE IF NOT EXISTS publicaciones ( ... );
CREATE TABLE IF NOT EXISTS imagenes_publicacion ( ... );
```

### 3. No se documentó el procedimiento de migración

El `.env.example` fue entregado pero no se indicó el orden de pasos para ejecutar la migración:

1. Instalar dependencias (`npm install`)
2. Crear la base de datos ejecutando `schema.sql`
3. Copiar `.env.example` a `.env` y llenar credenciales
4. Arrancar el servidor

---

## Resumen

| # | Carencia | Severidad |
|---|---|---|
| 1 | Rutas de `server.cjs` no actualizadas para usar las nuevas funciones MySQL | **Alto** |
| 2 | `schema.sql` sin las tablas `publicaciones` e `imagenes_publicacion` | **Alto** |
| 3 | Sin documentación del procedimiento de migración | **Bajo** |
