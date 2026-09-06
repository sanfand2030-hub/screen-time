# Screen Time
A totally (not) original idea, designed to increase productivity and help prevent procrastination.

## OS Support
App designed for macOS. Compiling it differently might work on Linux distributions (as POSIX libraries are used) but is not not tested in any way, shape, or form. Also can Swift/SwiftUI even compile on Linux

## Usage
The user sets a timer and a list of allowed applications. Then, they start the focus session, and the application (using low level direct control through C) prevents the user from being on disallowed applications.

The app then enforces those rules by killing user app processes that are not allowed.
