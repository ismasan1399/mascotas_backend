const express  = require('express');
const { supabase, testConnection, insertaMascota } = require('./db/conexion.cjs');
const bcrypt   = require('bcrypt');
const jwt      = require('jsonwebtoken');
const cors     = require('cors');

const SALT_ROUNDS_BCRYPT = 15;
const app  = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

// ── Middleware de autenticación JWT ───────────────────────────────────────────
function verificarToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) {
        return res.status(401).json({ ok: false, message: 'Token no proporcionado' });
    }
    try {
        req.usuario = jwt.verify(token, process.env.JWT_SECRET);
        next();
    } catch (_) {
        return res.status(401).json({ ok: false, message: 'Token inválido o expirado' });
    }
}

// ── Rutas generales ───────────────────────────────────────────────────────────
app.get('/', (req, res) => {
    res.send('Servidor funcionando correctamente');
});

app.get('/estatus', async (req, res) => {
    const estado = await testConnection();
    res.json(estado);
});

// ── Mascotas ──────────────────────────────────────────────────────────────────
app.post('/mascotas', async (req, res) => {
    const estado = await insertaMascota(req.body);
    res.json(estado);
});

app.get('/mascotas/:id', async (req, res) => {
    const { id } = req.params;
    const { data, error } = await supabase.from('mascotas').select().eq('id', id);
    if (error) {
        return res.status(503).json({ ok: false, message: 'Error al conectar con la base de datos' });
    }
    if (Array.isArray(data) && data.length > 0) {
        return res.status(200).json({ ok: true, message: 'Mascota encontrada', data });
    }
    res.status(200).json({ ok: true, message: 'Mascota no encontrada' });
});

// ── Auth ──────────────────────────────────────────────────────────────────────
app.post('/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ ok: false, success: false, message: 'Faltan datos de ingreso' });
        }

        const { data: usuario, error } = await supabase
            .from('usuarios')
            .select('*')
            .eq('email', email)
            .maybeSingle();

        if (error) {
            return res.status(503).json({ ok: false, success: false, message: 'Error de base de datos: ' + error.message });
        }
        if (!usuario) {
            return res.status(404).json({ ok: false, success: false, message: 'Usuario no encontrado' });
        }

        const match = await bcrypt.compare(password, usuario.password_hash);
        if (!match) {
            return res.status(401).json({ ok: false, success: false, message: 'Credenciales incorrectas' });
        }

        const token = jwt.sign(
            { dueno_id: usuario.dueno_id, usuario_id: usuario.id },
            process.env.JWT_SECRET,
            { expiresIn: '1h' }
        );

        // 'success' y 'ok' son equivalentes; Flutter usa 'success'
        res.status(200).json({ ok: true, success: true, message: 'Login exitoso', token });
    } catch (e) {
        res.status(503).json({ ok: false, success: false, message: 'Error del servidor: ' + e.message });
    }
});

app.get('/auth/perfil', verificarToken, async (req, res) => {
    try {
        const { dueno_id } = req.usuario;

        const { data: usuario, error } = await supabase
            .from('usuarios')
            .select('id, email, dueno_id, activo, duenos(nombre, apellido)')
            .eq('dueno_id', dueno_id)
            .maybeSingle();

        if (error) {
            return res.status(503).json({ ok: false, message: 'Error de base de datos: ' + error.message });
        }
        if (!usuario) {
            return res.status(404).json({ ok: false, message: 'Usuario no encontrado' });
        }

        res.status(200).json({ ok: true, data: usuario });
    } catch (e) {
        res.status(503).json({ ok: false, message: 'Error del servidor: ' + e.message });
    }
});

// ── Publicaciones e imágenes ──────────────────────────────────────────────────

// GET /publicaciones  →  lista de posts con sus imágenes de animales
app.get('/publicaciones', async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('publicaciones')
            .select('id, autor, descripcion, fecha_creacion, imagenes_publicacion(id, url, tipo_animal, es_animal)')
            .order('fecha_creacion', { ascending: false });

        if (error) {
            return res.status(503).json({ ok: false, message: 'Error al obtener publicaciones: ' + error.message });
        }

        const resultado = data.map(pub => ({
            id:             pub.id,
            autor:          pub.autor,
            descripcion:    pub.descripcion,
            fecha_creacion: pub.fecha_creacion,
            // Solo se exponen URLs donde es_animal = true
            imagenes: (pub.imagenes_publicacion || [])
                .filter(img => img.es_animal === true)
                .map(img => img.url),
        }));

        res.status(200).json({ ok: true, data: resultado });
    } catch (e) {
        res.status(503).json({ ok: false, message: 'Error del servidor: ' + e.message });
    }
});

// GET /publicaciones/:id/imagenes  →  solo URLs de animales para un post
app.get('/publicaciones/:id/imagenes', async (req, res) => {
    try {
        const id = parseInt(req.params.id, 10);
        if (isNaN(id)) {
            return res.status(400).json({ ok: false, message: 'ID de publicación inválido' });
        }

        const { data, error } = await supabase
            .from('imagenes_publicacion')
            .select('url, tipo_animal')
            .eq('publicacion_id', id)
            .eq('es_animal', true);   // ← validación: solo imágenes de animales

        if (error) {
            return res.status(503).json({ ok: false, message: 'Error al obtener imágenes: ' + error.message });
        }

        const imagenes = data.map(img => img.url);
        res.status(200).json({ ok: true, imagenes, total: imagenes.length });
    } catch (e) {
        res.status(503).json({ ok: false, message: 'Error del servidor: ' + e.message });
    }
});

// ─────────────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
    console.log(`Servidor ejecutándose en el puerto ${PORT}`);
});
