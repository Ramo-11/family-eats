import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  bool _isLoading = false;
  bool _isYearlySelected = true; // Default to yearly (better value)

  // TODO: Replace these with your actual links (Google Doc / Notion page works)
  final String _privacyUrl = "https://www.google.com";
  final String _termsUrl = "https://www.google.com";

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    try {
      Offerings offerings = await Purchases.getOfferings();
      debugPrint(
        "Offerings: ${offerings.current?.availablePackages.map((p) => p.identifier).toList()}",
      );

      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          _monthlyPackage = offerings.current!.monthly;
          _yearlyPackage = offerings.current!.annual;
        });
        debugPrint("Monthly: ${_monthlyPackage?.identifier}");
        debugPrint("Yearly: ${_yearlyPackage?.identifier}");
      } else {
        debugPrint("No offerings available!");
      }
    } catch (e) {
      debugPrint("Error fetching offers: $e");
    }
  }

  Package? get _selectedPackage =>
      _isYearlySelected ? _yearlyPackage : _monthlyPackage;

  String _calculateSavings() {
    if (_monthlyPackage == null || _yearlyPackage == null) return "";

    final monthlyPrice = _monthlyPackage!.storeProduct.price;
    final yearlyPrice = _yearlyPackage!.storeProduct.price;
    final yearlyMonthlyEquivalent = yearlyPrice / 12;
    final savings =
        ((monthlyPrice - yearlyMonthlyEquivalent) / monthlyPrice * 100).round();

    return savings > 0 ? "Save $savings%" : "";
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) {
      _showError("No package selected");
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("Starting purchase for: ${_selectedPackage!.identifier}");

      final result = await Purchases.purchase(
        PurchaseParams.package(_selectedPackage!),
      );

      final customerInfo = result.customerInfo;
      debugPrint("Purchase result: ${customerInfo.entitlements.all}");

      final isPro =
          customerInfo.entitlements.all["pro_access"]?.isActive ?? false;

      if (isPro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Welcome to Pro!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        debugPrint("Purchase completed but pro_access not active");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✓ Purchase completed! Activating Pro..."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      debugPrint("Purchase error code: $errorCode");
      debugPrint("Purchase error message: ${e.message}");

      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("User cancelled purchase");
      } else if (errorCode ==
          PurchasesErrorCode.productNotAvailableForPurchaseError) {
        _showError(
          "Product not available. Make sure you're signed into a Sandbox account.",
        );
      } else if (errorCode == PurchasesErrorCode.purchaseNotAllowedError) {
        _showError("Purchases not allowed on this device.");
      } else if (errorCode == PurchasesErrorCode.paymentPendingError) {
        _showError("Payment is pending. Please wait.");
      } else if (errorCode == PurchasesErrorCode.storeProblemError) {
        _showError(
          "App Store error. Try signing into Sandbox account in Settings.",
        );
      } else {
        _showError(e.message ?? "Purchase failed: $errorCode");
      }
    } catch (e) {
      debugPrint("Unexpected purchase error: $e");
      _showError("Unexpected error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all["pro_access"]?.isActive == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Purchases restored successfully!")),
          );
        }
      } else {
        _showError("No active subscription found.");
      }
    } catch (e) {
      _showError("Restore failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      _showError("Could not launch $urlString");
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF4A6C47);
    final scaffoldBg = const Color(0xFFF5F7F5);
    final savings = _calculateSavings();

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // --- 1. HEADER ---
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey.shade600),
              ),
            ),

            // --- 2. CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        size: 64,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      "Unlock FamilyEats Pro",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        color: Color(0xFF2D3A2D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Remove limits and bring the whole family together.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    _buildFeatureItem(
                      Icons.menu_book,
                      "Unlimited Recipes",
                      "Save your entire cookbook.",
                    ),
                    _buildFeatureItem(
                      Icons.groups,
                      "Unlimited Members",
                      "Invite partners, kids, and roommates.",
                    ),
                    _buildFeatureItem(
                      Icons.calendar_month,
                      "Unlimited Meal Plans",
                      "Plan as many meals as you need.",
                    ),
                    _buildFeatureItem(
                      Icons.favorite,
                      "Support Development",
                      "Help us build more features.",
                    ),
                  ],
                ),
              ),
            ),

            // --- 3. PURCHASE AREA ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Plan Selection Cards
                  if (_monthlyPackage != null || _yearlyPackage != null) ...[
                    Row(
                      children: [
                        // Yearly Option
                        if (_yearlyPackage != null)
                          Expanded(
                            child: _PlanCard(
                              title: "Yearly",
                              price: _yearlyPackage!.storeProduct.priceString,
                              period: "/year",
                              subtext: _getYearlyMonthlyPrice(),
                              badge: savings.isNotEmpty ? savings : null,
                              isSelected: _isYearlySelected,
                              onTap: () =>
                                  setState(() => _isYearlySelected = true),
                              primaryColor: primaryColor,
                            ),
                          ),
                        if (_yearlyPackage != null && _monthlyPackage != null)
                          const SizedBox(width: 12),
                        // Monthly Option
                        if (_monthlyPackage != null)
                          Expanded(
                            child: _PlanCard(
                              title: "Monthly",
                              price: _monthlyPackage!.storeProduct.priceString,
                              period: "/month",
                              subtext: "Flexible billing",
                              isSelected: !_isYearlySelected,
                              onTap: () =>
                                  setState(() => _isYearlySelected = false),
                              primaryColor: primaryColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),

                  // Subscribe Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || _selectedPackage == null
                          ? null
                          : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isYearlySelected
                                  ? "Subscribe Yearly"
                                  : "Subscribe Monthly",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Restore
                  TextButton(
                    onPressed: _isLoading ? null : _restore,
                    child: Text(
                      "Restore Purchases",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // Legal Footer
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegalLink(
                        text: "Terms of Service",
                        onTap: () => _launchUrl(_termsUrl),
                      ),
                      Text(
                        " • ",
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      _LegalLink(
                        text: "Privacy Policy",
                        onTap: () => _launchUrl(_privacyUrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getYearlyMonthlyPrice() {
    if (_yearlyPackage == null) return "";
    final yearlyPrice = _yearlyPackage!.storeProduct.price;
    final monthlyEquivalent = yearlyPrice / 12;
    // Format based on currency
    final currencySymbol = _yearlyPackage!.storeProduct.priceString.replaceAll(
      RegExp(r'[0-9.,]'),
      '',
    );
    return "${currencySymbol}${monthlyEquivalent.toStringAsFixed(2)}/month";
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, size: 24, color: const Color(0xFF4A6C47)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2D3A2D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String period;
  final String subtext;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;

  const _PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.period,
    required this.subtext,
    this.badge,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. MAIN CARD CONTENT
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row (Radio + Title ONLY)
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                        color: isSelected ? primaryColor : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: isSelected
                              ? primaryColor
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 20, // Slightly reduced for better fit
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? const Color(0xFF2D3A2D)
                            : Colors.grey.shade800,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Subtext
                Text(
                  subtext,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // 2. THE BADGE (Floating Top-Right)
          if (badge != null)
            Positioned(
              top: -8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFA726), Color(0xFFFF9800)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _LegalLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
