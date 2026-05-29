CREATE DATABASE IF NOT EXISTS mascotas_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE mascotas_db;

CREATE TABLE IF NOT EXISTS duenos (
  id         INT          NOT NULL AUTO_INCREMENT,
  nombre     VARCHAR(100) NOT NULL,
  apellido   VARCHAR(100) NOT NULL,
  telefono   VARCHAR(20)           DEFAULT NULL,
  direccion  VARCHAR(255)          DEFAULT NULL,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS usuarios (
  id            INT          NOT NULL AUTO_INCREMENT,
  dueno_id      INT          NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  activo        TINYINT(1)   NOT NULL DEFAULT 1,
  ultimo_login  DATETIME              DEFAULT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (dueno_id) REFERENCES duenos (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS mascotas (
  id          INT          NOT NULL AUTO_INCREMENT,
  nombre      VARCHAR(100) NOT NULL,
  especie     VARCHAR(50)           DEFAULT NULL,
  raza        VARCHAR(100)          DEFAULT NULL,
  edad        INT                   DEFAULT NULL,
  dueno_id    INT                   DEFAULT NULL,
  descripcion TEXT                  DEFAULT NULL,
  foto_url    VARCHAR(500)          DEFAULT NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY (dueno_id) REFERENCES duenos (id) ON DELETE SET NULL
);
