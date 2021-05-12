# Copyright 2021 walt@javins.net
# Use of this code is governed by the GNU GPLv3 found in the LICENSE file.
FROM gcr.io/distroless/base
EXPOSE 80
ADD build/drone-fork-approval-extension /
ENTRYPOINT ["/drone-fork-approval-extension"]
