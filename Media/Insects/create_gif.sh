# Generate a palette
ffmpeg -i short.mp4 -vf "fps=15,palettegen=stats_mode=full" -y palette.png

# Render the GIF using color mapping
ffmpeg -i short.mp4 -i palette.png -filter_complex "fps=15[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" -y demo.gif
