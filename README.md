# WhatAMess
**Make your Messages app as clean (or messy) as you want.**

_Designed with iOS 16 in mind, tested on NathanLR on iOS 17._

## Description

For far too long has the Messages app on modern jailbreaks been boring! With WhatAMess, customize (nearly) every color possible across the Messages app. Tailor your app to match your device theme, set your background to what you value most, or just get rid of those green bubbles.

## Features

### General/App-Wide
- Change App-Wide Tint Color
- Modern NavBar: A navigation bar that blurs content closer to the top of the screen. (Inspired by Messages on iOS 26. Togglable)
- Stock NavBar Tinting
- Cell Tinting

### Conversation List View
- Custom Background Color (Pinned and Cells separately)
- Custom Background Image
- Background Image Blur
- Custom Conversation Title, Preview, and Time/Date Color
- Pinned Conversation Preview Bubble + Text Color
- Custom NavBar Title String + Color
- Hide Separators
- Hide Search Background
- Hide Pinned Conversation Glow

### Chat View
- Custom Background Color
- Custom Background Image
- Background Image Blur
- Custom SMS, iMessage, and Recieved Bubble Colors
- Custom SMS, iMessage, and Recieved Bubble Text Colors
- Custom Timestamp Colors
- Modern Message Bar: A similar principle to Modern NavBar. Creates a blur behind the message bar that blurs content closer to the bottom of the screen.
- Stock Message Bar Tint Color
- Message Input Field Background Color
- Message Input Field Background Blur
- Message Input Field Placeholder Text + Text Color
- Input Text Color
- Camera/App Drawer Tint
- Link Bubble Background + Text Color

## Compatability
WhatAMess is compatible with devices running a _rootless_ jailbreak on iOS 16. ***Rootful support coming soon!***
The tweak was also tested on (and has a few specific hooks for) iOS 17, NathanLR, on a 2018 11" iPad Pro. That was the only other "jailbroken" device I had for testing. Technically speaking it should be mostly fine on iOS 17/NathanLR.

Compatability with the following is unknown/uncertain as I don't have the devices to test it but, considering the tweak injects into Messages only, it should be fine. If the tweak works, confirmed, on any of these, _please let me know_:
- Seratonin
- Roothide / Bootstrap
- Palera1n

## Known Issues
The following are issues I hope to address in future versions in the coming months.
Please keep in mind this is my _first tweak_ and I'm still getting familiar with the process. Things may take time. :)
- Replies, their "line" indicators, and their own view is currently broken/unmodified.
- Some text such as "2 Replies" may switch back to the system tint color occasionally on iOS 17.
- "Notify Anyway" text shown after sending a message to another user in DND mode may revert back to system color when leaving and reopening window.
- Link Bubbles in Pinned Message Previews sometimes break, displaying a square instead of a bubble.
- Contact "Info" view on iOS 17 is slightly broken.
