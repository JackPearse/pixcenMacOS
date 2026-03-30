# Low level pixel editor for C64

## Windows

Precompiled binaries for x86 and amd64 can be downloaded from:
http://binarybone.com/pixcen/pixcen.zip
http://binarybone.com/pixcen/pixcen64.zip

The source repository can be found here:
https://github.com/Hammarberg/pixcen/

To build Pixcen I recommend Visual Studio 2015 Community Edition that can be downloaded for free.

## MacOS

This project provides a MacOS port of Pixcen. We use the
original C++ code for reading/writing the file formats.

To compile the MacOS versoin use the XCode IDE from Apple.

This project was built with the older Storyboard-GUI-System
which gives it a deployment target of *MacOS 10.15*.

This means it is backwards compatible down to macOS Catalina.
It might break with XCode-Updates. At the time of writing 
Catalina is still supported. It was tested on MacOS Big Sur
and on MacOS Tahoe 26.4 and XCode Version 26.4.

Congratulations on more than 10 years of operation. This port 
was started in 2020 and was released in 2026. It took a lot of 
work and hasn’t been tested as thoroughly as the Windows version. 
Therefore, it may contain bugs. Use at your own risk. The usability 
has also been slightly adapted for macOS and touchpad operation.

It was fun reading the original code. I promised this project to our 
graphic designer, mgt, back in 2020 so she could use it on her MacBook Air. 
And I had truly underestimated the project. At first glance, this pixel 
editor seems simple. But it’s a real challenge. 

My respect goes to Hammarberg. 

You can download a binary bundle [here](https://github.com/JackPearse/pixcenMacOS/blob/main/pixcen.zip)
See the README.md of the download for instructions. On MacOS the bundle may appear
broken. That is a security issue of the OS. Looke into the README on how to resolve it.
