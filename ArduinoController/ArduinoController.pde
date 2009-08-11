// GuardianRobot Arduino controls. 

#include <Servo.h>
 
Servo arm;
Servo head;
char actingDirection;
char currentEmotion;
int bellyPin = 7;
int handPin = 5;
 
void setup() {
  head.attach(9);
  arm.attach(10);  // attaches the servo on pin 9 to the servo object
   
  pinMode(bellyPin, INPUT);
  pinMode(handPin, INPUT);
  
  Serial.begin(9600);
  
  changeToNeutralExpression();    
  currentEmotion = 'N';
  actingDirection = 'N';
}
 
 
void loop() {
    // look for button pushes
    actingDirection = readReactionPins();
    
    // If instructions are coming down the wire, overwrite the emotionState:
    if (Serial.available()) {
      actingDirection = Serial.read();
    }
      
    // Only if the emotionState has changed since the last loop, switch to new emotion:
    if (actingDirection != currentEmotion) {
      if (actingDirection == 'H') {
        changeToHappyExpression();
        currentEmotion = actingDirection; 
       } else if (actingDirection == 'S') {
         changeToSadExpression();
         currentEmotion = actingDirection;
       } else if (actingDirection == 'N') {
          changeToNeutralExpression();
          currentEmotion = actingDirection;
       }
    }
    
}

// This is done once per loop. NOT on button push.
char readReactionPins() {
   if (digitalRead(bellyPin) == HIGH) {
     Serial.print(1, BYTE);  // send hug
     delay(500);
     return 'N';             // reset to neutral
   } else if ( digitalRead(handPin) == HIGH) {
    Serial.print(2, BYTE);   // send highfive
     delay(500);
      return 'N';            // reset to neutral
   }
   return actingDirection;  // send back the current state (no change)
} 

void changeToHappyExpression() {
    head.write(120);
    arm.write(0);
    delay(1000);
}

void changeToSadExpression() {
    head.write(65);
    arm.write(180);
    delay(1000);
}

void changeToNeutralExpression() {
    head.write(90);
    arm.write(180);
    delay(1000);
}

