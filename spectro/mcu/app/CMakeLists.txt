
cmake_minimum_required(VERSION 3.20)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

#list(APPEND ZEPHYR_EXTRA_MODULES ${CMAKE_CURRENT_SOURCE_DIR}/..)

find_package(Zephyr REQUIRED)
project(spectro-app)

target_sources(app PRIVATE src/main.c)
