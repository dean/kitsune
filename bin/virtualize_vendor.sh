pip install peep==1.2
peep install peep_req.txt
cd ~/kitsune/vendor/packages
for f in *; do
    tar -zcvf "$f.tar.gz" "${f}"
done
for f in *.tar.gz; do
    pip install "${f}"
done
rm *.tar.gz
