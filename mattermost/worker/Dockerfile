# Copyright (c) 2015 Spinpunch, Inc. All Rights Reserved.
# See License.txt for license information.
FROM ubuntu:18.04

# Copy over files
ADD https://releases.mattermost.com/5.21.0/mattermost-team-5.21.0-linux-amd64.tar.gz /
RUN cd /var && tar -zxvf /mattermost-team-5.21.0-linux-amd64.tar.gz && rm /mattermost-team-5.21.0-linux-amd64.tar.gz

ADD docker-entry.sh /var/mattermost/bin/docker-entry.sh
RUN chmod +x /var/mattermost/bin/docker-entry.sh

# Create default storage directory
RUN mkdir /var/mattermost/data

# link log file to stdout
RUN ln -s /dev/stdout /var/mattermost/logs/mattermost.log

ENTRYPOINT ["/var/mattermost/bin/docker-entry.sh"]

# Expose port 80
EXPOSE 80
