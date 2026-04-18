const express = require('express')
const { supabase, testConnection, insertaMascota } = require('./db/conexion.cjs');

const app = express()
const PORT = 3000;

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


app.listen(PORT, () => {
    console.log(`Servidor ejecutandose en el puerto ${PORT}`)
});
