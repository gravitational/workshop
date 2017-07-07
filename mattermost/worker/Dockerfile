# Copyright (c) 2015 Spinpunch, Inc. All Rights Reserved.
# See License.txt for license information.
FROM ubuntu:14.04

# Copy over files
ADD https://releases.mattermost.com/2.1.0/mattermost-team-2.1.0-linux-amd64.tar.gz /var

ADD docker-entry.sh /var/mattermost/bin/docker-entry.sh
RUN chmod +x /var/mattermost/bin/docker-entry.sh

# Create default storage directory
RUN mkdir /var/mattermost/data

ENTRYPOINT ["/var/mattermost/bin/docker-entry.sh"]

# Expose port 80
EXPOSE 80
