FROM alpine:3.19 AS builder

RUN apk add --no-cache build-base cmake pkgconf mosquitto-dev

WORKDIR /app
COPY . .

RUN mkdir build && cd build && cmake .. && make

FROM alpine:3.19
RUN apk add --no-cache mosquitto-dev
WORKDIR /app
COPY --from=builder /app/build/iot_sim .

ENV MQTT_HOST=mosquitto
CMD ["./iot_sim"]
