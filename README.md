# Screen Time
A totally (not) original idea, designed to increase productivity and help prevent procrastination.

## OS Support
App designed for macOS. Compiling it differently might work on Linux distributions (as POSIX libraries are used) but is not not tested in any way, shape, or form. Also can Swift/SwiftUI even compile on Linux

## Usage
The user sets a timer and a list of allowed applications. Then, they start the focus session, and the application (using low level direct control through C) prevents the user from being on disallowed applications.

The app then enforces those rules by killing user app processes that are not allowed.

## Installation
To install, simply download the `Screen Time.zip` file, extract it, and move the resulting app into the Applications folder in Finder. Running it for the first time may result in the application being blocked; to solve this, do the following:
1. Open the System Settings app
2. Navigate to Privacy & Security
3. Scroll down to the Security section
4. Find the message stating that the application was blocked, and click "Open Anyway"

## Limitations
The application does not remember the previous settings when the window is closed. Thus, the details need to be re-entered each time the app is opened. However, this can be an upside if the allowed apps for each session are different.

Additionally, this application cannot manage browser tabs or web domains, as that requires their respective APIs which are not implemented.
