const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Simple HTTP function to check disruptions and send notifications
exports.checkMetroDisruptions = functions.https.onRequest(async (req, res) => {
  console.log('Checking for Metro disruptions...');
  
  try {
    // Fetch disruptions
    const response = await axios.get('https://ken.nebulalabs.cc/disruption/active/', {
      params: {
        facilities: 'train_service,step_free_access,lift,escalator,public_information_display,public_address_system,lighting',
        routes: 'green_line,yellow_line',
        stations: 'airport,bank_foot,bede,benton,brockley_whins,byker,callerton_parkway,central_station,chichester,chillingham_road,cullercoats,east_boldon,fawdon,fellgate,felling,four_lane_ends,gateshead,gateshead_stadium,hadrian_road,haymarket,hebburn,heworth,howdon,ilford_road,jarrow,jesmond,kingston_park,longbenton,manors,meadow_well,millfield,monkseaton,monument,north_shields,northumberland_park,pallion,palmersville,park_lane,percy_main,pelaw,regent_centre,seaburn,shiremoor,simonside,south_gosforth,south_hylton,south_shields,st_james,stadium_of_light,sunderland,tyne_dock,the_coast,tynemouth,university,walkergate,wallsend,wansbeck_road,west_jesmond,west_monkseaton,whitley_bay',
        priority_levels: 'service_suspension,service_disruption,station_closure,facilities_out_of_use,improvement_works,for_information_only,other'
      }
    });
    
    const currentDisruptions = response.data;
    
    // Filter out informational disruptions
    const notificationWorthy = currentDisruptions.filter(d =>
      d.priority_level !== 'for_information_only'
    );
    
    // Send a test notification to a topic
    if (notificationWorthy.length > 0) {
      const disruption = notificationWorthy[0];
      await sendNotification(disruption);
      res.status(200).send(`Sent notification for disruption: ${disruption.title}`);
    } else {
      res.status(200).send('No notification-worthy disruptions found');
    }
    
  } catch (error) {
    console.error('Error checking disruptions:', error.message);
    res.status(500).send(`Error: ${error.message}`);
  }
});

async function sendNotification(disruption) {
  console.log(`Sending notification for disruption: ${disruption.title}`);
  
  const message = {
    notification: {
      title: 'Metro Status Update',
      body: disruption.title
    },
    data: {
      disruptionId: disruption.id.toString(),
      priorityLevel: disruption.priority_level,
      content: disruption.content
    },
    topic: 'metro_disruptions'
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return true;
  } catch (error) {
    console.error('Error sending message:', error);
    return false;
  }
}
