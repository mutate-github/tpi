#!/bin/sh

git pull --rebase

echo "oracle@amazon1"
cat <<EOF | ssh oracle@a1 "/bin/bash"
cd start/tpi
git pull
echo "scp to jet:"
scp tpi jet:bin/

echo "oracle@mon"
cat <<EOL | ssh oracle@mon "/bin/bash"
cd start/tpi
git pull
echo "scp to aisprod:"
scp tpi aisprod:start/bin
EOL
EOF


