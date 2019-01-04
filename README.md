# neuralstyle-tf-masterscript
This is an all-in-one Bash script for use with @cysmith's [neural-style-tf](https://github.com/cysmith/neural-style-tf). I use a modified and extended version of @ProGamerGov's [Neural-Tile](https://github.com/ProGamerGov/Neural-Tile) and a slightly modified version of @larspars' [neural-style-video](https://github.com/larspars/neural-style-video).

### Features

* GUI-like input file (don't have to worry about using a command line)
* Upres support using both tiling (2x2 to 7x7) and Waifu2x
* Between-step option for blending styled image with original before engaging the tiling process
* Input-style parameter (colors, contrast, and brightness) matching option
* Autodetection for most options, allowing for customization or out-of-the-box useage
* Batch building
* Video support with framerate detection

Does not have integrated Deepflow at this time, unfortunately, as I was unable to get it to successfully compile on Windows. If anyone has/can figure it out, though, I'd be very happy to know, and it should be relatively easy to fork the script with Deepflow integration.

### Usage
Open `run_neuralstyle.sh` in a text editor, fill in the required fields, save, then run `run_neuralstyle.sh`.

Make sure neural_style.py and other assets are in the same directory as these scripts.

### Dependencies List
[neural-style-tf](https://github.com/cysmith/neural-style-tf)

[ImageMagick (with legacy components)](https://www.imagemagick.org/script/index.php)

[waifu2x-caffe](https://github.com/lltcggie/waifu2x-caffe)

[ffmpeg](https://ffmpeg.org/) in the system path

If you'd like a guide for getting all this to work on Windows, [check the Wiki entry here](https://github.com/audreyls/neuralstyle-tf-masterscript/wiki/Windows-Specific-Installation-Guide).
