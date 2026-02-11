FROM perl:stable

RUN <<EOF
cpanm File::Path
cpanm LWP::Simple
cpanm Mozilla:CA
cpanm WebService::Pandora
cpanm Crypt::Blowfish
cpanm Crypt::ECBE
cpanm MP3::Tag
cpanm MP3::Info
cpanm LWP::Protocol::https
EOF

COPY . /app
WORKDIR /app

# Should mount something to /music for this to work right.
CMD ["perl", "./panda.pl", "/music"]
