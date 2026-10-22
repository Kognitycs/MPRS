import 'package:mprs_android/core/app_config.dart';

class ApiConstants {
  static String get domain => AppConfig.domain;
  static String get baseUrl => AppConfig.baseUrl;
  static String get totalBookingsPath => '$baseUrl/admin/total-bookings';

  static String totalBookingsForStatus(String status) =>
      '$totalBookingsPath?status=${Uri.encodeQueryComponent(status.trim())}';

  static String get searchReports => '$baseUrl/admin/search/reports';

  /// Reports & analytics — all-time user count (`userType` optional).
  /// Omit [userType] for total all users; use `VIP` for VIP users.
  static String get adminUserCountPath => '$baseUrl/admin/user/count';

  static String adminUserCount({
    String? userType,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final params = <String>[];
    final type = userType?.trim() ?? '';
    if (type.isNotEmpty) {
      params.add('userType=${Uri.encodeQueryComponent(type)}');
    }
    if (fromDate != null) {
      params.add(
        'fromDate=${fromDate.year}-'
        '${fromDate.month.toString().padLeft(2, '0')}-'
        '${fromDate.day.toString().padLeft(2, '0')}',
      );
    }
    if (toDate != null) {
      params.add(
        'toDate=${toDate.year}-'
        '${toDate.month.toString().padLeft(2, '0')}-'
        '${toDate.day.toString().padLeft(2, '0')}',
      );
    }
    if (params.isEmpty) return adminUserCountPath;
    return '$adminUserCountPath?${params.join('&')}';
  }

  static String get supportDetails => '$baseUrl/user/support/details';

  static String supportDetailsForAccount(String accountId) {
    return '$supportDetails?account_id=${Uri.encodeQueryComponent(accountId.trim())}';
  }

  // Auth Endpoints
  static String get refreshToken => '$baseUrl/user/token';
  static String get login => '$baseUrl/auth/login';
  static String get signup => '$baseUrl/auth/signup';
  static String get sendOtp => '$baseUrl/auth/send-otp';
  static String get verifyPhone => '$baseUrl/auth/verify-phone';
  static String get forgotPassword => '$baseUrl/auth/forgot-password';
  static String get profile => '$baseUrl/auth/profile';
  static String get logOut => '$baseUrl/auth/logout';

  // User
  static String get allUsers => '$baseUrl/admin/all-users';
  static String get addUser => '$baseUrl/admin/add-user';
  static String get updateUser => '$baseUrl/admin/update-user';
  static String get changeUserType => '$baseUrl/admin/change-user-type';
  static String get changePassword => '$baseUrl/auth/change-password';

  // Template
  static String get createNotificationTemplate =>
      '$baseUrl/admin/create/notification-template';
  static String get getAllNotificationTemplates =>
      '$baseUrl/admin/get/all-notification-templates';
  static String get updateNotificationTemplate =>
      '$baseUrl/admin/update/notification-template';

  static String updateNotificationTemplateById(String templateId) =>
      '$updateNotificationTemplate/${Uri.encodeComponent(templateId.trim())}';

  // Notification
  static String get createNotification => '$baseUrl/admin/createNotification';

  /// Approve/reject after create — triggers server-side send when approved.
  static String notificationApproval(String notificationId) =>
      '$baseUrl/admin/notificationApproval/${Uri.encodeComponent(notificationId.trim())}';

  /// Admin endpoint — confirmed 200 for Admin/Internal users, 403 for External.
  static String get getAllNotifications =>
      '$baseUrl/admin/get/allNotifications';

  /// User endpoint — tried first for External/VIP/VVIP users.
  static String get userGetAllNotifications =>
      '$baseUrl/user/get/allNotifications';

  /// User endpoint with FCM token — allows server to return notifications
  /// targeted at the calling device's specific FCM token.
  static String userNotificationsByFcmToken(String fcmToken) =>
      '$userGetAllNotifications?fcmToken=${Uri.encodeQueryComponent(fcmToken.trim())}';

  /// Deployed Firebase Cloud Function (Firebase Admin SDK) for push dispatch.
  /// Backend should call this after notificationApproval, or replicate the logic
  /// with firebase-admin in the main API server.
  static const String firebaseSendAdminPush =
      'https://us-central1-mprs-rms.cloudfunctions.net/sendAdminPush';

  static String get updateNotification => '$baseUrl/admin/updateNotification';

  //Banners
  static String get allBanners => '$baseUrl/admin/allBanners';
  static String get createBanner => '$baseUrl/admin/createBanner';
  static String get updateBannerById => '$baseUrl/admin/updateBannerById';

  //Profile Edit Requests
  static String get allEditProfilesRequest =>
      '$baseUrl/admin/all/edit/profiles/request';

  //Pending Stats
  static String get pendingStats => '$baseUrl/admin/all/pending/request/count';

  //FCM Token
  static String get updateFcmToken => '$baseUrl/admin/update-fcm-token';
  static String get userUpdateFcmToken => '$baseUrl/user/update-fcm-token';

  //Booking
  static String get userBookings => '$baseUrl/user/booking';

  static String userBookingsList(String accountId) =>
      '$baseUrl/user/bookings?account_id=${Uri.encodeQueryComponent(accountId.trim())}';

  static String userInProgressBookings(String accountId) =>
      '$baseUrl/user/inprogress/bookings?account_id=${Uri.encodeQueryComponent(accountId.trim())}';

  static String getOpenBookings(String accountId) {
    return "$baseUrl/user/getData?sfQuery=SELECT+Id,OrderNumber,Port_of_Loading__c,Port_of_Destination__c,Vessel_Name__c,Voyage_Number__c,Tracking_Status__c,OrderReferenceNumber,Container_Number__c,Booked_Date__c,Picked_Up_Date__c,Gated_In_Date__c,On_Board_Date__c,Vessel_Sailed_Date__c,Discharged_Date__c,Transshipment_Loaded_Date__c,Transshipment_Discharge_Date__c,Cleared_Date__c,Returned_Date__c,Custom_Status__c,Arrival_Date__c,Departure_Date__c+FROM+Order+WHERE+Opportunity.AccountId='$accountId'+AND+Opportunity.StageName!='Closed+Lost'+AND+Custom_Status__c='Booking+Request+Received'";
  }

  /// Orders created today. Admin omits [accountId] and sees every account.
  static String ordersCreatedToday({String? accountId}) {
    final account = accountId?.trim() ?? '';
    final accountClause =
        account.isEmpty
            ? ''
            : "+AND+(AccountId='$account'+OR+Opportunity.AccountId='$account')";
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,OrderNumber,QuoteId,CreatedDate,AccountId,Account.Name,'
        'Opportunity.Name,Port_of_Loading__c,Port_of_Destination__c,'
        'Vessel_Name__c,Voyage_Number__c,Tracking_Status__c,OrderReferenceNumber,'
        'Container_Number__c,Booked_Date__c,Custom_Status__c,Arrival_Date__c,'
        'Departure_Date__c'
        '+FROM+Order+WHERE+CreatedDate=TODAY'
        '$accountClause'
        '+ORDER+BY+CreatedDate+DESC';
  }

  static String getDataBookings(String accountId) {
    return "$baseUrl/user/getData?sfQuery=SELECT+Id,OrderNumber,QuoteId,Opportunity.Name,Port_of_Loading__c,Port_of_Destination__c,Vessel_Name__c,Voyage_Number__c,Tracking_Status__c,OrderReferenceNumber,Container_Number__c,Booked_Date__c,Picked_Up_Date__c,Gated_In_Date__c,On_Board_Date__c,Vessel_Sailed_Date__c,Discharged_Date__c,Transshipment_Loaded_Date__c,Transshipment_Discharge_Date__c,Cleared_Date__c,Returned_Date__c,Custom_Status__c,Arrival_Date__c,Departure_Date__c+FROM+Order+WHERE+Opportunity.AccountId='$accountId'+AND+Opportunity.StageName!='Closed+Lost'";
  }

  /// Quote container fields only (safe on Quote object — no Opportunity join).
  static const String quoteContainerSelectFields =
      'Container_Type__c,Container_Size__c';

  static String getBookingRequestReceived(String accountId) {
    return "$baseUrl/user/getData?sfQuery="
        "SELECT+Id,Name,Status,ExpirationDate,CreatedDate,"
        "GrandTotal,PDF_Saved__c,Lead_Type__c,"
        "Net_Weight_KGS__c,Gross_Weight_KGS__c,Goods_Value__c,"
        "Origin_Port__r.Name,Destination_Port__r.Name,"
        "$quoteContainerSelectFields,"
        "Opportunity.Name,Account.Name,AccountId "
        "FROM+Quote "
        "WHERE+AccountId='$accountId' "
        "AND+Status+NOT+IN+('Accepted','Denied')";
  }

  static String getBookingSentToCustomer(String accountId) {
    return "$baseUrl/user/getData?sfQuery=SELECT+Id,OrderNumber,Opportunity.Name,Port_of_Loading__c,Port_of_Destination__c,Vessel_Name__c,Voyage_Number__c,Tracking_Status__c,OrderReferenceNumber,Container_Number__c,Booked_Date__c,Picked_Up_Date__c,Gated_In_Date__c,On_Board_Date__c,Vessel_Sailed_Date__c,Discharged_Date__c,Transshipment_Loaded_Date__c,Transshipment_Discharge_Date__c,Cleared_Date__c,Returned_Date__c,Custom_Status__c,Arrival_Date__c,Departure_Date__c+FROM+Order+WHERE+Opportunity.AccountId='$accountId'+AND+Opportunity.StageName!='Closed+Lost'+AND+Custom_Status__c='Booking+Sent+to+Customer'+AND+Departure_Date__c!=NULL";
  }

  static String get userBookingDetail => '$baseUrl/user/bookingItem?order_id=';

  /// Order booking documents / invoices (POST, `order_id` query param).
  static String get orderDocumentsForOrderPath =>
      '$baseUrl/user/invoices/for/order';

  static String orderDocumentsForOrder(String orderId) =>
      '$orderDocumentsForOrderPath?order_id=${Uri.encodeQueryComponent(orderId.trim())}';

  /// Upload BL / booking document (POST multipart).
  /// Query: `order_id`, `file_type` (e.g. `BL Draft (sent by Customer)`).
  static String get uploadBlDocumentPath => '$baseUrl/user/uploadBL/documents';

  static String uploadBlDocument({
    required String orderId,
    required String fileType,
  }) {
    final id = orderId.trim();
    final type = fileType.trim();
    return '$uploadBlDocumentPath?'
        'order_id=${Uri.encodeQueryComponent(id)}&'
        'file_type=${Uri.encodeQueryComponent(type)}';
  }

  static String get savedQuotations => '$baseUrl/user/quote';

  /// User quotes — omit [accountId] for admin (all users).
  static String userQuotes({String? accountId}) {
    final id = accountId?.trim() ?? '';
    if (id.isEmpty) return savedQuotations;
    return '$savedQuotations?account_id=${Uri.encodeQueryComponent(id)}';
  }

  /// Admin: all users — quotes linked to app-created opportunities (RMS flag).
  static String get adminRmsOpportunityQuotesSf =>
      '$baseUrl/user/getData?sfQuery='
      'SELECT+Id,Name,Status,ExpirationDate,GrandTotal,CurrencyIsoCode,'
      'CreatedDate,Origin_Port__r.Name,Destination_Port__r.Name,'
      'Lead_Type__c,Goods_Value__c,Net_Weight_KGS__c,Gross_Weight_KGS__c,'
      '$quoteContainerSelectFields,'
      'Opportunity.Name,Opportunity.Opp_From_RMS_App__c,Account.Name '
      'FROM+Quote+WHERE+Opportunity.Opp_From_RMS_App__c=true '
      'ORDER+BY+CreatedDate+DESC';

  /// Admin bookings (Booked tab): orders on RMS app opportunities.
  static String get adminRmsOpportunityOrdersSf =>
      '$baseUrl/user/getData?sfQuery='
      'SELECT+Id,OrderNumber,QuoteId,Opportunity.Name,'
      'Origin_Port__r.Name,Destination_Port__r.Name,'
      'Vessel_Name__c,Voyage_Number__c,Tracking_Status__c,'
      'OrderReferenceNumber,Container_Number__c,Booked_Date__c,'
      'Picked_Up_Date__c,Gated_In_Date__c,On_Board_Date__c,'
      'Vessel_Sailed_Date__c,Discharged_Date__c,'
      'Transshipment_Loaded_Date__c,Transshipment_Discharge_Date__c,'
      'Cleared_Date__c,Returned_Date__c,Custom_Status__c,'
      'Arrival_Date__c,Departure_Date__c,TotalAmount,CurrencyIsoCode '
      'FROM+Order+WHERE+Opportunity.Opp_From_RMS_App__c=true '
      "AND+Opportunity.StageName!='Closed+Lost' "
      'ORDER+BY+Booked_Date__c+DESC+NULLS+LAST';

  /// Fallback: all quotes with RMS flag field (filter client-side).
  static String get adminAllQuotesWithRmsFieldSf =>
      '$baseUrl/user/getData?sfQuery='
      'SELECT+Id,Name,Status,ExpirationDate,GrandTotal,CurrencyIsoCode,'
      'CreatedDate,Origin_Port__r.Name,Destination_Port__r.Name,'
      'Lead_Type__c,Goods_Value__c,Net_Weight_KGS__c,Gross_Weight_KGS__c,'
      '$quoteContainerSelectFields,'
      'Opportunity.Name,Opportunity.Opp_From_RMS_App__c,Account.Name '
      'FROM+Quote+ORDER+BY+CreatedDate+DESC';

  /// Opportunities created from the app. One query feeds both the total
  /// count and the most-searched routes. [accountId] limits the rows to one
  /// account; omit it for every account.
  static String rmsAppOpportunities({String? accountId}) {
    final id = accountId?.trim() ?? '';
    final accountClause = id.isEmpty ? '' : "+AND+AccountId='$id'";
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,AccountId,Opp_From_RMS_App__c,'
        'Origin_Port__c,Origin_Port__r.Name,'
        'Destination_Port__c,Destination_Port__r.Name '
        'FROM+Opportunity+WHERE+Opp_From_RMS_App__c=true'
        '$accountClause';
  }

  /// All account quotes with port names (Salesforce getData) for Recent Quotations.
  static String getAccountQuotesSf(String accountId) {
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,Name,Status,ExpirationDate,GrandTotal,CurrencyIsoCode,'
        'CreatedDate,AccountId,Origin_Port__r.Name,Destination_Port__r.Name,'
        'Lead_Type__c,Goods_Value__c,Net_Weight_KGS__c,Gross_Weight_KGS__c,'
        '$quoteContainerSelectFields '
        "FROM+Quote+WHERE+AccountId='$accountId' "
        'ORDER+BY+CreatedDate+DESC';
  }

  static String get quoteDetails => '$baseUrl/user/quote/line?quote_id=';
  static String pdfForQuote(String quoteId) =>
      '$baseUrl/user/pdfForQuote?quote_id=${Uri.encodeQueryComponent(quoteId.trim())}';

  static String detailedBooking(String accountId, String quoteId) {
    return '$baseUrl/user/detailed/booking?account_id=$accountId&quote_id=$quoteId';
  }

  /// Quote header via Salesforce getData (ports + weights; no Opportunity join).
  static String getQuoteHeaderById(String quoteId) {
    return getQuoteHeaderByIdMinimal(quoteId);
  }

  /// Weight / load / goods only (fallback when full query fails).
  static String getQuoteHeaderFieldsById(String quoteId) {
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,Name,Status,ExpirationDate,TotalPrice,GrandTotal,CurrencyIsoCode,'
        'Created_Date__c,Origin_Port__r.Name,Destination_Port__r.Name,'
        'Lead_Type__c,Goods_Value__c,Net_Weight_KGS__c,Gross_Weight_KGS__c,'
        '$quoteContainerSelectFields,Mode_of_Shipment__c '
        "+FROM+Quote+WHERE+Id='$quoteId'";
  }

  /// Container type/size on Quote header.
  static String getQuoteContainerFieldsById(String quoteId) {
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,$quoteContainerSelectFields,Lead_Type__c,Mode_of_Shipment__c '
        "+FROM+Quote+WHERE+Id='$quoteId'";
  }

  /// Container size/type from ocean-freight pricebook entry.
  static String getPricebookEntryContainerFieldsById(String pricebookEntryId) {
    return '$baseUrl/user/getData?sfQuery='
        'SELECT+Id,$quoteContainerSelectFields,Name '
        "+FROM+PricebookEntry+WHERE+Id='$pricebookEntryId'";
  }

  /// Minimal Quote query if custom fields are missing in org.
  static String getQuoteHeaderByIdMinimal(String quoteId) {
    return getQuoteHeaderFieldsById(quoteId);
  }

  //subscription
  static String get createSubscription => '$baseUrl/admin/create-subscription';
  static String get getAllSubscriptions => '$baseUrl/admin/all-subscriptions';
  static String get deleteSubscription => '$baseUrl/admin/delete-subscription';
  static String get sfTokenApi => '$baseUrl/user/sf-token';
  static String get sfOAuthToken =>
      'https://mprs--dev.sandbox.my.salesforce.com/services/oauth2/token';
  static String get bookQuoteApi => '$baseUrl/user/book/quote';

  // Quote creation
  static String userMarginAccount(String accountId) =>
      '$baseUrl/user/margin/account?accountId=${Uri.encodeQueryComponent(accountId.trim())}';

  static String get createQuote => '$baseUrl/user/create/quote';
  static String get createCaseFromRms => '$baseUrl/user/create/caseFromRMS';
  static String get receiptLocation => '$baseUrl/user/reciept/location';

  // Ports / commodities (Search Routes)
  static String get allPorts => '$baseUrl/user/all/ports';
  static String get commodities => '$baseUrl/user/get/commodities';

  static String pricebookForPorts(
    String origin,
    String destination, {
    String? mloCode,
    String? containerSize,
    String? containerType,
  }) {
    final buf = StringBuffer(
      '$baseUrl/user/pricebook/for/ports'
      '?originPort=$origin'
      '&destinationPort=$destination',
    );
    if (mloCode != null && mloCode.isNotEmpty) {
      buf.write('&mloCode=${Uri.encodeComponent(mloCode)}');
    }
    if (containerSize != null && containerSize.isNotEmpty) {
      buf.write('&containerSize=${Uri.encodeComponent(containerSize)}');
    }
    if (containerType != null && containerType.isNotEmpty) {
      buf.write('&containerType=${Uri.encodeComponent(containerType)}');
    }
    return buf.toString();
  }

  /// Fetches all surcharge PricebookEntry rows for the same Pricebook (MLO),
  /// container size, and origin port — used for the "Price Breakdown" accordion.
  ///
  /// The caller should prepend the main OCEAN FREIGHT entry to this list.
  static String otherChargesQuery({
    required String pricebook2Id,
    required String containerSize,
    required String originPort,
  }) {
    const fields =
        'Id, Name, UnitPrice, MPRS_Currency__c, '
        'Container_Size__c, Product2.Size__c, Product2.Type__c, Product2.Family';

    final soql =
        "SELECT $fields "
        "FROM PricebookEntry "
        "WHERE Pricebook2Id = '$pricebook2Id' "
        "AND Container_Size__c = '$containerSize' "
        "AND Product2.Origin_Port__r.Name = '$originPort' "
        "AND IsActive = true "
        "AND Name != 'OCEAN FREIGHT' "
        "AND Name != 'Miscellaneous Charges' "
        "ORDER BY Name ASC";

    return '$baseUrl/user/getData?sfQuery=${Uri.encodeQueryComponent(soql)}';
  }

  /// Builds a /user/getData?sfQuery=... URL with the full SOQL query for
  /// pricebook entries, using the exact Salesforce field conditions.
  ///
  /// [originPort]     – e.g. "Nhava Sheva"
  /// [destinationPort]– e.g. "Jebel Ali"
  /// [containerType]  – exact Container_Type__c value, e.g. "Standard(Dry Container)"
  static String pricebookSoqlQuery({
    required String originPort,
    required String destinationPort,
    required String containerType,
  }) {
    const fields =
        'Id, Name, Product2Id, UnitPrice, '
        'Container_Size__c, Container_Type__c, '
        'MPRS_Currency__c, Suggested_Margin__c, Override_Account_Margin__c, '
        'Via_Port__c, Pricebook2Id, '
        'Product2.Name, Product2.Type__c, Product2.Size__c, Product2.Family, '
        'Product2.Origin_Port__r.Name, Product2.Origin_Port__r.Port_Code__c, '
        'Product2.Destination_Port__r.Name, Product2.Destination_Port__r.Port_Code__c, '
        'Product2.Estimated_Transit_Time__c, '
        'Product2.Transit_Time__c, '
        'Pricebook2.MLO_Code__c, '
        'Pricebook2.MLO_Name__r.MLO_Code__c';

    final soql =
        "SELECT $fields "
        "FROM PricebookEntry "
        "WHERE Product2.Origin_Port__r.Name = '$originPort' "
        "AND Product2.Destination_Port__r.Name = '$destinationPort' "
        "AND Product2.IsActive = true "
        "AND IsActive = true "
        "AND UnitPrice != 0 "
        "AND Container_Type__c != 'AIR' "
        "AND Product2.Type__c = 'FCL' "
        "AND Container_Type__c = '$containerType' "
        "ORDER BY Pricebook2.MLO_Code__c ASC";

    return '$baseUrl/user/getData?sfQuery=${Uri.encodeQueryComponent(soql)}';
  }
}
