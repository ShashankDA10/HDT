const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.onReportAdded = functions.firestore
  .document("reports/{reportId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const patientId = data.patientId;
    if (!patientId) return;

    const userDoc = await admin.firestore().collection("users").doc(patientId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "📋 New Report Added",
        body: `${data.reportName} — Dr. ${data.doctorName}`,
      },
    });
  });