# neuralstyle-tf-masterscript
This is an all-in-one Bash script for use with @cysmith's [neural-style-tf](https://github.com/cysmith/neural-style-tf) formulated especially for Windows. Does not have integrated Deepflow at this time, unfortunately, as I was unable to get it to successfully compile. If anyone has/can figure it out, though, I'd be very happy to know!

I use a modified and extended version of @ProGamerGov's [Neural-Tile](https://github.com/ProGamerGov/Neural-Tile) and a slightly modified version of @larspars' [neural-style-video](https://github.com/larspars/neural-style-video).

### Usage
Open `run_neuralstyle.sh` in a text editor, fill in the required fields, save, then run `run_neuralstyle.sh`.

Make sure neural_style.py and other assets are in the same directory as these scripts.

### Dependencies List
[neural-style-tf](https://github.com/cysmith/neural-style-tf)

[ImageMagick (with legacy components)](https://www.imagemagick.org/script/index.php)

[waifu2x-caffe](https://github.com/lltcggie/waifu2x-caffe)

[ffmpeg](https://ffmpeg.org/) in the system path

## Windows-Specific Installation Guide
### 1. Git for Windows
[Git for Windows](https://git-scm.com/download/win) (for Windows users; [Cygwin](https://www.cygwin.com/) also works.)

### 2. CUDA 8.0
[Download CUDA v8.0 here](https://developer.nvidia.com/cuda-80-ga2-download-archive)

Install using the executable, default options should work okay. Will take a while to download and install.

The base installation directory I used is `C:/Program Files`

### 3. CuDNN 6.0
[Download CuDNN here](https://developer.nvidia.com/cudnn)
This requires a NVIDIA account. Make one. After logging in, look at bottom for "Archived cuDNN Releases". Find cuDNN v6.0 (April 27, 2017) for CUDA 8.0. Click "cuDNN 6.0 Library for Windows [7/10]".

Open the cuDNN .zip. Click into the "cuda" folder to see three folders: "lib", "include", and "bin". Drag these folders into the `C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v8.0` folder and merge them.

### 4. Python 3.5
[Get Python 3.5 here](https://www.python.org/downloads/release/python-352/)

Scroll down and click "Windows x86-64 executable installer" and download, then install via the executable. Make sure Python is added to the system path.

### 5. Python Packages
Download these packages. For 64-bit Windows, you want the cp35-cp35m-win_amd64.whl files.

[NumPy+MKL](https://www.lfd.uci.edu/~gohlke/pythonlibs/#numpy)

[Scipy](https://www.lfd.uci.edu/~gohlke/pythonlibs/#scipy)

[OpenCV](https://www.lfd.uci.edu/~gohlke/pythonlibs/#opencv)

Move the downloaded packages to some directory (for example, `C:/python`)

Open Git for Windows, and type:

`cd C:/python`

`pip3 install numpy-1.14.6+mkl-cp35-cp35m-win_amd64`

`pip3 install opencv_python-3.4.3+contrib-cp35-cp35m-win_amd64`

`pip3 install scipy-1.1.0-cp35-cp35m-win_amd64`

Then close down the command line and reopen it, before typing:

`pip3 install --upgrade tensorflow-gpu`

Now, test the imports to make sure everything is loading correctly. Type:

`python`

`import tensorflow as tf`

`import numpy as np`

`import scipy.io`

`import argparse`

`import struct`

`import errno`

`import time`

`import cv2`

`import os`

If there are any issues, you'll know what's causing it. 

If you can't import tensorflow, or it doesn't seem to work with CUDA, try downgrading to tensorflow 1.4:
`pip3 install --upgrade --ignore-installed tensorflow-gpu==1.4`

`pip3 uninstall numpy`

`cd C:/python`

`pip3 install numpy-1.14.6+mkl-cp35-cp35m-win_amd64.whl`

### 6. Neural Style
[Download neural-style-tf](https://github.com/cysmith/neural-style-tf)

Extract the contents of the zip somewhere, like `C:/python/ns`

Now download the model: [VGG-19](http://www.vlfeat.org/matconvnet/models/imagenet-vgg-verydeep-19.mat)

Move the model to the neural-style install directory (again, like `C:/python/ns`)

### 7. ImageMagick, waifu2x, ffmpeg
Download all three from the links in the Dependencies section above. 

**ImageMagick**: Make sure legacy components are installed

**Waifu2x**: Should work out of the box

**ffmpeg**: Make sure ffmpeg is above ImageMagick in the system path.

### 8. Modifying the system path
If you're not familiar with editing the path, I don't blame you, because Windows handles it awfully.

Thankfully there's a third-party GUI app for that: [Windows Path Editor by rix0rrr](https://rix0rrr.github.io/WindowsPathEditor/)

Just enter in the directories you need in the path and drag and drop to order:

`\...\NVIDIA GPU Computing Toolkit\CUDA\v8.0`

`\...\Python35\`

`\...\ffmpeg\bin`

`\...\ImageMagick\`

`\...\waifu2x-caffe\`

Then just use the supplied .sh scripts.
