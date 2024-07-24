#include <Adafruit_Fingerprint.h>

#if (defined(__AVR__) || defined(ESP8266)) && !defined(__AVR_ATmega2560__)
// For UNO and others without hardware serial, we must use software serial...
// pin #2 is IN from sensor (GREEN wire)
// pin #3 is OUT from arduino  (WHITE wire)
// Set up the serial port to use softwareserial..
#include <SoftwareSerial.h>
SoftwareSerial mySerial(2, 3);

#else
// On Leonardo/M0/etc, others with hardware serial, use hardware serial!
// #0 is green wire, #1 is white
#define mySerial Serial1

#endif

Adafruit_Fingerprint finger = Adafruit_Fingerprint(&mySerial);
uint8_t id;
bool enrolling = false;

void setup() {
  Serial.begin(9600);
  while (!Serial);  // For Yun/Leo/Micro/Zero/...
  delay(100);

  // set the data rate for the sensor serial port
  finger.begin(57600);

  if (finger.verifyPassword()) {
    Serial.println("fp_init_ok");
  } else {
    Serial.println("fp_init_fail");
    while (1) { delay(1); }
  }
}

uint8_t readnumber(void) {
  uint8_t num = 0;

  while (num == 0) {
    while (! Serial.available());
    num = Serial.parseInt();
  }
  return num;
}

void loop() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');
    if (command.startsWith("fp_delete ")) {
      id = command.substring(10).toInt();
      deleteFingerprint(id);
    } else if (command.startsWith("fp_enroll ")) {
      if (!enrolling) {
        id = command.substring(10).toInt();
        enrolling = true;
        enrollFingerprint(id);
      }
    } else if (command.equals("fp_detect")) {
      detectFingerprint();
    }
  }
}

uint8_t deleteFingerprint(uint8_t id) {
  uint8_t p = finger.deleteModel(id);

  if (p == FINGERPRINT_OK) {
    Serial.println("fp_delete_ok");
  } else {
    Serial.println("fp_delete_fail");
  }

  return p;
}

void enrollFingerprint(uint8_t id) {
  Serial.print("Enrolling ID #");
  Serial.println(id);
  if (getFingerprintEnroll(id) == FINGERPRINT_OK) {
    enrolling = false;
  }
}

uint8_t getFingerprintEnroll(uint8_t id) {
  int p = -1;
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    if (p != FINGERPRINT_NOFINGER) {
      delay(100);
    }
  }

  p = finger.image2Tz(1);
  if (p != FINGERPRINT_OK) {
    Serial.println("fp_enroll_fail");
    return p;
  }

  delay(2000);
  while (p != FINGERPRINT_NOFINGER) {
    p = finger.getImage();
  }

  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    if (p != FINGERPRINT_NOFINGER) {
      delay(100);
    }
  }

  p = finger.image2Tz(2);
  if (p != FINGERPRINT_OK) {
    Serial.println("fp_enroll_fail");
    return p;
  }

  p = finger.createModel();
  if (p != FINGERPRINT_OK) {
    Serial.println("fp_enroll_fail");
    return p;
  }

  p = finger.storeModel(id);
  if (p == FINGERPRINT_OK) {
    Serial.println("fp_enroll_ok");
  } else {
    Serial.println("fp_enroll_fail");
  }

  enrolling = false;
  return p;
}

void detectFingerprint() {
  const int maxRetries = 25;
  int retryCount = 0;

  while (retryCount < maxRetries) {
    uint8_t p = finger.getImage();
    if (p == FINGERPRINT_OK) {

      p = finger.image2Tz();
      if (p == FINGERPRINT_OK) {

        p = finger.fingerSearch();
        if (p == FINGERPRINT_OK) {
          Serial.print("fp_detect_ok ");
          Serial.println(finger.fingerID);
          return;
        } else if (p == FINGERPRINT_PACKETRECIEVEERR) {
          Serial.println("fp_detect_fail");
          return;
        } else if (p == FINGERPRINT_NOTFOUND) {
          retryCount++;
        } else {
          Serial.println("fp_detect_fail");
          return;
        }
      } else {
        retryCount++;
      }
    } else {
      retryCount++;
    }
    delay(200); // Add a short delay to avoid flooding the sensor with requests
  }

  Serial.println("fp_detect_fail");
}
