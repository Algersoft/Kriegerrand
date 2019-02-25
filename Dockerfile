# daemon runs in the background
# run something like tail /var/log/mindbraind/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/mindbraind:/var/lib/mindbraind -v $(pwd)/wallet:/home/kriegerrand --rm -ti kriegerrand:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG KRIEGRERRAND_BRANCH=master
ENV KRIEGRERRAND_BRANCH=${KRIEGRERRAND_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/Algersoft/kriegerrand.git /src/kriegerrand && \
    cd /src/kriegerrand && \
    git checkout $KRIEGRERRAND_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/MindBraind /usr/local/bin/MindBraind && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/MindBraind && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/kriegerrand && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the mindbraind service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/mindbraind mindbraind && \
    useradd -s /bin/bash -m -d /home/kriegerrand kriegerrand && \
    mkdir -p /etc/services.d/mindbraind/log && \
    mkdir -p /var/log/mindbraind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/mindbraind/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/mindbraind/run && \
    echo "cd /var/lib/mindbraind" >> /etc/services.d/mindbraind/run && \
    echo "export HOME /var/lib/mindbraind" >> /etc/services.d/mindbraind/run && \
    echo "s6-setuidgid mindbraind /usr/local/bin/MindBraind" >> /etc/services.d/mindbraind/run && \
    chmod +x /etc/services.d/mindbraind/run && \
    chown nobody:nogroup /var/log/mindbraind && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/mindbraind/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/mindbraind/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/mindbraind" >> /etc/services.d/mindbraind/log/run && \
    chmod +x /etc/services.d/mindbraind/log/run && \
    echo "/var/lib/mindbraind true mindbraind 0644 0755" > /etc/fix-attrs.d/mindbraind-home && \
    echo "/home/kriegerrand true kriegerrand 0644 0755" > /etc/fix-attrs.d/kriegerrand-home && \
    echo "/var/log/mindbraind true nobody 0644 0755" > /etc/fix-attrs.d/mindbraind-logs

VOLUME ["/var/lib/mindbraind", "/home/kriegerrand","/var/log/mindbraind"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/kriegerrand export HOME /home/kriegerrand s6-setuidgid kriegerrand /bin/bash"]
