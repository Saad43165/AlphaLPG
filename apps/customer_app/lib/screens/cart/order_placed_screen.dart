import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/brand.dart';
import '../../widgets/common.dart';

class OrderPlacedScreen extends StatelessWidget {
  const OrderPlacedScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Constrained(
        maxWidth: 460,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const CircleAvatar(
                radius: 48,
                backgroundColor: Brand.success,
                child: Icon(Icons.check_rounded, size: 56, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                'Order placed!',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Alpha LPG will confirm your order shortly. You can follow every step in the app.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/orders/$orderId'),
                child: const Text('Track my order'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
