#!/bin/sh

git pull --rebase

echo "oracle@c1"
cat <<EOF | ssh oracle@c1 "/bin/bash"
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
echo "scp to beta:"
scp tpi beta:start/bin
echo "scp to alpha:"
scp tpi alpha:start/bin
EOL
EOF


