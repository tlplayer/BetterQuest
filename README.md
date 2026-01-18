<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0dc3c668-5905-4686-928a-eb6094f3144b" />


This addon assumes and requires PFUI https://github.com/shagu/pfUI


To make portraits from images run this in portraits dir:
```sh
for file in *.tga; do     ffmpeg -i "$file" -c:v targa -pix_fmt bgr24 -y "temp_$file";     mv "temp_$file" "$file";     echo "Fixed: $file"; done
```