-- ============================================================
--  Schema completo para proyecto DogFace
--  Ejecutar en tu propio proyecto de Supabase
-- ============================================================

-- 1. Dueños de mascotas
CREATE TABLE IF NOT EXISTS duenos (
    id          SERIAL PRIMARY KEY,
    nombre      TEXT NOT NULL,
    apellido    TEXT NOT NULL,
    telefono    TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Usuarios del sistema
CREATE TABLE IF NOT EXISTS usuarios (
    id              SERIAL PRIMARY KEY,
    dueno_id        INTEGER REFERENCES duenos(id) ON DELETE CASCADE,
    email           TEXT NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    activo          BOOLEAN DEFAULT TRUE,
    ultimo_login    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Mascotas
CREATE TABLE IF NOT EXISTS mascotas (
    id          SERIAL PRIMARY KEY,
    nombre      TEXT NOT NULL,
    especie     TEXT,
    raza        TEXT,
    dueno_id    INTEGER REFERENCES duenos(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Publicaciones del feed
CREATE TABLE IF NOT EXISTS publicaciones (
    id              SERIAL PRIMARY KEY,
    dueno_id        INTEGER REFERENCES duenos(id) ON DELETE SET NULL,
    autor           TEXT DEFAULT 'Usuario',
    descripcion     TEXT DEFAULT '',
    fecha_creacion  TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Imágenes de publicaciones (con validación de animal)
CREATE TABLE IF NOT EXISTS imagenes_publicacion (
    id              SERIAL PRIMARY KEY,
    publicacion_id  INTEGER REFERENCES publicaciones(id) ON DELETE CASCADE,
    url             TEXT NOT NULL,
    es_animal       BOOLEAN NOT NULL DEFAULT TRUE,
    tipo_animal     TEXT CHECK (
                        tipo_animal IN ('perro','gato','ave','conejo','hamster','reptil','otro_animal')
                    ),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  Datos de prueba
-- ============================================================

INSERT INTO duenos (nombre, apellido, telefono) VALUES
    ('Carlos', 'Pérez', '5511223344');

-- Contraseña: "mascotas123"  (genera tu propio hash con bcrypt en producción)
-- Hash de ejemplo generado con bcrypt rounds=15:
INSERT INTO usuarios (dueno_id, email, password_hash, activo) VALUES
    (1, 'carlos@dogface.com',
     '$2b$15$KIX8zVDCdEY1HW4yZjWnG.8b3FqF3d9J7z0QuXH5jHFrI3SvN7Cey',
     TRUE);

INSERT INTO publicaciones (dueno_id, autor, descripcion) VALUES
    (1, 'Carlos Pérez', '¡Hermoso día con los amigos! 🌞');

-- Imágenes de animales (es_animal = TRUE → el API las retorna)
INSERT INTO imagenes_publicacion (publicacion_id, url, es_animal, tipo_animal) VALUES
    (1, 'https://images.dog.ceo/breeds/labrador/n02099712_2028.jpg',   TRUE, 'perro'),
    (1, 'https://images.dog.ceo/breeds/retriever-golden/n02099601_1094.jpg', TRUE, 'perro'),
    (1, 'https://images.dog.ceo/breeds/husky/n02110185_10047.jpg',     TRUE, 'perro');

-- Imagen de ejemplo rechazada (es_animal = FALSE → el API NO la retorna)
INSERT INTO imagenes_publicacion (publicacion_id, url, es_animal, tipo_animal) VALUES
    (1, 'https://picsum.photos/600/400?random=99', FALSE, NULL);
