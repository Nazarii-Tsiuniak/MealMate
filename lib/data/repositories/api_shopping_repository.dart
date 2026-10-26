import '../../models/shopping_item.dart';
import '../../repositories/shopping_list_repository.dart';
import '../api/api_client.dart';
import '../api/backend_json.dart';
import '../api/json_fields.dart';

class ApiShoppingRepository implements ShoppingListRepository {
  ApiShoppingRepository(this.api);
  final ApiClient api;
  final Map<DateTime, List<ShoppingItem>> _weeks = {};
  @override
  List<ShoppingItem> forWeek(DateTime week) => _weeks[week] ?? const [];
  @override
  void replaceWeek(DateTime week, List<ShoppingItem> items) =>
      _weeks[week] = List.unmodifiable(items);
  Future<List<ShoppingItem>> fetch(DateTime week) async {
    final raw = await api.request(
      'GET',
      'shopping-items',
      query: {'week_start': JsonFields.dateText(week)},
    );
    if (JsonFields.list(
      raw,
    ).any((v) => JsonFields.date(JsonFields.object(v)['week_start']) != week)) {
      throw const FormatException('Покупки іншого тижня');
    }
    return BackendJson.uniqueList(raw, BackendJson.shopping, (v) => v.id);
  }

  Future<ShoppingItem> addRemote(
    DateTime week,
    String name,
    double? quantity,
    String? unit,
    ShoppingCategory category,
  ) async => BackendJson.shopping(
    await api.request(
      'POST',
      'shopping-items',
      expected: {201},
      body: {
        'week_start': JsonFields.dateText(week),
        'ingredient_name': name.trim(),
        'quantity': quantity,
        'unit': unit,
        'category': category.name,
      },
    ),
  );
  Future<ShoppingItem> patch(String id, Map<String, Object?> body) async {
    final item = BackendJson.shopping(
      await api.request('PATCH', 'shopping-items/$id', body: body),
    );
    if (item.id != id) throw const FormatException('ID продукту не збігається');
    return item;
  }

  Future<void> deleteRemote(String id) async {
    await api.request('DELETE', 'shopping-items/$id', expected: {204});
  }
}
