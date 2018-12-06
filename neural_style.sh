#! /bin/bash

check_inputs(){
# Checks inputs from run_neuralstyle.sh

	input=$1
	style=$2

	basedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	
# A. Project Information

	# a1. Detect if there is no $projname
	if [ -z $projname ]; then
		input_name=$(basename $input)
		input_name_noex=${input_name%.*}
		style_name=$(basename $style)
		style_name_noex=${style_name%.*}
		echo "#a1. No project name specified. Setting to '${input_name_noex}-${style_name_noex}'"
		projname="${input_name_noex}-${style_name_noex}"
	fi
	
	# Specify path to master out directory for project
	outdir="$basedir/output/$projname"
	
	# a2. Detect if there is no $input
	if [ -z $input ] || [ ! -f $input ]; then
		echo "#a2. Either no input specified or the input directory has a typo."
		echo "Exiting."
		sleep 5
		exit 1
	fi
	
	# a3. Detect if there is no $style
	if [ -z $style ] || [ ! -f $style ]; then
		echo "#a3. Either no style image(s) were specified or there's a typo."
		echo "Exiting."
		sleep 5
		exit 1
	fi

	# a4. Detect if there is no $constraintsize
	if [ -z $constraintsize ]; then
		echo "#a4. No constraint size specified; please enter one (for example, '512')."
		echo "Exiting."
		sleep 5
		exit 1
	fi
	
	# a5. Detect if there is no $exportdir
	if [ -z $exportdir ]; then
		echo "#a5. No export directory specified."
		echo "Final video/image will be in ${outdir}."
		exportdir="$outdir"
	fi
	
	# a6. Detect if there is no $cleanup
	if [ -z $cleanup ]; then
		echo "#a6. Cleanup not specified. Setting to 'N'."
		cleanup="N"
	fi
	
# B. Parameters for neural_style	

	# b1. Detect if no $cweight
	if [ -z $cweight ]; then
		cweight="5e0"
	fi
	
	#b2. Detect if no $sweight
	if [ -z $sweight ]; then
		sweight="1e4"
	fi	
	
	#b3. Detect if no $tvweight
	if [ -z $tvweight ]; then
		tvweight="1e-3"
	fi	
	
	#b4. Detect if no $maxit
	if [ -z $maxit ]; then
		maxit="1000"
	fi	
	
	#b5. Detect if no $input_blend
	if [ -z $input_blend ]; then
		input_blend="100"
	fi	
	
	#b6. Detect if no $maxitupres
	if [ -z $maxitupres ]; then
		maxitupres="100"
	fi	
	
	#b7. Detect if no $style_scale
	if [ -z $style_scale ]; then
		style_scale="1"
	fi	
	
	#b8. $size autodetection occurs in image_setup() if unspecified
	
	#b9. Detect if no $origcolors
	if [ -z $origcolors ]; then
		origcolors="N"
	fi	

	#b10. Detect if no $matchparams
	if [ -z $matchparams ]; then
		matchparams="N"
	fi
	
	#b11. Detect if no $verbose
	if [ -z $verbose ]; then
		verbose="N"
	fi	
	
# C. Parameters for Waifu2x

	#c1. Detect if no $waifu_algo
	if [ -z $waifu_algo ]; then
		waifu_algo="UpRGB"
	fi
	
	#c2. Detect if no $waifu_noise
	if [ -z $waifu_noise ]; then
		waifu_noise="1"
	fi
	
	#c3. Detect if no $waifu_split
	if [ -z $waifu_split ]; then
		waifu_split=128
	fi
	
# D. Parameters for tiling

	#d1. Detect if no $skipbasic
	if [ -z $skipbasic ]; then
		skipbasic="N"
	fi
	
	#d2. $T detection occurs in image_setup() if undefined
	
	#d3. $overlap detection occurs in image_setup() if undefined
	
# E. Parameters for video (if applicable)

	#e1. Can leave $endframe empty
	
	#e2. Detect if no $framerate
	if [ -z $framerate ]; then
		framerate=24
	fi
	
	#e3. Can leave $remove_frame empty
	
	#e4. Detect if no $ns_video_opacity
	if [ -z $ns_video_opacity ]; then
		ns_video_opacity="1"
	fi
	
	# Move to launch()
	launch $1 $2
}

launch(){
# Detects the proper script to use and starts the session timer

	input=$1
	style=$2
	
	# Create master out directory for project specified in check_inputs()
	mkdir -p $outdir

	# Detect if input is a video or an image
	if [ type $ffmpeg > /dev/null ]; then
		# Split the input into frames
		testdir="$outdir/test"
		mkdir -p $testdir
		ffmpeg -v quiet -i "$1" -vframes "2" "${testdir}/frame_%04d.png"
		
		# Check if there's more than one frame
		if [ -f $testdir/frame_0002.png ]; then
			echo "File detected as video"
			fileformat=video
		else
			echo "File detected as image"
			fileformat=image
		fi
		# Clean up and return to base directory
		rm -r "$testdir"
	else
		echo "Could not find ffmpeg. Assuming file is an image"
		fileformat="image"
	fi
	
	# Start timer
	start=$SECONDS
	
	# Launch video or image script based on $fileformat
	if [ "$fileformat" = "video" ]; then
		video $1 $2
	fi
	
	if [ "$fileformat" = "image" ]; then
		frame="1"
		image_setup $1 $2
	fi
}

video(){
# Neural-styles video files

#A. Defines
	echo "==A. Setting video defines=="
	FFMPEG=ffmpeg
	ffplay=ffplay
	ffprobe=ffprobe

	content_video="$1"
	content_dir=$(dirname "$content_video")
	content_filename=$(basename "$content_video")
	extension="${content_filename##*.}"
	content_filename="${content_filename%.*}"
	content_filename=${content_filename//[%]/x}

	style_image="$2"
	style_dir=$(dirname "$style_image")
	style_filename=$(basename "$style_image")

#B. Save frames of the video as individual image files
	echo "==B. Splitting video into frames=="
	
	# Set up frame directory
	framedir="$outdir/01_rawframes"
	mkdir -p "$framedir"
	
	# Run ffmpeg
	if [ "$skip_basic" = "Y" ] || [ $input_blend -ne 100 ]; then
		if [ ! -z $end_frame ]; then
			ffmpeg -v quiet -i "$1" -r "$framerate" -vframes "$end_frame" -vf scale="$size":-1 "${framedir}/frame_%04d.png"
		else
			ffmpeg -v quiet -i "$1" -r "$framerate" -vf scale="$size":-1 "${framedir}/frame_%04d.png"
			end_frame=$(ls -1 $framedir | wc -l)
		fi
	else
		if [ ! -z $end_frame ]; then
			ffmpeg -v quiet -i "$1" -r "$framerate" -vframes "$end_frame" -vf scale="$constraintsize":-1 "${framedir}/frame_%04d.png"
		else
			ffmpeg -v quiet -i "$1" -r "$framerate" -vf scale="$constraintsize":-1 "${framedir}/frame_%04d.png"
			end_frame=$(ls -1 $framedir | wc -l)
		fi
	fi
	
	# Delete frames if told to by $remove_frame
	if [ ! -z $remove_frame ]; then
		if [ $remove_frame -gt 0 ]; then
			for frame in $(eval echo {1..$remove_frame}); do
				printf -v i "%04d" $frame
				rm "$framedir/frame_${i}.png"
			done
			(( new_first_frame = remove_frame + 1 ))
			for frame in $(eval echo {$new_first_frame..$end_frame}); do
				printf -v i "%04d" $frame
				(( frame_adjust= frame - remove_frame ))
				printf -v j "%04d" $frame_adjust
				mv "$framedir/frame_${i}.png" "$framedir/frame_${j}.png"
			done
			(( end_frame = end_frame - remove_frame ))
		fi
	fi
	
	if [ -z $remove_frame ]; then
		remove_frame="0"
	fi
	
	eval $(ffprobe -v error -of flat=s=_ -select_streams v:0 -show_entries stream=width,height "$1")
	width="${streams_stream_0_width}"
	height="${streams_stream_0_height}"
	
	if [ $width -gt $height ]; then
	  max_size="$width"
	else
	  max_size="$height"
	fi
	
	num_frames=$(find "$framedir" -iname "*.png" | wc -l)
	
	if [ -z $end_frame ]; then
		end_frame="$num_frames"
	fi
	
#C. Neural-style the frames
	echo "==C. Rendering stylized video frames=="
	
	# Set up flow directory
	flowdir=$outdir/02_preflow
	mkdir -p $flowdir

	# Set up neural-style directory
	nsdir=$outdir/04_ns
	mkdir -p $nsdir
	
	# Generate the styled frames
	for frame in $( eval echo {1..$end_frame} ); do
		(( framenext = frame + 1 ))
		printf -v i "%04d" $frame
		printf -v j "%04d" $framenext
		
		if [ ! -s $nsdir/frame_${i}.png ]; then
			echo "=STARTING $frame/$end_frame="
			# Neural Style
			if [ $frame = 1 ]; then
				image_setup $framedir/frame_0001.png $style_image
			else
				image_setup $flowdir/frame_${i}.png $style_image
			fi
			
			# Optical Flow
				echo "Calculating optical flow..."
				python opticalflow.py --input_1 $framedir/frame_${i}.png --input_1_styled $nsdir/frame_${i}.png  --input_2 $framedir/frame_${j}.png --output $flowdir/frame_${j}.png --alpha 0.05
			
			# Clean up processed frame directory if instructed
			if [ "$cleanup" = "Y" ]; then
				rm -r "$processed_dir"
			fi
			
			echo "=FRAME $frame/$end_frame DONE="
			
			# Print estimated time remaining in project
			timer_frame=$(echo $T_square $time_single_run $end_frame $frame | awk "{print ($T_square+1)*$time_single_run*($end_frame-$frame)}")
			timer_frame_san="${timer_frame%.*}"
			time_remaining_est=$(show_time $timer_frame_san)
			echo "Estimated time remaining on video project: $time_remaining_est"
		fi
	done

#D. Create video from output images, export, then exit
	echo "==D. Converting image sequence to video, then exporting to $exportdir=="
	
	# Put the video back together
	ffmpeg -v quiet -i "$nsdir/frame_%04d.png" -r "$framerate" -vf scale="$size":-1 "$outdir/${content_filename}-NS.$extension"
	echo "Neural-style conversion: Complete"
	nvo_awk=$(echo $ns_video_opacity | awk "{print $ns_video_opacity<1}")
	if [ $nvo_awk = 1 ]; then
		frame_begin=$(echo $remove_frame $framerate | awk "{print $remove_frame/$framerate}")
		vid_timestamp=$(echo $end_frame $framerate | awk "{print $end_frame/$framerate}")
		vid_timestamp=$(printf "%.3f\n" $vid_timestamp)
		# Put together the source video from the extracted frames (to preserve the new framerate)
		ffmpeg -v quiet -i "$framedir/frame_%04d.png" -r "$framerate" -t "$vid_timestamp" -vf scale="$size":-1 "$outdir/${content_filename}-original.$extension"
		echo "Original video conversion: Complete"
		# Blend the source video and the NS video together with alpha $ns_video_opacity
		ffmpeg -v quiet                                                                                                           \
		-ss "$frame_begin" -i "$outdir/${content_filename}-original.$extension"                                                   \
		-i "$outdir/${content_filename}-NS.$extension"                                                                            \
		-filter_complex "[1:v]format=rgba,colorchannelmixer=aa=${ns_video_opacity}[fg];[fg]setsar=1[logo];[0][logo]overlay=0:0"   \
		-c:a copy "$outdir/${content_filename}-NS-blended.$extension"
		# Remove input video and print to console
		rm "$outdir/${content_filename}-original.$extension"
		echo "Blended conversion: Complete"
	fi
	
	# Export the video(s)
	cp "$outdir/${content_filename}-NS.$extension" "$exportdir/${projname}-NS.$extension"
	
	if [ "$nvo_awk" = "1" ]; then
		cp "$outdir/${content_filename}-NS-blended.$extension" "$exportdir/${projname}-NS-blended.$extension"
	fi
	
	# Export project settings
	cp "$basedir/run_neuralstyle.sh" "$exportdir/${projname}-settings.txt"
	
	# Clean up directories if specified
	if [ "$cleanup" = "Y" ]; then
		rm -r "$framedir"
	fi
	
	sleep 1
	exit
}

image_setup(){
# Sets up the image/frame defines
	input=$1
	style=$2
	
	# Only perform the following actions for the first frame
	if [ -z $image_been_setup ]; then
		echo "# 0. Setting parameters"
		# Copy style image
		cp "$style" "$outdir/style.png"
		styleopt="$outdir/style.png"
		# Grab content image dimensions
		cw=$(convert $input -format "%w" info:)
		ch=$(convert $input -format "%h" info:)
		
		# Find the larger dimension for the content image, as well as its aspect ratio
		if [ -z $size ]; then
			if [ $cw -ge $ch ]; then
				cm=$cw
				cr=$(echo $cw $ch | awk "{print $cw/$ch}")
			else
				cm=$ch
				cr=$(echo $ch $cw | awk "{print $ch/$cw}")
			fi
		else
			cm=$size
		fi

		# Grab style image dimensions
		sw=$(convert $style -format "%w" info:)
		sh=$(convert $style -format "%h" info:)

		# Find the larger dimension for the style image, as well as its aspect ratio
		if [ $sw -ge $sh ]; then
			sm=$sw
			sr=$(echo $sw $sh | awk "{print $sw/$sh}")
		else
			sm=$sh
			sr=$(echo $sh $sw | awk "{print $sh/$sw}")
		fi
		
		# Autodetect size if $size null
		if [ -z $size ]; then
			if [ $frame = 1 ]; then
				echo "No size specified. Autodetecting..."
			fi
			size=$cm
			if [ $frame = 1 ]; then
				echo "Size detected as "$cw"x"$ch", largest dimension $cm. Size set to $size"
			fi
		fi

		# Grab tiling number
		if [ ! -z $tile_num ]; then
			if [ $tile_num -ge 1 ] && [ $tile_num -le 7 ]; then
				T="$tile_num"
			else
				if [ $frame = 1 ]; then 
					echo "Tile number specified out of bounds (1-7). Autodetecting instead."
				fi
				tile_num=""
			fi
		fi
		
		if [ -z $tile_num ]; then
			if [ $size -ge 1 ] && [ $size -le $constraintsize ]; then
				T=1
			fi
			
			(( constraintsize2 = constraintsize*2 ))
			if [ $size -gt $constraintsize ] && [ $size -le $constraintsize2 ]; then
				T=2
			fi

			(( constraintsize3 = constraintsize*3 ))
			if [ $size -gt $constraintsize2 ] && [ $size -le $constraintsize3 ]; then
				T=3
			fi
			
			(( constraintsize4 = constraintsize*4 ))
			if [ $size -gt $constraintsize3 ] && [ $size -le $constraintsize4 ]; then
				T=4
			fi

			(( constraintsize5 = constraintsize*5 ))
			if [ $size -gt $constraintsize4 ] && [ $size -le $constraintsize5 ]; then
				T=5
			fi
			
			(( constraintsize6 = constraintsize*6 ))
			if [ $size -gt $constraintsize5 ] && [ $size -le $constraintsize6 ]; then
				T=6
			fi
			
			(( constraintsize7 = constraintsize*7 ))
			if [ $size -gt $constraintsize6 ] && [ $size -le $constraintsize7 ]; then
				T=7
			fi

			if [ $size -gt $constraintsize7 ]; then
				if [ $frame = 1 ]; then
					echo "Image size is very large. Neural-style may fail"
				fi
				T=7
			fi
		fi

		T_square=$(echo $T | awk "{print $T*$T-1}")
		
		# Compute dimensions of tiles
		tile_w=$(echo $cw $T | awk "{print $cw/$T}")
		tile_h=$(echo $cw $T | awk "{print $cw/$T}")
		if [ ${tile_w%.*} -ge ${tile_h%.*} ]; then
			tile_m=$tile_w
		else
			tile_m=$tile_h
		fi
		tile_m="${tile_m%.*}"

		# Autodetect $overlap if null
		if [ -z $overlap ] && [ $T -gt 1 ]; then
			if [ $frame = 1 ]; then 
				echo "No tiling overlap specified. Generating a best-guess number..."
			fi
			
			if [ $T = 2 ]; then 
				mod=$(echo $cm | awk "{print 0.05*$cm}")
				overlap="${mod%.*}"
			fi
		
			if [ $T = 3 ]; then 
				mod=$(echo $cm | awk "{print 0.04*$cm}")
				overlap="${mod%.*}"
			fi
			
			if [ $T = 4 ]; then 
				mod=$(echo $cm | awk "{print 0.03*$cm}")
				overlap="${mod%.*}"
			fi		
		
			if [ $T = 5 ]; then
				mod=$(echo $cm | awk "{print 0.02*$cm}")
				overlap="${mod%.*}"
			fi
			
			if [ $T = 6 ]; then
				mod=$(echo $cm | awk "{print 0.0175*$cm}")
				overlap="${mod%.*}"
			fi
		
			if [ $T = 7 ]; then
				mod=$(echo $cm | awk "{print 0.015*$cm}")
				overlap="${mod%.*}"
			fi
			
			if [ $frame = 1 ]; then
				echo "Set overlap to $overlap"
			fi
		fi

		# Generate feathering radius (equal to $overlap here)
		feather="$overlap"
		
		# Style scaling
		# Pretty bad right now, but neuralstyle-tf has no inbuilt style scaling
		if [ ! -z $style_scale ]; then
			ss_lowerbound=$(echo $style_scale | awk "{if ($style_scale < 0.1) print 1; else print 0}")
			ss_upperbound=$(echo $style_scale | awk "{if ($style_scale > 10) print 1; else print 0}")
			ss_sizeup=$(echo $style_scale | awk "{if ($style_scale > 1) print 1; else print 0}")
			ss_sizedown=$(echo $style_scale | awk "{if ($style_scale < 1) print 1; else print 0}")
			ss_tilesize=$(echo $style_scale $constraintsize | awk "{if ($style_scale*$sm*2 > $constraintsize) print 1; else print 0}")
			scale_mod=$(echo $style_scale | awk "{print 100*$style_scale}")
		fi
		
		# Sanitize the input style scale
		if [ $ss_lowerbound = 1 ]; then
			style_scale="0.1"
		fi
		
		if [ $ss_upperbound = 1 ]; then
			style_scale="10"
		fi
		
		# Adjust style image size up
		# Zooms into the center of the image and crops (will lose edge information with this method)
		if [ ! -z $style_scale ] && [ $ss_sizeup = 1 ]; then
			echo "Increasing style image per supplied style scale..."
			convert "$styleopt" -gravity center -resize "$scale_mod"% -crop "$sw"x"$sh"+0+0 "$styleopt"
		fi
		
		# Adjust style image size down
		# Zooms out of the center of the image and generates a 1x1 or 2x2 tiled representation of the input
		if [ ! -z $style_scale ] && [ $ss_sizedown = 1 ]; then
			echo "Decreasing style image per supplied style scale..."
			if [ $ss_tilesize = 1 ]; then
				# Overlay smaller image on top of full-size image
				convert "$styleopt" -geometry "$scale_mod"% "${styleopt%.*}-down.png"
				composite -compose Copy -gravity Center "${styleopt%.*}-down.png" "$styleopt" "$styleopt"
			else
				# Overlay smaller image on 2x2 tile of full-size image
				convert "$styleopt" -geometry "$scale_mod"% "${styleopt%.*}-down.png"
				montage "$styleopt" +clone +clone +clone -resize "$scale_mod"% -mode Concatenate -tile "2x2" "$styleopt"
				composite -compose Copy -gravity Center "${styleopt%.*}-down.png" "$styleopt" "$styleopt"
			fi
			rm "${styleopt%.*}-down.png"
		fi
		
		# Rotate style image to match orientation of content image
		if [ $cw -gt $ch ] && [ $sw -lt $sh ]; then
			mogrify -rotate "90" "$styleopt"
		fi
		
		if [ $ch -gt $cw ] && [ $sh -lt $sw ]; then
			mogrify -rotate "90" "$styleopt"
		fi
		
		# Resize style image to match content image size
		if [ "$skipbasic" = "Y" ]; then
			(( tile_m_true = tile_m + overlap ))
			convert "$styleopt" -geometry "$tile_m_true"x "$styleopt"
		else
			if [ $cw -ge $ch ]; then
				convert "$styleopt" -geometry "$constraintsize"x "$styleopt"
			else
				convert "$styleopt" -geometry x"$constraintsize" "$styleopt"
			fi
		fi
		
		image_been_setup="Y"
	fi
	
	# Match parameters
	if [ "$matchparams" = "Y" ]; then
		echo "Matching style image parameters to input image parameters..."
		match_parameters $input $styleopt $styleopt
		echo "Matching complete."
	fi
	
	# Send to neural_style image script
	if [ "$skipbasic" = "Y" ]; then
		tile $1 $styleopt
	else
		basic $1 $styleopt
	fi
}

basic(){
# Basic script (single-image neural style)

# 1. Directories and defines
	echo "# 1. Setting up directories"
	
	input=$1
	input_file=$(basename $input)
	clean_name="${input_file%.*}"
	
	style=$2
	
	# Create directories
	if [ "$fileformat" = "video" ]; then
		processed_dir=$outdir/03_processedframes/${clean_name}-$frame
		mkdir -p "$processed_dir"
		upresdir=$processed_dir/basic-output
		mkdir -p "$upresdir"
	else
		upresdir=$outdir/basic-output
		mkdir -p "$upresdir"		
	fi	
	
# 2. Grab image data
	echo "# 2. Grabbing image data"
	
	if [ "$fileformat" = "image" ]; then
		cp "$input" "$outdir/input.png"
		inputopt="$outdir/input.png"
	else
		cp "$input" "$processed_dir/input.png"
		inputopt="$processed_dir/input.png"
	fi
	
# 3. Neural-style the image
	echo "# 3. Neural-styling the image"
	
	call_from="script_basic"
		neural_style $inputopt $styleopt $upresdir
	
# 4. Move the result image and (if told to) delete the temporary directory
	if [ $T = 1 ] && [ "$fileformat" = "image" ]; then	
		if [ $size = $constraintsize ]; then
			echo "# 4. Exporting to $exportdir"
			# Export image
			cp "$outdir/${echoname}.png" "$exportdir/$projname-NS.png"
		else	
			# Resize image through Waifu2x
			waifu2x "$upresdir/${echoname}.png" "$upresdir"
			# Move image to export directory
			echo "# 4. Exporting to $exportdir"
			cp "$upresdir/waifu.png" "$outdir/${projname}_final.png"
			rm -r "$upresdir"
			cp "$outdir/${projname}_final.png" "$exportdir/$projname-NS.png"
		fi
		
		# Export project settings
		cp "$basedir/run_neuralstyle.sh" "$exportdir/${projname}-settings.txt"
		
		# Display time elapsed on project and exit
		time_total=$(( SECONDS - start ))
		time_elapsed=$(show_time $time_total)
		echo "Time elapsed: $time_elapsed"
		
		sleep 1
		exit
	fi

	if [ $T = 1 ] && [ "$fileformat" = "video" ]; then
		echo "# 4. Increasing size of image to $size via Waifu2x and moving image to master frame directory"
		# Resize image through Waifu2x
		waifu2x "$upresdir/${echoname}.png" "$upresdir"
		# Move image to master frame directory
		cp "$upresdir/waifu.png" "$nsdir/frame_${i}.png"
	fi
	
	if [ $T -gt 1 ]; then
		echo "# 4. Shifting to tiling up-resolution process"
		# Resize image through Waifu2x
		waifu2x "$upresdir/${echoname}.png" "$upresdir"
		# Move to tile
		tile "$input" "$style"
	fi
}

tile(){
# Tile-and-recombine script

# 5. Directories and defines
	echo "# 5. Setting up directories"
	
	input=$1
	input_file=$(basename $input)
	clean_name="${input_file%.*}"
	
	style=$2
	
	# Create directories
	if [ "$skipbasic" = "Y" ]; then
		if [ "$fileformat" = "video" ]; then
			processed_dir=$outdir/03_processedframes/${clean_name}-$frame
			mkdir -p "$processed_dir"
			upresdir=$processed_dir
			mkdir -p "$upresdir"
		else
			upresdir=$outdir
			mkdir -p "$upresdir"
		fi
	fi
	
# 6. Grab image data
	echo "# 6. Grabbing image data"
	
	# Set input image for tiling process
	if [ "$skipbasic" = "Y" ]; then
		cp "$input" "$upresdir/input.png"
		inputopt="$upresdir/input.png"
	else
		if [ $input_blend -ne 100 ]; then
			cp "$input" "$outdir/input_resize.png"
			if [ "$cw" -ge "$ch" ]; then
				convert "$outdir/input_resize.png" -geometry "$size"x "$outdir/input_resize.png"
			else
				convert "$outdir/input_resize.png" -geometry x"$size" "$outdir/input_resize.png"
			fi
			composite -dissolve "$input_blend" -gravity Center "$upresdir/waifu.png" "$outdir/input_resize.png" -alpha Set "$upresdir/blendedinput.png"
			inputopt="$upresdir/blendedinput.png"
		else
			inputopt="$upresdir/waifu.png"
		fi
	fi
	
	
	if [ "$fileformat" = "image" ]; then
		if [ "$cw" -ge "$ch" ]; then
			convert -geometry "$size"x "$inputopt" "$inputopt"
		else
			convert -geometry x"$size" "$inputopt" "$inputopt"
		fi
	fi
	
# 7. Tile input
	if [ "$fileformat" = "image" ]; then
		base=$outdir/base
	else
		base=$processed_dir/base
	fi
	
	mkdir -p $base
	
	if [ $T = 2 ]; then
		echo "# 7. Tiling the input image into a 2x2 grid"
		convert "$inputopt" -crop 2x2+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	if [ $T = 3 ]; then
		echo "# 7. Tiling the input image into a 3x3 grid"
		convert "$inputopt" -crop 3x3+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	if [ $T = 4 ]; then
		echo "# 7. Tiling the input image into a 4x4 grid"
		convert "$inputopt" -crop 4x4+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	if [ $T = 5 ]; then
		echo "# 7. Tiling the input image into a 5x5 grid"
		convert "$inputopt" -crop 5x5+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	if [ $T = 6 ]; then
		echo "# 7. Tiling the input image into a 6x6 grid"
		convert "$inputopt" -crop 6x6+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	if [ $T = 7 ]; then
		echo "# 7. Tiling the input image into a 7x7 grid"
		convert "$inputopt" -crop 7x7+"$overlap"+"$overlap"@ +repage +adjoin $base/$clean_name"_%d.png"
	fi
	
	# Remove aberrant tiles
	# Strange tiles that sometimes occur due to ImageMagick (typically on 7x7)
	(( T_upperbound = T_square*2 ))
	
	# Because of minor size discrepancies between tiles, I pad by not including $overlap to be safe
	sizecheckreal_w=$(echo $overlap $cw $T | awk "{print $cw/$T}")
	sizecheckreal_w="${sizecheckreal_w%.*}"
	
	sizecheckreal_h=$(echo $overlap $ch $T | awk "{print $ch/$T}")
	sizecheckreal_h="${sizecheckreal_h%.*}"
	
	# Remove aberrant tiles (step 1)
	for tile in $(eval echo {0..$T_upperbound}); do
		if [ -f "$base/${clean_name}_${tile}.png" ]; then
			sizecheck_w=$(convert $base/${clean_name}_${tile}.png -format "%w" info:)
			sizecheck_h=$(convert $base/${clean_name}_${tile}.png -format "%h" info:)
		else
			sizecheck_w=$sizecheckreal_w
			sizecheck_h=$sizecheckreal_h
		fi
		# The aberrant tiles are always too small
		# Checks if at least one dimension is smaller than what it's supposed to be
		if [ $sizecheck_w -lt $sizecheckreal_w ] || [ $sizecheck_h -lt $sizecheckreal_h ]; then
			rm -r "$base/${clean_name}_${tile}.png"
		fi
	done
	
	# Reorder the tiles if there were any resultant deletions from above (step 2)
	for tile in $(eval echo {0..$T_square}); do
		if [ ! -f "$base/${clean_name}_${tile}.png" ]; then
			# Find the next tile that exists
			complete=0
			for check in $(eval echo {$tile..$T_upperbound}); do
				if [ $complete = 0 ] && [ -f "$base/${clean_name}_${check}.png" ]; then
					tileafter=$check
					complete=1
				fi
			done
			# Renumber the tile
			if [ -f "$base/${clean_name}_${tileafter}.png" ]; then
				mv "$base/${clean_name}_${tileafter}.png" "$base/${clean_name}_${tile}.png"
			fi
		fi
	done

	# Remove aberrant tiles numbered higher than $T_square (step 3)
	(( T_square_unr = T_square + 1 ))
		for tile in $(eval echo {$T_square_unr..$T_upperbound}); do
			if [ -f "$base/${clean_name}_${tile}.png" ]; then
				rm -r "$base/${clean_name}_${tile}.png"
			fi
		done
	
	original_tile_w=$(convert $base/${clean_name}_0.png -format "%w" info:)
	original_tile_h=$(convert $base/${clean_name}_0.png -format "%h" info:)
	
	if [ $original_tile_w -ge $original_tile_h ]; then
		original_tile_m="$original_tile_w"
	else
		original_tile_m="$original_tile_h"
	fi
	
	# Resize all tiles to account for rounding errors
	mogrify -path $base -resize "$original_tile_w"x"$original_tile_h"\! $base/*.png
	
	# Output overall setup time
	time_setup=$(( SECONDS - start ))
	
# 8. Neural-style each tile
	echo "# 8. Neural-styling the tiles"
	
	if [ "$fileformat" = "image" ]; then
		tiles_dir=$outdir/tiles
		tileinput_dir=$outdir/base
	else
		tiles_dir=$processed_dir/tiles
		tileinput_dir=$processed_dir/base
	fi
	
	mkdir -p $tiles_dir
	
	call_from="script_tile"
	for tile in $( eval echo {0..$T_square} ); do
		neural_style ${tileinput_dir}/"${clean_name}_"$tile.png $styleopt $tiles_dir
	done
	
	upres_tile_w=$(convert $tiles_dir/$clean_name'_0.png' -format "%w" info:)
	upres_tile_h=$(convert $tiles_dir/$clean_name'_0.png' -format "%h" info:)

	tile_diff_w=$(echo $upres_tile_w $original_tile_w | awk '{print $1/$2}')
	tile_diff_h=$(echo $upres_tile_h $original_tile_h | awk '{print $1/$2}')

	smush_value_w=$(echo $overlap $tile_diff_w | awk '{print $1*$2}')
	smush_value_h=$(echo $overlap $tile_diff_h | awk '{print $1*$2}')

# 9. Feather tiles
	echo "# 9. Feathering tiles"
	
	if [ "$fileformat" = "image" ]; then
		feathered_dir=$outdir/feathered
	else
		feathered_dir=$processed_dir/feathered
	fi
	
	mkdir -p $feathered_dir
	
	for tile in $( eval echo "${clean_name}_"{0..$T_square}.png ); do
		tile_name="${tile%.*}"
		convert $tiles_dir/$tile -alpha set -virtual-pixel transparent -channel A -morphology Distance Euclidean:1,"$feather"\! +channel "$feathered_dir/$tile_name.png"
	done

# 10. Smush the feathered tiles together
	echo "# 10. Combining feathered tiles"
	
	if [ "$fileformat" = "image" ]; then
		smushdir=$outdir
	else
		smushdir=$processed_dir
	fi
	
	if [ $T = 2 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' +smush -$smush_value_w -background transparent \) \
			\( $feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' +smush -$smush_value_w -background transparent \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi
	
	if [ $T = 3 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' $feathered_dir/$clean_name'_2.png' +smush -$smush_value_w -background transparent \) \
			\( $feathered_dir/$clean_name'_3.png' $feathered_dir/$clean_name'_4.png' $feathered_dir/$clean_name'_5.png' +smush -$smush_value_w -background transparent \) \
			\( $feathered_dir/$clean_name'_6.png' $feathered_dir/$clean_name'_7.png' $feathered_dir/$clean_name'_8.png' +smush -$smush_value_w -background transparent \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi
	
	if [ $T = 4 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' $feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' +smush -$smush_value_w -background transparent \)     \
			\( $feathered_dir/$clean_name'_4.png' $feathered_dir/$clean_name'_5.png' $feathered_dir/$clean_name'_6.png' $feathered_dir/$clean_name'_7.png' +smush -$smush_value_w -background transparent \)     \
			\( $feathered_dir/$clean_name'_8.png' $feathered_dir/$clean_name'_9.png' $feathered_dir/$clean_name'_10.png' $feathered_dir/$clean_name'_11.png' +smush -$smush_value_w -background transparent \)   \
			\( $feathered_dir/$clean_name'_12.png' $feathered_dir/$clean_name'_13.png' $feathered_dir/$clean_name'_14.png' $feathered_dir/$clean_name'_15.png' +smush -$smush_value_w -background transparent \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi

	if [ $T = 5 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' $feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' $feathered_dir/$clean_name'_4.png' +smush -$smush_value_w -background transparent \)      \
			\( $feathered_dir/$clean_name'_5.png' $feathered_dir/$clean_name'_6.png' $feathered_dir/$clean_name'_7.png' $feathered_dir/$clean_name'_8.png' $feathered_dir/$clean_name'_9.png' +smush -$smush_value_w -background transparent \)      \
			\( $feathered_dir/$clean_name'_10.png' $feathered_dir/$clean_name'_11.png' $feathered_dir/$clean_name'_12.png' $feathered_dir/$clean_name'_13.png' $feathered_dir/$clean_name'_14.png' +smush -$smush_value_w -background transparent \) \
			\( $feathered_dir/$clean_name'_15.png' $feathered_dir/$clean_name'_16.png' $feathered_dir/$clean_name'_17.png' $feathered_dir/$clean_name'_18.png' $feathered_dir/$clean_name'_19.png' +smush -$smush_value_w -background transparent \) \
			\( $feathered_dir/$clean_name'_20.png' $feathered_dir/$clean_name'_21.png' $feathered_dir/$clean_name'_22.png' $feathered_dir/$clean_name'_23.png' $feathered_dir/$clean_name'_24.png' +smush -$smush_value_w -background transparent \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi

	if [ $T = 6 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' $feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' $feathered_dir/$clean_name'_4.png' $feathered_dir/$clean_name'_5.png' +smush -$smush_value_w \)       \
			\( $feathered_dir/$clean_name'_6.png' $feathered_dir/$clean_name'_7.png' $feathered_dir/$clean_name'_8.png' $feathered_dir/$clean_name'_9.png' $feathered_dir/$clean_name'_10.png' $feathered_dir/$clean_name'_11.png' +smush -$smush_value_w \)     \
			\( $feathered_dir/$clean_name'_12.png' $feathered_dir/$clean_name'_13.png' $feathered_dir/$clean_name'_14.png' $feathered_dir/$clean_name'_15.png' $feathered_dir/$clean_name'_16.png' $feathered_dir/$clean_name'_17.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_18.png' $feathered_dir/$clean_name'_19.png' $feathered_dir/$clean_name'_20.png' $feathered_dir/$clean_name'_21.png' $feathered_dir/$clean_name'_22.png' $feathered_dir/$clean_name'_23.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_24.png' $feathered_dir/$clean_name'_25.png' $feathered_dir/$clean_name'_26.png' $feathered_dir/$clean_name'_27.png' $feathered_dir/$clean_name'_28.png' $feathered_dir/$clean_name'_29.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_30.png' $feathered_dir/$clean_name'_31.png' $feathered_dir/$clean_name'_32.png' $feathered_dir/$clean_name'_33.png' $feathered_dir/$clean_name'_34.png' $feathered_dir/$clean_name'_35.png' +smush -$smush_value_w \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi
	
	if [ $T = 7 ]; then
		convert -background transparent \
			\( $feathered_dir/$clean_name'_0.png' $feathered_dir/$clean_name'_1.png' $feathered_dir/$clean_name'_2.png' $feathered_dir/$clean_name'_3.png' $feathered_dir/$clean_name'_4.png' $feathered_dir/$clean_name'_5.png' $feathered_dir/$clean_name'_6.png' +smush -$smush_value_w \)        \
			\( $feathered_dir/$clean_name'_7.png' $feathered_dir/$clean_name'_8.png' $feathered_dir/$clean_name'_9.png' $feathered_dir/$clean_name'_10.png' $feathered_dir/$clean_name'_11.png' $feathered_dir/$clean_name'_12.png' $feathered_dir/$clean_name'_13.png' +smush -$smush_value_w \)    \
			\( $feathered_dir/$clean_name'_14.png' $feathered_dir/$clean_name'_15.png' $feathered_dir/$clean_name'_16.png' $feathered_dir/$clean_name'_17.png' $feathered_dir/$clean_name'_18.png' $feathered_dir/$clean_name'_19.png' $feathered_dir/$clean_name'_20.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_21.png' $feathered_dir/$clean_name'_22.png' $feathered_dir/$clean_name'_23.png' $feathered_dir/$clean_name'_24.png' $feathered_dir/$clean_name'_25.png' $feathered_dir/$clean_name'_26.png' $feathered_dir/$clean_name'_27.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_28.png' $feathered_dir/$clean_name'_29.png' $feathered_dir/$clean_name'_30.png' $feathered_dir/$clean_name'_31.png' $feathered_dir/$clean_name'_32.png' $feathered_dir/$clean_name'_33.png' $feathered_dir/$clean_name'_34.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_35.png' $feathered_dir/$clean_name'_36.png' $feathered_dir/$clean_name'_37.png' $feathered_dir/$clean_name'_38.png' $feathered_dir/$clean_name'_39.png' $feathered_dir/$clean_name'_40.png' $feathered_dir/$clean_name'_41.png' +smush -$smush_value_w \) \
			\( $feathered_dir/$clean_name'_42.png' $feathered_dir/$clean_name'_43.png' $feathered_dir/$clean_name'_44.png' $feathered_dir/$clean_name'_45.png' $feathered_dir/$clean_name'_46.png' $feathered_dir/$clean_name'_47.png' $feathered_dir/$clean_name'_48.png' +smush -$smush_value_w \) \
			-background none  -background transparent -smush -$smush_value_h  $smushdir/$clean_name.large_feathered.png
	fi

# 11. Smush the non-feathered tiles together and combine
	echo "# 11. Combining non-feathered tiles"
	
	if [ $T = 2 ]; then
		convert -background transparent \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_2.png' $tiles_dir/$clean_name'_3.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi

	if [ $T = 3 ]; then
		convert -background transparent \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' $tiles_dir/$clean_name'_2.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_3.png' $tiles_dir/$clean_name'_4.png' $tiles_dir/$clean_name'_5.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_6.png' $tiles_dir/$clean_name'_7.png' $tiles_dir/$clean_name'_8.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi
	
	if [ $T = 4 ]; then
		convert -background transparent \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' $tiles_dir/$clean_name'_2.png' $tiles_dir/$clean_name'_3.png' +smush -$smush_value_w \)     \
			\( $tiles_dir/$clean_name'_4.png' $tiles_dir/$clean_name'_5.png' $tiles_dir/$clean_name'_6.png' $tiles_dir/$clean_name'_7.png' +smush -$smush_value_w \)     \
			\( $tiles_dir/$clean_name'_8.png' $tiles_dir/$clean_name'_9.png' $tiles_dir/$clean_name'_10.png' $tiles_dir/$clean_name'_11.png' +smush -$smush_value_w \)   \
			\( $tiles_dir/$clean_name'_12.png' $tiles_dir/$clean_name'_13.png' $tiles_dir/$clean_name'_14.png' $tiles_dir/$clean_name'_15.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi

	if [ $T = 5 ]; then
		convert -background transparent \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' $tiles_dir/$clean_name'_2.png' $tiles_dir/$clean_name'_3.png' $tiles_dir/$clean_name'_4.png' +smush -$smush_value_w \)      \
			\( $tiles_dir/$clean_name'_5.png' $tiles_dir/$clean_name'_6.png' $tiles_dir/$clean_name'_7.png' $tiles_dir/$clean_name'_8.png' $tiles_dir/$clean_name'_9.png' +smush -$smush_value_w \)      \
			\( $tiles_dir/$clean_name'_10.png' $tiles_dir/$clean_name'_11.png' $tiles_dir/$clean_name'_12.png' $tiles_dir/$clean_name'_13.png' $tiles_dir/$clean_name'_14.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_15.png' $tiles_dir/$clean_name'_16.png' $tiles_dir/$clean_name'_17.png' $tiles_dir/$clean_name'_18.png' $tiles_dir/$clean_name'_19.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_20.png' $tiles_dir/$clean_name'_21.png' $tiles_dir/$clean_name'_22.png' $tiles_dir/$clean_name'_23.png' $tiles_dir/$clean_name'_24.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi
	
	if [ $T = 6 ]; then
		convert \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' $tiles_dir/$clean_name'_2.png' $tiles_dir/$clean_name'_3.png' $tiles_dir/$clean_name'_4.png' $tiles_dir/$clean_name'_5.png' +smush -$smush_value_w \)       \
			\( $tiles_dir/$clean_name'_6.png' $tiles_dir/$clean_name'_7.png' $tiles_dir/$clean_name'_8.png' $tiles_dir/$clean_name'_9.png' $tiles_dir/$clean_name'_10.png' $tiles_dir/$clean_name'_11.png' +smush -$smush_value_w \)     \
			\( $tiles_dir/$clean_name'_12.png' $tiles_dir/$clean_name'_13.png' $tiles_dir/$clean_name'_14.png' $tiles_dir/$clean_name'_15.png' $tiles_dir/$clean_name'_16.png' $tiles_dir/$clean_name'_17.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_18.png' $tiles_dir/$clean_name'_19.png' $tiles_dir/$clean_name'_20.png' $tiles_dir/$clean_name'_21.png' $tiles_dir/$clean_name'_22.png' $tiles_dir/$clean_name'_23.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_24.png' $tiles_dir/$clean_name'_25.png' $tiles_dir/$clean_name'_26.png' $tiles_dir/$clean_name'_27.png' $tiles_dir/$clean_name'_28.png' $tiles_dir/$clean_name'_29.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_30.png' $tiles_dir/$clean_name'_31.png' $tiles_dir/$clean_name'_32.png' $tiles_dir/$clean_name'_33.png' $tiles_dir/$clean_name'_34.png' $tiles_dir/$clean_name'_35.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi

	if [ $T = 7 ]; then
		convert \
			\( $tiles_dir/$clean_name'_0.png' $tiles_dir/$clean_name'_1.png' $tiles_dir/$clean_name'_2.png' $tiles_dir/$clean_name'_3.png' $tiles_dir/$clean_name'_4.png' $tiles_dir/$clean_name'_5.png' $tiles_dir/$clean_name'_6.png' +smush -$smush_value_w \)        \
			\( $tiles_dir/$clean_name'_7.png' $tiles_dir/$clean_name'_8.png' $tiles_dir/$clean_name'_9.png' $tiles_dir/$clean_name'_10.png' $tiles_dir/$clean_name'_11.png' $tiles_dir/$clean_name'_12.png' $tiles_dir/$clean_name'_13.png' +smush -$smush_value_w \)    \
			\( $tiles_dir/$clean_name'_14.png' $tiles_dir/$clean_name'_15.png' $tiles_dir/$clean_name'_16.png' $tiles_dir/$clean_name'_17.png' $tiles_dir/$clean_name'_18.png' $tiles_dir/$clean_name'_19.png' $tiles_dir/$clean_name'_20.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_21.png' $tiles_dir/$clean_name'_22.png' $tiles_dir/$clean_name'_23.png' $tiles_dir/$clean_name'_24.png' $tiles_dir/$clean_name'_25.png' $tiles_dir/$clean_name'_26.png' $tiles_dir/$clean_name'_27.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_28.png' $tiles_dir/$clean_name'_29.png' $tiles_dir/$clean_name'_30.png' $tiles_dir/$clean_name'_31.png' $tiles_dir/$clean_name'_32.png' $tiles_dir/$clean_name'_33.png' $tiles_dir/$clean_name'_34.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_35.png' $tiles_dir/$clean_name'_36.png' $tiles_dir/$clean_name'_37.png' $tiles_dir/$clean_name'_38.png' $tiles_dir/$clean_name'_39.png' $tiles_dir/$clean_name'_40.png' $tiles_dir/$clean_name'_41.png' +smush -$smush_value_w \) \
			\( $tiles_dir/$clean_name'_42.png' $tiles_dir/$clean_name'_43.png' $tiles_dir/$clean_name'_44.png' $tiles_dir/$clean_name'_45.png' $tiles_dir/$clean_name'_46.png' $tiles_dir/$clean_name'_47.png' $tiles_dir/$clean_name'_48.png' +smush -$smush_value_w \) \
			-background none -smush -$smush_value_h  $smushdir/$clean_name.large.png
	fi
	
	# Combine feathered and un-feathered output images to disguise feathering
	composite $smushdir/$clean_name.large_feathered.png $smushdir/$clean_name.large.png $smushdir/$clean_name.large_final.png
	
# 12. Move the result image and (if told to) delete the temporary directory

	if [ "$fileformat" = "image" ]; then
		echo "# 12. Exporting to $exportdir"
		# Export image
		if [ "$skipbasic" = "Y" ]; then
			cp "$smushdir/$clean_name.large_final.png" "$exportdir/$projname-NS.png"
		else
			cp "$smushdir/$clean_name.large_final.png" "$exportdir/$projname-NS.png"
		fi
		
		# Export project settings
		cp "$basedir/run_neuralstyle.sh" "$exportdir/${projname}-settings.txt"
		
		# Clean up directories if told to
		if [ "$cleanup" = "Y" ]; then
			rm "$outdir/$clean_name.large.png"
			rm "$outdir/$clean_name.large_feathered.png"
			rm -r "$tiles_dir"
			rm -r "$tileinput_dir"			
			rm -r "$feathered_dir"
			rm -r "$smushdir"
		fi
		
		# Display time elapsed on project and exit
		time_total=$(( SECONDS - start ))
		time_elapsed=$(show_time $time_total)
		echo "Time elapsed: $time_elapsed"
		
		sleep 1
		exit
	fi
	
	if [ "$fileformat" = "video" ]; then
		if [ "$cleanup" = "Y" ]; then
			echo "# 12. Moving image to master directory and clearing the preliminary images"
			mv "$smushdir/$clean_name.large_final.png" "$nsdir/frame_${i}.png"
			rm -r "$processed_dir"
		else
			echo "# 12. Moving image to master directory"
			cp "$smushdir/$clean_name.large_final.png" "$nsdir/frame_${i}.png"
		fi
	fi	
}

neural_style(){
# Runs neural_style.py
# $1 = input file path; $2 = style file path; $3 = output file path

	echoname="$(basename $1 .png)"
	
	# Detect if called from basic() or tile()
	if [ "$call_from" = "script_basic" ]; then
		maxitdetect="$maxit"
		sizedetect="$constraintsize"
		timerecho="N"
		tile="0"
	fi
	
	if [ "$call_from" = "script_tile" ]; then
		maxitdetect="$maxitupres"
		sizedetect="$size"
		timerecho="Y"
	fi
	
	# Define $timercount
	if [ -z $timercount ]; then
		timercount="1"
	fi
	
	# Begin timer
	if [ $timercount -lt 10 ]; then
		local timer_1=$(( SECONDS - start ))
	fi
	
	# Main Script
	if [ ! -s $3/$echoname.png ]; then
		# Print
		if [ "$fileformat" = "video" ]; then
			if [ "$call_from" = "script_basic" ]; then
				echo "Neural Style Transferring, basic (frame $frame)..."		
			fi
			
			if [ "$call_from" = "script_tile" ]; then
				echo "Neural Style Transferring, tile $tile/$T_square (frame $frame)..."
			fi
		else
			if [ "$call_from" = "script_basic" ]; then
				echo "Neural Style Transferring $echoname..."		
			fi
			
			if [ "$call_from" = "script_tile" ]; then
				echo "Neural Style Transferring Tile $tile/$T_square..."
			fi
		fi
		
		# Run neural_style.py
		if [ "$origcolors" = "Y" ]; then
			if [ "$verbose" = "Y" ]; then
				python neural_style.py --content_img $1 --style_imgs $2 --img_output_dir $3 \
					--max_size $sizedetect                                                  \
					--original_colors                                                       \
					--content_weight $cweight --style_weight $sweight --tv_weight $tvweight \
					--max_iterations $maxitdetect --device /gpu:0                           \
					--verbose
			else
				python neural_style.py --content_img $1 --style_imgs $2 --img_output_dir $3 \
					--max_size $sizedetect                                                  \
					--original_colors                                                       \
					--content_weight $cweight --style_weight $sweight --tv_weight $tvweight \
					--max_iterations $maxitdetect --device /gpu:0
			fi
		else
			if [ "$verbose" = "Y" ]; then
				python neural_style.py --content_img $1 --style_imgs $2 --img_output_dir $3 \
					--max_size $sizedetect                                                  \
					--content_weight $cweight --style_weight $sweight --tv_weight $tvweight \
					--max_iterations $maxitdetect --device /gpu:0                           \
					--verbose
			else
				python neural_style.py --content_img $1 --style_imgs $2 --img_output_dir $3 \
					--max_size $sizedetect                                                  \
					--content_weight $cweight --style_weight $sweight --tv_weight $tvweight \
					--max_iterations $maxitdetect --device /gpu:0
			fi
		fi
		
		# Clean up results folder
		mv "$3/result/result.png" "$3/${echoname}.png"
		rm -r "$3/result"	
	fi
	
	# Retry
	if [ ! -s $3/$echoname.png ] && [ $retry -lt 3 ]; then
		if [ $retry = 1 ]; then
			retrygrammar="first"
		fi
		
		if [ $retry = 2 ]; then
			retrygrammar="second"
		fi
		
		echo "Transfer Failed. Retrying for $retrygrammar time. Check system memory"
		retry=$(echo $retry | awk '{print 1+$retry}')
		neural_style $1 $2 $3
	fi
	
	retry=1
	
	# End timer
	if [ $timercount -lt 10 ]; then
		local timer_2=$(( SECONDS - start ))
		time_all_runs=$(echo $time_all_runs $timer_2 $timer_1 | awk "{print $time_all_runs+$timer_2-$timer_1}")
		time_single_run=$(echo $time_all_runs $timercount | awk "{print $time_all_runs/$timercount}")
		time_single_run_san="${time_single_run%.*}"
		if [ $time_single_run_san -ne 0 ]; then
			(( timercount = timercount + 1 ))
		fi
	fi
	
	# Echo estimated time to completion
	if [ "$timerecho" = "Y" ] && [ $time_single_run_san -gt 0 ]; then
		if [ "$tile" -ne "$T_square" ]; then
			local timer_it=$(echo $time_single_run $T_square $tile | awk "{print $time_single_run*($T_square-$tile)}")
			local timer_it_san="${timer_it%.*}"
			local time_est=$(show_time $timer_it_san)
			echo "Estimated time remaining in neural_style loop: $time_est"
		fi
	fi
	
	if [ "$timerecho" = "Y" ] && [ $time_single_run_san -gt 0 ]; then
		if [ $tile = $T_square ]; then
			local timer_3=$(( SECONDS - start ))
			local time_all_it=$(echo $timer_3 $time_setup | awk "{print $timer_3-$time_setup}")
			local time_all_it_print=$(show_time $time_all_it)
			echo "Time elapsed in neural_style loop: $time_all_it_print"
		fi
	fi
	
}

match_parameters(){
# Uses ImageMagick to make parameters of image 2 be like parameters of image 1
# $1 = input file path; $2 = style file path; $3 = output file path

	# Grab means and SD for each color channel for input image
	local i_mean_R=$(convert $1 -format "%[fx:mean.r]" info:)
	local i_mean_G=$(convert $1 -format "%[fx:mean.g]" info:)
	local i_mean_B=$(convert $1 -format "%[fx:mean.b]" info:)
	local i_sd_R=$(convert $1 -format "%[fx:standard_deviation.r]" info:)
	local i_sd_G=$(convert $1 -format "%[fx:standard_deviation.g]" info:)
	local i_sd_B=$(convert $1 -format "%[fx:standard_deviation.b]" info:)
	
	# Grab means and SD for each color channel for style image
	local s_mean_R=$(convert $2 -format "%[fx:mean.r]" info:)
	local s_mean_G=$(convert $2 -format "%[fx:mean.g]" info:)
	local s_mean_B=$(convert $2 -format "%[fx:mean.b]" info:)
	local s_sd_R=$(convert $2 -format "%[fx:standard_deviation.r]" info:)
	local s_sd_G=$(convert $2 -format "%[fx:standard_deviation.g]" info:)
	local s_sd_B=$(convert $2 -format "%[fx:standard_deviation.b]" info:)

	# Calculate the gains and biases
	local s_sd_R_check=$(echo $s_sd_R | awk "{if ($s_sd_R > 0) print 1; else print 0}")
	if [ $s_sd_R_check = 1 ]; then
		local gain_R=$(echo $i_sd_R $s_sd_R | awk "{print $i_sd_R/$s_sd_R}")
	else
		local gain_R="divzero"
	fi
	
	local s_sd_G_check=$(echo $s_sd_G | awk "{if ($s_sd_G > 0) print 1; else print 0}")
	if [ $s_sd_G_check = 1 ]; then
		local gain_G=$(echo $i_sd_G $s_sd_G | awk "{print $i_sd_G/$s_sd_G}")
	else
		local gain_G="divzero"
	fi
	
	local s_sd_B_check=$(echo $s_sd_B | awk "{if ($s_sd_B > 0) print 1; else print 0}")
	if [ $s_sd_B_check = 1 ]; then
		local gain_B=$(echo $i_sd_B $s_sd_B | awk "{print $i_sd_B/$s_sd_B}")
	else
		local gain_B="divzero"
	fi
	
	local bias_R=$(echo $i_mean_R $s_mean_R $gain_R | awk "{print $i_mean_R-$s_mean_R*$gain_R}")
	local bias_G=$(echo $i_mean_G $s_mean_G $gain_G | awk "{print $i_mean_G-$s_mean_G*$gain_G}")
	local bias_B=$(echo $i_mean_B $s_mean_B $gain_B | awk "{print $i_mean_B-$s_mean_B*$gain_B}")

	# Modify the style image to be like the input image
	if [ "$gain_R" != "divzero" ]; then
		convert $2 -channel R -function Polynomial ${gain_R},${bias_R} +channel $3
	fi
	
	if [ "$gain_G" != "divzero" ]; then
		convert $2 -channel G -function Polynomial ${gain_G},${bias_G} +channel $3
	fi
	
	if [ "$gain_B" != "divzero" ]; then
		convert $2 -channel B -function Polynomial ${gain_B},${bias_B} +channel $3
	fi

}

waifu2x(){
# Calls waifu2x to increase the size of the basic neural-style image
# $1 = input file path; $2 = output file path
	
	# Specify the model directory based on the algorithm specified
	if [ "$waifu_algo" = "UpRGB" ]; then
		waifu_model="models/upconv_7_anime_style_art_rgb"
	fi
	
	if [ "$waifu_algo" = "UpPhoto" ]; then
		waifu_model="models/upconv_7_photo"
	fi
	
	if [ "$waifu_algo" = "RGB" ]; then
		waifu_model="models/anime_style_art_rgb"
	fi

	if [ "$waifu_algo" = "Photo" ]; then
		waifu_model="models/photo"
	fi	

	if [ "$waifu_algo" = "Y" ]; then
		waifu_model="models/ukbench"
	fi	
	
	if [ "$waifu_algo" = "UpResNet10" ]; then
		waifu_model="models/upresnet10"
	fi	

	# Determine how much to scale the image up
	local mod=$(echo $size | awk "{print 100*$size/$constraintsize}")
	local mod2="${mod%.*}"
	local waifu_scale=$(echo $mod | awk "{print $mod2/100}")
	waifu_scale_length="${#waifu_scale}"
	
	# Run waifu2x
	waifu2x-caffe-cui.exe -i "$1" --model_dir "$waifu_model" --scale_ratio "$waifu_scale" --noise_level "$waifu_noise" --crop_size "$waifu_split" --output_file "$2"
	
	# Rename waifu2x file
	if [ $waifu_scale_length = 1 ]; then
		mv "$2/input(${waifu_algo})(noise_scale)(Level${waifu_noise})(x${waifu_scale}.000000).png" "$2/waifu.png"
	fi
	
	if [ $waifu_scale_length = 3 ]; then
		mv "$2/input(${waifu_algo})(noise_scale)(Level${waifu_noise})(x${waifu_scale}00000).png" "$2/waifu.png"
	fi
	
	if [ $waifu_scale_length = 4 ]; then
		mv "$2/input(${waifu_algo})(noise_scale)(Level${waifu_noise})(x${waifu_scale}0000).png" "$2/waifu.png"
	fi
	
	# Use ImageMagick to make sure the resultant file is the correct size
	if [ $cw -ge $ch ]; then
		convert -geometry "$size"x "$2/waifu.png" "$2/waifu.png"
	else
		convert -geometry x"$size" "$2/waifu.png" "$2/waifu.png"
	fi
}

show_time(){
# Takes an input in seconds and convert to hours, minutes and seconds
# $1 = input number in seconds

	num=$1
	min=0
	hour=0
	
	if (( num > 59 )); then
		(( sec = num%60 ))
		(( num = num/60 ))
        if (( num  > 59 )); then
			(( min = num%60 ))
			(( num =  num/60 ))
			(( hour = num ))
		else
			(( min = num ))
		fi
	else
		(( sec = num ))
	fi
	
    echo "$hour"h "$min"m "$sec"s
}

# Make sure script is called from the starting script
if [ "$#" -ne 2 ]; then
	echo "This script isn't meant to be used directly -- edit and then start run_neuralstyle.sh. Exiting."
	sleep 3
	exit 1
else
	retry=1
	check_inputs $1 $2
fi
