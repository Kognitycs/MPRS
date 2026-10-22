/**
 * Firebase Admin push dispatch for MPRS Genie.
 *
 * Deploy from the firebase/ folder:
 *   npm install --prefix functions
 *   firebase deploy --only functions
 *
 * Your Node backend should call sendAdminPush (or mirror this logic inside
 * PATCH /admin/notificationApproval/:id) after a notification is approved.
 *
 * The Flutter app subscribes devices to topics:
 *   all_users, external, vip, vvip, admin, internal
 */

const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const CHANNEL_ID = "high_importance_channel";

function normalizeTopic(userType) {
  const value = String(userType || "").trim().toLowerCase();
  if (!value) return null;
  if (["external", "vip", "vvip", "admin", "internal"].includes(value)) {
    return value;
  }
  return null;
}

function buildMessage({ title, body, data, topic, token }) {
  // Data-only FCM so Android invokes the Flutter background handler and the
  // app can persist to SQLite + show a local notification. Including a
  // `notification` payload prevents onBackgroundMessage on Android.
  const payload = {
    data: Object.fromEntries(
      Object.entries({
        ...(data || {}),
        messageHeader: title || "MPRS Genie",
        messageBody: body || "",
        title: title || "MPRS Genie",
        body: body || "",
        androidChannelId: CHANNEL_ID,
      }).map(([key, val]) => [key, String(val ?? "")]),
    ),
    android: {
      priority: "high",
    },
  };

  if (topic) payload.topic = topic;
  if (token) payload.token = token;
  return payload;
}

/**
 * POST /sendAdminPush
 * Body:
 * {
 *   "messageHeader": "Title",
 *   "messageBody": "Body text",
 *   "notificationId": "uuid",
 *   "targetUsers": ["External", "VIP"],
 *   "tokens": ["optional-direct-fcm-token"]
 * }
 */
exports.sendAdminPush = onRequest({ cors: true, invoker: "public" }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ success: false, message: "POST only" });
    return;
  }

  try {
    const {
      messageHeader = "",
      messageBody = "",
      notificationId = "",
      targetUsers = [],
      tokens = [],
      link = "",
    } = req.body || {};

    const title = String(messageHeader).trim() || "New Notification";
    const body = String(messageBody).trim();
    const data = {
      messageHeader: title,
      messageBody: body,
      notificationId: String(notificationId),
      targetUsers: JSON.stringify(targetUsers),
      link: String(link),
      approvalType: "notification",
      status: "received",
    };

    const messaging = getMessaging();
    const results = [];

    for (const token of tokens) {
      if (!token) continue;
      const id = await messaging.send(
        buildMessage({ title, body, data, token: String(token) }),
      );
      results.push({ type: "token", token: String(token).slice(0, 12), id });
    }

    const topics = new Set(["all_users"]);
    for (const userType of targetUsers) {
      const topic = normalizeTopic(userType);
      if (topic) topics.add(topic);
    }

    for (const topic of topics) {
      const id = await messaging.send(
        buildMessage({ title, body, data, topic }),
      );
      results.push({ type: "topic", topic, id });
    }

    res.status(200).json({
      success: true,
      dispatched: results.length,
      results,
    });
  } catch (error) {
    console.error("sendAdminPush error:", error);
    res.status(500).json({
      success: false,
      message: error.message || "FCM dispatch failed",
    });
  }
});
