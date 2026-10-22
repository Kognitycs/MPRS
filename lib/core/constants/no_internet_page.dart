import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'base_client.dart';

class NoInternetPage extends StatelessWidget {
  const NoInternetPage(
      {super.key, required this.callBack, required this.apiRequest});
  final ApiRequest apiRequest;
  final Function(ApiRequest apiRequest) callBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            //Image.asset(Assets.iconsThunderstorm),
            const SizedBox(
              height: 20,
            ),
             Text(
              "Oops",
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 10,
            ),
             Text(
              "Check Your Internet Connection",
              style: TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(
              height: 15,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: ElevatedButton(
                onPressed: () async {
                  Get.back();
                  await callBack(apiRequest);
                },
                child:  Text(
                  "Refresh",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
