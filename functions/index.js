// index.js (for Firebase Cloud Functions)

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Store the previous state of disruptions
let previousDisruptions = [];

// Function that runs every minute to check for new disruptions
exports.checkMetroDisruptions = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  console.log('Checking for Metro disruptions...');
  
  try {
    // Fetch current disruptions
    const response = await axios.get(
      'https://ken.nebulalabs.cc/disruption/active/',
      {
        params: {
          facilities: 'train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting',
          routes: 'green_line,yellow_line',
          stations: 'airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay',
          priority_levels: 'service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other'
        }
      }
    );
    
    const currentDisruptions = response.data;
    
    // Filter out "for_information_only" disruptions
    const notificationWorthy = currentDisruptions.filter(
      disruption => disruption.priority_level !== 'for_information_only'
    );
    
    // Get previous notification-worthy disruptions
    const previousNotificationWorthy = previousDisruptions.filter(
      disruption => disruption.priority_level !== 'for_information_only'
    );
    
    // Find new disruptions (ones that weren't in the previous list)
    const newDisruptions = notificationWorthy.filter(
      current => !previousNotificationWorthy.some(prev => prev.id === current.id)
    );
    
    console.log(`Found ${newDisruptions.length} new disruptions`);
    
    // Send notifications for each new disruption
    for (const disruption of newDisruptions) {
      await sendDisruptionNotification(disruption);
    }
    
    // Update the previous disruptions
    previousDisruptions = currentDisruptions;
    
    // Store the latest disruptions in Firestore for reference
    const batch = admin.firestore().batch();
    
    // Clear the existing collection
    const disruptionsRef = admin.firestore().collection('disruptions');
    const snapshot = await disruptionsRef.get();
    
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // Add the new disruptions
    currentDisruptions.forEach(disruption => {
      const docRef = disruptionsRef.doc(disruption.id.toString());
      batch.set(docRef, {
        ...disruption,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
    
    return null;
  } catch (error) {
    console.error('Error checking for disruptions:', error);
    return null;
  }
});

// Function to send a notification for a specific disruption
async function sendDisruptionNotification(disruption) {
  console.log(`Sending notification for disruption ID: ${disruption.id}`);
  
  // Create the notification message
  const message = {
    notification: {
      title: 'Metro Status Update',
      body: disruption.title
    },
    data: {
      disruptionId: disruption.id.toString(),
      priorityLevel: disruption.priority_level,
      title: disruption.title,
      content: disruption.content,
      createdAt: disruption.created_at
    },
    android: {
      notification: {
        icon: 'ic_stat_metro',
        color: getPriorityColor(disruption.priority_level)
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default'
        }
      }
    }
  };
  
  // Topics to send to based on the disruption
  const topics = ['metro_disruptions'];
  
  // Add topics based on impacted routes
  if (disruption.all_routes) {
    topics.push('green_line');
    topics.push('yellow_line');
  } else {
    if (disruption.impacted_routes.includes('green_line')) {
      topics.push('green_line');
    }
    if (disruption.impacted_routes.includes('yellow_line')) {
      topics.push('yellow_line');
    }
  }
  
  // Send to each topic
  for (const topic of topics) {
    try {
      message.topic = topic;
      const response = await admin.messaging().send(message);
      console.log(`Successfully sent message to topic ${topic}:`, response);
    } catch (error) {
      console.error(`Error sending message to topic ${topic}:`, error);
    }
  }
}

// Helper function to get color for priority level
function getPriorityColor(priorityLevel) {
  switch (priorityLevel) {
    case 'service_suspension':
      return '#FF0000'; // Red
    case 'service_disruption':
      return '#FFA500'; // Orange
    case 'station_closure':
      return '#FF0000'; // Red
    case 'facilities_out_of_use':
      return '#FFFF00'; // Yellow
    case 'improvement_works':
      return '#0000FF'; // Blue
    default:
      return '#808080'; // Gray
  }
}

// HTTP endpoint to manually trigger a check (useful for testing)
exports.manualCheckDisruptions = functions.https.onRequest(async (req, res) => {
  try {
    // Reuse the same logic from the scheduled function
    const response = await axios.get(
      'https://ken.nebulalabs.cc/disruption/active/',
      {
        params: {
          facilities: 'train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting',
          routes: 'green_line,yellow_line',
          stations: 'airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay',
          priority_levels: 'service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other'
        }
      }
    );
    
    const currentDisruptions = response.data;
    
    // For testing purposes, treat all disruptions as new
    for (const disruption of currentDisruptions) {
      if (disruption.priority_level !== 'for_information_only') {
        await sendDisruptionNotification(disruption);
      }
    }
    
    res.status(200).send({
      success: true,
      message: `Processed ${currentDisruptions.length} disruptions`,
      disruptions: currentDisruptions
    });
  } catch (error) {
    console.error('Error in manual check:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});

// Optional: Endpoint to send a test notification to a specific token
exports.sendTestNotification = functions.https.onRequest(async (req, res) => {
  try {
    const { token } = req.query;
    
    if (!token) {
      return res.status(400).send({ error: 'Device token is required' });
    }
    
    const message = {
      notification: {
        title: 'Test Notification',
        body: 'This is a test notification from BetterMetro'
      },
      token: token
    };
    
    const response = await admin.messaging().send(message);
    
    res.status(200).send({
      success: true,
      messageId: response
    });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});

// API endpoint to register a device
exports.registerDevice = functions.https.onRequest(async (req, res) => {
  // Ensure this is a POST request
  if (req.method !== 'POST') {
    return res.status(405).send({ error: 'Method not allowed' });
  }
  
  try {
    const { token, device, app_version } = req.body;
    
    if (!token) {
      return res.status(400).send({ error: 'Device token is required' });
    }
    
    // Store the device token in Firestore
    await admin.firestore().collection('devices').doc(token).set({
      token,
      device: device || 'unknown',
      app_version: app_version || 'unknown',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    // Subscribe the device to topics
    await admin.messaging().subscribeToTopic(token, 'metro_disruptions');
    await admin.messaging().subscribeToTopic(token, 'green_line');
    await admin.messaging().subscribeToTopic(token, 'yellow_line');
    
    res.status(200).send({
      success: true,
      message: 'Device registered successfully'
    });
  } catch (error) {
    console.error('Error registering device:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});
