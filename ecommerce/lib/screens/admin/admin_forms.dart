import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/admin.dart';
import '../../services/product_image_picker.dart';
import '../../services/shop_gateway.dart';
import '../../widgets/shopping_feedback.dart';

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
String? _slug(String? value) =>
    value == null ||
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value.trim())
    ? 'Use lowercase words separated by hyphens.'
    : null;

abstract class _FormState<T extends StatefulWidget> extends State<T> {
  final form = GlobalKey<FormState>();
  bool saving = false;
  bool get working => saving;
  Future<void> submit(Future<Object?> Function() operation) async {
    if (saving || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    try {
      final result = await operation();
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget page(String title, List<Widget> fields, VoidCallback save) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ...fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: field,
                  ),
                ),
                FilledButton(
                  onPressed: working ? null : save,
                  child: Text(
                    saving
                        ? 'Saving…'
                        : working
                        ? 'Selecting photo…'
                        : 'Save',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminCategoryForm extends StatefulWidget {
  const AdminCategoryForm({super.key, required this.shop, this.category});
  final ShopGateway shop;
  final AdminCategory? category;
  @override
  State<AdminCategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends _FormState<AdminCategoryForm> {
  late final _id = widget.category?.id ?? const Uuid().v4();
  late final _name = TextEditingController(text: widget.category?.name);
  late final _slugValue = TextEditingController(text: widget.category?.slug);
  late final _sort = TextEditingController(
    text: '${widget.category?.sortOrder ?? 0}',
  );
  late bool _active = widget.category?.active ?? true;
  @override
  void dispose() {
    _name.dispose();
    _slugValue.dispose();
    _sort.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => page(
    widget.category == null ? 'Add category' : 'Edit category',
    [
      TextFormField(
        controller: _name,
        enabled: !saving,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Category name'),
        validator: _required,
      ),
      TextFormField(
        controller: _slugValue,
        enabled: !saving,
        maxLength: 120,
        decoration: const InputDecoration(
          labelText: 'Slug',
          hintText: 'silver-jewelry',
        ),
        validator: _slug,
      ),
      TextFormField(
        controller: _sort,
        enabled: !saving,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Display order'),
        validator: (value) =>
            int.tryParse(value ?? '') == null ? 'Enter a whole number.' : null,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Active'),
        subtitle: const Text(
          'Archived categories and their products are hidden from shoppers.',
        ),
        value: _active,
        onChanged: saving ? null : (value) => setState(() => _active = value),
      ),
    ],
    () => submit(() async {
      await widget.shop.admin.saveCategory(
        AdminCategory(
          id: _id,
          name: _name.text.trim(),
          slug: _slugValue.text.trim(),
          active: _active,
          sortOrder: int.parse(_sort.text),
        ),
      );
      return null;
    }),
  );
}

class AdminProductForm extends StatefulWidget {
  const AdminProductForm({
    super.key,
    required this.shop,
    required this.catalog,
    this.product,
    this.pickImage,
  });
  final ShopGateway shop;
  final AdminCatalog catalog;
  final AdminProduct? product;
  final Future<UploadImage?> Function()? pickImage;
  @override
  State<AdminProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends _FormState<AdminProductForm> {
  late final _id = widget.product?.id ?? const Uuid().v4();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _slugValue = TextEditingController(text: widget.product?.slug);
  late final _description = TextEditingController(
    text: widget.product?.description,
  );
  late String? _category =
      widget.product?.categoryId ?? widget.catalog.categories.firstOrNull?.id;
  late bool _active = widget.product?.active ?? false;
  UploadImage? _photo;
  bool _picking = false;
  @override
  bool get working => saving || _picking;

  Future<void> _choosePhoto() async {
    if (working) return;
    setState(() => _picking = true);
    try {
      final picker = widget.pickImage ?? pickProductImage;
      final photo = await picker();
      if (mounted && photo != null) setState(() => _photo = photo);
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _slugValue.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => page(
    widget.product == null ? 'Add product' : 'Edit product',
    [
      Text('Cover photo', style: Theme.of(context).textTheme.titleLarge),
      const Text(
        'JPEG, PNG, or WebP · up to 5 MB. The photo uploads when you save.',
      ),
      if (_photo != null)
        SizedBox(
          height: 180,
          child: Image.memory(
            _photo!.bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Center(child: Icon(Icons.image_outlined, size: 48)),
          ),
        )
      else if (widget.product?.images.isNotEmpty == true)
        SizedBox(
          height: 180,
          child: Image.network(
            widget.product!.images.first.url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.image_outlined, size: 48),
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: working ? null : _choosePhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _picking
                  ? 'Selecting…'
                  : _photo == null
                  ? 'Choose photo'
                  : 'Choose another photo',
            ),
          ),
          if (_photo != null)
            TextButton(
              onPressed: working ? null : () => setState(() => _photo = null),
              child: const Text('Undo photo selection'),
            ),
        ],
      ),
      TextFormField(
        controller: _name,
        enabled: !saving,
        maxLength: 160,
        decoration: const InputDecoration(labelText: 'Product name'),
        validator: _required,
      ),
      TextFormField(
        controller: _slugValue,
        enabled: !saving,
        maxLength: 160,
        decoration: const InputDecoration(
          labelText: 'Slug',
          hintText: 'archive-tee',
        ),
        validator: _slug,
      ),
      DropdownButtonFormField<String>(
        initialValue: _category,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Category'),
        items: widget.catalog.categories
            .map(
              (category) => DropdownMenuItem(
                value: category.id,
                child: Text(
                  '${category.name}${category.active ? '' : ' (archived)'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: saving ? null : (value) => setState(() => _category = value),
        validator: (value) => value == null ? 'Choose a category.' : null,
      ),
      TextFormField(
        controller: _description,
        enabled: !saving,
        maxLines: 5,
        maxLength: 4000,
        decoration: const InputDecoration(labelText: 'Description'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Published'),
        subtitle: const Text(
          'Keep new products as drafts until images and variants are ready.',
        ),
        value: _active,
        onChanged: saving ? null : (value) => setState(() => _active = value),
      ),
    ],
    () => submit(() async {
      final owner = widget.shop.currentUser?.id;
      await widget.shop.admin.saveProduct(
        AdminProduct(
          id: _id,
          categoryId: _category!,
          name: _name.text.trim(),
          slug: _slugValue.text.trim(),
          description: _description.text.trim(),
          active: _active,
        ),
      );
      if (_photo != null && mounted && widget.shop.currentUser?.id == owner) {
        try {
          await widget.shop.admin.uploadImage(
            _id,
            _photo!,
            0,
            replacing: widget.product?.images.firstOrNull,
          );
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Product saved, but photo upload was not confirmed. Check Photos & stock before retrying.',
                ),
              ),
            );
          }
        }
      }
      return _id;
    }),
  );
}

class AdminVariantForm extends StatefulWidget {
  const AdminVariantForm({
    super.key,
    required this.shop,
    required this.productId,
    this.variant,
  });
  final ShopGateway shop;
  final String productId;
  final AdminVariant? variant;
  @override
  State<AdminVariantForm> createState() => _VariantFormState();
}

class _VariantFormState extends _FormState<AdminVariantForm> {
  late final _sku = TextEditingController(text: widget.variant?.sku);
  late final _option = TextEditingController(text: widget.variant?.option);
  late final _price = TextEditingController(
    text: widget.variant == null
        ? ''
        : '${widget.variant!.priceMinor ~/ 100}.${(widget.variant!.priceMinor % 100).toString().padLeft(2, '0')}',
  );
  late final _stock = TextEditingController(
    text: '${widget.variant?.stock ?? 0}',
  );
  late bool _active = widget.variant?.active ?? true;
  @override
  void dispose() {
    _sku.dispose();
    _option.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => page(
    widget.variant == null ? 'Add variant' : 'Edit variant',
    [
      TextFormField(
        controller: _sku,
        enabled: !saving,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Unique SKU',
          hintText: 'CH-TEE-M',
        ),
        validator: _required,
      ),
      TextFormField(
        controller: _option,
        enabled: !saving,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Option / size',
          hintText: 'M or US 8',
        ),
        validator: _required,
      ),
      TextFormField(
        controller: _price,
        enabled: !saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Price in PHP',
          hintText: '12000.00',
        ),
        validator: (value) => parsePesoInput(value ?? '') == null
            ? 'Enter a positive price with up to 2 decimal places.'
            : null,
      ),
      TextFormField(
        controller: _stock,
        enabled: !saving,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Stock on hand'),
        validator: (value) {
          final stock = int.tryParse(value ?? '');
          if (stock == null || stock < 0 || stock > 2147483647) {
            return 'Enter a valid whole stock quantity.';
          }
          return stock < (widget.variant?.reserved ?? 0)
              ? 'Stock cannot be lower than reserved items.'
              : null;
        },
      ),
      Text(
        'Currently reserved: ${widget.variant?.reserved ?? 0}. Available stock is stock on hand minus reservations.',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Active variant'),
        value: _active,
        onChanged: saving ? null : (value) => setState(() => _active = value),
      ),
    ],
    () => submit(() async {
      await widget.shop.admin.saveVariant(
        AdminVariant(
          id: widget.variant?.id,
          productId: widget.productId,
          sku: _sku.text.trim(),
          option: _option.text.trim(),
          priceMinor: parsePesoInput(_price.text)!,
          stock: int.parse(_stock.text),
          reserved: widget.variant?.reserved ?? 0,
          active: _active,
          updatedAt: widget.variant?.updatedAt,
        ),
      );
      return null;
    }),
  );
}
