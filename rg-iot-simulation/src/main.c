#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <mosquitto.h>

#define BROKER_HOST "mosquitto"
#define BROKER_PORT 1883
#define TOPIC "sensors/hvac/telemetry"

void on_connect(struct mosquitto *mosq, void *obj, int rc) {
    if(rc == 0) {
        printf("Connected to MQTT Broker successfully!\n");
    } else {
        printf("Failed to connect, return code %d\n", rc);
    }
}

int main() {
    struct mosquitto *mosq;
    int rc;

    // Initialize mosquitto library
    mosquitto_lib_init();

    // Create a new client instance
    mosq = mosquitto_new("hvac_sensor_sim_1", true, NULL);
    if(!mosq) {
        fprintf(stderr, "Error: Out of memory.\n");
        return 1;
    }

    mosquitto_connect_callback_set(mosq, on_connect);

    const char *host = getenv("MQTT_HOST") ? getenv("MQTT_HOST") : BROKER_HOST;
    
    // Connect to the MQTT Broker (with retries if the broker is still booting in Docker)
    while(1) {
        rc = mosquitto_connect(mosq, host, BROKER_PORT, 60);
        if(rc == MOSQ_ERR_SUCCESS) {
            break;
        }
        printf("Waiting for broker at %s:%d...\n", host, BROKER_PORT);
        sleep(5);
    }

    // Start network thread
    mosquitto_loop_start(mosq);

    srand(time(NULL));

    // Continuous simulation loop
    while(1) {
        float temp = 20.0 + ((rand() % 100) / 10.0); // Random temp between 20.0 and 30.0
        float humidity = 40.0 + ((rand() % 200) / 10.0); // Random humidity between 40.0 and 60.0

        char payload[256];
        snprintf(payload, sizeof(payload), "{\"asset_id\": \"HVAC-001\", \"temperature\": %.2f, \"humidity\": %.2f}", temp, humidity);

        printf("Publishing telemetry: %s\n", payload);
        
        // Publish to topic with QoS 0
        mosquitto_publish(mosq, NULL, TOPIC, strlen(payload), payload, 0, false);
        
        // Wait 10 seconds before next sensor reading
        sleep(10);
    }

    // Cleanup
    mosquitto_loop_stop(mosq, true);
    mosquitto_destroy(mosq);
    mosquitto_lib_cleanup();

    return 0;
}
