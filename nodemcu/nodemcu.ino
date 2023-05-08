#include <ESP8266WiFi.h>
#include <WiFiClientSecure.h>
#include <MQTT.h>
#include <time.h>
#include <string.h>

#include "secrets.h"			// в этом файле задать login & password WiFi, MQTT password, SSL root certificate 
#include "secret_ids.h"			// файл созданный терраформом с ID для датчика
#include "DHT22_Sensor.h"

BearSSL::WiFiClientSecure net;
MQTTClient client;

unsigned long lastMillis = 0;
time_t now;

char buff[100], MQTT_TOPIC[80] ;



void mqtt_connect()
{
    Serial.print("checking wifi...");
    while (WiFi.status() != WL_CONNECTED)
    {
        Serial.print(".");
        delay(1000);
    }

    Serial.print("\nMQTT connecting ");
//    while (!client.connect(MQTT_USER, MQTT_USER, MQTT_PASS))
    {
        Serial.print(".");
        delay(1000);
    }

    Serial.println("connected!");

//    client.subscribe(MQTT_TOPIC);
}

void messageReceived(String &topic, String &payload)
{
    Serial.println("Recieved [" + topic + "]: " + payload);
}

void setup()
{
    Serial.begin(115200);
    dht.begin();                                                    // ========= Initialize & Start DHT sensor ==============================
    Serial.println(); Serial.println();
    Serial.print("WiFi. Attempting to connect to SSID: ");
    Serial.print(ssid);
//    WiFi.hostname(MQTT_USER);
    WiFi.mode(WIFI_STA);
    WiFi.begin(ssid, pass);                                        // connect to WiFi
    while (WiFi.status() != WL_CONNECTED)                          // waiting for connection loop
    {
        Serial.print(".");
        delay(1000);
    }
    Serial.println("== >>> connected to WiFi <<<==");

    Serial.print("Setting time using SNTP");
    configTime(-5 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    now = time(nullptr);
    while (now < 1666666666)
    {
        delay(500);
        Serial.print(".");
        now = time(nullptr);
    }
    Serial.println("done!");
    struct tm timeinfo;
    gmtime_r(&now, &timeinfo);
    Serial.print("Current time: ");
    Serial.print(asctime(&timeinfo));
// ============================================== SSL MQTT ======================================================
//  sprintf(MQTT_TOPIC, "$devices/%s/events", MQTT_USER) ; 
  Serial.print("TOPIC >>>>> ") ;
  Serial.println(MQTT_TOPIC) ;
	BearSSL::X509List cert(digicert);
	net.setTrustAnchors(&cert);
  client.setKeepAlive(240); 
  client.begin(MQTT_HOST, MQTT_PORT, net);
  client.onMessage(messageReceived);
  mqtt_connect();
// ============================================== SSL ======================================================
}

void loop()
{
    now = time(nullptr);
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.print("Checking wifi");
        while (WiFi.waitForConnectResult() != WL_CONNECTED)
        {
            WiFi.begin(ssid, pass);
            Serial.print(".");
            delay(10);
        }
        Serial.println("connected");
    }
    else
    {
        if (!client.connected())
        {
            mqtt_connect();
        }
        else
        {
            client.loop();
        }
    }
        lastMillis = millis();
        DHT_datas ht ;
        ht = get_Humidity_Temperature() ;
        sprintf(buff, "abc;%lu;%.2f;%.2f", now, ht.temper, ht.humid ) ; 			// abc - любой префикс, без него глючит sprintf если в начале формируемой строки число
        client.publish(MQTT_TOPIC, buff, false, 1);								// собственно отсылка данных в облако
        Serial.println(buff);
        delay(15*1000);					// 15 секунд задержка - МЕНЯЙТЕ
}
