#Modified from http://github.com/TomKellyGenetics/cellranger_clean
FROM ubuntu:18.04

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# Install dependencies for cellranger
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y \
    apt-utils \
    clang-6.0 \
    cython \
    dialog \
#    golang-1.10-go \
    gcc-multilib \
    libbz2-dev \
    liblzma-dev \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libgfortran-5-dev \
    libffi-dev \
    libhdf5-dev \
    libhts-dev \
    libncurses-dev \
    libopenblas-dev \
    libpixman-1-dev \
    libpng-dev \
    libsodium-dev \
    libssl-dev \
    libtiff5-dev \
    libtiff-tools \
    libxml2-dev \
    libxslt1-dev \
    libzmq3-dev \
    llvm \
    lzma-dev \
    python-cairo \
    python-h5py \
#    python-libtiff \ 
    python-matplotlib \
    python-nacl \
    python-numpy \
    python-pip \
    python-libxml2 \
    python-redis \
    python-ruamel.yaml \
    python-sip \
    python-sqlite \
    python-tables \
    python-tk \
    samtools \
    tar \
    wget \
    zlib1g-dev

RUN pip install libtiff

RUN wget https://dl.google.com/go/go1.11.linux-amd64.tar.gz \
 && tar -xvf go1.11.linux-amd64.tar.gz \
 && mv go /usr/local

ENV GOROOT=/usr/local/go
ENV GOPATH=$HOME/go
ENV PATH=$GOPATH/bin:$GOROOT/bin:$PATH

RUN ln -s /usr/lib/go-1.11/bin/go /usr/bin/go

RUN  apt-get remove -y python-openssl \
&&  apt-get install -y --reinstall python-openssl

RUN wget https://files.pythonhosted.org/packages/40/d0/8efd61531f338a89b4efa48fcf1972d870d2b67a7aea9dcf70783c8464dc/pyOpenSSL-19.0.0.tar.gz \
 && tar -xzvf pyOpenSSL-19.0.0.tar.gz \
 && cd pyOpenSSL-19.0.0 \ 
 python setup.py install \
 && cd ..

COPY requirements.txt /opt/requirements.txt
RUN pip install --upgrade pip
RUN pip install -r /opt/requirements.txt

# RUN easy_install -U pip
# RUN easy_install -U pyOpenSSL
# RUN apt-get install python-dateutil

# Install rust and cargo. Note that installing with apt gets a rust that won't complie
# cellranger.
RUN apt-get install -y \
    curl \
    git  \
 && curl https://sh.rustup.rs -sSf | sh -s -- -y

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh  -s -- -y

#RUN apt-get install -y libstd-rust-1.40 cargo
ENV PATH /root/.cargo/bin/:$PATH
ENV PATH  $HOME/.cargo/bin:$PATH
RUN bash $HOME/.cargo/env

RUN rustup install 1.40.0
RUN rustup default 1.40.0

RUN mkdir -p cellranger-3.0.2.9001 \
  && cd cellranger-3.0.2.9001 \
  && mkdir -p cellranger-cs \
  && mkdir -p cellranger-cs/3.0.2.9001 \
  cd /

# Build cellranger itself 
RUN git clone https://github.com/TomKellyGenetics/cellranger.git cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001  \
 && cd cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001 \
 && make && make louvain-clean &&  make louvain \
 && cd ../..

RUN ln -s cellranger-cs/3.0.2/bin/cellranger . \
&& cd /

RUN curl -sL https://deb.nodesource.com/setup_13.x | bash - \
 && apt-get install -y nodejs

# Install Martian. Note that we're just building the executables, not the web stuff
RUN git clone --recursive https://github.com/martian-lang/martian.git \
 && cd martian \
 && make mrc mrf mrg mrp mrs mrstat mrjob

# Set up paths to cellranger. This is most of what sourceme.bash would do.
ENV PATH /cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/bin/:/cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/lib/bin:/cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/tenkit/bin/:/cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/tenkit/lib/bin:/martian/bin/:$PATH
ENV PYTHONPATH /cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/lib/python:/cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/tenkit/lib/python:/martian/adapters/python:$PYTHONPATH
ENV MROPATH /cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/mro/:/cellranger-3.0.2.9001/cellranger-cs/3.0.2.9001/tenkit/mro/
ENV _TENX_LD_LIBRARY_PATH whatever
