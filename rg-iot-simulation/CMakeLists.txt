cmake_minimum_required(VERSION 3.10)
project(RGIotSimulation C)

set(CMAKE_C_STANDARD 99)

# Find Mosquitto library using pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(MOSQUITTO REQUIRED libmosquitto)

include_directories(${MOSQUITTO_INCLUDE_DIRS})
link_directories(${MOSQUITTO_LIBRARY_DIRS})

add_executable(iot_sim src/main.c)
target_link_libraries(iot_sim ${MOSQUITTO_LIBRARIES})
