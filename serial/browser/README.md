<p align="center">
    <picture>
        <source media="(prefers-color-scheme: dark)" srcset="https://github.com/jgphilpott/polyslice/blob/main/imgs/favicon/white.png">
        <img width="123" height="123" src="https://github.com/jgphilpott/polyslice/blob/main/imgs/favicon/black.png">
    </picture>
</p>

# About

The [Web G-code Sender](https://jgphilpott.github.io/polyslice/serial/browser/sender.html) is a **mini app** that was built as a development aid for [Polyslice](https://github.com/jgphilpott/polyslice), an FDM slicer designed specifically for [three.js](https://github.com/mrdoob/three.js). The app can connect to a 3D printer via a serial port (USB or Bluetooth) to send individual G-codes and read the printers response data.

Various [other apps](https://github.com/kliment/Printrun) exist that do the same thing but [I](https://github.com/jgphilpott) wanted something browser based for a more seamless user experience, no download or installation should be necessary. Furthermore, I wanted more *raw* access to the API so that I could integrate this functionality into my own applications and not be limited by another developers GUI.

I failed to find what I was looking for online so I built this app as a result. If you also want to integrate this functionality into your own applications then take a look at [this thread](https://3dprinting.stackexchange.com/questions/23119/can-i-use-web-serial-api-to-send-g-code-to-my-ender-5-pro) I created on the [3D Printing Stack Exchange](https://3dprinting.stackexchange.com). **That thread, along with the source code in this repo, should help you connect to a printer and write/read data with only a few lines of JavaScript.**

# Settings

The app uses [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API) to create the connection with the [serial port](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort) and write/read data. This is currently the only method that I am aware of to create such a connection, the only drawback is that it is not supported by all browsers yet, you can view a compatibility matrix [here](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API#browser_compatibility).

The [connection method](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open) takes six parameters (although only one is required), you can read more about them below:

### [Baud Rate](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#baudrate)

This is the **only mandatory argument** when making the connection. It should be a positive, non-zero integer indicating the baud rate at which serial communication should be established. I have found that `115200` is a good default for 3D printers. However, if you are having a problem connecting try looking up the recommended baud rate for your printer/firmware version.

### [Buffer Size](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#buffersize)

An unsigned long integer indicating the size of the read and write buffers that are to be established. If not passed, defaults to `255` ... or `1024` in this application.

### [Data Bits](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#databits)

An integer value of `7` or `8` indicating the number of data bits per frame. If not passed, defaults to `8`.

### [Stop Bits](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#stopbits)

An integer value of `1` or `2` indicating the number of stop bits at the end of the frame. If not passed, defaults to `1`.

### [Flow Control](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#flowcontrol)

The flow control type, either `'none'` or `'hardware'`. The default value is `'none'`.

### [Parity](https://developer.mozilla.org/en-US/docs/Web/API/SerialPort/open#parity)

The parity mode, either `'none'`, `'even'`, or `'odd'`. The default value is `'none'`.

# Resources

If you are new to [G-code](https://en.wikipedia.org/wiki/G-code) then here are few helpful resources to get you started:

**[Introduction To Marlin Commands and G-Codes](https://www.youtube.com/playlist?list=PLyYZUiBHD1QjbgqMVvEBIMxTS8LQdyywZ)** - This is a helpful six video YouTube tutorial to teach you the basics of G-code.

**[Marlin Documentation](https://marlinfw.org/docs/gcode/G000-G001.html)** - This is a useful reference material for beginners and advanced users alike!