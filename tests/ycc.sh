rm -r ycc
mkdir ycc ;
cd jpeg ;
for file in *.jpg ;
do
    cd ..
    convert -depth 8 "jpeg:jpeg/${file}" "ycbcr:ycc/${file}.ycc" ;
    cd jpeg
done ;
cd .. ;
