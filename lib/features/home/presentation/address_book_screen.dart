import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../application/food_app_controller.dart';
import '../models/delivery_address.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({
    required this.controller,
    this.selectionMode = false,
    super.key,
  });

  final FoodAppController controller;
  final bool selectionMode;

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  bool _isSaving = false;
  String? _error;

  Future<void> _editAddress([DeliveryAddress? existing]) async {
    final result = await showDialog<({String label, String address, bool makeDefault})>(
      context: context,
      builder: (context) => _AddAddressDialog(address: existing),
    );
    if (result == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      if (existing == null) {
        await widget.controller.addAddress(
          label: result.label,
          address: result.address,
          makeDefault: result.makeDefault,
        );
      } else {
        await widget.controller.updateAddress(
          id: existing.id,
          label: result.label,
          address: result.address,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Delivery address saved to your account.'
                  : 'Delivery address updated.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectAddress(DeliveryAddress address) async {
    if (address.isDefault) {
      Navigator.of(context).pop(address);
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.controller.selectAddress(address.id);
      if (mounted) Navigator.of(context).pop(address);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.selectionMode ? 'Delivery address' : 'Your addresses'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF294D3A), Color(0xFF628768)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.white, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'The perfect meal\nstarts at your door.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Icon(Icons.delivery_dining_rounded, color: Colors.white70, size: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saved places',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _isSaving ? null : () => _editAddress(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add new'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 7),
                  Text(_error!, style: const TextStyle(color: AppTheme.primary)),
                ],
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                for (final address in controller.addresses)
                  _AddressCard(
                    address: address,
                    selected:
                        address.id == controller.selectedAddress?.id,
                    canSelect: widget.selectionMode,
                    onTap: _isSaving || !widget.selectionMode
                        ? null
                        : () => _selectAddress(address),
                    onEdit: _isSaving ? null : () => _editAddress(address),
                  ),
                if (!widget.selectionMode && controller.addresses.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  const Text(
                    'Your saved addresses are protected by your Savor account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: widget.selectionMode && controller.selectedAddress != null
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.of(context).pop(controller.selectedAddress),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Use this address'),
              )
            : null,
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selected,
    required this.canSelect,
    required this.onTap,
    required this.onEdit,
  });

  final DeliveryAddress address;
  final bool selected;
  final bool canSelect;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final icon = switch (address.label.toLowerCase()) {
      'work' => Icons.work_outline_rounded,
      'other' => Icons.place_outlined,
      _ => Icons.home_outlined,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(top: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: selected ? AppTheme.primary : Colors.transparent,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: selected ? const Color(0xFFE6F2E8) : AppTheme.canvas,
          child: Icon(icon, color: selected ? AppTheme.primary : AppTheme.ink),
        ),
        title: Row(
          children: [
            Text(address.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'DEFAULT',
                  style: TextStyle(
                    color: Color(0xFF3F7954),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(address.address, style: Theme.of(context).textTheme.bodySmall),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSelect)
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppTheme.primary : AppTheme.muted,
              ),
            IconButton(
              tooltip: 'Edit ${address.label} address',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAddressDialog extends StatefulWidget {
  const _AddAddressDialog({this.address});

  final DeliveryAddress? address;

  @override
  State<_AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<_AddAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(
    text: widget.address?.label ?? 'Home',
  );
  late final _address = TextEditingController(
    text: widget.address?.address ?? '',
  );
  bool _makeDefault = false;

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.address == null ? 'Add a delivery place' : 'Edit address'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _label,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'Home, Work, Other',
              ),
              validator: (value) =>
                  (value?.trim().length ?? 0) < 2 ? 'Add a short label' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Full address',
                hintText: 'House, street, city',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 5
                  ? 'Enter a complete address'
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _makeDefault,
              title: const Text('Make this my default', style: TextStyle(fontSize: 13)),
              onChanged: (value) => setState(() => _makeDefault = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((
              label: _label.text.trim(),
              address: _address.text.trim(),
              makeDefault: _makeDefault,
            ));
          },
          child: Text(widget.address == null ? 'Save address' : 'Save changes'),
        ),
      ],
    );
  }
}
