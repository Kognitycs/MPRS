import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/offers/create_offer_screen.dart';
import 'package:mprs_android/screens/offers/offer_card.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/search_user_bar.dart';

class OfferManagementScreen extends StatefulWidget {
  const OfferManagementScreen({super.key});

  @override
  State<OfferManagementScreen> createState() => _OfferManagementScreenState();
}

class _OfferManagementScreenState extends State<OfferManagementScreen> {
  final searchController = TextEditingController();
  List<Offer> offerList = [];
  List<Offer> filteredOfferList = [];

  @override
  void initState() {
    super.initState();
    loadOfferList();
  }

  void loadOfferList() {
    offerList = OfferStorage.getOffers();
    filteredOfferList = List.from(offerList);
    setState(() {});
  }

  void applyFilters() {
    String query = searchController.text.toLowerCase();

    filteredOfferList =
        offerList.where((offer) {
          return offer.title.toLowerCase().contains(query);
        }).toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Offer Management",
        actionWidget: Text(
          "Add New",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () async {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateOfferScreen()),
          );
          loadOfferList();
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            SearchUserBar(
              hintText: "Search offer",
              controller: searchController,
              onChanged: (value) => applyFilters(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  filteredOfferList.isEmpty
                      ? Center(
                        child: Text(
                          "No offers available",
                          style: TextStyle(color: AppColors.lightGrey),
                        ),
                      )
                      : ListView.builder(
                        itemCount: filteredOfferList.length,
                        itemBuilder: (context, index) {
                          final offer = filteredOfferList[index];
                          return OfferCard(
                            imageUrl: offer.imagePath ?? "",
                            title: offer.title,
                            description: offer.description,
                            validUntil: "",
                            onEdit: () {},
                            onDelete: () {},
                            onApply: () {},
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class Offer {
  final String title;
  final String description;
  final String? imagePath;
  final double? price;
  final bool isActive;

  Offer({
    required this.title,
    required this.description,
    this.imagePath,
    this.price,
    this.isActive = true,
  });
}

class OfferStorage {
  static List<Offer> getOffers() {
    return [
      Offer(
        title: "Winter Sale",
        imagePath: "https://picsum.photos/200/300",
        description: "Up to 50% off on winter clothing",
        price: 99.99,
        isActive: true,
      ),
      Offer(
        title: "Summer Sale",
        imagePath: "https://picsum.photos/200/300",
        description: "Buy 1 Get 1 Free on summer collection",
        price: 49.99,
        isActive: false,
      ),
      Offer(
        title: "New Year Offer",
        imagePath: "https://picsum.photos/200/300",
        description: "Flat 30% discount on all products",
        price: 79.99,
        isActive: true,
      ),
    ];
  }
}
