########## Snort Docker Container
#
FROM ubuntu:14.04.2
MAINTAINER neiltylerbell
ENV DEBIAN_FRONTEND noninteractive
ENV SNORT_VERSION 2.9.7.3
ENV DAQ_VERSION 2.0.5
ENV BARNYARD2_VERSION 2-1.13
ENV PULLEDPORK_VERSION 0.7.0

# Install dependencies
RUN apt-get update && apt-get install -y wget supervisor make autoconf libtool build-essential libpcap-dev libpcre3-dev libdumbnet-dev bison flex zlib1g-dev libmysqlclient-dev mysql-client libcrypt-ssleay-perl liblwp-useragent-determined-perl

# Install DAQ
RUN cd /tmp && wget https://www.snort.org/downloads/snort/daq-${DAQ_VERSION}.tar.gz && \
 tar -xvzf daq-${DAQ_VERSION}.tar.gz && \
 cd daq-${DAQ_VERSION} && ./configure && make && make install

# Install Snort
RUN cd /tmp && wget https://www.snort.org/downloads/snort/snort-${SNORT_VERSION}.tar.gz && \
 tar -xvzf snort-${SNORT_VERSION}.tar.gz && \
 cd snort-${SNORT_VERSION} && ./configure --enable-sourcefire && \
 make && make install && \
 ldconfig && ln -s /usr/local/bin/snort /usr/sbin/snort

# Configure Snort
RUN groupadd snort && useradd snort -r -s /sbin/nologin -c SNORT_IDS -g snort
RUN mkdir /etc/snort && mkdir /etc/snort/rules && \
 touch /etc/snort/rules/white_list.rules && \
 touch /etc/snort/rules/black_list.rules && \
 mkdir /etc/snort/preproc_rules && \
 mkdir /var/log/snort && \
 mkdir /usr/local/lib/snort_dynamicrules && \
 chmod -R 5775 /etc/snort && \
 chmod -R 5775 /var/log/snort && \
 chmod -R 5775 /usr/local/lib/snort_dynamicrules && \
 chown -R snort.snort /etc/snort && \
 chown -R snort.snort /var/log/snort && \
 chown -R snort.snort /usr/local/lib/snort_dynamicrules
RUN cp /tmp/snort-${SNORT_VERSION}/etc/*.conf* /etc/snort && \
 cp /tmp/snort-${SNORT_VERSION}/etc/*.map /etc/snort

# Install Barnyard2
RUN cd /tmp && wget https://github.com/firnsy/barnyard2/archive/v${BARNYARD2_VERSION}.tar.gz -O barnyard2-${BARNYARD2_VERSION}.tar.gz && \
 tar zxvf barnyard2-${BARNYARD2_VERSION}.tar.gz && cd barnyard2-${BARNYARD2_VERSION} && autoreconf -fvi -I ./m4 && \
 ./configure --with-mysql --with-mysql-libraries=/usr/lib/x86_64-linux-gnu && \
 make && \
 make install

# Configure Barnyard2 
RUN mkdir /var/log/barnyard2 && \
 chown snort.snort /var/log/barnyard2 && \
 touch /var/log/snort/barnyard2.waldo && \
 chown snort.snort /var/log/snort/barnyard2.waldo

# Install and Configure PulledPork
RUN cd /tmp && wget https://pulledpork.googlecode.com/files/pulledpork-${PULLEDPORK_VERSION}.tar.gz && \
 tar xvfz pulledpork-${PULLEDPORK_VERSION}.tar.gz && \
 cp pulledpork-${PULLEDPORK_VERSION}/pulledpork.pl /usr/local/bin && \
 chmod +x /usr/local/bin/pulledpork.pl && \
 cp pulledpork-${PULLEDPORK_VERSION}/etc/*.conf /etc/snort && \
 mkdir /etc/snort/rules/iplists && \
 touch /etc/snort/rules/iplists/default.blacklist

# Add PulledPork cronjob
ADD assets/crons.conf /root/crons.conf
RUN crontab /root/crons.conf
RUN cron

# Add necessary config files
ADD assets/supervisord.conf /etc/supervisor/
ADD assets/snort.conf /etc/snort/
ADD assets/barnyard2.conf /etc/snort/
ADD assets/local.rules /etc/snort/rules/
ADD assets/pulledpork.conf /etc/snort/

# Run PulledPork
RUN bash -c "/usr/local/bin/pulledpork.pl -c /etc/snort/pulledpork.conf -l"

CMD ["/usr/bin/supervisord"]
