cd portraits/
for f in *.png; do
    ffmpeg -y -i "$f" -vf "scale=256:256" -pix_fmt rgb24 "${f%.*}.tga"
done