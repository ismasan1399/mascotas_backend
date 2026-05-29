const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: parseInt(process.env.DB_PORT || '3306', 10),
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

async function testConnection() {
  try {
    const [[{ count }]] = await pool.query('SELECT COUNT(*) AS count FROM mascotas');
    console.log('Sin error');
    console.log(count);
    return { ok: true, message: 'Conexion exitosa y se tienen:', count };
  } catch (e) {
    console.error(e);
    return { ok: false, message: 'Error al conectar con la base de datos' };
  }
}

async function insertaMascota(datos) {
  const camposPermitidos = ['nombre', 'especie', 'raza', 'edad', 'dueno_id', 'descripcion', 'foto_url'];
  const campos = Object.keys(datos).filter((c) => camposPermitidos.includes(c));

  if (campos.length === 0) {
    return { ok: false, message: 'No se proporcionaron datos válidos' };
  }

  const columnas = campos.map((c) => `\`${c}\``).join(', ');
  const placeholders = campos.map(() => '?').join(', ');
  const valores = campos.map((c) => datos[c]);

  try {
    const [result] = await pool.query(
      `INSERT INTO mascotas (${columnas}) VALUES (${placeholders})`,
      valores
    );
    const [[mascota]] = await pool.query('SELECT * FROM mascotas WHERE id = ?', [result.insertId]);
    return { ok: true, message: 'Mascota insertada correctamente', data: mascota };
  } catch (e) {
    console.error(e);
    return { ok: false, message: 'Error al insertar la mascota' };
  }
}

async function getMascotaById(id) {
  try {
    const [rows] = await pool.query('SELECT * FROM mascotas WHERE id = ?', [id]);
    return { ok: true, data: rows };
  } catch (e) {
    console.error(e);
    return { ok: false, message: 'Error al conectar con la base de datos' };
  }
}

async function createUsuario({ dueno_id, email, password_hash }) {
  try {
    const ahora = new Date();
    const [result] = await pool.query(
      'INSERT INTO usuarios (dueno_id, email, password_hash, activo, ultimo_login, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [dueno_id, email, password_hash, true, ahora, ahora]
    );
    const [[usuario]] = await pool.query(
      'SELECT id, dueno_id, email, activo, ultimo_login FROM usuarios WHERE id = ?',
      [result.insertId]
    );
    return { ok: true, data: usuario };
  } catch (e) {
    console.error(e);
    return { ok: false, message: e.message };
  }
}

async function getUsuarioByEmail(email) {
  try {
    const [rows] = await pool.query('SELECT * FROM usuarios WHERE email = ?', [email]);
    return { ok: true, data: rows[0] || null };
  } catch (e) {
    console.error(e);
    return { ok: false, message: e.message };
  }
}

module.exports = { pool, testConnection, insertaMascota, getMascotaById, createUsuario, getUsuarioByEmail };
