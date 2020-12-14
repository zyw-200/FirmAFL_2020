
AFL="./afl-fuzz -m none -t 800000+ -Q -i ./inputs -o ./outputs -x keywords"

chroot . \
${AFL} \
./sbin/httpd @@
