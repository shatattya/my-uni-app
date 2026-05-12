const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize the Firebase Admin SDK
admin.initializeApp();

/**
 * Triggers every time a new document is created in the "announcements" collection.
 */
exports.sendAnnouncementNotification = functions.firestore
  .document("announcements/{announcementId}")
  .onCreate(async (snap, context) => {
    // 1. Grab the data from the newly created announcement
    const newNotice = snap.data();
    const title = newNotice.title;
    const body = newNotice.body;
    const isGlobal = newNotice.isGlobal;
    const sems = newNotice.targetSemesters || [];
    const secs = newNotice.targetSections || [];

    // 2. Figure out which topics need to hear about this
    let targetTopics = [];

    if (isGlobal) {
      targetTopics.push("global");
    } else {
      // Create a specific topic string for every combination of semester and section chosen
      sems.forEach((sem) => {
        secs.forEach((sec) => {
          // Exactly matches the topic format we used in Flutter: sem_7_sec_C
          targetTopics.push(`sem_${sem}_sec_${sec.toUpperCase()}`);
        });
      });
    }

    // 3. Prevent errors if no targets were somehow selected
    if (targetTopics.length === 0) {
      console.log("No targets specified, skipping notification.");
      return null;
    }

    console.log(`Sending notifications to topics: ${targetTopics.join(", ")}`);

    // 4. Create the array of notification messages
    const messages = targetTopics.map((topic) => {
      return {
        notification: {
          title: title,
          body: body,
        },
        topic: topic,
        // Optional: Adding Android-specific settings to make it pop
        android: {
          notification: {
            sound: "default",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
      };
    });

    // 5. Blast them out to Firebase Cloud Messaging!
    try {
      // Send all messages simultaneously
      const responses = await Promise.all(
        messages.map((msg) => admin.messaging().send(msg))
      );
      console.log(`Successfully sent ${responses.length} messages.`);
      return null;
    } catch (error) {
      console.error("Error sending notifications:", error);
      return null;
    }
  });
