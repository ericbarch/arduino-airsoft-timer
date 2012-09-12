#include <LiquidCrystal.h>
#include <Keypad.h>

#define SETGAMETYPE 1
#define SETCODES 2
#define SETATTEMPTS 3
#define SETTIME 4
#define STARTGAME 5
#define SETUPCOMPLETE 6

#define ASSAULT 1
#define DEFEND 2
#define CAPTURE 3

#define ALPHA 1
#define BRAVO 2

int buzzPin = 3;      // Buzzer pin
int auxPortPin = 14;  // Aux Port pin
const byte ROWS = 4;  // Four keypad rows
const byte COLS = 3;  // Three keypad columns
char keys[ROWS][COLS] = {
  {'1','2','3'},
  {'4','5','6'},
  {'7','8','9'},
  {'*','0','#'}
};
byte rowPins[ROWS] = {9, 7, 13, 11}; //connect to the row pinouts of the keypad
byte colPins[COLS] = {10, 8, 12};    //connect to the column pinouts of the keypad

//Define our keypad and LCD objects
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
LiquidCrystal lcd(6,5,0,1,2,4);

//Global variables used throughout the program
unsigned long timeLeftAlpha;
unsigned long timeLeftBravo;
unsigned long lastMillis = 0;
unsigned long attemptsMillis = 0;
unsigned long overflowLimit = 4294900000;
unsigned int matchNum;
unsigned int countingTeam = 0;
int disarmAttempts = 0;
boolean detonated = false;
boolean disarmed = false;
boolean armed = false;
boolean paused = false;
boolean codesConfigured = false;
boolean timeSet = false;
boolean matchStart = false;
boolean battAlert = false;
unsigned int setupState = SETGAMETYPE;
int gameType = 0;

//Key vars
int codeIndex = 0;
int disarmIndex = 0;
int timeIndex = 0;
char disarmInput[] = "******";
char alphaKey[] = "------";  //Alpha / Arm Code
char bravoKey[] = "------";  //Bravo / Disarm Code
char refKey[] = "------";    //Ref Code
char disarmEntered[] = "--";
char hourAlpha[] = "--";
char hourBravo[] = "--";
char minAlpha[] = "--";
char minBravo[] = "--";

//Beep vars
unsigned long nextBeep = 0;
unsigned long nextBeepOff = 0;


void setup()
{
  pinMode(buzzPin, OUTPUT);     //set buzzer pin as output
  pinMode(auxPortPin, OUTPUT);  //set aux pin as output
  digitalWrite(auxPortPin, LOW);
  lcd.begin(20,4);
  randomSeed(analogRead(5));
  matchNum = random(1000);
  while (setupState != SETUPCOMPLETE) {
    setupMode();
  }
  lastMillis = millis();
}

void loop()
{
  int timeDiff;
  
  displayMenu("*-Del        Enter-#");
  
  while (!disarmed && !detonated) {
    if (!paused)
      timeDiff = millis() - lastMillis;
    else
      timeDiff = 0;

    lastMillis = millis();
    countdown(timeDiff);
    
    if (!battAlert)
      batteryCheck();
  }
  endGameMode();
}


/*** MAIN STATES FUNCTIONS ***/

void setupMode() {
  switch(setupState){
    case SETGAMETYPE:
      lcd.setCursor(0,0);
      lcd.print("--Choose Game Type--");
      lcd.setCursor(0,1);
      lcd.print("1-ASSAULT (ARM/DARM)");
      lcd.setCursor(0,2);
      lcd.print("2-DEFEND (DARM ONLY)");
      lcd.setCursor(0,3);
      lcd.print("3-CAPTURE (KOTH)");
      while (gameType == 0) {
        handleKeypadEvents();
      }
      setupState++;
      break;
    case SETCODES:
      lcd.clear();
      displayMenu("*-Del     SetCodes-#");
      while (codesConfigured == false) {
        lcd.setCursor(0,0);
        lcd.print("Ref Code: ");
        lcd.print(refKey);
        lcd.setCursor(0,1);
        if (gameType == ASSAULT)
          lcd.print("Arm Code: ");
        else if (gameType == CAPTURE)
          lcd.print("Alpha Code: ");
        if (gameType != DEFEND)
          lcd.print(alphaKey);
        lcd.setCursor(0,2);
        if (gameType != CAPTURE)
          lcd.print("Disarm Code: ");
        else
          lcd.print("Bravo Code: ");
        lcd.print(bravoKey);
        handleKeypadEvents();
      }
      setupState++;
      break;
    case SETATTEMPTS:
      if (gameType == CAPTURE) {
        setupState++;
        break; 
      }
      lcd.clear();
      lcd.setCursor(0,0);
      lcd.print("---Disarm Options---");
      lcd.setCursor(0,2);
      lcd.print("Enter value 01 to 99");
      displayMenu("*-Del        Enter-#");
      while (disarmAttempts == 0) {
        lcd.setCursor(0,1);
        lcd.print("Set Attempts: ");
        lcd.print(disarmEntered);
        handleKeypadEvents();
      }
      setupState++;
      break;
    case SETTIME:
      lcd.setCursor(0,0);
      lcd.print("---Countdown Time---");
      displayMenu("*-Del      SetTime-#");
      while (timeSet == false) {
        lcd.setCursor(0,1);
        if (gameType == CAPTURE)
          lcd.print("Alpha: ");
        else
          lcd.print("Time: ");
        lcd.print(hourAlpha);
        lcd.print("hrs ");
        lcd.print(minAlpha);
        lcd.print("mins");
        if (gameType == CAPTURE) {
          lcd.setCursor(0,2);
          lcd.print("Bravo: ");
          lcd.print(hourBravo);
          lcd.print("hrs ");
          lcd.print(minBravo);
          lcd.print("mins");
        }
        handleKeypadEvents();
      }
      
      timeLeftAlpha = (atoi(hourAlpha) * 3600000) + (atoi(minAlpha) * 60000);
      
      if (gameType == CAPTURE)
        timeLeftBravo = (atoi(hourBravo) * 3600000) + (atoi(minBravo) * 60000);
      
      setupState++;
      break;
    case STARTGAME:
      displayMatchNum();
      lcd.setCursor(0,1);
      lcd.print("Take note of match #");
      lcd.setCursor(0,2);
      lcd.print("                    ");
      displayMenu("       BEGIN MATCH-#");
      while (matchStart == false) {
        handleKeypadEvents();
      }
      setupState++;
      break;
    case SETUPCOMPLETE:
      break;
    default:
      break;
  }
      
  lcd.clear();
  
  if (gameType != CAPTURE)
    displayMatchNum();
  if (gameType == ASSAULT)
    paused = true;
    
  codeIndex = 0;
}


void countdown(int timeDiff) {
  lcd.setCursor(0,2);
  lcd.print("Enter Code: ");
  lcd.print(disarmInput);
  
  if (gameType == CAPTURE) {
    displayTimeLeft(timeLeftAlpha, 0);
    displayTimeLeft(timeLeftBravo, 1);
    if (countingTeam == ALPHA)
      timeLeftAlpha -= timeDiff;
    else if (countingTeam == BRAVO)
      timeLeftBravo -= timeDiff;
  }
  else {
    if (millis() < attemptsMillis) {
       lcd.setCursor(0,1);
       lcd.print("Tries Left: ");
       lcd.print(disarmAttempts);
    }
    else
      displayTimeLeft(timeLeftAlpha, 1);
    timeLeftAlpha -= timeDiff;
  }
  
  if (!paused)
    countdownBeeper();
  else
    analogWrite(buzzPin, 0);
    
  handleKeypadEvents();
  
  if (timeLeftAlpha > overflowLimit) {  //Check if we've run out of time (timer overflow)
    timeLeftAlpha = 0;
    detonateSeq();
  }
  else if (timeLeftBravo > overflowLimit) {  //Check if we've run out of time (timer overflow)
    timeLeftBravo = 0;
    detonateSeq();
  }
}

void endGameMode() {
  displayMatchNum();
  while(1) {
    if ((millis() % 1000) < 500) {
      displayTimeLeft(timeLeftAlpha, 1);
      if (gameType == CAPTURE)
        displayTimeLeft(timeLeftBravo, 2);
      else
        displayTimeLeft(timeLeftAlpha, 2);
    }
    else {
      displayBlankTime();
    }
  }
}



/* BEGIN Keypad press handler */
void handleKeypadEvents() {
  char key = keypad.getKey();
    
  if (key != NO_KEY){
    //Chirp!
    TCCR2B = (TCCR2B & 0xF8) | 2;  //Set the last value lower to get a higher tone and vice versa
    analogWrite(buzzPin, 127);
    delay(15);
    analogWrite(buzzPin, 0);
    
    if (setupState == SETGAMETYPE) {
      if (key == '1')
        gameType = ASSAULT;
      else if (key == '2')
        gameType = DEFEND;
      else if (key == '3')
        gameType = CAPTURE;
    }
    else if (setupState == SETATTEMPTS) {
      if (disarmIndex < 2 && key != '*' && key != '#')
        disarmEntered[disarmIndex++] = key;
      else if (key == '*' && disarmIndex > 0)
        disarmEntered[--disarmIndex] = '-';
      else if (key == '#' && disarmIndex == 2) {
        if (atoi(disarmEntered) > 0 && atoi(disarmEntered) < 100) {
          disarmAttempts = atoi(disarmEntered);
        }
      }
    }
    else if (setupState == SETCODES) {
      if (key == '*' && gameType == DEFEND && codeIndex == 12)
        codeIndex = 6;
      
      if (key != '*' && key != '#') {
        if (codeIndex < 6)
          refKey[codeIndex++] = key;
        else if (codeIndex >= 6 && codeIndex < 12)
          alphaKey[((codeIndex++) - 6)] = key;
        else if (codeIndex >= 12 && codeIndex < 18)
          bravoKey[((codeIndex++) - 12)] = key;
      }
      else if (key == '*') {
        if (codeIndex > 0 && codeIndex < 7)
          refKey[--codeIndex] = '-';
        else if (codeIndex >= 7 && codeIndex < 13)
          alphaKey[--codeIndex - 6] = '-';
        else if (codeIndex >= 13 && codeIndex < 19)
          bravoKey[--codeIndex - 12] = '-';
      }
      else if (key == '#') {
        if (codeIndex == 18 && strcmp(alphaKey, refKey) != 0 && strcmp(bravoKey, refKey) != 0) {
          if (gameType == CAPTURE && strcmp(bravoKey, alphaKey) == 0)
            codesConfigured = false;
          else
            codesConfigured = true;
        }
      }
      
      if (gameType == DEFEND && codeIndex == 6)
        codeIndex = 12;
    }
    else if (setupState == SETTIME) {
      if (key != '*' && key != '#') {
        if (timeIndex < 2)
          hourAlpha[timeIndex++] = key;
        else if (timeIndex >= 2 && timeIndex < 4)
          minAlpha[((timeIndex++) - 2)] = key;
        else if (timeIndex >= 4 && timeIndex < 6 && gameType == CAPTURE)
          hourBravo[((timeIndex++) - 4)] = key;
        else if (timeIndex >= 6 && timeIndex < 8 && gameType == CAPTURE)
          minBravo[((timeIndex++) - 6)] = key;
      }
      else if (key == '*') {
        if (timeIndex > 0 && timeIndex < 3)
          hourAlpha[--timeIndex] = '-';
        else if (timeIndex >= 3 && timeIndex < 5)
          minAlpha[--timeIndex - 2] = '-';
        else if (timeIndex >= 5 && timeIndex < 7)
          hourBravo[--timeIndex - 4] = '-';
        else if (timeIndex >= 7 && timeIndex < 9)
          minBravo[--timeIndex - 6] = '-';
      }
      else if (key == '#') {
        if (gameType == CAPTURE && timeIndex == 8) {
          if ((atoi(minAlpha) > 0 || atoi(hourAlpha) > 0) && (atoi(minBravo) > 0 || atoi(hourBravo) > 0) && atoi(hourAlpha) <= 48 && atoi(hourBravo) <= 48)
            timeSet = true;
        }
        else if (gameType != CAPTURE && timeIndex == 4) {
          if ((atoi(minAlpha) > 0 || atoi(hourAlpha) > 0) && atoi(hourAlpha) <= 48)
            timeSet = true;
        }
      }
    }
    else if (setupState == STARTGAME) {
      if (key == '#')
        matchStart = true;
    }
    else {  //We are in the middle of the game
      if (codeIndex < 6 && key != '*' && key != '#')
        disarmInput[codeIndex++] = key;
      else if (key == '*' && codeIndex > 0)
        disarmInput[--codeIndex] = '*';
      else if (key == '#') {
        if (strcmp(disarmInput, refKey) == 0 && matchStart == true) {
          for (int i=0;i<6;i++)
            disarmInput[i] = '*';
          codeIndex = 0;
          if (!paused)
            paused = true;
          else
            paused = false;
        }
        else if (strcmp(disarmInput, alphaKey) == 0 && !armed && gameType == ASSAULT) {
          for (int i=0;i<6;i++)
            disarmInput[i] = '*';
          codeIndex = 0;
          paused = false;
          armed = true;
        }
        else if (strcmp(disarmInput, bravoKey) == 0 && !paused && codeIndex == 6 && gameType != CAPTURE)
          disarmSeq();
        else if (strcmp(disarmInput, alphaKey) == 0 && !paused && codeIndex == 6 && gameType == CAPTURE) {
          countingTeam = ALPHA;
          for (int i=0;i<6;i++)
            disarmInput[i] = '*';
          codeIndex = 0;
        }
        else if (strcmp(disarmInput, bravoKey) == 0 && !paused && codeIndex == 6 && gameType == CAPTURE) {
          countingTeam = BRAVO;
          for (int i=0;i<6;i++)
            disarmInput[i] = '*';
          codeIndex = 0;
        }
        else if (!paused && codeIndex == 6 && gameType != CAPTURE) {
          if (disarmAttempts-- <= 1)
            detonateSeq();
          else {
            for (int i=0;i<6;i++)
            disarmInput[i] = '*';
            codeIndex = 0;
            TCCR2B = (TCCR2B & 0xF8) | 5;  //Set the last value lower to get a higher tone and vice versa
            analogWrite(buzzPin, 175);
            delay(50);
            analogWrite(buzzPin, 0);
            delay(50);
            analogWrite(buzzPin, 175);
            delay(50);
            analogWrite(buzzPin, 0);
            lcd.setCursor(0,1);
            lcd.print("                    ");
            attemptsMillis = millis() + 2000;
          }
        }
        else {
          for (int i=0;i<6;i++)
            disarmInput[i] = '*';
          codeIndex = 0;
        }
      }
    }
  }
}
/* END Keypad press handler */



/* BEGIN Countdown Beeper related functions */
void countdownBeeper() {
    if (timeLeftAlpha <= 60000 && millis() >= nextBeep && !disarmed) {
      if ((gameType == CAPTURE && countingTeam == ALPHA) || (gameType != CAPTURE)) {
        lowChirp();
        nextBeep = millis() + (timeLeftAlpha / map(timeLeftAlpha, 60000, 0, 20, 38));
      }
    }
    if (timeLeftBravo <= 60000 && millis() >= nextBeep && !disarmed && countingTeam == BRAVO) {
      lowChirp();
      nextBeep = millis() + (timeLeftBravo / map(timeLeftBravo, 60000, 0, 20, 38));
    }
    if (timeLeftAlpha <= 60000 || timeLeftBravo <= 60000)
      checkBuzzer();
    else
      analogWrite(buzzPin, 0);
}

void lowChirp() {
  TCCR2B = (TCCR2B & 0xF8) | 3;  //Set the last value lower to get a higher tone and vice versa
  analogWrite(buzzPin, 175);
  nextBeepOff = millis() + 30;
}

void checkBuzzer() {
  if (millis() >= nextBeepOff)
    analogWrite(buzzPin, 0);
}
/* END Countdown Beeper related functions */



void disarmSeq() {
  lcd.setCursor(0,0);
  lcd.print("------DISARMED------");
  lcd.setCursor(0,1);
  lcd.print("------DISARMED------");
  lcd.setCursor(0,2);
  lcd.print("------DISARMED------");
  lcd.setCursor(0,3);
  lcd.print("------DISARMED------");
  TCCR2B = (TCCR2B & 0xF8) | 4;  //Set the last value lower to get a higher tone and vice versa
  analogWrite(buzzPin, 175);
  delay(25);
  analogWrite(buzzPin, 0);
  delay(200);
  analogWrite(buzzPin, 175);
  delay(25);
  analogWrite(buzzPin, 0);
  disarmed = true;
}



void detonateSeq() {
  lcd.setCursor(0,0);
  lcd.print("------DETONATED-----");
  lcd.setCursor(0,1);
  lcd.print("------DETONATED-----");
  lcd.setCursor(0,2);
  lcd.print("------DETONATED-----");
  lcd.setCursor(0,3);
  lcd.print("------DETONATED-----");
  TCCR2B = (TCCR2B & 0xF8) | 2;  //Set the last value lower to get a higher tone and vice versa
  analogWrite(buzzPin, 127);
  digitalWrite(auxPortPin, HIGH);
  delay(10000);
  digitalWrite(auxPortPin, LOW);
  delay(1000);
  analogWrite(buzzPin, 0);
  detonated = true;
}


void displayTimeLeft(long timeRemain, char teamLine) {
  lcd.setCursor(0,teamLine);
  if (gameType == CAPTURE && teamLine == 0 && !detonated && !disarmed)
    lcd.print("A: ");
  else if (gameType == CAPTURE && teamLine == 1 && !detonated && !disarmed)
    lcd.print("B: ");
  else if (gameType == CAPTURE && teamLine == 1 && (detonated || disarmed))
    lcd.print("A: ");
  else if (gameType == CAPTURE && teamLine == 2 && (detonated || disarmed))
    lcd.print("B: ");
  
  int hours = (((timeRemain/1000)/60)/60) % 60;
  int mins = ((timeRemain/1000)/60) % 60;
  int secs = (timeRemain/1000) % 60;
  int ms = timeRemain % 1000;
      
  if (hours < 10)
    lcd.print("0");
  lcd.print(hours);
  lcd.print("h:");
  if (mins < 10)
    lcd.print("0");
  lcd.print(mins);
  lcd.print("m:");
  if (secs < 10)
    lcd.print("0");
  lcd.print(secs);
  lcd.print("s.");
  if (ms < 10)
    lcd.print("00");
  else if (ms < 100)
    lcd.print("0");
  lcd.print(ms);
}

void displayBlankTime() {
  lcd.setCursor(0,1);
  lcd.print("                    ");
  lcd.setCursor(0,2);
  lcd.print("                    ");
}

void displayMenu(char *menu) {
  lcd.setCursor(0,3);
  lcd.print("                    ");
  lcd.setCursor(0,3);
  lcd.print(menu);
}

void displayMatchNum() {
  lcd.setCursor(0,0);
  lcd.print("                    ");
  lcd.setCursor(0,0);
  lcd.print("PZTv001 - Match #");
  lcd.print(matchNum); 
}

void batteryCheck() {
  int getVolt = map(analogRead(1), 0, 1023, 0, 1000);
  if (getVolt <= 750) {
    displayMenu("*-Del !LOBATT! Ent-#");
    battAlert = true;
  }
}
