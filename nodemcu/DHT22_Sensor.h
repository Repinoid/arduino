// DHT Temperature & Humidity Sensor
// Unified Sensor Library Example
// Written by Tony DiCola for Adafruit Industries
// Released under an MIT license.

// REQUIRES the following Arduino libraries:
// - DHT Sensor Library: https://github.com/adafruit/DHT-sensor-library
// - Adafruit Unified Sensor Lib: https://github.com/adafruit/Adafruit_Sensor

//#include <Adafruit_Sensor.h>
#include <DHT.h>
#include <DHT_U.h>

struct DHT_datas
{
    float temper ;
    float humid ;
};

#define DHTPIN D7     // Digital pin connected to the DHT sensor -------------> пин платы куда датчик подключен
// Feather HUZZAH ESP8266 note: use pins 3, 4, 5, 12, 13 or 14 --
// Pin 15 can work but DHT must be disconnected during program upload.

#define DHTTYPE    DHT22     // DHT 22 (AM2302)
DHT_Unified dht(DHTPIN, DHTTYPE);

void setup_DHT() {
    Serial.begin(115200);
    dht.begin();
}

char DHT_out_string[100] ;

DHT_datas get_Humidity_Temperature() {
    DHT_datas DHT_out ;
    sensors_event_t event;
    String humid, temper ;
    dht.temperature().getEvent(&event); 
    DHT_out.temper  = isnan(event.temperature)        ? 404 :  event.temperature;			// если 404 в значении температуры или влажности - ошибка датчика
    dht.humidity().getEvent(&event); 
    DHT_out.humid   = isnan(event.relative_humidity)  ? 404 :  event.relative_humidity;
    return DHT_out ;
}


