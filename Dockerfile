# Version 1.0
FROM ubuntu:14.04
MAINTAINER Florian GAUVIN "florian.gauvin@nl.thalesgroup.com"

ENV DEBIAN_FRONTEND noninteractive

#Download all the packages needed 

RUN apt-get update && apt-get install -y \
	cmake \
	git \
	python \
	wget \
	unzip \
	bc\
	language-pack-en \
	mercurial \
	zip \
	openjdk-7-jdk \
	libcups2-dev \
	libfreetype6-dev \
	libasound2-dev\
	libffi-dev \
	libX11-dev \
	libxext-dev \
	libxrender-dev \
	libxtst-dev \
	libxt-dev \
        && apt-get clean 

#Download and install the latest version of Docker (You need to be the same version to use this Dockerfile)

RUN wget -qO- https://get.docker.com/ | sh

#Prepare the usr directory by downloading in it : Buildroot, the configuration file of Buildroot, Openjdk8 and Apache Ace

WORKDIR /usr

RUN wget http://git.buildroot.net/buildroot/snapshot/buildroot-2015.05.tar.gz && \
	tar -xf buildroot-2015.05.tar.gz && \
	git clone https://github.com/florian-gauvin/Buildroot-configure.git --branch ace buildroot-configure-ace && \
	cp buildroot-configure-ace/.config buildroot-2015.05/ && \
	hg clone http://hg.openjdk.java.net/jdk8u/jdk8u openjdk8 && \
	wget http://www.eu.apache.org/dist/ace/apache-ace-2.0.1/apache-ace-2.0.1-bin.zip && \
	unzip apache-ace-2.0.1-bin.zip

#Create a small base of the future image with buildroot and decompress it

WORkDIR /usr/buildroot-2015.05

RUN make

WORKDIR /usr/buildroot-2015.05/output/images

RUN tar -xf rootfs.tar &&\
	rm rootfs.tar
	
# Install etcdctl

RUN cd /tmp \
	&& export ETCDVERSION=v2.0.13 \
	&& curl -k -L https://github.com/coreos/etcd/releases/download/$ETCDVERSION/etcd-$ETCDVERSION-linux-amd64.tar.gz | gunzip | tar xf - \
	&& cp etcd-$ETCDVERSION-linux-amd64/etcdctl /usr/buildroot-2015.05/output/images/bin/

#Add the resources
ADD resources /usr/buildroot-2015.05/output/images/tmp

#Compile the 3 compact profiles of Openjdk8, for more information about the compact profiles of openjdk8 see this link : http://openjdk.java.net/jeps/161

WORKDIR /usr/openjdk8

RUN bash ./get_source.sh && \
	export LIBFFI_CFLAGS=-I/usr/lib/x86_64-linux-gnu/include && \
	export LIBFFI_LIBS="-L/usr/lib/x86_64-linux-gnu/ -lffi" && \
	bash ./configure --with-jvm-variants=zero --enable-openjdk-only --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib/x86_64-linux-gnu --with-extra-cflags=-Wno-error --with-extra-cxxflags=-Wno-error && \
	make profiles 

#Copy the built compact 2 profiles of openjdk8 and Apache-Ace in the Base image created with buildroot (We choose compact 2 for our project but you can copy an other compact profiles if you need by replacing "j2re-compact2-image" by "j2re-compact1-image" or "j2re-compact3-image"). Then we have all we need so we can compress all the files.

RUN cp -fr /usr/openjdk8/build/linux-x86_64-normal-zero-release/images/j2re-compact2-image /usr/buildroot-2015.05/output/images/usr/ && \
	cp -r /usr/apache-ace-2.0.1-bin /usr/buildroot-2015.05/output/images/usr && \
	cd /usr/buildroot-2015.05/output/images/ &&\
	tar -cf rootfs.tar *

# Either uncomment this line, or map the bundles folder as a docker volume to /bundles when starting the container!

#ADD bundles /usr/buildroot-2015.05/output/images/bundles

#When the builder image is launch, it creates the openjdk8 and ace docker image that you will be able to see by running the command : docker images

ENTRYPOINT for i in `seq 0 100`; do sudo mknod -m0660 /dev/loop$i b 7 $i; done && \
	service docker start && \
	docker import - inaetics/ace-agent < /usr/buildroot-2015.05/output/images/rootfs.tar &&\
	/bin/bash


