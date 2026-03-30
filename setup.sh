#!/bin/bash
echo "=== Instaliram Java ==="
sudo rm -f /etc/apt/sources.list.d/yarn.list
sudo apt-get update -qq && sudo apt-get install -y -qq openjdk-17-jdk-headless

echo "=== Instaliram Flutter ==="
git clone https://github.com/flutter/flutter.git -b stable ~/flutter --depth 1

echo "=== Instaliram Android SDK ==="
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools
curl -o tools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q tools.zip
mv cmdline-tools latest
yes | ~/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/android-sdk "platforms;android-34" "build-tools;34.0.0" "platform-tools"

echo "=== Podesavam environment ==="
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$HOME/flutter/bin:$HOME/android-sdk/cmdline-tools/latest/bin:$HOME/android-sdk/platform-tools:$PATH
export ANDROID_HOME=~/android-sdk
export CHROME_EXECUTABLE=/usr/bin/chromium-browser

cd /workspaces/cash_rheo
flutter pub get

echo "=== GOTOVO! ==="
echo "Pokreni ovo pre buildovanja:"
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 && export PATH=$JAVA_HOME/bin:$HOME/flutter/bin:$HOME/android-sdk/cmdline-tools/latest/bin:$HOME/android-sdk/platform-tools:$PATH && export ANDROID_HOME=~/android-sdk && export CHROME_EXECUTABLE=/usr/bin/chromium-browser'
