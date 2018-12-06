# A. Project Information

	# a1. Set name of project
		projname=""
		
	# a2. Set input
	#     Accepts: both image and video | Must enter, or project will fail
		input=""

	# a3. Set style
	#     Accepts: only images | Must enter, or project will fail
		style=""
		
	# a4. What is the largest image size you want your GPU to run on at any one time, in pixels?
	#     Accepts: any non-negative integer | Must enter, or project will fail
		constraintsize=""

	# a5. Set export directory, where the processed image/video will be moved to
		exportdir=""

	# a6. Do you want to clean up directories after they are processed, leaving only the stylized image(s)?
	#     Default: N | Accepts: Y/N
		cleanup=""

# B. Parameters for neural_style

	# b1. Weigh the amount of content. Higher numbers mean image more like original.
	#     Default: 5e0
		cweight=""

	# b2. Weigh the amount of style transfer. Higher numbers mean more stylization.
	#     Default: 1e4
		sweight=""

	# b3. Weigh the amount given to the total variation loss. Higher numbers often mean less noisy images.
	#     Default: 1e-3
		tvweight=""

	# b4. How many iterations on the basic, one-tile process? Higher numbers have greater stylization. 
	#     Default: 1000
		maxit=""
		
	# b5. Would you like to blend the waifu2x result with the original input before the upres process? 
	#     If so, what opacity should the (neural-styled) waifu2x result be set to?
	#     Default: 100 | Accepts: 0-100
		input_blend=""
	
	# b6. How many iterations in the multi-tile, upres process (if applicable)?
	#     Default: 100
		maxitupres=""
	
	# b7. By what factor do you want to alter the style image's size?
	#     Default: 1 | Accepts: 0.1 to 10
		style_scale=""

	# b8. Set maximum size of the processed image in pixels.
	#     Default: Leave blank for autodetect.
		size=""
		
	# b9. Do you want to keep the original colors of the input, rather than overlaying the style images colors?
	#     Default: N | Accepts: Y/N
		origcolors=""
	
	# b10. Do you want to match the parameters of the input and the style images? May lead to more cohesive stylization.
	#     Default: N | Accepts: Y/N
		matchparams=""
	
	# b11. Do you want the neural_style script to run verbosely--how many steps completed, loading model weights, etc.?
	#      Default: N | Accepts: Y/N
		verbose=""
	
# C. Parameters for Waifu2x

	# c1. Which model do you want to use? 
	#     Default: UpRGB | Accepts: UpRGB, UpPhoto, RGB, Photo, Y, UpResNet10
		waifu_algo=""
	
	# c2. What noise level do you want to use? Higher numbers look smoother.
	#     Default: 1 | Accepts: 0-3
		waifu_noise=""
	
	# c3. What split size do you want to use?
	#     Default: 128 | Accepts: 64, 100, 128, 240, 256, 384, 432, 480, 512
		waifu_split=""

# D. Parameters for tiling

	# d1. Do you want to skip the basic script step, and just neural-style the tiles of an image?
	#     Default: N | Accepts: Y/N
		skipbasic=""
	
	# d2. How many tiles N do you want in an NxN grid?
	#     Default: Leave blank for autodetect | Accepts: 1-7 (1 meaning no upres process)
		tile_num=""

	# d3. How large do you want the overlap between each tile to be, in pixels, while cropping?
	#     Default: Leave blank for autodetect
		overlap=""
	
# E. Parameters for video (if applicable)

	# e1. How many frames of video would you like to process?
	#     Default: Leave blank to process the whole video.
		end_frame=""
	
	# e2. What framerate would you like?
	#     Default: Leave blank for 24fps.
		framerate=""
		
	# e3. Would you like to trim any frames from the beginning of the video? If so, how many? 
	#     Default: 0 | Accepts: Any non-negative integer (saying "1" removes the first frame, for example)
		remove_frame=""
		
	# e4. Would you like to blend the neural-styled video with the original? Will output both the original video file and the blended video file.
	#     What opacity should the neural_style be set to? 
	#     Default: 1 | Accepts: 0-1
		ns_video_opacity=""
		
################################

# Sanitize backslashes for bash
exportdir="${exportdir//\\//}"
input="${input//\\//}"
style="${style//\\//}"

# Export variables
export projname
export exportdir
export cleanup
export constraintsize

export cweight
export sweight
export tvweight
export maxit
export input_blend
export maxitupres
export style_scale
export size
export origcolors
export matchparams
export verbose

export waifu_algo
export waifu_noise
export waifu_split

export skipbasic
export tile_num
export overlap

export end_frame
export framerate
export remove_frame
export ns_video_opacity

# Run script
chmod +x neural_style.sh
./neural_style.sh $input $style

exit
