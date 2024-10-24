<p align="center">
    <img width="333" height="333" src="https://raw.githubusercontent.com/jgphilpott/polyslice/refs/heads/main/imgs/favicon/black.png">
</p>

# About

Polyslice is an [FDM](https://en.wikipedia.org/wiki/Fused_filament_fabrication) [slicer](https://en.wikipedia.org/wiki/Slicer_(3D_printing)) designed specifically for [three.js](https://github.com/mrdoob/three.js) and inspired by the discussion on [this three.js issue](https://github.com/mrdoob/three.js/issues/17981). The idea is to be able to go straight from a mesh in a three.js scene to a machine usable [G-code](https://en.wikipedia.org/wiki/G-code), thus eliminating the need for intermediary file formats and 3rd party slicing software.

Currently, if you want to print something you have designed in three.js you need to first export it to an [STL](https://en.wikipedia.org/wiki/STL_(file_format)) or [OBJ](https://en.wikipedia.org/wiki/Wavefront_.obj_file) file, slice that file with another software like [Cura](https://github.com/Ultimaker/Cura) and then transfer the resulting [G-code](https://en.wikipedia.org/wiki/G-code) to your 3D printer. Ideally, you should be able to use a three.js plugin to slice the meshes in your scene and send the G-code directly to your 3D printer via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API).

With this approach the design, slicing and printing process becomes much more seamless! No download or installation is required, the entire process can happen without leaving a web browser. Intermediary file formats become obsolete and G-codes become invisible for the average user.

# Tools

To assist in designing and testing this slicer I developed a simple mini app called '[Web G-code Sender](https://jgphilpott.github.io/polyslice/serial/browser/sender.html)' for experimenting with G-code and writing/reading printer data via [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Serial_API). I recommend taking a look at it if you want to learn G-code or how to remotely control a 3D printer from a web browser.
