
cmake_minimum_required(VERSION 3.20)

find_package(Zephyr REQUIRED)
project(spectro_mcu)

target_sources(app PRIVATE src/main.c)
