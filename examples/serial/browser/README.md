<p align="center">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://github.com/jgphilpott/polyslice/blob/main/imgs/favicon/white.png">
        <img width="123" height="123" src="https://github.com/jgphilpott/polyslice/blob/main/imgs/favicon/black.png">
    </picture>
</p>

# About

The [Web G-code Sender](https://jgphilpott.github.io/polyslice/examples/serial/browser/sender.html) is a mini app that was built as a development aid for [Polyslice](https://github.com/jgphilpott/polyslice), an FDM slicer designed specifically for [three.js](https://github.com/mrdoob/three.js). The app can connect to a 3D printer via a serial port (USB or Bluetooth) to send G-codes and read the printers response data.

Various [other apps](https://github.com/kliment/Printrun) exist that do the same thing but [I](https://github.com/jgphilpott) wanted something browser based for a more seamless user experience, no download or installation should be necessary. Furthermore, I wanted more *raw* access to the API so that I could integrate this functionality into my own applications and not be limited by another developers GUI.

I failed to find what I was looking for online so I built this app as a result. If you also want to integrate this functionality into your own applications then take a look at [this thread](https://3dprinting.stackexchange.com/questions/23119/can-i-use-web-serial-api-to-send-g-code-to-my-ender-5-pro) I created on the [3D Printing Stack Exchange](https://3dprinting.stackexchange.com). **That thread, along with the source code in this repo, should help you connect to a printer and write/read data with only a few lines of JavaScript.**

# Contents

- [About](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#about)
- [Contents](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#contents)
- [Features](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#features)
  - [Help](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#help)
  - [Connect/Disconnect](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#connectdisconnect)
  - [Upload](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#upload)
  - [Reset](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#reset)
- [Settings](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#settings)
  - [Connection Settings](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#connection-settings)
    - [Baud Rate](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#baud-rate)
    - [Buffer Size](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#buffer-size)
    - [Data Bits](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#data-bits)
    - [Stop Bits](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#stop-bits)
    - [Flow Control](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#flow-control)
    - [Parity](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#parity)
  - [Style Settings](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#style-settings)
    - [Timestamps](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#timestamps)
    - [Colors](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#colors)
    - [Emojis](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#emojis)
- [Resources](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md#resources)

# Features

In the very top left corner you should see four buttons. These buttons provide an interface for the apps core functions, see more detail about each below.

### Help

This button simply links users to [this README file](https://github.com/jgphilpott/polyslice/blob/main/examples/serial/browser/README.md) for more information about the app.

### Connect/Disconnect

This button can create or end the serial connection with your printer. When connecting you will be prompted to select your printer from a list of available devices.

### Upload

This button gives you the option to upload a full `.gcode` file rather than typing/pasting commands into the prompt at the bottom of the screen. However, this feature may not work with all firmware types. It was primarily developed to work with [Marlin](https://github.com/MarlinFirmware/Marlin) firmware, it may work with other firmware types also but that cannot be guaranteed.

### Reset

This button gives you the option to reset the app to its default state. It will clear your logs and restore all settings to their default values.

# Settings

The app uses [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) to create the connection with the [serial port](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort) and write/read data. This is currently the only method that I am aware of to create such a connection, the only drawback is that it is not supported by all browsers yet, you can view a compatibility matrix [here](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API#browser_compatibility).

### Connection Settings

The [connection method](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open) takes six parameters (although only one is required), you can read more about them below:

#### [Baud Rate](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#baudrate)

This is the **only mandatory argument** when making the connection. It should be a positive, non-zero integer indicating the baud rate at which serial communication should be established. I have found that `115200` is a good default for 3D printers. However, if you are having a problem connecting try looking up the recommended baud rate for your printer/firmware version.

#### [Buffer Size](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#buffersize)

An unsigned long integer indicating the size of the read and write buffers that are to be established. If not passed, defaults to `255` ... or `1024` in this application.

#### [Data Bits](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#databits)

An integer value of `7` or `8` indicating the number of data bits per frame. If not passed, defaults to `8`.

#### [Stop Bits](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#stopbits)

An integer value of `1` or `2` indicating the number of stop bits at the end of the frame. If not passed, defaults to `1`.

#### [Flow Control](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#flowcontrol)

The flow control type, either `'none'` or `'hardware'`. The default value is `'none'`.

#### [Parity](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#parity)

The parity mode, either `'none'`, `'even'`, or `'odd'`. The default value is `'none'`.

### Style Settings

In addition to the connection settings you can also customize your UI with the following style settings:

#### Timestamps

A simple checkbox to toggle on/off the use of timestamps in the logs.

#### Colors

A simple checkbox to toggle on/off the use of colors in the logs.

#### Emojis

A simple checkbox to toggle on/off the use of emojis in the logs.

# Resources

If you are new to [G-code](https://en.wikipedia.org/wiki/G-code) then here are few helpful resources to get you started:

**[Introduction To Marlin Commands and G-Codes](https://www.youtube.com/playlist?list=PLyYZUiBHD1QjbgqMVvEBIMxTS8LQdyywZ)** - This is a helpful six video YouTube tutorial to teach you the basics of G-code.

**[Marlin Documentation](https://marlinfw.org/docs/gcode/G000-G001.html)** - This is a useful reference material for beginners and advanced users alike!