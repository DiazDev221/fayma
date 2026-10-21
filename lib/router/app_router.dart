import 'package:go_router/go_router.dart';

import '../screens/add_client_screen.dart';
import '../screens/client_detail_screen.dart';
import '../screens/deposit_screen.dart';
import '../screens/home_screen.dart';
import '../screens/pick_contact_screen.dart';
import '../screens/purchase_screen.dart';
import '../screens/repayment_screen.dart';

/// Chemins de l'application, centralisés pour éviter les fautes de frappe.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const newClient = '/clients/new';
  static const pickContact = '/clients/contacts';

  static const _client = '/clients';
  static String client(String id) => '$_client/$id';
  static String purchase(String id) => '$_client/$id/purchase';
  static String repayment(String id) => '$_client/$id/repayment';
  static String deposit(String id) => '$_client/$id/deposit';
}

/// Routes de l'application, une par écran de la maquette.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    // 01 - Accueil
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    // 02 - Ajouter un client
    // Déclaré avant '/clients/:id' pour que "new" ne soit pas pris pour un id.
    GoRoute(
      path: AppRoutes.newClient,
      builder: (context, state) => const AddClientScreen(),
    ),
    // 07 - Choisir un contact
    GoRoute(
      path: AppRoutes.pickContact,
      builder: (context, state) => const PickContactScreen(),
    ),
    // 03 - Fiche client
    GoRoute(
      path: '/clients/:id',
      builder: (context, state) =>
          ClientDetailScreen(clientId: state.pathParameters['id']!),
      routes: [
        // 04 - Nouvel achat à crédit
        GoRoute(
          path: 'purchase',
          builder: (context, state) =>
              PurchaseScreen(clientId: state.pathParameters['id']!),
        ),
        // 05 - Remboursement
        GoRoute(
          path: 'repayment',
          builder: (context, state) =>
              RepaymentScreen(clientId: state.pathParameters['id']!),
        ),
        // 06 - Nouveau dépôt
        GoRoute(
          path: 'deposit',
          builder: (context, state) =>
              DepositScreen(clientId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);