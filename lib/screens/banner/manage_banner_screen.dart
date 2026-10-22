import 'package:flutter/material.dart';
import 'package:mprs_android/core/constants/app_colors.dart';
import 'package:mprs_android/screens/user/add_user_screen.dart';
import 'package:mprs_android/widget/common_appbar.dart';
import 'package:mprs_android/widget/custom_buttons.dart';

class ManageBannerScreen extends StatefulWidget {
  const ManageBannerScreen({super.key});

  @override
  State<ManageBannerScreen> createState() => _ManageBannerScreenState();
}

class _ManageBannerScreenState extends State<ManageBannerScreen> {

  List<BannerItem> banners = [
    BannerItem(imageUrl: "https://fastly.picsum.photos/id/1/5000/3333.jpg?hmac=Asv2DU3rA_5D1xSe22xZK47WEAN0wjWeFOhzd13ujW4"),
    BannerItem(),
    BannerItem(),
  ];

  List<bool> expanded = [true, false, false];


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CommonAppBar(
        title: "Promotional banner manage",
        actionWidget: Text(
          "Save",
          style: TextStyle(
            color: AppColors.main,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onActionPressed: () async {
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: banners.length,
                itemBuilder: (context, index) {
                  return buildBannerCard(index);
                },
              ),
            ),




            MainButton(text: 'Add Banner', onPressed: () {

            }),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget buildBannerCard(int index) {
    final item = banners[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        children: [
          // HEADER
          InkWell(
            onTap: () {
              setState(() {
                expanded[index] = !expanded[index];
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "Banner ${index + 1}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    expanded[index]
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),

          // BODY (only visible when expanded)
          if (expanded[index])
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGE BOX
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: item.imageUrl == null
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.cloud_upload_outlined,
                              size: 40, color: Colors.grey),
                          SizedBox(height: 6),
                          Text("Upload image",
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(item.imageUrl!,
                          width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),

                  const SizedBox(height: 10),



                  const SizedBox(height: 14),

                  // ADD LINK
                  const Text(
                    "Add Link",
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.black,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),

                  TextField(
                    decoration: InputDecoration(
                      hintText: "Type link",
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Change Image (only visible if image exists)
                      if (item.imageUrl != null)
                        GestureDetector(
                          onTap: () {
                            // Pick new image
                          },
                          child: Text(
                            "Change image",
                            style: TextStyle(
                              color: AppColors.main,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(), // keeps alignment stable when no image

                      // Delete button (always visible)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            banners.removeAt(index);
                            expanded.removeAt(index);
                          });
                        },
                        icon: Icon(Icons.delete_outline, color: AppColors.main),
                      ),
                    ],
                  )


                ],
              ),
            ),
        ],
      ),
    );
  }

}

class BannerItem {
  String? imageUrl;
  String link;

  BannerItem({this.imageUrl, this.link = ""});
}

