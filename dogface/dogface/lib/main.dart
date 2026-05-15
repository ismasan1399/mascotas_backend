import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== PUNTO DE ENTRADA ====================
void main() => runApp(const MiApp());

/// Aplicación principal de DogFace
class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const PaginaLogin(),
      debugShowCheckedModeBanner: false,
      title: 'DogFace',
    );
  }
}

// ==================== LOGIN ====================
class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _EstadoPaginaLogin();
}

class _EstadoPaginaLogin extends State<PaginaLogin> {
  final ctrlUsuario = TextEditingController();
  final ctrlContrasena = TextEditingController();
  String mensajeError = '';
  bool cargando = false;
  static const String urlApi = 'http://127.0.0.1:3000/auth/login';

  Future<void> iniciarSesion() async {
    if (ctrlUsuario.text.isEmpty || ctrlContrasena.text.isEmpty) {
      setState(() => mensajeError = 'Completa todos los campos');
      return;
    }

    setState(() {
      cargando = true;
      mensajeError = '';
    });

    try {
      final respuesta = await http.post(
        Uri.parse(urlApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': ctrlUsuario.text,
          'password': ctrlContrasena.text,
        }),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['success'] == true) {
        await _guardarToken(datos['token']);
        _navegarAPaginaPrincipal();
      } else {
        setState(
          () => mensajeError = datos['error'] ?? 'Credenciales incorrectas',
        );
      }
    } catch (_) {
      setState(() => mensajeError = 'Error de conexión. Verifica tu red.');
    } finally {
      setState(() => cargando = false);
    }
  }

  Future<void> _guardarToken(String token) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString('token', token);
  }

  void _navegarAPaginaPrincipal() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PaginaPrincipal()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _construirLogo(),
                _construirCamposFormulario(),
                _construirBotonIngreso(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirLogo() {
    return const Column(
      children: [
        Icon(Icons.pets, size: 100, color: Colors.white),
        SizedBox(height: 16),
        Text(
          'DogFace',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _construirCamposFormulario() {
    return Column(
      children: [
        _campoTexto(ctrlUsuario, 'Usuario', Icons.person),
        const SizedBox(height: 16),
        _campoTexto(
          ctrlContrasena,
          'Contraseña',
          Icons.lock,
          esContrasena: true,
        ),
        const SizedBox(height: 8),
        Text(mensajeError, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _campoTexto(
    TextEditingController ctrl,
    String etiqueta,
    IconData icono, {
    bool esContrasena = false,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: esContrasena,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiqueta,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icono, color: Colors.white),
        filled: true,
        fillColor: Colors.white24,
      ),
    );
  }

  Widget _construirBotonIngreso() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: cargando ? null : iniciarSesion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF667eea),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: cargando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF667eea),
                ),
              )
            : const Text(
                'Ingresar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  @override
  void dispose() {
    ctrlUsuario.dispose();
    ctrlContrasena.dispose();
    super.dispose();
  }
}

// ==================== PÁGINA PRINCIPAL ====================
class PaginaPrincipal extends StatefulWidget {
  const PaginaPrincipal({super.key});

  @override
  State<PaginaPrincipal> createState() => _EstadoPaginaPrincipal();
}

class _EstadoPaginaPrincipal extends State<PaginaPrincipal> {
  int indiceSeleccionado = 0;
  final List<Map<String, dynamic>> listaComentarios = [];
  Map<String, dynamic>? reaccionSeleccionada;
  bool mostrarReacciones = false;

  // Imágenes cargadas desde el backend (solo animales validados)
  List<String> imagenesPublicacion = [];
  bool cargandoImagenes = true;

  static const String _urlImagenesPost = 'http://127.0.0.1:3000/publicaciones/1/imagenes';

  @override
  void initState() {
    super.initState();
    _cargarImagenesPublicacion();
  }

  Future<void> _cargarImagenesPublicacion() async {
    try {
      final respuesta = await http.get(Uri.parse(_urlImagenesPost));
      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        if (datos['ok'] == true && datos['imagenes'] != null) {
          setState(() {
            imagenesPublicacion = List<String>.from(datos['imagenes']);
          });
        }
      }
    } catch (_) {
      // Si falla la conexión, la galería queda vacía
    } finally {
      setState(() => cargandoImagenes = false);
    }
  }

  static const List<Map<String, dynamic>> catalogoReacciones = [
    {'icon': Icons.thumb_up, 'color': Colors.blue, 'label': 'Me gusta'},
    {'icon': Icons.favorite, 'color': Colors.red, 'label': 'Me encanta'},
    {
      'icon': Icons.emoji_emotions,
      'color': Colors.orange,
      'label': 'Me divierte',
    },
    {'icon': Icons.auto_awesome, 'color': Colors.amber, 'label': 'Me asombra'},
    {
      'icon': Icons.sentiment_very_dissatisfied,
      'color': Colors.brown,
      'label': 'Me entristece',
    },
    {'icon': Icons.mood_bad, 'color': Colors.red, 'label': 'Me enoja'},
  ];

  void seleccionarReaccion(Map<String, dynamic> reaccion) {
    setState(() {
      reaccionSeleccionada = reaccion;
      mostrarReacciones = false;
    });
  }

  void alternarReacciones() {
    setState(() => mostrarReacciones = !mostrarReacciones);
  }

  void mostrarDialogoComentarios() {
    final ctrlComentario = TextEditingController();
    showDialog(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, actualizar) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.chat, color: Color(0xFF667eea)),
              SizedBox(width: 8),
              Text('Comentarios'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                _construirListaComentarios(actualizar),
                const SizedBox(height: 8),
                _construirCampoNuevoComentario(ctrlComentario, actualizar),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  final ScrollController _controladorGaleria = ScrollController();

  @override
  void dispose() {
    _controladorGaleria.dispose();
    super.dispose();
  }

  Widget _construirGaleriaImagenes(List<String> urls) {
    if (cargandoImagenes) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF667eea)),
        ),
      );
    }
    if (urls.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Icon(Icons.image, size: 60, color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 250,
          child: Scrollbar(
            controller: _controladorGaleria,
            thumbVisibility: true, 
            child: ListView.builder(
              controller: _controladorGaleria,
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          urls[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        if (index == 0 && urls.length > 1)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${urls.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              'Desliza o usa la barra lateral para ver más (${urls.length} fotos)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _construirListaComentarios(void Function(void Function()) actualizar) {
    return Expanded(
      child: listaComentarios.isEmpty
          ? const Center(
              child: Text(
                'Sin comentarios aún. ¡Sé el primero!',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: listaComentarios.length,
              itemBuilder: (_, indice) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF764ba2),
                  child: Text(
                    listaComentarios[indice]['usuario'][0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  listaComentarios[indice]['usuario'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(listaComentarios[indice]['texto']),
              ),
            ),
    );
  }

  Widget _construirCampoNuevoComentario(
    TextEditingController ctrl,
    void Function(void Function()) actualizar,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Escribe un comentario...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: Color(0xFF667eea)),
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              actualizar(
                () =>
                    listaComentarios.add({'usuario': 'Tú', 'texto': ctrl.text}),
              );
              setState(() {});
              ctrl.clear();
            }
          },
        ),
      ],
    );
  }

  Widget construirPaginaInicio() =>
      SingleChildScrollView(child: Column(children: [_construirPublicacion()]));
  Widget construirPaginaVideo() =>
      _paginaPlaceholder(Icons.video_library, '🎬 Videos');
  Widget construirPaginaMarket() =>
      _paginaPlaceholder(Icons.store, '🛒 Market');
  Widget construirPaginaAlertas() =>
      _paginaPlaceholder(Icons.notifications, '🔔 Alertas');
  Widget construirPaginaMenu() => _paginaPlaceholder(Icons.menu, '📋 Menú');

  Widget _paginaPlaceholder(IconData icono, String titulo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget obtenerPaginaActual() {
    switch (indiceSeleccionado) {
      case 0:
        return construirPaginaInicio();
      case 1:
        return construirPaginaVideo();
      case 2:
        return construirPaginaMarket();
      case 3:
        return construirPaginaAlertas();
      case 4:
        return construirPaginaMenu();
      default:
        return construirPaginaInicio();
    }
  }

  Widget _construirPublicacion() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _construirCabeceraPublicacion(),
          _construirGaleriaImagenes(imagenesPublicacion),
          if (reaccionSeleccionada != null) _construirBannerReaccion(),
          _construirBarraAcciones(),
          _construirTextoPublicacion(),
          _construirPiePublicacion(),
        ],
      ),
    );
  }

  Widget _construirCabeceraPublicacion() {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFF764ba2),
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: const Text(
        'Carlos Pérez',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('Hace 2 horas'),
    );
  }

  Widget _construirImagenPublicacion() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF667eea),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: const Center(
        child: Icon(Icons.image, size: 80, color: Colors.white24),
      ),
    );
  }

  Widget _construirBannerReaccion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          Icon(
            reaccionSeleccionada!['icon'],
            color: reaccionSeleccionada!['color'],
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Reaccionaste con: ${reaccionSeleccionada!['label']}',
            style: TextStyle(
              color: reaccionSeleccionada!['color'],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBarraAcciones() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [_botonMeGusta(), _botonComentar(), _botonCompartir()],
          ),
        ),
        if (mostrarReacciones) _menuReacciones(),
      ],
    );
  }

  Widget _botonMeGusta() {
    return GestureDetector(
      onTap: alternarReacciones,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.thumb_up,
              color: mostrarReacciones ? const Color(0xFF667eea) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Me gusta',
              style: TextStyle(
                color: mostrarReacciones
                    ? const Color(0xFF667eea)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonComentar() {
    return GestureDetector(
      onTap: mostrarDialogoComentarios,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble, color: Colors.grey),
            SizedBox(width: 4),
            Text('Comentar', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _botonCompartir() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.share, color: Colors.grey),
          SizedBox(width: 4),
          Text('Compartir', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _menuReacciones() {
    return Positioned(
      left: 10,
      bottom: 55,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: catalogoReacciones
                .map(
                  (reaccion) => InkWell(
                    onTap: () => seleccionarReaccion(reaccion),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        reaccion['icon'],
                        color: reaccion['color'],
                        size: 36,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _construirTextoPublicacion() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        '¡Hermoso día con los amigos! 🌞',
        style: TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _construirPiePublicacion() {
    return Column(
      children: [
        Container(height: 1, color: Colors.grey[300]),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '245 personas más reaccionaron a esto.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: _construirAppBar(),
      body: obtenerPaginaActual(),
      bottomNavigationBar: _construirBottomNav(),
    );
  }

  PreferredSizeWidget _construirAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF667eea),
      elevation: 2,
      title: const Row(
        children: [
          Icon(Icons.pets, size: 32),
          SizedBox(width: 8),
          Text(
            'DogFace',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, size: 28),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaginaConfiguracion()),
          ),
        ),
      ],
    );
  }

  Widget _construirBottomNav() {
    return BottomNavigationBar(
      currentIndex: indiceSeleccionado,
      onTap: (indice) => setState(() => indiceSeleccionado = indice),
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF667eea),
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library),
          label: 'Video',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.store), label: 'Market'),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Alertas',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menú'),
      ],
    );
  }
}

// ==================== CONFIGURACIÓN ====================
class PaginaConfiguracion extends StatefulWidget {
  const PaginaConfiguracion({super.key});

  @override
  State<PaginaConfiguracion> createState() => _EstadoPaginaConfiguracion();
}

class _EstadoPaginaConfiguracion extends State<PaginaConfiguracion> {
  // ─── Estado del perfil ───
  String nombreUsuario = '';
  String correoUsuario = '';
  bool cargandoPerfil = true;
  String errorPerfil = '';

  static const String urlPerfil = 'http://127.0.0.1:3000/auth/perfil';

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  /// Consulta API para obtener datos del usuario autenticado
  Future<void> _cargarDatosPerfil() async {
    setState(() {
      cargandoPerfil = true;
      errorPerfil = '';
    });

    try {
      final preferencias = await SharedPreferences.getInstance();
      final token = preferencias.getString('token');

      if (token == null) {
        setState(() {
          errorPerfil = 'No hay sesión activa';
          cargandoPerfil = false;
        });
        return;
      }

      final respuesta = await http.get(
        Uri.parse(urlPerfil),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body);
        final infoUsuario = datos['data'] as Map<String, dynamic>?;

        if (infoUsuario != null) {
          final email =
              infoUsuario['email'] as String? ?? 'sin-email@ejemplo.com';

          final duenos = infoUsuario['duenos'] as Map<String, dynamic>?;
          final nombre = duenos?['nombre'] as String? ?? 'Usuario';
          final apellido = duenos?['apellido'] as String? ?? '';

          setState(() {
            nombreUsuario = '$nombre $apellido'.trim();
            correoUsuario = email;
            cargandoPerfil = false;
          });
        } else {
          setState(() {
            errorPerfil = 'Datos de usuario no encontrados';
            cargandoPerfil = false;
          });
        }
      } else {
        setState(() {
          errorPerfil = 'Error al cargar perfil';
          cargandoPerfil = false;
        });
      }
    } catch (_) {
      setState(() {
        errorPerfil = 'Error de conexión';
        cargandoPerfil = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[100]!, Colors.grey[200]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _construirSeccionPerfil(),
              const SizedBox(height: 24),
              _construirIconoConfig(),
              const SizedBox(height: 40),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _itemConfig(
                      Icons.lock,
                      'Privacidad',
                      'Configurar privacidad',
                    ),
                    _itemConfig(
                      Icons.notifications,
                      'Notificaciones',
                      'Administrar alertas',
                    ),
                    _itemConfig(Icons.palette, 'Apariencia', 'Cambiar tema'),
                    _itemConfig(Icons.help, 'Ayuda', 'Centro de ayuda'),
                    _itemConfig(
                      Icons.logout,
                      'Cerrar sesión',
                      'Salir de la aplicación',
                      esPeligro: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirSeccionPerfil() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person, color: Color(0xFF667eea), size: 24),
              SizedBox(width: 8),
              Text(
                'Mi Perfil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cargandoPerfil)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)),
            )
          else if (errorPerfil.isNotEmpty)
            Column(
              children: [
                Text(errorPerfil, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _cargarDatosPerfil,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _datoPerfil(Icons.person, 'Nombre', nombreUsuario),
                const SizedBox(height: 12),
                _datoPerfil(Icons.email, 'Correo', correoUsuario),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _cargarDatosPerfil,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Actualizar'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _datoPerfil(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Icon(icono, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirIconoConfig() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: const Icon(Icons.settings, size: 64, color: Color(0xFF667eea)),
    );
  }

  Widget _itemConfig(
    IconData icono,
    String titulo,
    String subtitulo, {
    bool esPeligro = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          icono,
          color: esPeligro ? Colors.red : const Color(0xFF667eea),
        ),
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: esPeligro ? Colors.red : null,
          ),
        ),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
