# This is a Dockerfile for firod.
FROM debian:bullseye as build-image

# Install required system packages
RUN apt-get update && apt-get install -y \
    automake \
    bsdmainutils \
    curl \
    g++ \
    libtool \
    make \
    pkg-config \
    patch 

# Build Firo
COPY . /tmp/firo/

WORKDIR /tmp/firo

RUN cd depends && \
    NO_QT=true make HOST=$(uname -m)-linux-gnu -j$(nproc)

RUN ./autogen.sh && \
    ./configure --without-gui --enable-tests --prefix=/tmp/firo/depends/$(uname -m)-linux-gnu && \
    make -j$(nproc) && \
    make check && \
    make install

# extract shared dependencies of firod and firo-cli
# copy relevant binaries to /usr/bin, the COPY --from cannot use $(uname -m) variable in argument
RUN mkdir /tmp/ldd && \
    ./depends/ldd_copy.sh -b "./depends/$(uname -m)-linux-gnu/bin/firod" -t "/tmp/ldd" && \
    ./depends/ldd_copy.sh -b "./depends/$(uname -m)-linux-gnu/bin/firo-cli" -t "/tmp/ldd" && \
    cp ./depends/$(uname -m)-linux-gnu/bin/* /usr/bin/

FROM debian:bullseye-slim

COPY --from=build-image /usr/bin/firod /usr/bin/firod
COPY --from=build-image /usr/bin/firo-cli /usr/bin/firo-cli
COPY --from=build-image /tmp/ldd /tmp/ldd

# restore ldd files in correct paths
# -n will not override libraries already present in this image,
# standard libraries like `libc` can crash when overriden at runtime
RUN cp -vnrT /tmp/ldd / && \
    rm -rf /tmp/ldd && \
    ldd /usr/bin/firod

# Create user to run daemon
RUN useradd -m -U firod
USER firod

RUN mkdir /home/firod/.firo
VOLUME [ "/home/firod/.firo" ]

# Main network ports
EXPOSE 8168
EXPOSE 8888

# Test network ports
EXPOSE 18168
EXPOSE 18888

# Regression test network ports
EXPOSE 18444
EXPOSE 28888

ENTRYPOINT ["/usr/bin/firod", "-printtoconsole"]

