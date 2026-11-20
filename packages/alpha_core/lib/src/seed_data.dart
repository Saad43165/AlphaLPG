import 'models/app_settings.dart';
import 'models/product.dart';

/// Catalogue as published on alphalpg.pk (November 2026). Used to seed
/// Firestore and as the offline/demo catalogue. Live prices come from
/// Firestore `products/*` and are edited in the admin app.
abstract final class SeedData {
  static const products = [
    Product(
      id: 'cyl-6kg',
      name: '6kg Gas Cylinder',
      sizeKg: 6,
      refillPrice: 1676,
      description:
          'Compact cylinder for small kitchens, hostels and camping stoves.',
      imageAsset: 'assets/products/6kg.png',
      segment: CustomerSegment.home,
      sortOrder: 1,
    ),
    Product(
      id: 'cyl-10kg-composite',
      name: '10kg Composite Cylinder',
      sizeKg: 10,
      refillPrice: 2793,
      description: 'Lightweight, rust-free composite cylinder with a see-through gas level strip.',
      badge: 'Lightweight',
      imageAsset: 'assets/products/10kg.png',
      segment: CustomerSegment.home,
      sortOrder: 2,
    ),
    Product(
      id: 'cyl-11-8kg',
      name: '11.8kg Gas Cylinder',
      sizeKg: 11.8,
      refillPrice: 3296,
      description: 'The standard domestic cylinder for everyday home cooking.',
      badge: 'Most popular',
      imageAsset: 'assets/products/11_8kg.png',
      segment: CustomerSegment.home,
      sortOrder: 3,
    ),
    Product(
      id: 'cyl-45-4kg',
      name: '45.4kg Gas Cylinder',
      sizeKg: 45.4,
      refillPrice: 12682,
      description:
          'Commercial cylinder for restaurants, hotels, bakeries and industry.',
      badge: 'Commercial',
      imageAsset: 'assets/products/45_4kg.png',
      segment: CustomerSegment.business,
      sortOrder: 4,
    ),
  ];

  static const settings = AppSettings(
    deliveryFee: 150,
    freeDeliveryFrom: 6000,
    serviceAreas: [
      'Cantt',
      'Clifton Colony',
      'DHA',
      'Garden Town',
      'Gulberg',
      'Johar Town',
      'Model Town',
      'Cavalry Ground',
      'Askari',
      'Faisal Town',
      'Bahria Town',
      'Wapda Town',
    ],
  );
}
