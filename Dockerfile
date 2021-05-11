FROM gcr.io/distroless/base
EXPOSE 80
ADD build/drone-fork-approval-extension /
ENTRYPOINT ["/drone-fork-approval-extension"]
