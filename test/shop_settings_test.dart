import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fayma/services/shop_settings.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('enregistre, relit et retire le nom de la boutique', () async {
    final settings = ShopSettings();

    expect(await settings.readShopName(), isEmpty);

    await settings.saveShopName('  Boutique Awa  ');
    expect(await settings.readShopName(), 'Boutique Awa');

    await settings.saveShopName('   ');
    expect(await settings.readShopName(), isEmpty);
  });

  test('le nom est relu par une nouvelle instance', () async {
    final settings = ShopSettings();
    await settings.saveShopName('Boutique Awa');

    final other = ShopSettings();
    expect(await other.readShopName(), 'Boutique Awa');
  });

  test('enregistre, relit et retire le plafond de crédit', () async {
    final settings = ShopSettings();

    expect(await settings.readCreditLimit(), isNull);

    await settings.saveCreditLimit(15000);
    expect(await settings.readCreditLimit(), 15000);

    await settings.saveCreditLimit(null);
    expect(await settings.readCreditLimit(), isNull);
  });

  test('le plafond est relu par une nouvelle instance', () async {
    final settings = ShopSettings();
    await settings.saveCreditLimit(25000);

    final other = ShopSettings();
    expect(await other.readCreditLimit(), 25000);
  });
}
