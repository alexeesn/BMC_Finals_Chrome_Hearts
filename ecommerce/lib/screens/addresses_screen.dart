import 'package:flutter/material.dart';

import '../models/shopping.dart';
import '../services/shop_gateway.dart';
import '../widgets/sign_in_prompt.dart';
import '../widgets/shopping_feedback.dart';

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, required this.gateway});
  final ShopGateway gateway;
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late final _changes = widget.gateway.authChanges;
  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _changes,
    builder: (context, _) {
      final owner = widget.gateway.currentUser?.id;
      return owner == null
          ? Scaffold(
              appBar: AppBar(title: const Text('My addresses')),
              body: SignInPrompt(
                gateway: widget.gateway,
                message: 'Sign in to manage your delivery addresses.',
              ),
            )
          : _AddressList(
              key: ValueKey(owner),
              gateway: widget.gateway,
              owner: owner,
            );
    },
  );
}

class _AddressList extends StatefulWidget {
  const _AddressList({super.key, required this.gateway, required this.owner});
  final ShopGateway gateway;
  final String owner;
  @override
  State<_AddressList> createState() => _AddressListState();
}

class _AddressListState extends State<_AddressList> {
  late Future<List<DeliveryAddress>> _addresses = widget.gateway
      .loadAddresses();
  bool _busy = false;

  Future<void> _reload() async {
    final future = widget.gateway.loadAddresses();
    setState(() => _addresses = future);
    try {
      await future;
    } catch (_) {
      /* FutureBuilder shows retry. */
    }
  }

  Future<void> _edit([DeliveryAddress? address]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddressEditor(
          gateway: widget.gateway,
          owner: widget.owner,
          address: address,
        ),
      ),
    );
    if (mounted && saved == true) await _reload();
  }

  Future<void> _action(Future<void> Function() operation) async {
    if (_busy || widget.gateway.currentUser?.id != widget.owner) return;
    setState(() => _busy = true);
    try {
      await operation();
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(DeliveryAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this address?'),
        content: Text(address.fullAddress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep address'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) {
      await _action(() => widget.gateway.deleteAddress(address.id!));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My addresses')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: const Text('Add address'),
    ),
    body: FutureBuilder<List<DeliveryAddress>>(
      future: _addresses,
      builder: (context, snapshot) {
        if (widget.gateway.currentUser?.id != widget.owner) {
          return const Center(
            child: Text('Account changed. Return to My addresses.'),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load your addresses.'),
                TextButton(
                  onPressed: _reload,
                  child: const Text('Retry addresses'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text('Add your first delivery address.'));
        }
        return Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: snapshot.data!
                      .map(
                        (address) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address.recipient,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(address.phone),
                                const SizedBox(height: 8),
                                Text(address.fullAddress),
                                if (address.instructions.isNotEmpty)
                                  Text(address.instructions),
                                if (address.isDefault)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Chip(
                                      label: Text('Default address'),
                                      avatar: Icon(Icons.check, size: 18),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _edit(address),
                                      child: const Text('Edit'),
                                    ),
                                    if (!address.isDefault)
                                      TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _action(
                                                () => widget.gateway
                                                    .setDefaultAddress(
                                                      address.id!,
                                                    ),
                                              ),
                                        child: const Text('Set as default'),
                                      ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _delete(address),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class AddressEditor extends StatefulWidget {
  const AddressEditor({
    super.key,
    required this.gateway,
    required this.owner,
    this.address,
  });
  final ShopGateway gateway;
  final String owner;
  final DeliveryAddress? address;
  @override
  State<AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<AddressEditor> {
  final _form = GlobalKey<FormState>();
  late final _changes = widget.gateway.authChanges;
  late final Map<String, TextEditingController> _fields = {
    'recipient': TextEditingController(text: widget.address?.recipient),
    'phone': TextEditingController(text: widget.address?.phone),
    'province': TextEditingController(text: widget.address?.province),
    'city': TextEditingController(text: widget.address?.city),
    'barangay': TextEditingController(text: widget.address?.barangay),
    'street': TextEditingController(text: widget.address?.street),
    'postal_code': TextEditingController(text: widget.address?.postalCode),
    'instructions': TextEditingController(text: widget.address?.instructions),
  };
  bool _saving = false;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (widget.gateway.currentUser?.id != widget.owner) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    String value(String name) => _fields[name]!.text.trim();
    try {
      await widget.gateway.saveAddress(
        DeliveryAddress(
          id: widget.address?.id,
          recipient: value('recipient'),
          phone: value('phone'),
          province: value('province'),
          city: value('city'),
          barangay: value('barangay'),
          street: value('street'),
          postalCode: value('postal_code'),
          instructions: value('instructions'),
        ),
      );
      if (mounted && widget.gateway.currentUser?.id == widget.owner) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showShoppingError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: _changes,
    builder: (context, _) {
      if (widget.gateway.currentUser?.id != widget.owner) {
        return Scaffold(
          appBar: AppBar(title: const Text('Address')),
          body: const Center(
            child: Text('Account changed. Go back to your addresses.'),
          ),
        );
      }
      const labels = {
        'recipient': 'Recipient name',
        'phone': 'Phone number',
        'province': 'Province',
        'city': 'City / municipality',
        'barangay': 'Barangay',
        'street': 'Street / building / unit',
        'postal_code': 'Postal code',
        'instructions': 'Delivery instructions (optional)',
      };
      return PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.address == null ? 'Add address' : 'Edit address',
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text('Philippines', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    ...labels.entries.map((entry) {
                      final key = entry.key;
                      final maxLength = key == 'recipient'
                          ? 120
                          : key == 'street'
                          ? 250
                          : key == 'instructions'
                          ? 500
                          : key == 'phone'
                          ? 25
                          : key == 'postal_code'
                          ? 4
                          : 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _fields[key],
                          enabled: !_saving,
                          maxLength: maxLength,
                          maxLines: key == 'instructions' ? 3 : 1,
                          keyboardType: key == 'phone'
                              ? TextInputType.phone
                              : key == 'postal_code'
                              ? TextInputType.number
                              : TextInputType.streetAddress,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(labelText: entry.value),
                          validator: (input) {
                            final value = input?.trim() ?? '';
                            if (key == 'instructions') return null;
                            if (value.isEmpty) return 'This field is required.';
                            if (key == 'phone' &&
                                !RegExp(r'^\+?[0-9 ()-]{7,25}$')
                                    .hasMatch(value)) {
                              return 'Enter a valid phone number.';
                            }
                            if (key == 'postal_code' &&
                                !RegExp(r'^[0-9]{4}$').hasMatch(value)) {
                              return 'Enter a 4-digit postal code.';
                            }
                            return null;
                          },
                        ),
                      );
                    }),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save address'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
