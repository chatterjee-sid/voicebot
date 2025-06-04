# Voice-controlled Driving Robot with LLM Integration

## About
This is a project built under the course CS232, Artificial Intelligence, SVNIT Surat from March to April 2025.

This particular repository contains the files used to create the Application Interface to run the project. In other words, this is what connects you to our command translator and ultimately to the robot.

## How to use
In simple terms, this is how you can use this project.
1. Extract [VoiceBot.zip](https://github.com/chatterjee-sid/voicebot/blob/main/VoiceBot.zip) and run voicebot.exe on your computer (should work in a Windows environment)
2. Make sure that your PC hotspot name and password matches what's coded in ESP32.
3. Once the application opens, click on the wifi button at bottom right corner, and click on scan devices.
4. Click on the ESP32 option when it is shown on the screen. Make sure that enough power is being provided to ESP32. You will need atleast 10-11 V of potential difference in your battery source.
4. Once you ensure that the ESP32 is connected, click on the microphone button at the centre.
4. When the screen changes and a stopwatch starts, record your command. Make sure that your PC has a working microphone.
5. Once you are done giving your command, click on the "Stop recording" button.
6. Now wait for about 10-15 seconds.
7. After a few seconds you will receive a feedback (Forward, Backward, Left, Right, No operation), which matches your command. A command will be sent to the ESP32 accordingly, and your car shall move as per your command.

Approximately, 8 out of every 10 commands you give will be reflected correctly

## Hardware used
- ESP32
- DC Motors
- L298N Motor Driver
- Chassis
- Wheels
- Electricity Supply (Approx. 12V DC)

## Tech-stack used
- Flutter/Dart
- Pytorch
- Embedded C (ESP32 Programming)

## Everything Else About This Project
You can find a [PPT](https://github.com/chatterjee-sid/voicebot/blob/main/presentation.pptx) regarding our project in this repository. Here is the [added explanation](https://youtu.be/wJW6Bu-QPoQ).

## Members behind the scenes
- [Naishadh Rana (U23CS014)](https://github.com/Zenith1009)
- [Nikhil Chhasiya (U23CS022)](https://github.com/NIKHIL-07-CYBER)
- [Parth Gandhi (U23CS024)](https://github.com/IAMonlyParthGandhi)
- [Siddhartha Chatterjee (U23CS028)](https://github.com/chatterjee-sid)
- [Divyansh Vijay (U23CS080)](https://github.com/Divyansh2992)
