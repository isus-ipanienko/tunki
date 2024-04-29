cmake_minimum_required(VERSION 3.20)

set(CMAKE_BUILD_TYPE Release)
set(CMAKE_C_COMPILER "clang")
set(CMAKE_C_STANDARD 23)
set(CMAKE_CXX_COMPILER "clang++")
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -Wpedantic\
 -Wno-c99-extensions -Wno-c99-designator -Wno-unused-parameter")

project(tunki
    VERSION
        0.0.1
    DESCRIPTION
        "A learning experience in emulation."
    LANGUAGES
        C CXX
)

add_executable(${PROJECT_NAME} 
    src/main.cpp
    )

target_include_directories(${PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
    )
