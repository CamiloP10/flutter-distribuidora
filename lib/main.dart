import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/init_provider.dart';
import 'providers/producto_provider.dart';
import 'providers/cliente_provider.dart';
import 'screens/home_screen.dart';
import 'screens/agregar_producto_screen.dart';
import 'screens/agregar_cliente_screen.dart';
import 'providers/ventas_provider.dart';
import 'screens/creditos_screen.dart';
import 'providers/cierre_dia_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppWithProviders());
}

class AppWithProviders extends StatelessWidget {
  const AppWithProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InitProvider()),
        ChangeNotifierProvider(create: (_) => ProductoProvider()),
        ChangeNotifierProvider(create: (_) => ClienteProvider()),
        ChangeNotifierProvider(create: (_) => VentasProvider()),
        ChangeNotifierProvider(create: (_) => CierreDiaProvider()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DISTRIBUIDORA  LA BELLEZA',
      theme: ThemeData(primarySwatch: Colors.teal),
      debugShowCheckedModeBanner: false,
      home: const AppInitializer(),
      routes: {
        '/agregarProducto': (context) => const AgregarProductoScreen(),
        '/agregarCliente': (context) => const AgregarClienteScreen(),
        '/creditos': (context) => const CreditosScreen(),
      },
    );
  }
}

class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    final initProvider = Provider.of<InitProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      initProvider.inicializarTodo();
    });

    if (initProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 🔄 Cargar datos iniciales en los providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Providers individuales
      Provider.of<ProductoProvider>(context, listen: false).cargarProductos();
      Provider.of<ClienteProvider>(context, listen: false).cargarClientes();

      // VentasProvider -> necesita tenertodo cargado para que funcione bien en ventas y cargues
      final ventasProvider = Provider.of<VentasProvider>(context, listen: false);
      ventasProvider.cargarFacturas();
      ventasProvider.cargarCargues();
      ventasProvider.cargarClientes();   //asegura clientes en memoria
      ventasProvider.cargarProductos();  // asegura productos en memoria
    });

    return const HomeScreen();
  }
}