const express   = require('express');
const { supabase, testConnection, insertaMascota } = require('./db/conexion.cjs');
const bcrypt    = require('bcrypt');
const jwt      = require('jsonwebtoken');
const cors = require('cors');
const SALT_ROUNDS_BCRYPT = 15;
const app = express()
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
    res.send('Servidor funcionando correctamente')
});

app.get('/estatus', async (req, res) => {
    const estado = await testConnection();
    res.json(estado);
});

app.post('/mascotas', async (req, res) => {
    console.log(req.body);
    const estado = await insertaMascota(req.body);
    res.json(estado);
})

app.get('/mascotas/:id', async (req, res) => {
   const {id} = req.params;
   const {data, error} = await supabase.from("mascotas").select().eq("id", id);
   if (error) {
     res.status(503).json({ok: false, message: "Error al conectar con la base de datos"});
   } else {
     if (Array.isArray(data) && data.length > 0) {
        res.status(200).json({ok: true, message: "Mascota encontrada", data}); 
     } else {
        res.status(200).json({ok: true, message: "Mascota no encontrada"});  
     }
   }  
});


app.get('/crea_cuenta', async (req, res) => {
    const dueno_id = 3;
    const email    = "micorreo3@correo.com";
    const pass     = "asdfghjk";
    const pass_hash= await bcrypt.hash(pass, SALT_ROUNDS_BCRYPT);
    console.log("Hash generado: ", pass_hash);
    const {data, error} = await supabase
         .from('usuarios')
         .insert([
            {
                dueno_id,
                email,
                password_hash: pass_hash,
                activo: true,
                ultimo_login: new Date().toISOString(),
                created_at: new Date().toISOString(),
            }
         ])
         .select('id, dueno_id, email, activo, ultimo_login')
         .single();
    if (error) {
        res.status(503).json({ok: false, message: "Error al conectar con la base de datos: " + error.message});
    } else {
        res.status(200).json({ok: true, message: "Cuenta creada exitosamente", data});
    }
});

app.post('/auth/login', async(req, res)  => {
   try 
   {
     const {email, password} = req.body;
     console.log(req.body);
     if (!email || !password) {
        res.status(200).json({ok: false, message: "Faltan datos de ingreso"});
        return;
     }
    const {data: usuario, error} = await supabase
        .from('usuarios')    
        .select('*')
        .eq('email', email)
        .maybeSingle();
    if (error) {
        res.status(503).json({ok: false, message: "Error al conectar con la base de datos: " + error.message});
        return;
    }
    if (!usuario) {
        res.status(404).json({ok: false, message: "Usuario no encontrado"});
        return;
    }
    console.log("Usuario encontrado: ", usuario);
    const match = await bcrypt.compare(password, usuario.password_hash);
    if (!match) {
        res.status(401).json({ok: false, message: "Credenciales incorrectas"});
        return;
    }
    const token = jwt.sign({
        dueno_id: usuario.dueno_id,
    }, 
    process.env.JWT_SECRET, 
    { expiresIn: "1h" });
    res.status(200).json({ok: true, message: "Login exitoso", token});
   } catch (e) {
      res.status(503).json({ok: false, message: "Error al conectar con la base de datos: " + e.message});
   }
});


app.listen(PORT, () => {
    console.log(`Servidor ejecutandose en el puerto ${PORT}`)
});
