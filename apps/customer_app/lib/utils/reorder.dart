import 'package:alpha_core/alpha_core.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/cart.dart';

/// "Order the same again": fills the cart and goes straight to checkout when
/// everything needed is already known (signed in, a delivery address). The
/// customer then only slides to place the order: two taps from the home screen.
void reorderNow(BuildContext context, LpgOrder o) {
  final state = context.read<AppState>();
  context.read<Cart>().reorder(o);
  context.push(
    state.signedIn && state.selectedAddress != null ? '/checkout' : '/cart',
  );
}
