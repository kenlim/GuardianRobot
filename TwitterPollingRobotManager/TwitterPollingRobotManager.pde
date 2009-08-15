// Twitter paging test
import processing.serial.*;
import java.util.List;

Twitter twitter; 
String username;
String password;
String happyHashExpression = ".*\\#highfivetest.*";
String sadHashExpression = ".*\\#ineedahugtest.*";
String happyReply = "Got a high-five! You rock!";
String sadReply = "I just received a hug; Sending it to you. *hug*";
String stillWaitingForHighFive = "Still waiting for high-five. Please don't leave me hanging.";
String stillWaitingForHug = "Still waiting for a hug...";

int pollingInterval = 60 * 1000; // 60 seconds
int lastTwitterPollTime;
int lastRobotUpdateTime;

long placeholderStatusId;
List jobList;

boolean waitingForRobot;

// Display settings
int screenWidth = screen.width;
int screenMargin = 50;
PFont fontA;
int x = 30;
PImage userImage;
PImage nextImage;

// Serial communication settings
Serial robotPort;
int inByte = -1;

Status currentStatusJob;
Status receivingButtonPushForStatus;

void setup() {
  String[]lines = loadStrings("credentials.txt");
  
  username  = lines[0];
  password = lines[1];
  twitter = new Twitter(username, password);
  lastTwitterPollTime = millis() - pollingInterval - 1000; // so it is overdue on setup()

  // Setting up display 
  size(screenWidth - screenMargin, screen.height/2);
  background(0);
  fontA = loadFont("LiberationSans-Bold-48.vlw");
  textFont(fontA, 48);
  
  // get my last reply, and figure out who it was for. That is the starting point.  
  List userUpdates = new ArrayList();
  try {
//    twitter.updateStatus("Guardian Robot online. Internet Connection enabled. Hello, world!");
    userUpdates = twitter.getUserTimeline();
  } catch (TwitterException e) {println(e);}
  placeholderStatusId = getMostRecentSentResponse(userUpdates);    
  
  jobList = new ArrayList();
  waitingForRobot = false;
  
  String portName = Serial.list()[0];
  robotPort = new Serial(this, portName, 9600);
  
  delay(5000);
}

long getMostRecentSentResponse(List userUpdates) {
  for (int i=0; i < userUpdates.size(); i++) {
    Status status = (Status) userUpdates.get(i);
    String statusText = status.getText();
    if (statusText.matches("^@.*")) {
      long statusThisRepliedTo = status.getInReplyToStatusId();
      println("Last reply sent was: " + statusText + " (statusId: " + statusThisRepliedTo + ")");
      return statusThisRepliedTo; 
    }
  }
  return 0;
}

/// The main loop
void draw() {
  // Poll twitter at intervals specified
 if (intervalHasPast()) {
    println("Polling twitter at: " + millis());
    List recentReplies = getAllRepliesSinceStatusId(placeholderStatusId);
   
    // make sure we don't keep asking for the same new stuff. 
    if (recentReplies.size() > 0) {
      placeholderStatusId = ((Status) recentReplies.get(0)).getId();
    }
        
    List filteredReplies = returnOnlyValidReplies(recentReplies);    
    jobList.addAll(filteredReplies);
    println("Found " + filteredReplies.size() + " new posts");
    printStatusList(filteredReplies);
    
    
    lastTwitterPollTime = millis();
 } 
 
 // If not waiting for response, then send instructions to robot, and wait.
 if (!waitingForRobot && jobList.size() > 0) {
   // FIFO policy, so get the first job
   currentStatusJob = (Status) jobList.get(0);
   
   displayStatus(currentStatusJob);
   try {
     if (statusIsHappy(currentStatusJob)) {
       println("Set robot to happy mode");
       robotPort.write('H'); // be happy
     } else if (statusNeedsHug(currentStatusJob)) {
       println("Set robot to sad mode");
       robotPort.write('S'); // be sad    
     } 
   } catch (Exception e) {}
   
   waitingForRobot = true;
   println("last robot update time : " + millis());
   lastRobotUpdateTime = millis();
 }
 
 if (waitingForRobot && (millis() - lastRobotUpdateTime) > 18000) {  // start complaining after 10 minutes
     try {
     if (statusIsHappy(currentStatusJob)) {
       // do you have another high five buffered?
       Status nextHappy = getNextAvailableHighFive();
       // if yes, then forward that instead. 
       if (nextHappy !=null) {
         println("Outsourcing highfive...");
         displayForwardedHug(currentStatusJob, nextHappy, "Forwarding highfive from");
         twitter.updateStatus("@" + currentStatusJob.getUser().getName() + " : Got a high five from " + nextHappy.getUser().getName() + " for you. You Rock!");
         delay(5000);
         // send neutral expression
         robotPort.write('N');
         // remove the jobs
              jobList.remove(currentStatusJob);    
              jobList.remove(nextHappy);    
         // don't wait for the robot anymore. 
        waitingForRobot = false; 
       }
       
     } else if (statusNeedsHug(currentStatusJob)) {
       // do you have another hug buffered?
       Status nextHug = getNextAvailableHug();
       // if yes, then forward that instead. 
       if (nextHug !=null) {
         println("Outsourcing hug...");
         displayForwardedHug(currentStatusJob, nextHug, "Forwarding hug from");
         twitter.updateStatus("@" + currentStatusJob.getUser().getName() + " : I got a hug from " + nextHug.getUser().getName() + "; Passing it to you. *hug*");
         delay(5000);
         // send neutral expression
         robotPort.write('N');
         // remove the jobs
              jobList.remove(currentStatusJob);    
              jobList.remove(nextHug);    
         // don't wait for the robot anymore. 
        waitingForRobot = false; 
       }
     } 
   } catch (TwitterException e) {}
 }
 
}

// get next available high five
Status getNextAvailableHighFive() {
  for(int i = 0; i < jobList.size(); i++) {
    Status status = (Status) jobList.get(i);
    if(statusIsHappy(status) && !status.equals(currentStatusJob)){
      return status;
    } 
  }
 return null; 
}

// get next available high five
Status getNextAvailableHug() {
  for(int i = 0; i < jobList.size(); i++) {
    Status status = (Status) jobList.get(i);
    if(statusNeedsHug(status)  && !status.equals(currentStatusJob)){
      return status;
    } 
  }
 return null; 
}

// Respond to button pushes
void serialEvent(Serial robotPort) {
  if (waitingForRobot) {
     String userName = currentStatusJob.getUser().getScreenName();

     try {
      inByte = robotPort.read(); 
      
       if (inByte > 0) {
         if (statusIsHappy(currentStatusJob)) {
          // send Highfive
          twitter.updateStatus( "@" + userName + " : " + happyReply, currentStatusJob.getId()); 
	  reportReply("Highfive received and forwarded!", currentStatusJob);
          println("Sent happy message to: " + userName);

        } else if (statusNeedsHug(currentStatusJob)) {
          // Send hug 
          twitter.updateStatus( "@" + userName + " : " + sadReply, currentStatusJob.getId()); 
	  reportReply("Hug received and forwarded...", currentStatusJob);
          println("Sent hug to: " + userName);
        }
       }  
     } catch (Exception e) {}

     jobList.remove(currentStatusJob);    
     waitingForRobot = false;   
  }
}

boolean intervalHasPast() {
  return (millis() - lastTwitterPollTime) > pollingInterval;
}  

List getAllRepliesSinceStatusId(long sinceId) {
  if (sinceId > 0) {
  try {
    return twitter.getMentions(new Paging(1).sinceId(sinceId));
  } catch (TwitterException e) {}
  }
  return new ArrayList();
}

List returnOnlyValidReplies(List statuses) {
  List result = new ArrayList();
  for(int i = 0; i < statuses.size(); i++) {
    Status status = (Status) statuses.get(i);
    if(statusIsHappy(status) || statusNeedsHug(status)){
     result.add(status);
    } 
  }
  
  return result;
}

void printStatusList(List statuses) {
 for(int i = 0; i < statuses.size(); i++) {
    Status status = (Status) statuses.get(i);
    println(status.getUser().getName() + " : " +  status.getText());
  } 
}

boolean statusIsHappy(Status status) {
  return status.getText().matches(happyHashExpression);
}

boolean statusNeedsHug(Status status) {
  return status.getText().matches(sadHashExpression);
}

void displayStatus(Status status) {
  background(0);
    userImage = loadImage(status.getUser().getProfileImageURL().toString());
      image(userImage, x, 30);
  fill(255);
  text(status.getUser().getName() + " ", x + 75, 60); 
  fill(255);
  text(status.getText(), x, 95, screenWidth - 50 - x -x, screen.height - 95);
}

void reportReply(String message, Status status) {
  background(0);

  image(userImage, x, 30);
  fill(255);
  text(status.getUser().getName() + " ", x + 75, 60); 
  fill(255);
  text("> " + message, x, 95, screenWidth - 50 - x -x, screen.height - 95);
}

void displayForwardedHug(Status currentStatus, Status nextStatus, String message) {
  background(0);
  nextImage = loadImage(nextStatus.getUser().getProfileImageURL().toString());

  image(userImage, x, 30);
  fill(255);
  text(currentStatus.getUser().getName() + " ", x + 75, 60); 
  fill(255);
  text("> " + message, x, 175);
  image(nextImage, x, 200);
    text(nextStatus.getUser().getName(), x + 75, 250);
}

