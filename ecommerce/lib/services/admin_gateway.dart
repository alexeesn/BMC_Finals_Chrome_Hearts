import '../models/admin.dart';
import '../models/order.dart';

abstract interface class AdminGateway {
  Future<AdminStats> loadStats();
  Future<AdminCatalog> loadCatalog();
  Future<void> saveCategory(AdminCategory category);
  Future<void> saveProduct(AdminProduct product);
  Future<void> saveVariant(AdminVariant variant);
  Future<void> uploadImage(
    String productId,
    UploadImage image,
    int sortOrder, {
    AdminImage? replacing,
  });
  Future<List<ShopOrder>> loadOrders({
    required int offset,
    String? paymentStatus,
  });
  Future<ShopOrder> loadOrder(String id);
  Future<void> updateFulfillment(String orderId, String status);
}
