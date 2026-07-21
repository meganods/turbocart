const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

// Fix 3: Send Push Notification when Order Status changes
exports.onOrderStatusChange = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const orderId = context.params.orderId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if status changed
    if (beforeData.status === afterData.status) {
      return null;
    }

    const newStatus = afterData.status;
    const userId = afterData.userId;

    if (!userId) {
      console.log(`No userId found for order ${orderId}`);
      return null;
    }

    try {
      // Fetch user's FCM token
      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token registered for user ${userId}`);
        return null;
      }

      const statusLabel = newStatus.replace("_", " ").toUpperCase();
      const payload = {
        notification: {
          title: "Order Status Update",
          body: `Your order #${orderId.substring(0, 8).toUpperCase()} is now: ${statusLabel}`,
        },
        token: fcmToken,
      };

      // Send message
      const response = await admin.messaging().send(payload);
      console.log(`Successfully sent message to user ${userId}:`, response);
      return response;
    } catch (e) {
      console.error("Error sending push notification:", e);
      return null;
    }
  });

// Fix 4: Decrement Stock and low stock alert trigger
exports.onOrderCreated = functions.firestore
  .document("orders/{orderId}")
  .onCreate(async (snapshot, context) => {
    const orderData = snapshot.data();
    const items = orderData.items || [];
    const db = admin.firestore();

    try {
      const batch = db.batch();

      for (const item of items) {
        const productId = item.productId;
        const quantity = item.quantity || 0;

        if (!productId) continue;

        const productRef = db.collection("products").doc(productId);
        const productSnap = await productRef.get();

        if (productSnap.exists) {
          const productData = productSnap.data();
          const currentStock = productData.stock || 0;
          const newStock = Math.max(0, currentStock - quantity);

          // Update stock count
          batch.update(productRef, { stock: newStock });

          // If new stock is below 5, write to alerts collection
          if (newStock < 5) {
            const alertRef = db.collection("alerts").doc();
            batch.set(alertRef, {
              type: "low_stock",
              productId: productId,
              productName: productData.name || "Product",
              remainingStock: newStock,
              createdAt: admin.firestore.Timestamp.now(),
              read: false,
            });
            console.log(`Low stock alert queued for product ${productId}: remaining stock is ${newStock}`);
          }
        }
      }

      await batch.commit();
      console.log(`Processed stock decrement for order: ${context.params.orderId}`);
    } catch (e) {
      console.error("Error processing stock decrements:", e);
    }
    return null;
  });

// Fix 5: Secure payment signature verification API
exports.verifyPayment = functions.https.onCall(async (data, context) => {
  const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = data;

  if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing payment signature parameters."
    );
  }

  // Get keys from Firebase config (using dummy environment values for simulation)
  const keySecret = functions.config().razorpay ? functions.config().razorpay.secret : "dummy_secret_key_12345";

  // Razorpay signature verify math
  const generatedSignature = crypto
    .createHmac("sha256", keySecret)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  if (generatedSignature === razorpaySignature) {
    return { verified: true };
  } else {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Razorpay payment signature mismatch. Verification failed."
    );
  }
});
