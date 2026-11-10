cmake_minimum_required(VERSION 3.20)
project(dms_chatgpt_webengine_probe LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick WebEngineQuick)
add_executable(dms-chatgpt-webengine-probe main.cpp)
target_link_libraries(dms-chatgpt-webengine-probe PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::WebEngineQuick)
