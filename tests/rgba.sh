rm -r rgba
mkdir rgba ;
cd jpeg ;
for file in *.jpg ;
do
    cd ..
    convert -depth 16 "jpeg:jpeg/${file}" "rgba:rgba/${file}.rgba" ;
    cd jpeg
done ;
cd .. ;
