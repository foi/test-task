FROM crystallang/crystal:1.7.3-alpine as builder
COPY . /app/
WORKDIR /app/
RUN shards build test-task --static --release

FROM alpine:3.17
COPY --from=builder /app/bin/test-task /bin/
EXPOSE 8080
CMD /bin/test-task