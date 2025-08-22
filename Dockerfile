FROM python:3.12-slim
WORKDIR /app
COPY . /app
RUN pip install --no-cache-dir . && useradd -ms /bin/bash runner
USER runner
ENTRYPOINT ["snailpath"]
