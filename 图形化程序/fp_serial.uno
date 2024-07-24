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
  while (!Serial)
    ;  // For Yun/Leo/Micro/Zero/...
  delay(100);

  // set the data rate for the sensor serial port
  finger.begin(57600);

  if (finger.verifyPassword()) {
    Serial.println("fp_init_ok");
  } else {
    Serial.println("Did not find fingerprint sensor :(");
    while (1)
      ;
  }

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
    } else if (command.equals("fp_empty")) {
      finger.emptyDatabase();
      delay(100);
      Serial.print("fp_empty");
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
  if (getFingerprintEnroll(id) == FINGERPRINT_OK) {
    enrolling = false;
  }
}

uint8_t getFingerprintEnroll(uint8_t id) {
  int p = -1;
  Serial.println("fp_enroll_press");
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    switch (p) {
      case FINGERPRINT_OK:
        break;
      case FINGERPRINT_NOFINGER:
        break;
      case FINGERPRINT_PACKETRECIEVEERR:
        Serial.println("Communication error");
        break;
      case FINGERPRINT_IMAGEFAIL:
        Serial.println("Imaging error");
        break;
      default:
        Serial.println("Unknown error");
        break;
    }
  }

  p = finger.image2Tz(1);
  switch (p) {
    case FINGERPRINT_OK:
      Serial.println("Image converted");
      break;
    case FINGERPRINT_IMAGEMESS:
      Serial.println("Image too messy");
      return p;
    case FINGERPRINT_PACKETRECIEVEERR:
      Serial.println("Communication error");
      return p;
    case FINGERPRINT_FEATUREFAIL:
      Serial.println("Could not find fingerprint features");
      return p;
    case FINGERPRINT_INVALIDIMAGE:
      Serial.println("Could not find fingerprint features");
      return p;
    default:
      Serial.println("Unknown error");
      return p;
  }

  delay(2000);
  p = 0;
  Serial.println("fp_enroll_remove");
  while (p != FINGERPRINT_NOFINGER) {
    p = finger.getImage();
  }
  Serial.println("fp_enroll_press_again");
  while (p != FINGERPRINT_OK) {
    p = finger.getImage();
    switch (p) {
      case FINGERPRINT_OK:
        Serial.println("Image taken");
        break;
      case FINGERPRINT_NOFINGER:
        break;
      case FINGERPRINT_PACKETRECIEVEERR:
        Serial.println("Communication error");
        break;
      case FINGERPRINT_IMAGEFAIL:
        Serial.println("Imaging error");
        break;
      default:
        Serial.println("Unknown error");
        break;
    }
  }

  p = finger.image2Tz(2);
  switch (p) {
    case FINGERPRINT_OK:
      break;
    case FINGERPRINT_IMAGEMESS:
      Serial.println("Image too messy");
      return p;
    case FINGERPRINT_PACKETRECIEVEERR:
      Serial.println("Communication error");
      return p;
    case FINGERPRINT_FEATUREFAIL:
      Serial.println("Could not find fingerprint features");
      return p;
    case FINGERPRINT_INVALIDIMAGE:
      Serial.println("Could not find fingerprint features");
      return p;
    default:
      Serial.println("Unknown error");
      return p;
  }

  p = finger.createModel();
  if (p == FINGERPRINT_OK) {
  } else if (p == FINGERPRINT_PACKETRECIEVEERR) {
    Serial.println("Communication error");
    return p;
  } else if (p == FINGERPRINT_ENROLLMISMATCH) {
    Serial.println("Fingerprints did not match");
    return p;
  } else {
    Serial.println("Unknown error");
    return p;
  }

  p = finger.storeModel(id);
  if (p == FINGERPRINT_OK) {
    Serial.println("fp_enroll_ok");
  } else if (p == FINGERPRINT_PACKETRECIEVEERR) {
    Serial.println("Communication error");
    return p;
  } else if (p == FINGERPRINT_BADLOCATION) {
    Serial.println("Could not store in that location");
    return p;
  } else if (p == FINGERPRINT_FLASHERR) {
    Serial.println("Error writing to flash");
    return p;
  } else {
    Serial.println("Unknown error");
    return p;
  }

  return true;
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
    delay(200);  // Add a short delay to avoid flooding the sensor with requests
  }

  Serial.println("fp_detect_fail");
}
