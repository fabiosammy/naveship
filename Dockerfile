FROM ruby:2.3

# Tell debconf to run in non-interactive mode
ENV DEBIAN_FRONTEND noninteractive

# Install apt based dependencies required to run Rails as 
# well as RubyGems. As the Ruby image itself is based on a 
# Debian image, we use apt-get to install those.
RUN apt-get update

RUN apt-get install -y --no-install-recommends \ 
  build-essential \ 
  sudo \
  nodejs 

RUN apt-get install -y --no-install-recommends \ 
  libsdl2-dev \
  libsdl2-ttf-dev \
  libpango1.0-dev \
  libgl1-mesa-dev \
  libfreeimage-dev \
  libopenal-dev \
  libsndfile-dev \
  libiconv-hook-dev \
  libxml2-dev \
  freeglut3 \
  freeglut3-dev \
  ImageMagick \
  libmagickwand-dev

RUN apt-get install -y \ 
  xauth \
  alsa-utils \
  libgl1-mesa-dri \
  libgl1-mesa-glx \
  libpangoxft-1.0-0 \
  libssl1.0.0 \
  libxss1 

RUN apt-get install -y \
  mesa-utils \
  binutils \
  x-window-system \
  module-init-tools \
  xserver-xorg-video-all 

# TO NVIDIA
RUN wget -O /tmp/nvidia-driver.run http://us.download.nvidia.com/XFree86/Linux-x86_64/352.63/NVIDIA-Linux-x86_64-352.63.run \
  && sh /tmp/nvidia-driver.run -a -N --ui=none --no-kernel-module \
  && rm /tmp/nvidia-driver.run

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# ADD an user
RUN adduser --disabled-password --gecos '' bomberman \
  && usermod -a -G video bomberman \
  && usermod -a -G sudo bomberman \
  && usermod -a -G dialout bomberman \
  && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
  && echo 'bomberman:bomberman' | chpasswd

# SET ENV Gems
ENV HOME=/home/bomberman \
  APP=/usr/src/app \
  LIBGL_DEBUG=verbose

# Configure the main working directory. This is the base 
# directory used in any further RUN, COPY, and ENTRYPOINT 
# commands.
RUN mkdir -p $HOME \
  && mkdir -p $APP \
  && chown -R bomberman:bomberman $APP \
  && gem install bundler \
  && echo "PATH=$PATH" >> /etc/profile \
  && echo "export GEM_HOME=/usr/local/bundle" >> /etc/profile \
  && echo "GEM_HOME=/usr/local/bundle" >> /etc/environment \
  && chown -R bomberman:bomberman $HOME

# Expose port 3000 to the Docker host, so we can access it 
# from the outside.
#EXPOSE 22
#EXPOSE 3000
#EXPOSE 5532

# Copy the Gemfile as well as the Gemfile.lock and install 
# the RubyGems. This is a separate step so the dependencies 
# will be cached unless changes to one of those two files 
# are made.
WORKDIR $APP
COPY Gemfile Gemfile.lock $APP/
RUN bundle install --jobs 20 --retry 5

# Copy the main application.
COPY . ./
RUN chown -R bomberman:bomberman $APP

# The main command to run when the container starts. Also 
# tell the Rails dev server to bind to all interfaces by 
# default.
#CMD ["/usr/bin/sudo", "/usr/sbin/sshd", "-D"]
USER bomberman:bomberman
CMD ["ruby", "main.rb"]

