import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'floor_plan_screen.dart';  // Import Booth from floor_plan_screen

// AddonItem class
class AddonItem {
  final String name;
  final double price;
  final IconData icon;

  AddonItem({required this.name, required this.price, required this.icon});
}

class ApplicationFormScreen extends StatefulWidget {
  final String exhibitionId;
  final String exhibitionName;
  final List<Booth> selectedBooths;  // Now uses Booth from floor_plan_screen

  const ApplicationFormScreen({
    super.key,
    required this.exhibitionId,
    required this.exhibitionName,
    required this.selectedBooths,
  });

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyDescriptionController = TextEditingController();
  final TextEditingController _exhibitProfileController = TextEditingController();

  List<String> _selectedAddons = [];
  bool _isSubmitting = false;

  final List<AddonItem> _availableAddons = [
    AddonItem(name: 'Extra Furniture', price: 200, icon: Icons.chair),
    AddonItem(name: 'Promotional Spot', price: 500, icon: Icons.campaign),
    AddonItem(name: 'Extended WiFi', price: 150, icon: Icons.wifi),
    AddonItem(name: 'Electricity Supply', price: 300, icon: Icons.electrical_services),
    AddonItem(name: 'Banner Display', price: 250, icon: Icons.flag),
  ];

  double _getAddonsTotal() {
    return _availableAddons
        .where((addon) => _selectedAddons.contains(addon.name))
        .fold(0, (sum, addon) => sum + addon.price);
  }

  double _getBoothsTotal() {
    return widget.selectedBooths.fold(0, (sum, booth) => sum + booth.price);
  }

  double _getGrandTotal() {
    return _getBoothsTotal() + _getAddonsTotal();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final applicationData = {
        'exhibitorId': user.uid,
        'exhibitionId': widget.exhibitionId,
        'exhibitionName': widget.exhibitionName,
        'booths': widget.selectedBooths.map((b) => {
          'boothNumber': b.boothNumber,
          'type': b.type,
          'price': b.price,
        }).toList(),
        'companyName': _companyNameController.text.trim(),
        'companyDescription': _companyDescriptionController.text.trim(),
        'exhibitProfile': _exhibitProfileController.text.trim(),
        'addons': _selectedAddons,
        'addonsTotal': _getAddonsTotal(),
        'boothsTotal': _getBoothsTotal(),
        'totalPrice': _getGrandTotal(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('applications').add(applicationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Go back to exhibitor dashboard — clears the floor plan + form from stack
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(AppRoutes.exhibitor);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booth Application Form'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selected Booths Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Booths',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: widget.selectedBooths.map((booth) {
                          return Chip(
                            label: Text('${booth.boothNumber} - RM${booth.price.toInt()}'),
                            backgroundColor: Colors.green.shade50,
                          );
                        }).toList(),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Booths Total:'),
                          Text(
                            'RM${_getBoothsTotal().toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Company Information
              const Text(
                'Company Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyNameController,
                decoration: InputDecoration(
                  labelText: 'Company Name',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Company Description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _exhibitProfileController,
                decoration: InputDecoration(
                  labelText: 'Exhibit Profile (What you will showcase)',
                  prefixIcon: const Icon(Icons.storefront),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              const SizedBox(height: 24),

              // Add-ons
              const Text(
                'Additional Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._availableAddons.map((addon) => CheckboxListTile(
                title: Text(addon.name),
                subtitle: Text('RM${addon.price.toInt()}'),
                secondary: Icon(addon.icon, color: Colors.blue.shade700),
                value: _selectedAddons.contains(addon.name),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedAddons.add(addon.name);
                    } else {
                      _selectedAddons.remove(addon.name);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              )),

              const SizedBox(height: 24),

              // Total Price
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Booths Total:'),
                          Text('RM${_getBoothsTotal().toInt()}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add-ons Total:'),
                          Text('RM${_getAddonsTotal().toInt()}'),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            'RM${_getGrandTotal().toInt()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Submit Application',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}