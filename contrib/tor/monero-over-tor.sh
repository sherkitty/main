#!/bin/bash

DIR=$(realpath $(dirname $0))

echo "Checking sherkittyd..."
sherkittyd=""
for dir in \
  . \
  "$DIR" \
  "$DIR/../.." \
  "$DIR/build/release/bin" \
  "$DIR/../../build/release/bin" \
  "$DIR/build/Linux/master/release/bin" \
  "$DIR/../../build/Linux/master/release/bin" \
  "$DIR/build/Windows/master/release/bin" \
  "$DIR/../../build/Windows/master/release/bin"
do
  if test -x "$dir/sherkittyd"
  then
    sherkittyd="$dir/sherkittyd"
    break
  fi
done
if test -z "$sherkittyd"
then
  echo "sherkittyd not found"
  exit 1
fi
echo "Found: $sherkittyd"

TORDIR="$DIR/sherkitty-over-tor"
TORRC="$TORDIR/torrc"
HOSTNAMEFILE="$TORDIR/hostname"
echo "Creating configuration..."
mkdir -p "$TORDIR"
chmod 700 "$TORDIR"
rm -f "$TORRC"
cat << EOF > "$TORRC"
ControlSocket $TORDIR/control
ControlSocketsGroupWritable 1
CookieAuthentication 1
CookieAuthFile $TORDIR/control.authcookie
CookieAuthFileGroupReadable 1
HiddenServiceDir $TORDIR
HiddenServicePort 12770 127.0.0.1:12770
EOF

echo "Starting Tor..."
nohup tor -f "$TORRC" 2> "$TORDIR/tor.stderr" 1> "$TORDIR/tor.stdout" &
ready=0
for i in `seq 10`
do
  sleep 1
  if test -f "$HOSTNAMEFILE"
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting Tor"
  cat "$TORDIR/tor.stdout"
  exit 1
fi

echo "Starting sherkittyd..."
HOSTNAME=$(cat "$HOSTNAMEFILE")
"$sherkittyd" \
  --anonymous-inbound "$HOSTNAME":12770,127.0.0.1:12770,25 --tx-proxy tor,127.0.0.1:9050,10 \
  --add-priority-node zbjkbsxc5munw3qusl7j2hpcmikhqocdf4pqhnhtpzw5nt5jrmofptid.onion:12770 \
  --add-priority-node 2catusdnode5itf65lz.onion:12770 \
  --detach
ready=0
for i in `seq 10`
do
  sleep 1
  status=$("$sherkittyd" status)
  echo "$status" | grep -q "Height:"
  if test $? = 0
  then
    ready=1
    break
  fi
done
if test "$ready" = 0
then
  echo "Error starting sherkittyd"
  tail -n 400 "$HOME/.bitsherkitty/bitsherkitty.log" | grep -Ev stacktrace\|"Error: Couldn't connect to daemon:"\|"src/daemon/main.cpp:.*Sherkitty\ \'" | tail -n 20
  exit 1
fi

echo "Ready. Your Tor hidden service is $HOSTNAME"
