FROM ghcr.io/nesquena/hermes-webui:latest AS webui
FROM nousresearch/hermes-agent:latest AS agent
FROM webui
COPY --from=agent /opt/hermes /opt/hermes
RUN rm -rf /opt/hermes/.venv /opt/hermes/.git /opt/hermes/__pycache__
# make agent install lock readable: hermeswebui staging rsync must read it (base image ships root:600)
RUN chmod a+r /opt/hermes/tools/.install.lock
RUN test -f /opt/hermes/pyproject.toml && test -f /apptoo/server.py
