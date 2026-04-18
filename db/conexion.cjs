const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error("No estan configuradas las variables de entorno");
    process.exit(1);
}
const supabase = createClient(supabaseUrl, supabaseKey);

async function testConnection() {
    try {
        const { data, error, count } = await supabase.from('mascotas').select('*', { count: 'exact', head: true });
        if (error) {
            if (error.code === 'PGRST116') {
                console.error("La tabla mascotas esta vacia o no tengo permisos");
                return { ok: false, message: 'La tabla mascotas esta vacia o no tengo permisos' }
            }
            throw error;
        }
    console.log("Sin error");
    console.log(count);    
    return { ok: true, message: 'Conexion exitosa y se tienen:', count};
    } catch(e){
        console.error(e);
        return { ok: false, message: 'Error al conectar con la base de datos' }
    }
}

async function insertaMascota(datos) {
    const {data, error} = await supabase.from("mascotas").insert(datos).select();
    if (error) {
        console.error(error);
        return { ok: false, message: "Error al insertar la mascota" };
    } else {
        return { ok: true, message: "Mascota insertada correctamente", data: data[0] };
    }
}

module.exports = {supabase,testConnection,insertaMascota};